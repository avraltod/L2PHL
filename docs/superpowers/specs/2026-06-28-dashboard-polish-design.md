# Dashboard Polish — Design Spec

**Date:** 2026-06-28 · **Status:** approved · **Sub-project 5** of the QC "new-delivery workflow" (1✓ 2✓ 3✓ 4✓; **5 polish ← this**; 6 QC→storyline).

## Purpose

Make the dashboard reflect the issue *lifecycle* visually, so accepted/resolved issues stop colouring modules, and the new issue UI is self-explanatory. Three `gen_dashboard.py` edits, no backend/data change.

## Items

**1. Module-card colour driven by OPEN issues + missing-data.** Currently the card chip + border use `module_summary.rag` (raw skip/mandatory/missing thresholds) — a module stays red even after its issues are `accepted`/`wontfix`. New:
```
rag = worst( ISUM[m].headline ,  missing%≥30→red / ≥10→yellow / else green )
```
The skip/mandatory/oor problems are now lifecycle-aware (via the issue layer); a high missing-% still keeps a module amber/red so no data gap is hidden. The "Why red/yellow" line is rewritten to its true drivers: `N open issue(s)` · `worst variable X% missing`. The raw stat lines (Skip violations / Mandatory missing / Max missing) and the per-round strip + "Issues: N open" line stay.

**2. Strip legend.** A one-line legend above the module grid: `■ open firm issue · ■ open · ■ closed · ■ clean` (red/yellow/grey/green idots).

**3. Issues-page summary.** A verdict-breakdown line at the top of the Issues page (e.g. `By verdict: A2:2 · B:1 · D:13 · REVIEW:2`) so the page leads with the shape of the work.

## Verification

No live browser available. Each edit verified by: regenerate the dashboard cleanly · `node --check` the embedded script · grep the new markup · for item 1, a `node` eval of the `worst()` rag formula across (issue-status × missing%) combinations to confirm the precedence. Pixel-level visuals deferred to the user opening the file.

## Out of scope

Layout/typography overhaul, dark-mode, a dashboard "Delivery" panel (separate), anything requiring live browser tuning.
