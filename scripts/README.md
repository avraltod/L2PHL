# scripts/

Tree-wide maintenance tooling (tracked, unlike `CATI/Analysis/QC/scripts/`).

## tidy.py — file-organization maintenance

```bash
python3 scripts/tidy.py --dry-run                 # writes tidy-manifest.{csv,md}
# review tidy-manifest.md; strike rows you disagree with in tidy-manifest.csv
python3 scripts/tidy.py --apply --csv tidy-manifest.csv
```

- One live file per slot (latest `@AP@`); others move to local `_attic/`.
- Fixes `L2PH`→`L2PHL` prefix typos; renames archive folders to `_attic/`.
- `FLAG` rows need a human decision (no canonical AP file, or two same-date AP files).
- Never deletes; writes a reversible `_attic/.tidy-log.csv`.

## build_cati_story.py — regenerate the CATI storyline

```bash
python3 scripts/build_cati_story.py --stata   # .dta -> sl_stats.json -> HTML -> verify
python3 scripts/build_cati_story.py           # rebuild HTML from existing sl_stats.json
python3 scripts/build_cati_story.py --check    # verify only (CI gate)
```

Numbers live only in `sl_stats.json` (Stata writes it via `_stat_emit.do`); never
hand-edit numbers in the HTML.

On this machine, batch Stata (`stata-mp -b`) is unlicensed, so `--stata` cannot
run the master here. Instead, run `CATI/Analysis/SL/l2phl_master_analysis.do` in
the GUI/MCP (licensed) Stata to refresh `sl_stats.json`, then run
`python3 scripts/build_cati_story.py` (no `--stata`) to rebuild and verify the HTML.

Run `python3 -m pytest scripts/tests/ -q` after editing.
