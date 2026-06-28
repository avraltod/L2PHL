# QC → Storyline Grounding — Design Spec

**Date:** 2026-06-28 · **Status:** approved · **Sub-project 6 (final)** of the QC "new-delivery workflow" (1✓ 2✓ 3✓ 4✓ 5✓; **6 ← this**).

## Purpose

Ground the CATI storyline's narrative claims in the QC issue state, per module **and round**, so before publishing the storyline the author knows which claims rest on data with open firm issues. Connects [[issue-intelligence-core]] to `CATI/Analysis/SL/l2p_cati_story.html`.

## The connection

The storyline is data-bound: every claim binds to a `sl_stats.json` key like `employment.emp_status_r5`. Two structural joins:
- **group → CATI module**: `sample→M01 · fies→M08 · shocks→M03 · finance→M06 · health→M07 · employment→M04 · views→M09` (curated map).
- **`_rN` suffix → round** (regex `_r(\d+)`; `f17`/`a16eq3` etc. are correctly *not* rounds).

For each claim, look up that module/round's QC state in `cache/issue_summary.json` (the per-round strip + headline) and `cache/issues.json` (open firm issues). A claim is a **caveat** if its module has an **open firm issue** (verdict A1/A2/B, open status) with a count in the claim's round (or any round, for non-round claims).

## v1 deliverable — author-facing grounding report

- `scripts/grounding.py` — pure `ground(stat_keys, issue_summary, issues) -> [{key, module, round, qc_status, open_firm_issues, grounded}]` + `GROUP_TO_MODULE` + `_round_of`.
- `scripts/build_grounding.py` — reads `sl_stats.json` + the QC caches, writes `output/L2PHL_CATI_Storyline_Grounding_<date>.md` (claims to caveat, with the offending issue keys; unmapped groups flagged) + console summary. A `--check` mode prints the caveats and returns nonzero if any (a pre-publish gate).
- `scripts/qc_issue.py grounding [--check]` hook.

**qc_status** = the strip colour for round-specific claims, else the module headline. **grounded** = no open firm issue affects the claim (D/REVIEW issues are structural/uncertain and do NOT caveat a substantive claim — only A1/A2/B do).

## Why a report, not inline badges

`l2p_cati_story.html` is drift-checked by `build_story.py` (strict injector); editing it risks the binding. The report connects the two systems safely and is what the author needs. Inline reader-facing badges (bound via the injector to a new `qc.*` stat group) are a clean v2 once the report's shape is proven.

## Testing

- `grounding`: pure, TDD — `_round_of` extraction; group→module + round join; caveat detection (open firm issue in the round); unmapped group; non-round → headline.
- `build_grounding`: smoke — generates the report against real caches; `--check` returns nonzero iff caveats exist.

## Out of scope (v2)

Inline storyline badges; per-claim round-exact recompute; auto-caveat text injection; grounding the CAPI storyline.
