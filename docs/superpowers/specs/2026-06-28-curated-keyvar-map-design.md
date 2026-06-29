# Curated Key→Variable Map for Aggregate Claims — Design Spec

**Date:** 2026-06-28 · **Status:** approved · deeper v2 of variable-level grounding ([[issue-intelligence-core]]).

## Problem

`_var_of` extracts the embedded Kobo variable for keys like `no_contract_a16eq2`→`a16`, but **aggregate** keys (`sample.hh_r1`, `fies.mod_sev_r5`, `views.life_sat_r5`) embed none, so they fall back to conservative module-level grounding — caveated by *any* open firm issue in the module. On current data that mis-flags the `sample.hh_*` counts via M01's `d26_2` (a migration-destination issue that doesn't change a household *count*).

## Curated map (derived from `l2phl_master_analysis.do`)

A `KEY_VARS` map gives the underlying Kobo variable(s) each aggregate stat is computed from:

| Key / prefix | Vars | Source (do-file) |
|---|---|---|
| `sample` | `[]` (structural interview count) | `count if round==N` (L100–101) |
| `fies` | `f08_a, f08_b, f08_c, f08_d, f08_e` | rowtotal FIES items (L145–156) |
| `views` | `v1` | mean v1 (L835–845) |
| `employment.emp_status` | `a1, emp_status` | a1 R1–R3, emp_status R4–R5 (L64) |
| `shocks.any_shock` | `sh1` | `gen any_shock=(sh1==1)` (L270) |
| `shocks.water_disruption`, `shocks.mean_water_days` | `sh3` | `gen water_dis=(sh3==1)` (L281) |
| `health.total_individuals` | `[]` (count) | — |

`[]` = mapped to *no data variable* → never caveated (a count isn't affected by a field error). **Unmapped** keys (e.g. `shocks.elec*`, `shocks.internet*`, `health.philhealth*`) keep today's module-level fallback (conservative).

## Logic

In `ground()`, when a key has no embedded variable (`_var_of` is None): look up `_curated_vars(key)` by **longest-prefix** match. If it returns a list (possibly empty) → variable-scoped (caveat only by issues on those vars; empty → never). If None (unmapped) → module-level fallback.

## Impact (current data)

`sample.hh_*`/`total_hh` → `[]` → grounded (d26_2 doesn't match). Every other group already clean. **Caveats 3 → 0; storyline badges 5 → 0** — the honest result: none of the storyline's claimed statistics rest on the 3 open firm issues. Badges reappear if a relevant issue arises (e.g. an `a1` issue → `emp_status` claims; an `f08_*` issue → FIES claims).

## Changes

- `scripts/grounding.py` — add `KEY_VARS`, `_curated_vars(key)`; in `ground()` use embedded var, else curated vars (list incl. `[]`), else module fallback.
- Regenerate the grounding report + storyline badges (→ 0).

## Testing

- `grounding`: TDD — curated `sample` (count, `[]`) is grounded despite a module issue; curated `fies` is caveated by an `f08_*` issue; curated `employment.emp_status` caveated by an `a1` issue; an *unmapped* aggregate (`health.philhealth`) still falls back to module-level. Existing embedded-var + clean-claim tests still pass; two existing tests that assumed module-fallback for now-curated groups are updated.
- end-to-end: grounding → 0 caveats; badges → 0; `build_story.py --check` still CHECK OK.

## Out of scope

Completing the map for the remaining unmapped aggregates (`elec`, `internet`, `philhealth`) — left at conservative module fallback; the user can extend `KEY_VARS`. Boolean-aware rule_C.
