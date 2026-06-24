<!-- CATI/Analysis/SL/docs/sl_stats_schema.md -->
# sl_stats.json — key namespace (Stata ↔ HTML contract)

`sl_stats.json` is the single source of truth for the CATI storyline. Stata writes
it (`_stat_emit.do`); `build_story.py` injects it into `l2p_cati_story.html`.

## Top level
- `_meta` — generation metadata (date, rounds, source do-file).
- `charts` — chart data; keys equal the `DATA.*` names the HTML chart code reads.
- `sample`, `fies`, `shocks`, `finance`, `health`, `employment`, `views` — scalar
  groups bound to prose/KPI `data-stat` spans.

## Conventions
- Raw values only (no `%`, `₱`, or thousands separators) — formatting lives in `data-fmt`.
- A scalar key path (e.g. `fies.mod_sev_r1`) is the exact string used in
  `<span data-stat="fies.mod_sev_r1">`.
- Percentages stored as the number (41.0 = "41%"); pesos as integer pesos; counts as integers.
- `charts.fies` (the FIES-items chart object) and top-level `fies` (the prose
  scalars) are different paths — they do not collide.

## Scalar keys (seed set — extend as the HTML binds more)
| Key | Meaning | Example | Typical data-fmt |
|-----|---------|---------|------------------|
| sample.total_hh | Unique panel households | 1917 | intcomma |
| fies.mod_sev_r1 | Mod-sev food insecurity, R1 (%) | 41.0 | pct0 |
| fies.mod_sev_r5 | Mod-sev food insecurity, R5 (%) | 18.2 | pct1 |
| fies.change_ppt | R1→R5 drop (ppt) | 22.8 | ppt |
| fies.severe_r5 | Severe food insecurity, R5 (%) | 3.7 | pct1 |
