# L2PHL Operational Manual — Design Spec

**Date:** 2026-07-16 · **Author:** Avralt-Od Purevjav · **Status:** design, pending user review
**Deadline driver:** WB ↔ firm turnover meeting, 2026-07-17

## Goal

Produce one polished PDF — *Listening to the Philippines (L2PHL) — Operational Manual* —
that lets a receiving team operate, maintain, and replicate the L2PHL survey program
(CAPI baseline + CATI panel), mirroring the L2SC Operational Manual's structure and
World Bank Poverty & Equity styling, and **weighted toward the CATI QC dashboard and
weighting** so it directly answers the firm's turnover questions.

It is an **operational manual, not a results report** (findings live in the storylines/
dashboards, which are cataloged and shown how to rebuild, not summarized here).

## Reference inputs

- **Template to mirror:** `~/iDrive/GitHub/L2SC/L2SC_Guideline_v4.pdf` (32 pp). No `.tex`
  source exists locally → preamble is rebuilt from scratch.
- **Turnover questions to answer:** `~/Downloads/L2PHL (Project TIPON) - Consolidated
  Questions for WB Turnover Meeting.pdf` (reproduced verbatim in Annex B).
- **Repo sources:** `CAPI/` and `CATI/` folders, `CATI/KOBO/` XLSForms,
  `CATI/Field Reports/` (8 Field Documentation Summary PDFs, Baseline+R1 → R8),
  `CAPI/Analysis/SL/tex/L2PHL_WEIGHTING_TECHNICAL_NOTE.tex` (weight construction),
  the QC pipeline under `CATI/Analysis/QC/`, and the CATI analysis/weighting do-file
  `CATI/Analysis/do/hf_l2phl_analysis@AP@20260709.do`.
- **S2S income imputation:** `CAPI/S2S/` — `S2S_PHL_note.docx` (methodology note),
  `s2s_diagnostics.xlsx`, and `target_hh_imputed.dta` (the source copied to `HF/R00/`).

## Decisions (locked with user)

1. **Scope:** full manual mirroring L2SC, with CATI QC-dashboard + weighting sections
   deepened to answer every turnover question. One PDF.
2. **Turnover questions:** deep operational sections **plus** an appendix crosswalk
   ("Turnover Questions — Answered": each question → 1–2 sentence direct answer + section
   pointer).
3. **CAPI / Part I:** full CAPI operational depth; **condense** TOR/Vendor setup; mark
   repo gaps as "noted for a future revision" (L2SC convention). CATI + dashboard are the
   deep core.
4. **Storylines/dashboards/deep dives:** document as **deliverables + rebuild pipeline**
   (catalog + production workflow do→results→HTML), in Parts II/III + Annex A. No findings.

## Format & tooling

- **LaTeX → PDF** via `tectonic`. Custom preamble replicating the L2SC look:
  - `xcolor` WB navy `#002244` / blue `#009FDA`; blue section headings via `titlesec`.
  - `tcolorbox` for two box styles: light-blue **procedure boxes** (step-by-step) and
    grey **Reference Documents** boxes (exact repo paths). A third "Recommendation/Note"
    callout as in L2SC.
  - `fancyhdr` header (`L2PHL Operational Manual` + page) and footer
    (`World Bank – Poverty and Equity Global Practice`).
  - `booktabs` tables; `hyperref` blue TOC links; Latin Modern / matching serif.
- **Source file:** `CAPI/Analysis/SL/tex/L2PHL_Operational_Manual.tex`
  **Output PDF:** `CAPI/Analysis/SL/tex/L2PHL_Operational_Manual.pdf` (compiled; also the
  hand-over artifact). *(Path/author confirmable at review.)*
- Numbers and file paths are Stata/repo-sourced; nothing invented. Absent material is
  flagged, not fabricated.

## Document structure

### Front matter
- Title page (title, subtitle, author line, date, Project TIPON codename).
- Contents (hyperlinked).
- **Scope box:** "operational manual, not a results report."

### Motivation + Overview
- Motivation: two modes (CAPI baseline frozen, CATI panel rolling R1–R9), purpose =
  operate + replicate + hand over.
