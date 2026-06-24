# CATI Storyline Reproducibility — Design Spec

**Date:** 2026-06-24
**Author:** AP (Avralt-Od Purevjav)
**Scope:** Part B of the workflow-optimization effort, **reference pipeline only**: the CATI panel storyline (`CATI/Analysis/SL/l2p_cati_story.html`). The pattern is built here first, then replicated to other deliverables (CAPI baseline story, dashboard, deep dives) in their own spec/plan cycles.
**Status:** Approved design → ready for implementation plan.
**Predecessor:** Part A (file-organization cleanup) — merged to `main` (`3c4c27e`).

## Problem

Numbers reach the CATI storyline through **three manual transcription hops**:

```
Stata log  →(hand-typed)→  sl_stats.json  →(hand-typed)→  const DATA + prose in HTML
```

Specifics found in the current code:
- `l2phl_master_analysis_v2.do` (697 lines) computes every headline stat but **writes no JSON** — its "exports to sl_stats_v2.json" header is aspirational; it only prints to the Stata log. So `sl_stats.json` is hand-typed from the console.
- The HTML carries a **hand-maintained `const DATA = {…}`** literal (charts) **plus** prose/KPI numbers hardcoded separately (e.g. `41% → 18%`, `108.7M`, `2,470` — the same value repeated in 3–5 places).
- The do-file even records a past drift bug: `sl_stats.json said 15.0% → correct 29.7%`.
- File-naming drift: `sl_stats.json` (2026-03-22, stale), `sl_stats_v2.json` (2026-05-28, live), `sl_stats_v2_R.json` (absent).

Result: re-running the analysis is fragile, and the HTML silently drifts from Stata. The two named pains are **re-running Stata** and **hand-editing the HTML**.

## Decisions (locked)

1. **Reference pipeline = CATI storyline.** Build the full pattern here, replicate later.
2. **Single source of truth = `sl_stats.json`.** One canonical file; retire `_v2`/`_v2_R` suffixes (overwritten fresh each run; git is the history).
3. **Stata emits the JSON directly** via an inline `stat_put` emitter in the master do-file (option A — no recomputation, keys map 1:1 to HTML bindings).
4. **HTML numbers are build-time-injected** (option A) — charts and prose bind to JSON keys; `build_story.py` fills them; output stays a self-contained single file.
5. **One orchestrator command** runs the chain; default Stata invocation is **batch** so it runs without a Claude session. Stata run is included (`--stata`).
6. **Verification gate** checks all three layers agree; the R script is an optional independent cross-check, not a build dependency.

## Architecture

```
 pooled .dta ──▶ Stata master (+ stat_put) ──▶ sl_stats.json ──▶ build_story.py ──▶ l2p_cati_story.html ──▶ verify
                 computes AND writes JSON      SINGLE SOURCE      injects bindings    self-contained        all 3 agree? else FAIL
```

## Components

### 1. Stata emitter — `_stat_emit.do`

A reusable program `include`d at the top of the master do-file. API:

```stata
stat_open  "CATI/Analysis/SL/sl_stats.json"
stat_put   "fies.mod_sev_r1" = r(mean)          // scalar; dotted key → nested path
stat_arr   "fies.food_trend"  41.0 31.0 26.8 21.5 18.2    // array (trend series)
stat_obj   "sev_macro"  NCR 66.3  Luzon 60.0  Visayas 42.7  Mindanao 37.0   // label→value object
stat_close                                       // assemble + write valid nested JSON
```

- `stat_open` initialises an accumulator; each call appends a typed entry keyed by a **dotted path**; `stat_close` writes well-formed nested JSON via pure Stata `file write` (no community commands).
- One `stat_put` is dropped next to each headline stat **where it is already computed** — analysis logic is not restructured.
- **Raw values only** — Stata emits unformatted numbers; display formatting lives in the HTML binding.
- **Fail-fast:** `stat_close` errors on a duplicate key or a missing/`.` value.

### 2. Canonical artifact — `sl_stats.json`

Single nested JSON mirroring the current `const DATA` (chart series/objects) plus scalar headline numbers. The **key namespace is the contract** between Stata and HTML, documented in `CATI/Analysis/SL/docs/sl_stats_schema.md` (every key, type, meaning).

### 3. HTML bindings (one-time refactor of `l2p_cati_story.html`)

- **Charts:** replace the hand-written `const DATA = {…}` with an injected block:
  ```html
  <script id="sl-data" type="application/json">{ /* injected */ }</script>
  <script>const DATA = JSON.parse(document.getElementById('sl-data').textContent);</script>
  ```
  Chart code keeps reading `DATA.fies_items_trend` unchanged.
