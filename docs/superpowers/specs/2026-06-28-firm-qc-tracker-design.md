# Firm QC Tracker — Design Spec

**Date:** 2026-06-28 · **Status:** approved · **Sub-project 4** of the QC "new-delivery workflow" (1 issue-intelligence core ✓, 2 dashboard rendering ✓, 3 orchestration, **4 firm-report generator ← this**, 5 dashboard polish, 6 QC→storyline).

## Purpose

Turn the issue-intelligence layer into a firm-actionable Excel handoff: one row per *open, firm-owned* QC issue, stating what's wrong, the root cause, the exact fix, and empty columns for the firm to respond in. Closes the loop from detection ([[issue-intelligence-core]]) to an actionable artifact the local firm works from.

## Source & filter

Reads `CATI/Analysis/QC/cache/issues.json` (records emitted by `build_issues.py`). A row is included iff:
- `report_to_firm == True`, **and**
- `status in OPEN_STATES` (`new`, `acknowledged`, `fix-pending`, `reopened`) — i.e. not yet `resolved`/`wontfix`/`accepted`.

On current data this yields 3 rows: M04 `a18`, M04 `a19` (A2 field leaks), M01 `d26_2` (B processing gap). Resolved/wontfix issues drop off automatically; new firm issues appear automatically.

## Output

`CATI/Analysis/QC/output/L2PHL_CATI_Firm_QC_Tracker_<YYYYMMDD>.xlsx` (date = run date via `datetime.date.today()`). One sheet "Firm QC Tracker". Rows sorted by **owner → module → variable**. A title row + a "Generated <date> · N open firm issues" summary line above the table.

## Columns (one row per issue)

| Col | Source (record field) |
|-----|----------------------|
| # | running index |
| Module | `module` |
| Variable | `variable` |
| Issue | `label` (the rule that's violated) |
| Rounds affected | `counts_by_round` → `"R5:9, R6:12"` (nonzero, round-sorted) |
| Total flagged | sum of `counts_by_round` values |
| Root cause | `verdict` mapped: A1→"Questionnaire / Kobo skip logic", A2→"Field / interviewer", B→"Do-file / pooler processing" |
| Owner | `owner` (firm-questionnaire / firm-field / firm-dofile) |
| Evidence — Kobo gate | latest `evidence.kobo.relevant_by_round` value, + `gate_refs_missing` if any (else "(var not in Kobo)") |
| Evidence — Do-file | `evidence.dofile.ever_touched` → "touched by a round do-file" / "not touched" |
| Recommended fix | `notes` (curated via `qc_issue.py set … --notes`; blank until a note is added) |
| Status | `status` |
| **Firm response / fixed?** | empty — firm fills |
| **Date fixed** | empty — firm fills |

`severity` is intentionally omitted (not carried on the record); rounds + total + root cause convey priority.

## Styling (openpyxl — already a dependency)

- Header row: bold white on WB-navy `#002244`, frozen (`freeze_panes` below header).
- The two response columns (last two): light-yellow fill `#FFF8DC` to signal "firm fills these."
- Column widths sized to content; wrap on the long text columns (Issue, Kobo gate, Recommended fix).
- Title row merged across, 14pt bold.

## Build & wiring

- `scripts/firm_report.py` — pure `firm_rows(records) -> list[dict]` (filter + shape). Unit-tested.
- `scripts/build_firm_report.py` — `main()` reads `issues.json`, calls `firm_rows`, writes the styled xlsx via openpyxl. Verified by generating and reading back with openpyxl.
- `scripts/qc_issue.py` — add a `firm-report` subcommand that invokes the builder, so the analyst runs `python3 scripts/qc_issue.py firm-report` after curating notes.
- NOT wired into `update_pipeline.py` — the tracker is an on-demand deliverable (generated when handing off to the firm), not every pipeline run.

## Testing

- `firm_rows`: pure, TDD — filters correctly (open firm only; excludes closed and non-firm), shapes rounds string, maps root cause, pulls fix from notes, sorts by owner/module/variable.
- `build_firm_report`: write a workbook, read it back with openpyxl — assert the header labels, the 3 data rows, the tinted response columns, and the title/summary.
- `qc_issue firm-report`: smoke (invokes builder, file appears).

## Out of scope (later)

- Markdown/Word variants (sub-project deferred). Auto-emailing the firm. Per-round historical trackers. Carrying `severity` onto the record (a build_issues change).
