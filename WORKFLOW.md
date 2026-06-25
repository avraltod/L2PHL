# L2PHL Workflow

How to work in this repo after the 2026-06 workflow optimization (file organization + reproducibility). For project background see [CLAUDE.md](CLAUDE.md).

---

## 1. Updating the CATI storyline (reproducible pipeline)

**Numbers live in exactly one place: `CATI/Analysis/SL/sl_stats.json`.** Stata writes it; the HTML reads it. You never hand-edit a number in the HTML.

```
edit l2phl_master_analysis.do  →  run it in Stata  →  sl_stats.json  →  build_cati_story.py  →  l2p_cati_story.html
   (change the analysis)          (writes the JSON)   (single source)   (injects + verifies)
```

### Routine update
1. Edit `CATI/Analysis/SL/l2phl_master_analysis.do` — each headline stat is emitted right where it's computed, e.g. `stat_put "fies.mod_sev_r1" = r(mean)`.
2. Run the master in your **licensed Stata (GUI or MCP)** — the batch binary is unlicensed on this machine. It writes `sl_stats.json` via `_stat_emit.do`.
3. Rebuild + verify:
   ```bash
   python3 scripts/build_cati_story.py
   ```
4. Drift gate (CI-style, no write):
   ```bash
   python3 scripts/build_cati_story.py --check     # CHECK OK, or fails loudly on drift
   ```

### Data prerequisites for the Stata run (must run where the data lives)
The reproducibility *tooling* is data-independent, but regenerating the numbers needs the full data environment — verified 2026-06-24 that neither runs end-to-end in a fresh checkout:
- **CATI:** the master needs `CATI/Analysis/HF/l2phl_M08_fies.dta` (FIES-coded: `f08_a…f08_e`, `mod_sev`, `food_sec`, `fies_score`). The repo's `l2phl_M08_food.dta` does **not** contain those variables — build/place the FIES dataset or repoint the M08 section (do-file lines 140, 964).
- **CAPI:** `11_…_replication.do` needs the baseline microdata in `CAPI/Round00/dta/` (`*_M01_roster.dta`, `*_M02_edu.dta`, …), which is gitignored and absent in a clean checkout. The wealth index (`CAPI/Analysis/SL/data/`) is present.

Run each in your environment where these exist, then `build_*_story.py --check` surfaces the value diffs. See memory `repro-stata-data-prereqs`.

**One-command status:** `python3 scripts/verify_repro.py` runs both drift gates, reports whether the FIES + Round00 datasets are present, and prints the exact next step — re-run it after dropping the data in.

### Adding a new number to the story
1. Add the key + value to `sl_stats.json` and document it in `CATI/Analysis/SL/docs/sl_stats_schema.md`.
2. Emit it from the do-file: `stat_put` (scalar), `stat_arr` (array), `stat_obj` (label→value), or `stat_objarr_open/row/close` (object-of-arrays trend).
3. Wrap the spot in the HTML: `<span data-stat="your.key" data-fmt="pct1">…</span>` (formats: `int intcomma pct0 pct1 millions1 peso ppt raw`).
4. Rebuild. `--check` confirms it bound.

### Tooling map
| File | Role |
|------|------|
| `CATI/Analysis/SL/_stat_emit.do` | Stata → JSON emitter (`stat_put/arr/obj/objarr`) |
| `CATI/Analysis/SL/sl_stats.json` | Single source of truth |
| `CATI/Analysis/SL/docs/sl_stats_schema.md` | Key namespace (Stata ↔ HTML contract) |
| `CATI/Analysis/SL/sl_build/` | Reusable formatter / resolver / injector (deliverable-agnostic) |
| `CATI/Analysis/SL/build_story.py` | Inject JSON into HTML; `--check` verifies |
| `scripts/build_cati_story.py` | Orchestrator: `[--stata] → build → verify` |

The drift gate catches: a number that didn't rebuild (drift), a `data-stat` key missing from the JSON (unbound, hard fail), and a JSON key never shown (orphan, warning).

---

## 2. Keeping the repo tidy (file organization)

One live `@AP@` file per slot; everything superseded goes to a local `_attic/`. Run any time clutter builds (e.g. each new round):

```bash
python3 scripts/tidy.py --dry-run                 # review tidy-manifest.md
python3 scripts/tidy.py --apply --csv tidy-manifest.csv
```

- Keeps the latest-dated `@AP@` file live; archives non-AP / older-dated / `_v2`-style duplicates.
- `RENAME-DIR` consolidates every `zzz`/`zArc`/`arch`/`arc`/`Attic` to one `_attic/`.
- `FLAG` rows need a human decision (no canonical AP file, or two same-date AP files) — never auto-moved.
- Never deletes; writes a reversible `_attic/.tidy-log.csv`.
- Convention auto-loads from `.claude/rules/file-organization.md`.

⚠️ **`_v2` is often the *newer* file here** — `tidy.py` treats version-suffixed files as superseded, so review those rows before applying.

---

## 3. What is still manual (not yet on the pipeline)

- **CAPI baseline story, dashboard, 10 deep dives** — still hand-edited HTML. The CATI storyline was the reference build; the `sl_build/` module is deliverable-agnostic and ready to replicate to these (own spec → plan when wanted).
- **CATI story: 14 stopgap charts + ~40 secondary numbers** — still hand-literal (`TODO(repro)` markers in the do-file; unbound prose numbers). They work but won't auto-update until wired.
- **3 flagged data discrepancies** await Stata verification (cover-₱300k, "saved" label, epilogue PhilHealth) — see project memory.

---

## Conventions (auto-loaded rules)

`.claude/rules/` holds path-scoped rules loaded by file type: `file-organization`, `survey-methodology` (Stata is authoritative; the diagnostic chain for wrong numbers), `stata-conventions`, `data-weights`, `stat-reporting`, `world-bank-style`, `branding`, `chart-conventions`, `html-editing`.

**Specs & plans** for this work: `docs/superpowers/specs/` and `docs/superpowers/plans/` (2026-06-23 file-organization, 2026-06-24 CATI reproducibility).