- **Prose & KPI numbers:** wrap each in a bound span:
  ```html
  fell from <span data-stat="fies.mod_sev_r1" data-fmt="pct0">41%</span>
  to <span data-stat="fies.mod_sev_r5" data-fmt="pct1">18.2%</span>
  ```
  Inner text is a last-built preview; the builder rewrites it. A key may appear many times and all stay in sync.
- **Format vocabulary (`data-fmt`):** `int`, `intcomma` (`2,470`), `pct0`/`pct1` (`41%`,`18.2%`), `millions1` (`108.7M`), `peso` (`₱19,497`), `ppt` (`23`), `raw`.

### 4. `build_story.py`

1. Read `sl_stats.json`.
2. Inject it into the `#sl-data` block.
3. For each `data-stat` span: resolve the dotted path, format per `data-fmt`, rewrite the span text.
4. Write the file back (still one self-contained HTML).
- **Idempotent**; **fails loudly** on any missing key or unknown `data-fmt`.

### 5. Verification — `build_story.py --check` (read-only)

- **Completeness:** every `data-stat` key and injected chart key resolves in `sl_stats.json`.
- **Orphans:** every JSON key is consumed by the HTML (flags computed-but-unshown stats and typos).
- **Agreement:** each rendered span value equals the formatted JSON value (catches a stale build).
- **Optional `--cross-check`:** diff against the R script's JSON beyond a tolerance; surfaced as warnings.

### 6. Orchestrator — `scripts/build_cati_story.py`

```
python3 scripts/build_cati_story.py            # JSON → build → verify
python3 scripts/build_cati_story.py --stata    # run Stata master (batch) first
python3 scripts/build_cati_story.py --check     # verify only, no write
```
`--stata` shells `stata-mp -b do l2phl_master_analysis.do`; because Stata batch returns 0 even on error, it greps the log for `r(###);` and aborts with the log tail on failure. Then build, then verify.

## Code organization

- `CATI/Analysis/SL/l2phl_master_analysis.do` — the live master, **renamed** from `l2phl_master_analysis_v2.do` (resolves its `_v2` suffix per decision 2) and extended with `stat_put` calls; the stale `l2phl_master_analysis.do` (and `_v2`) go to `_attic/`.
- `CATI/Analysis/SL/_stat_emit.do` — Stata emitter.
- `CATI/Analysis/SL/build_story.py` — story-specific bind/inject/verify entry.
- `CATI/Analysis/SL/docs/sl_stats_schema.md` — key namespace.
- `CATI/Analysis/SL/sl_build/` — shared, reusable module: `formatter.py` (the `data-fmt` vocabulary), `resolver.py` (dotted-path lookup), `injector.py` (DATA block + span rewriting). These are deliverable-agnostic so the next pipeline (CAPI baseline story) reuses them.
- `scripts/build_cati_story.py` — orchestrator (tracked top-level `scripts/`, next to `tidy.py`).
- Tests in `CATI/Analysis/SL/tests/` (Python) + a batch round-trip do-file for the emitter.

## Testing (TDD)

- **Formatter:** unit test per `data-fmt` (`108667043 → 108.7M`; `18.2 → 18.2%`; `2470 → 2,470`; etc.).
- **Resolver:** dotted-key lookup incl. missing-key error.
- **Injector:** golden-file — sample `sl_stats.json` + template fragment → expected rendered HTML.
- **Verify:** drifted fixture fails; matched fixture passes; orphan key detected.
- **Emitter:** batch round-trip do-file — `stat_put`/`stat_arr`/`stat_obj` a few values, read back the JSON, assert structure and fail-fast on duplicate key.

## Error handling

- Build aborts on missing key / unknown format, naming the offending `data-stat`.
- Verify exits non-zero with a precise diff list (drifted, unbound, orphan).
- `--stata` aborts on detected `r(###);` in the log and prints the tail.

## Acceptance criteria

- Running `python3 scripts/build_cati_story.py --stata` regenerates `sl_stats.json` from `.dta` and produces a `l2p_cati_story.html` whose every chart and prose number derives from that JSON.
- No number is hand-edited in the HTML; changing a stat means editing the analysis and re-running.
- `--check` passes on a fresh build and fails on any introduced drift (stale HTML, missing/typo key, orphan stat).
- The shared `sl_build/` module is deliverable-agnostic (no CATI-specific assumptions), ready to back the CAPI pipeline next.
- `sl_stats.json` is the only stats file; `_v2`/`_v2_R` retired.

## Out of scope (this spec)

- CAPI baseline story / dashboard / deep dives (replicate later, own specs).
- Changing *which* statistics are reported or their methodology — this is plumbing, not analysis.
- Headless-Stata environment setup beyond invoking the existing batch binary.

## Next

After this reference pipeline is implemented and verifying green, replicate the `sl_build/` pattern to the CAPI baseline storyline (its own brainstorm → spec → plan).
