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