- **Project Folder Structure:** real L2PHL tree (`CAPI/`, `CATI/`, `.claude/rules|docs`, etc.).
- **Survey at a Glance** table: CAPI (2,470 HH · 10,496 persons · 247 PSU · 39 strata ·
  Sep–Oct 2025 · CAPI F2F) and CATI (baseline-HH phone panel · R1–R9 monthly · ~1,100/round ·
  attrition + replenishment). Round-date list (R1 Nov 2025 … R9 Jul 2026).

### Part I — Program Setup (condensed)
- Roles & responsibilities (WB team vs implementing firm).
- **Data Sources & Access:** repo layout, Google Drive masters, `KOBO/`, `Field Reports/`.
- TOR/Vendor kept to a short paragraph; gaps flagged.

### Part II — Baseline Household Survey (CAPI), full
- **Sampling:** two-stage stratified PPS; **39 strata** (17 regions × urban/rural + 5 BARMM
  special areas); MOS correction → post-stratification → age-sex calibration; weights
  `indw`/`hhw`/`popw` (summarized from the weighting note, with a pointer to it).
- **Questionnaire:** 14 modules M00–M14 (with per-module weight assignment table).
- **Fieldwork Operations:** Sep–Oct 2025, sourced from the Baseline Field Documentation
  Summary.
- **Post-Fieldwork:** Round00 pipeline `stg2raw → raw2dta → psu2wgt → dta2smp`; cleaning/fix.
- **Income Imputation (Survey-to-Survey / S2S):** dedicated subsection documenting
  `CAPI/S2S/` — the S2S method (baseline joined to a richer income/consumption survey via
  PSGC to impute per-capita household income), inputs/outputs, `s2s_diagnostics.xlsx`
  (~99.3% match), and the product `target_hh_imputed.dta` (`pcinc_imp_mean`). Points to
  `S2S_PHL_note.docx` as the methodology reference. This is the upstream half of the
  `target_hh_imputed.dta` provenance answer; Part III shows how it is consumed.
- **Deliverables & Analytical Outputs:** 16-tab CAPI dashboard, 12-chapter baseline
  storyline, wealth chapter, 10 deep dives — cataloged (what/where/GitHub Pages link) +
  the production pipeline (do → results `.md`/JSON → HTML; storyline-rebuild &
  replication-audit workflows). No findings.

### Part III — High-Frequency Panel Survey (CATI), deep
- **Panel design:** baseline HHs followed by phone; R1–R9; monthly; round dates; panel is
  attrition **+ replenishment** (not a closed cohort); pooled HF masters.
- **Questionnaire:** 10 modules M00–M09; per-round Kobo XLSForms (R01–R09); module
  standardization; rotating blocks (health R5/R8, Middle-East R6–R8, finance gates R5+).
- **Per-round processing:** round do-files, HF pooling, cleaning.
- **Weighting (deep):** per-round `indw` recalibration to census age×sex×stratum cells;
  `popw` = Σ indw within HH; `hhw` = mean indw → PSU-smoothed → rescaled to census HH
  totals. **Answers `target_hh_imputed.dta`:** it is the **S2S imputation product**
  (Part II §Income Imputation), copied from `CAPI/S2S/` to `HF/R00/`, merged onto
  `final_weights.dta` by `hhid` (`keepusing(pcinc_imp_mean)`, `assert(3)`) to attach
  per-capita imputed household income for income-quintile breakdowns — an income-imputation
  input, **not part of weight construction**. (Chain confirmed against the analysis do-file
  and `S2S_PHL_note.docx` when writing.)
- **Deliverables:** CATI panel storyline (catalog + rebuild).

### Part IV — Quality Control & the DQ Dashboard (deep core)
- **Pipeline architecture:** `update_pipeline.py --all` — the 6 steps; script map
  (`build_dq`, `build_panel`, `build_interviewer`, `build_issues`, `gen_dashboard`,
  `build_report`, `parse_kobo`); `cache/` JSON intermediates; outputs
  (`output/l2phl_dq_dashboard.html`, `L2PHL_Questionnaire_Cross_Round_Report.xlsx`).
- **What each dashboard panel shows:** tracker, heatmap, Kobo skip logic, issues,
  interviewer, cross-round questionnaire report.
