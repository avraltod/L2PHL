# Variable-Level Grounding — Design Spec

**Date:** 2026-06-28 · **Status:** approved · v2 precision fix for sub-project 6 ([[issue-intelligence-core]] grounding) + the storyline badges.

## Problem

`ground()` caveats a storyline claim if ANY open firm issue touches its module/round. Too coarse: the contract-type employment claims (`a16`) are flagged by the open `a18`/`a19` (pension/benefits) issues — *different variables*. An `a18` data error doesn't affect the `a16` distribution, so those badges are false alarms.

## Refinement

`ground()` adds a per-claim variable check. Many stat keys embed their underlying Kobo variable:
`_var_of(subkey)` drops `eq<value>` then takes the last `[a-z]+\d+` token (excluding rounds): `no_contract_a16eq2 → a16`, `bank_acc_f17 → f17`, `oop_among_h9a → h9`; derived/aggregate keys (`hh_r1`, `mod_sev_r5`, `any_shock_r3`, `life_sat_r5`) → `None`.

A claim is a **caveat** iff an open firm issue (A1/A2/B) touches its **module AND round AND — when the claim embeds a variable — that variable** (base-insensitive, `_base` strips `_N`). Claims with no embedded variable keep today's conservative **module/round fallback**.

## Impact (current data)

- `employment.{verbal,written,no_contract,dont_know}_a16eq*` → `a16`; open M04 issues are `a18`/`a19` → no match → **no longer caveated** (4 keys / ~4 badges removed — correctly).
- `sample.{total_hh,hh_r1,hh_r3}` → no embedded var → module fallback → still caveated by M01 `d26_2` (conservative).
- Grounding caveats 7 → 3; storyline badges 9 → 5.

## Changes

- `scripts/grounding.py` — add `_var_of`, `_base`; restructure `ground()` to filter candidate firm issues per claim (module → round → variable); add `claim_var` to each row.
- Regenerate: `build_grounding` report + `build_storyline_badges` (removes the 4 employment badges; self-heals).

## Testing

- `grounding`: TDD — var-mismatch excludes (a16 claim vs a18 issue → grounded); var-match caveats (a16 issue → caveat); aggregate (no embedded var) falls back to module-level. Existing 6 grounding tests still pass.
- end-to-end: grounding report → 3 caveats (sample only); storyline badges → 5; `build_story.py --check` still CHECK OK.

## Out of scope (v2+)

A curated key→variable map for aggregate claims (`hh` → roster count vars) so even the sample claims get variable precision. Trailing-letter var normalization (`f13a` vs `f13`). Boolean-aware rule_C.
