# Delivery Changelog — Design Spec

**Date:** 2026-06-28 · **Status:** approved · **Sub-project 3** of the QC "new-delivery workflow" (1 issue-core ✓, 2 dashboard ✓, 4 firm-report ✓, **3 orchestration ← this**, 5 polish, 6 QC→storyline).

## Purpose

Make processing a new firm data delivery tell you **what changed in the issue landscape** — which issues the firm RESOLVED, which are NEW, which REGRESSED — and fold the firm-tracker regeneration into the run. Closes the loop from [[issue-intelligence-core]]: the lifecycle (auto-verify/reopen) becomes a visible per-delivery changelog so fixed issues are credited and regressions surface.

## Core mechanism: snapshot + diff

Each `new_delivery` run saves a **snapshot** of the issue state to `cache/issue_snapshots/<YYYYMMDD-HHMMSS>.json` = `{key: {status, verdict, total, open}}` (gitignored; `cache/` is ignored). A run diffs the **current** `issues.json` against the **most recent prior snapshot** with set logic on issue keys (open = status in OPEN_STATES):

| Category | Definition | Meaning |
|----------|-----------|---------|
| Resolved | `prev_open − current_open` | firm fixed it (closed in registry, or flag cleared/gone) |
| New | `current_open − prev_keys` | open now, never seen before |
| Regressed | `current_open ∩ (prev_keys − prev_open)` | open now, was closed last delivery (reopened) |
| Still open | `current_open ∩ prev_open` | open in both |

First run has no prior snapshot → baseline (everything "new"). Snapshots are taken **only on `new_delivery` runs**, not on every pipeline rebuild, so the diff is per-*delivery*.

## Entry point — `new_delivery.py`

1. Find the latest prior snapshot (before changing anything).
2. If `--rebuild`: run `update_pipeline.py --all` (subprocess) so data + issues.json are fresh. Otherwise assume the pipeline already ran.
3. Diff prior snapshot vs current `issues.json`.
4. Save the new snapshot.
5. Regenerate the firm tracker (`build_firm_report.main()`).
6. Print a one-line summary and write a dated changelog `output/L2PHL_CATI_Delivery_Changelog_<date>.md`.

Also exposed as `qc_issue.py delivery [--rebuild]`.

## Changelog format (markdown + console)

```
# L2PHL CATI — Delivery Changelog
**Delivery 2026-06-28** (vs prior 2026-05-30): 2 resolved · 1 new · 0 regressed · 15 still open

## Resolved (firm fixed) (2)
- `M05/ia3/…` (was A2) — gone (flag cleared)
## New (1)
- `M07/h4/…` (A2 · firm-field) — <label>
## Regressed (reopened) (0)
_none_
## Still open (15)
M00:6, M01:3, M04:6
```
Console: `Delivery 2026-06-28: 2 resolved · 1 new · 0 regressed · 15 still open  | changelog -> …md`.

## Build (3 tasks)

- `scripts/delivery_diff.py` — pure `snapshot(issues)`, `diff(prev, issues)`, `format_changelog(diff, today, prev_date)`. Unit-tested.
- `scripts/new_delivery.py` — `run(rebuild, today)` orchestrator + `main()`. Smoke-verified (run twice: baseline then no-change → 0/0/0).
- `scripts/qc_issue.py` — add `delivery [--rebuild]` subcommand.

## Testing

- `delivery_diff`: pure, TDD — snapshot shape; the four diff categories; empty-prev baseline; changelog formatting.
- `new_delivery`: smoke — first run writes a baseline snapshot + changelog (+ tracker); second run with no data change → 0 resolved / 0 new / 0 regressed, all persisting.

## Out of scope (later)

- A dashboard "Delivery" panel (sub-project 5 polish). Pulling masters from Google Drive (manual). Emailing the changelog. Per-round delivery history UI.
