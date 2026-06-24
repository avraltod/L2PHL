# CAPI Baseline Storyline Reproducibility — Design Spec

**Date:** 2026-06-24
**Author:** AP (Avralt-Od Purevjav)
**Scope:** Replicate the reproducibility pattern (established for the CATI storyline) to the **CAPI baseline storyline** `CAPI/Analysis/SL/html/l2phl_baseline_story.html` — **prose/KPI numbers only** this pass. Charts and the separate wealth chapter are out of scope.
**Status:** Approved design → ready for implementation plan.
**Predecessors:** Part A (file organization, `3c4c27e`), Part B/CATI (CATI storyline reproducibility, `610e586`). Reuses the `sl_build/` module built there.

## Problem

The CAPI baseline storyline's prose numbers (`108.7M`, `2,470`, "median age 25", `40.6%`, `₱46,834`) are hardcoded in the HTML and hand-edited, drifting from Stata — the same problem solved for CATI.

**The head start:** unlike CATI, `CAPI/Analysis/SL/do/11_L2PHL_CAPI_R00_replication.do` already exports **164 `ID | Label | Value` rows** to `CAPI/Analysis/SL/results/storyline_results_stata.md` (e.g. `R01_POP | Weighted population | 108667043`). The prose numbers are already machine-readable with stable IDs — no Stata emitter is needed.

**The difference from CATI:** the CAPI HTML (~3,294 lines) has **no single `const DATA` block**; chart data is inline literals scattered across ~12 separate `new Chart({data:{…}})` calls. Charts are therefore deferred this pass.

## Decisions (locked)

1. **Source of truth = the existing `storyline_results_stata.md`** (the 164-row `ID|Value` table). No new JSON artifact; the `.md` is parsed on each build. The user keeps producing it by running the replication do-file as today.
2. **Scope = prose/KPI numbers only.** Charts stay hand-edited; the wealth chapter is a separate effort.
3. **Reuse `sl_build/`** (formatter, resolver, injector) from the CATI build — promoted to a shared location so both deliverables import one copy.
4. **Prose binds to IDs:** `<span data-stat="R01_POP" data-fmt="millions1">108.7M</span>`.
5. **Injector chart injection becomes optional** (`chart_key=None` → skip the `#sl-data` step) so `sl_build` supports a prose-only deliverable.
6. **Same verification gate:** `--check` flags drift / unbound spans; orphan IDs (rows not shown in prose) are warnings.
7. **Target file only:** `l2phl_baseline_story.html`.

## Architecture

```
run 11_replication.do  →  storyline_results_stata.md  →  build_capi_story.py  →  l2phl_baseline_story.html
   (Stata, as today)       (164 ID|Value rows =          (parse md → inject     (prose numbers bound;
                            SINGLE SOURCE OF TRUTH)        prose → verify)         charts untouched)
```

The `.md` table is the single source of truth; `build_capi_story.py` parses it into `{ID: value}` on each run and injects. IDs are flat keys (no dotting). Charts are skipped (`chart_key=None`).

## Components

### 1. `sl_build/md_parser.py` (new, reusable)
Parse the `| ID | Label | Value |` markdown table → `{ID: value}` (float where numeric, raw string otherwise). Ignores the header row, the `:---` separator, section headings (`## …`), and blank lines. One responsibility: table → dict.

### 2. `sl_build/injector.py` (small enhancement)
`inject(html, data, chart_key=None)`. When `chart_key is None`, skip the `#sl-data` block entirely and only rewrite `data-stat` spans (the unbound-span sweep, missing-key error, and idempotency all still apply). With a `chart_key`, behavior is unchanged (CATI path).

### 3. `sl_build/` promotion (one-time refactor)
Move `CATI/Analysis/SL/sl_build/` → a shared **`scripts/sl_build/`** that both `CATI/Analysis/SL/build_story.py` and `CAPI/Analysis/SL/build_capi_story.py` import. Update every importer and the CATI tests' `sys.path` so the CATI suite stays green. No fork of the module.

### 4. `CAPI/Analysis/SL/build_capi_story.py` (new, CAPI entry)
Mirror of `build_story.py`: read `storyline_results_stata.md`, parse via `md_parser`, `inject(html, data, chart_key=None)` (build) or compare (`--check`). Build fails on a missing `data-stat` ID; `--check` fails on drift, warns on orphans.

### 5. `scripts/build_capi_story.py` (new, orchestrator)
Sibling of `build_cati_story.py`. Default: parse the existing `.md` → build → verify. `--check`: verify only. `--stata`: best-effort run of `11_L2PHL_CAPI_R00_replication.do` first, with the same unlicensed-batch detection and "run it in your licensed Stata" message.

### 6. HTML refactor of `l2phl_baseline_story.html` (mechanical)
Wrap each prose/KPI number in a `data-stat="ID"` span (ID from the matching `.md` row) with a `data-fmt`. **Guardrail:** the formatted `.md` value must equal the number originally shown — a mismatch is flagged (real discrepancy or wrong ID), never silently changed, and that number is left unwrapped pending the user's decision. Section by section; the verifier is the acceptance gate. Charts untouched.

## Format vocabulary
Reuse the existing `data-fmt` set: `int`, `intcomma`, `pct0`, `pct1`, `millions1`, `peso`, `ppt`, `raw`. The `.md` stores raw values (`108667043`, `40.56`), so formatting lives in the binding exactly as in CATI.

## Testing (TDD)
- `md_parser` — golden sample table → expected dict; numeric vs raw values; skips header / `:---` / `## headings` / blank lines.
- injector `chart_key=None` — spans rewritten, no `#sl-data` touched, unbound-span error still fires.
- `sl_build` promotion — full CATI suite green after the move (regression guard).
- `build_capi_story` — build then `--check` passes; drift fails; missing-ID errors.
- HTML — `--check` = CHECK OK after refactor; a deliberately wrong ID fails.

## Error handling
- Build aborts on a `data-stat` ID absent from the `.md`, naming the ID.
- `--check` exits non-zero on drift; warns (exit 0) on orphan IDs.
- `--stata` aborts with a clear message when batch Stata is unavailable/unlicensed.

## Acceptance criteria
- `python3 scripts/build_capi_story.py` rebuilds `l2phl_baseline_story.html` with every bound prose number sourced from `storyline_results_stata.md`; `--check` = CHECK OK.
- No bound prose number is hand-edited; changing one means editing the analysis and re-running the replication do-file.
- `sl_build/` is shared (one copy) and the CATI pipeline still passes `--check` + its full test suite.
- Charts and the wealth chapter are unchanged.

## Out of scope (this spec)
- CAPI chart data (the ~12 inline `new Chart` literals) — a focused follow-on.
- The wealth chapter (`l2phl_wealth_chapter.html`) and the 10 deep dives.
- Changing which statistics are reported or their methodology.

## Next
After prose is bound and verifying green, a follow-on can tackle CAPI charts (refactor the inline literals into an injectable block + emit their array/object data), reusing this same machinery.