- **Maintenance playbook (procedure boxes):**
  - (a) **Add a new round** — the exact R9 procedure as a *worked demonstration*
    (bump `ROUNDS` in `build_dq`/`build_panel`/`build_interviewer`/`build_report`;
    `range(1,N)` in `gen_dashboard`/`issue_rollup`; JS round arrays/labels/CSV; add form
    to `parse_kobo` + `ROUND_MAP`; run `--all`; verify R9 in JSON + HTML).
  - (b) **New/removed questions** — module standardization in `gen_dashboard`, authoritative
    var lists + preload-gated annotations in `build_dq`, heatmap curation.
  - (c) **Update filters when skip logic changes** — `parse_kobo` relevant-inheritance
    (repeat/group `relevant` folded into each var); Kobo skip-logic JSON.
  - (d) **Full data→dashboard run** — one command, what it regenerates.
- **Verifying flags & tracing numbers:**
  - Trace a number to source: do-file → log → Excel → HTML chain (survey-methodology rule);
    the `cross-checker` agent.
  - Real issue vs filtering artifact: skip-logic gating; issue-intelligence taxonomy
    (A1/A2/B/C/D); worked examples of false positives.
  - Real-time fieldwork monitoring: yes — how (partial-round handling, e.g. R9 = 558 HHs).
  - **Common causes of incorrect flags/counts:** curated list (cross-module vars absent
    from pooled `.dta`; preload-gated vars; FIES R6+ false flags; case normalization;
    derived/`_oth` vars; skip-gate drift).
  - Most frequent dashboard issues.
- **Conventions & which files to touch most:** `@AP@` naming, one-live-file-per-slot,
  `_attic/`, path-scoped rules; the short list of files edited every round.

### Annex A — Replicability Package
- Script/folder tables by stage (L2SC A-style), for CAPI Round00, CATI per-round, QC
  pipeline, SL/DB/DD, and cross-round analysis. Key conventions; how to run each stage.

### Annex B — Turnover Questions, Answered
- Reproduce every firm question (Quality Checks · Weighting · Dashboard · Other) with a
  1–2 sentence direct answer + section pointer. This is the meeting walk-through sheet.

### Annex C — Data Access & Security
- Google Drive access, confidentiality, sensitive-material handling (identifiers kept out
  of shared/replicability paths).

## Turnover-question → section coverage map

| Firm question | Answered in |
|---|---|
| Continued dashboard access; team ownership; walkthrough of generating/maintaining QC | Part IV intro + Annex C + Annex B |
| `target_hh_imputed.dta` provenance & purpose | Part II §Income Imputation (S2S) + Part III §Weighting |
| Edits when a new round is uploaded | Part IV playbook (a) — R9 demonstration |
| Edits for new/removed questions | Part IV playbook (b) |
| Updating filters when questionnaire logic changes | Part IV playbook (c) |
| Full data-prep → dashboard process | Part IV pipeline architecture + playbook (d) |
| Trace a dashboard number to source data | Part IV §Verifying/tracing |
| Verify a flag is real vs filtering artifact | Part IV §Verifying/tracing |
| Real-time fieldwork/DQ monitoring | Part IV §Verifying/tracing |
| Which files to modify most often | Part IV §Conventions |
| Coding standards / naming conventions | Part IV §Conventions + Annex A |
| Common causes of incorrect flags/counts | Part IV §Verifying/tracing |
| Most frequent dashboard issues | Part IV §Verifying/tracing |

## Out of scope / honest limitations

- No survey findings/results (operational manual only).
- No R9 Field Report (round in progress); R9 fieldwork noted as partial (558 HHs).
- TOR/vendor-selection history condensed; procurement detail not in repo is flagged.
- Any weight/QC number cited is repo/Stata-sourced; unverifiable claims are marked.

## Build & verification

- Compile `L2PHL_Operational_Manual.tex` with `tectonic`; confirm it produces a clean PDF
  (no undefined refs, all boxes/tables render, running header/footer present).
- Spot-check that every turnover question in Annex B resolves to a real section.
- Confirm all Reference-Documents box paths exist in the repo.
