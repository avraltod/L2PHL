# L2PHL Operational Manual Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce `CAPI/Analysis/SL/tex/L2PHL_Operational_Manual.pdf` — a WB-styled operational manual for the L2PHL survey program (CAPI baseline + CATI panel), mirroring the L2SC manual and deepened on the CATI QC dashboard + weighting to answer the firm's turnover questions.

**Architecture:** One LaTeX master (`L2PHL_Operational_Manual.tex`) that `\input`s focused section files under `CAPI/Analysis/SL/tex/manual/`. The master + preamble compile from the start with empty stubs; each task fills one stub and re-compiles. A `check_manual.py` script verifies every cited repo path exists and every turnover question appears in Annex B. Compiler: `tectonic`.

**Tech Stack:** LaTeX (`article` class, `titlesec`, `tcolorbox`, `fancyhdr`, `booktabs`, `xcolor`, `hyperref`), `tectonic` (already installed), `pdftotext` (poppler, for content checks), Python 3 (`check_manual.py`).

**Design spec:** `docs/superpowers/specs/2026-07-16-l2phl-operational-manual-design.md` — read it before starting.

**Working directory for all commands:** `/Users/avraa/iDrive/GitHub/PHL/L2PHL`

---

## Conventions for every task

- **Compile check** (the "test" for a document). From repo root:
  ```bash
  cd CAPI/Analysis/SL/tex && tectonic L2PHL_Operational_Manual.tex && cd -
  ```
  Expected: exit 0, ends with "Writing `L2PHL_Operational_Manual.pdf`". No `undefined` / `LaTeX Error`.
- **Content check:** `pdftotext CAPI/Analysis/SL/tex/L2PHL_Operational_Manual.pdf - | grep -c "<phrase>"` returns ≥1 for a phrase the task added.
- **Never invent numbers or file paths.** Every statistic and every path in a Reference-Documents box must be sourced from the repo. If a fact is genuinely absent, write "noted for a future revision" (the L2SC convention) — do not fabricate.
- **Wrap every repo path in `\rd{...}`** — in prose, `refbox`es, and tables. Write paths literally (`\rd{CATI/Analysis/QC/update_pipeline.py}`); the `\detokenize` in `\rd` prints underscores, so no `\_` escaping is needed. `check_manual.py` (Task 14) verifies every `\rd{}` path exists, so a wrapped path that doesn't exist fails the build — keeping paths honest.
- **Commit after each task** with a lowercase descriptive message.
- **Voice:** World Bank operational register (see `.claude/rules/world-bank-style.md`): third person, present tense for current state, no exclamation marks, percentages to one decimal, ₱ with commas, "R3" after first "Round 3 (January 2026)".
- **Branding:** "L2Phl" not "L2P"; never show weight variable names (`indw`/`hhw`) in user-facing prose — describe them ("individual weight") — except in Annex A / weighting sections where the variable name is the technical point.

---

### Task 1: LaTeX preamble, title page, and always-compiling scaffold

**Files:**
- Create: `CAPI/Analysis/SL/tex/L2PHL_Operational_Manual.tex`
- Create: `CAPI/Analysis/SL/tex/manual/00_frontmatter.tex` … `13_annex_c.tex` (14 empty stubs)

- [ ] **Step 1: Create the master file with full preamble and all `\input` lines**

Create `CAPI/Analysis/SL/tex/L2PHL_Operational_Manual.tex`:

```latex
\documentclass[11pt]{article}
\usepackage[a4paper,margin=1in,headheight=14pt]{geometry}
\usepackage[T1]{fontenc}
\usepackage{lmodern}
\usepackage{microtype}
\usepackage{xcolor}
\usepackage{graphicx}
\usepackage{booktabs}
\usepackage{array}
\usepackage{longtable}
\usepackage{enumitem}
\usepackage{titlesec}
\usepackage{fancyhdr}
\usepackage[most]{tcolorbox}
\usepackage{hyperref}

% ── World Bank palette ───────────────────────────────────────────────
\definecolor{wbnavy}{HTML}{002244}
\definecolor{wbblue}{HTML}{009FDA}
\definecolor{boxblue}{HTML}{DCEBF7}
\definecolor{boxgrey}{HTML}{EFEFEF}
\definecolor{rulegrey}{HTML}{999999}

\hypersetup{colorlinks=true, linkcolor=wbblue, urlcolor=wbblue,
  pdftitle={L2PHL Operational Manual}, pdfauthor={Purevjav, Piza, Sousa}}

% ── Blue headings ────────────────────────────────────────────────────
\titleformat{\section}{\Large\bfseries\color{wbnavy}}{\thesection.}{0.5em}{}
\titleformat{\subsection}{\large\bfseries\color{wbblue}}{\thesubsection}{0.5em}{}
\titleformat{\subsubsection}{\normalsize\bfseries\color{wbnavy}}{\thesubsubsection}{0.5em}{}
\newcommand{\parttitle}[1]{\clearpage\begin{center}\LARGE\bfseries\color{wbnavy} #1\end{center}\vspace{1em}}

% ── Header / footer ──────────────────────────────────────────────────
\pagestyle{fancy}
\fancyhf{}
\fancyhead[L]{\small\color{wbnavy}L2Phl Operational Manual}
\fancyhead[R]{\small\thepage}
\fancyfoot[C]{\small\color{wbnavy}World Bank -- Poverty and Equity Global Practice}
\renewcommand{\headrulewidth}{0.4pt}
\renewcommand{\footrulewidth}{0.4pt}

% ── Box styles ───────────────────────────────────────────────────────
% Procedure box (light blue): step-by-step workflows
\newtcolorbox{procbox}[1]{colback=boxblue,colframe=wbblue,boxrule=0.6pt,
  arc=1mm,left=3mm,right=3mm,top=2mm,bottom=2mm,
  title={\bfseries #1},coltitle=wbnavy,fonttitle=\bfseries}
% Reference box (grey): exact repo file paths
\newtcolorbox{refbox}{colback=boxgrey,colframe=rulegrey,boxrule=0.4pt,
  arc=0.5mm,left=3mm,right=3mm,top=2mm,bottom=2mm}
% Note / recommendation callout
\newtcolorbox{notebox}[1]{colback=boxblue!40,colframe=wbnavy,boxrule=0.6pt,
  arc=1mm,left=3mm,right=3mm,top=2mm,bottom=2mm,
  title={\bfseries #1},coltitle=wbnavy}
% Repo-path shorthand. \detokenize prints underscores literally, so paths are
% written as-is: \rd{CATI/Analysis/HF/l2phl_M00_passport.dta} (no \_ escaping).
\newcommand{\rd}[1]{\texttt{\small\detokenize{#1}}}

\begin{document}

% Title page
\begin{titlepage}
\centering
\vspace*{3cm}
{\Huge\bfseries\color{wbnavy} Listening to the Philippines (L2Phl)\par}
\vspace{0.8cm}
{\LARGE\color{wbblue} Operational Manual\par}
\vspace{1.5cm}
{\large Baseline (CAPI) and High-Frequency Panel (CATI):\\[0.3em]
Implementation, Data Processing, and Quality Control\par}
\vspace{2cm}
{\large Avralt-Od Purevjav\\[0.3em] Sharon Faye Alariao Piza\\[0.3em] Liliana D. Sousa\par}
\vspace{1.5cm}
{\large July 2026\par}
\vfill
{\small\itshape Internal project codename: Project TIPON.\par}
\end{titlepage}

\tableofcontents

\input{manual/00_frontmatter}
\input{manual/01_overview}
\input{manual/02_part1_setup}
\input{manual/03_capi_sampling_quest}
\input{manual/04_capi_fieldwork_post}
\input{manual/05_capi_s2s_deliverables}
\input{manual/06_cati_design_quest}
\input{manual/07_cati_processing_weighting}
\input{manual/08_qc_architecture}
\input{manual/09_qc_playbook}
\input{manual/10_qc_verify_conventions}
\input{manual/11_annex_a}
\input{manual/12_annex_b}
\input{manual/13_annex_c}

\end{document}
```

- [ ] **Step 2: Create 14 empty stub files**

```bash
mkdir -p CAPI/Analysis/SL/tex/manual
cd CAPI/Analysis/SL/tex/manual
for f in 00_frontmatter 01_overview 02_part1_setup 03_capi_sampling_quest \
  04_capi_fieldwork_post 05_capi_s2s_deliverables 06_cati_design_quest \
  07_cati_processing_weighting 08_qc_architecture 09_qc_playbook \
  10_qc_verify_conventions 11_annex_a 12_annex_b 13_annex_c; do
  printf '%% %s\n' "$f" > "$f.tex"
done
cd -
```

- [ ] **Step 3: Compile the scaffold**

Run: `cd CAPI/Analysis/SL/tex && tectonic L2PHL_Operational_Manual.tex && cd -`
Expected: exit 0, produces `L2PHL_Operational_Manual.pdf` with a title page + empty TOC.

- [ ] **Step 4: Verify title page renders**

Run: `pdftotext CAPI/Analysis/SL/tex/L2PHL_Operational_Manual.pdf - | grep -c "Operational Manual"`
Expected: ≥1.

- [ ] **Step 5: Add tex build artifacts to .gitignore and commit**

Add to `.gitignore` (if not already ignored): `CAPI/Analysis/SL/tex/*.aux`, `*.toc`, `*.out`, `*.log`. Then:
```bash
git add CAPI/Analysis/SL/tex/L2PHL_Operational_Manual.tex CAPI/Analysis/SL/tex/manual/ .gitignore
git commit -m "manual: latex scaffold, preamble, title page (compiles empty)"
```

---

### Task 2: Motivation + Overview (folder tree, Survey at a Glance)

**Files:**
- Modify: `CAPI/Analysis/SL/tex/manual/00_frontmatter.tex`
- Modify: `CAPI/Analysis/SL/tex/manual/01_overview.tex`

**Source before writing:** `CLAUDE.md` (key statistics, round dates, modules, deliverable table); repo tree from `find . -maxdepth 2 -type d`.

- [ ] **Step 1: Write `00_frontmatter.tex` — Scope box + Motivation**

Content (write in full):
- A `\section*{Motivation}` (unnumbered): L2Phl is a nationally representative survey of ~108.7 million Filipinos through 2,470 households and 10,496 members across 18 regions, in two modes — a **CAPI baseline** (14 modules, face-to-face, Sep–Oct 2025, frozen) and a **CATI panel** (10 modules, monthly phone rounds R1–R9, Nov 2025–Jul 2026, rolling). Purpose of the manual: let a new team **operate, maintain, and replicate** every stage. Internal codename Project TIPON.
- A `notebox` titled "Scope of this document": "This is the operational manual — it documents how the survey is designed, processed, weighted, and quality-controlled so a new team can replicate and maintain it. It is not a results report; substantive findings live in the storylines, dashboards, and deep dives cataloged in the Deliverables sections."

- [ ] **Step 2: Write `01_overview.tex` — Overview prose + folder tree + Survey at a Glance**

- `\section*{Overview}`: the manual follows the repository layout; CAPI is baseline-frozen while CATI rolls forward; the QC dashboard and weighting receive the deepest treatment because they are the live, hand-over-critical workstreams.
- **Project Folder Structure** as a `refbox` with a `verbatim` tree (use the real top-level dirs): `CAPI/` (Analysis/{DB,DD,SL,SSB}, Round00, S2S), `CATI/` (Analysis/{QC,SL,HF,do,2share}, KOBO, Questionnaire, Field Reports, Round01–Round09), `.claude/` (rules, docs, skills), `docs/`, `scripts/`.
- **Survey at a Glance** as a `booktabs` table with columns Component | Mode | N | Fieldwork | Key design:
  - Baseline | CAPI (F2F) | 2,470 HH / 10,496 persons | Sep–Oct 2025 | Two-stage stratified PPS; 247 PSUs; 39 strata; sampling frame for CATI
  - Panel R1–R9 | CATI (phone) | ~1,100/round | Nov 2025–Jul 2026 | Baseline-HH panel; attrition + replenishment; per-round recalibrated weights
- **Round-date list** (bullet or inline): R1 Nov 25 2025 · R2 Dec 28 2025 · R3 Jan 28 2026 · R4 Feb 28 2026 · R5 Mar 30 2026 · R6 Apr 29 2026 · R7 May 20 2026 · R8 Jun 26 2026 · R9 Jul 2026 (partial, in progress). Add a note: "R9 fieldwork is in progress at the time of writing (558 households as of mid-July 2026)."

- [ ] **Step 3: Compile and content-check**

Run: `cd CAPI/Analysis/SL/tex && tectonic L2PHL_Operational_Manual.tex && cd -`
Then: `pdftotext CAPI/Analysis/SL/tex/L2PHL_Operational_Manual.pdf - | grep -c "Survey at a Glance"`
Expected: compile exit 0; grep ≥1.

- [ ] **Step 4: Commit**

```bash
git add CAPI/Analysis/SL/tex/manual/00_frontmatter.tex CAPI/Analysis/SL/tex/manual/01_overview.tex
git commit -m "manual: motivation, overview, folder tree, survey-at-a-glance"
```

---

### Task 3: Part I — Program Setup (condensed)

**Files:**
- Modify: `CAPI/Analysis/SL/tex/manual/02_part1_setup.tex`

**Source before writing:** `CLAUDE.md` (.gitignore policy, deployment); `.claude/rules/file-organization.md`; confirm Google Drive + KOBO + Field Reports locations (from the design spec).

- [ ] **Step 1: Write Part I**

- `\parttitle{Part I: Program Setup}` + one-paragraph intro.
- `\section{Roles and Responsibilities}`: World Bank team (survey design & sampling, questionnaire, weighting, QC dashboard, analysis & storylines) vs implementing firm (SurveyCTO/Kobo programming, enumerator training, CAPI + CATI fieldwork, raw + cleaned data delivery, field documentation). Keep to two bullet lists. Note TOR/vendor-selection history is condensed here and "noted for a future revision" where procurement records are not in the repo.
- `\section{Data Sources and Access}`: describe the four inputs the receiving team works from, each with a `refbox` path:
  - Repository (`CAPI/`, `CATI/`) — do-files, QC pipeline, HTML deliverables, docs (tracked); `.dta`/`raw/` gitignored per `.gitignore` policy.
  - Google Drive masters — pooled `.dta` datasets restored to `CATI/Analysis/HF/` (require WB authorization; household-level, confidential).
  - `CATI/KOBO/` — XLSForm ground truth, `L2PHL_CATI_R01.xlsx` … `R09.xlsx`.
  - `CATI/Field Reports/` — 8 Field Documentation Summary PDFs (Baseline+R1 → R8).

- [ ] **Step 2: Compile and content-check**

Compile (as Task 2 Step 3); `pdftotext … | grep -c "Data Sources and Access"` → ≥1.

- [ ] **Step 3: Commit**

```bash
git add CAPI/Analysis/SL/tex/manual/02_part1_setup.tex
git commit -m "manual: part I program setup (roles, data sources & access)"
```

---

### Task 4: Part II — CAPI Sampling + Questionnaire

**Files:**
- Modify: `CAPI/Analysis/SL/tex/manual/03_capi_sampling_quest.tex`

**Source before writing:** `CAPI/Analysis/SL/tex/L2PHL_WEIGHTING_TECHNICAL_NOTE.tex` (sampling design, 39 strata, weight construction); `CLAUDE.md` (CAPI modules M00–M14, weights); `.claude/rules/data-weights.md`.

- [ ] **Step 1: Write CAPI intro + Sampling**

- `\parttitle{Part II: Baseline Household Survey (CAPI)}` + intro (baseline is the foundation and the sampling frame for CATI).
- `\section{Sampling}`: two-stage stratified design; PSU = barangay, SSU = household; **39 strata** = 17 regions × urban/rural (34) + 5 BARMM special geographic areas (region codes 101–105) entering as one stratum each; 247 PSUs; 2,470 households. PPS selection. Weights: individual, household, and population (describe roles, not variable names, in prose; the weighting note is the technical reference — cite it in a `refbox`).
- A `notebox` "Weights in one line": individual weight for person-level indicators, household weight for household-level behaviour, population weight for "how many Filipinos" welfare framing. Point to `L2PHL_WEIGHTING_TECHNICAL_NOTE.pdf` for construction (base weight → exact MOS correction → post-stratification → age-sex calibration).

- [ ] **Step 2: Write Questionnaire (Modules)**

- `\section{Questionnaire and Modules}`: 14-module structure with a `booktabs` table Module | Name | Unit/weight:
  M00 Passport · M01 Roster (indiv) · M02 Education (indiv) · M03 Employment (indiv) · M04 Income (mixed) · M05 Finance (HH) · M06 Migration (indiv) · M07 Health (indiv) · M08 Food (HH/indiv) · M09 Hazards (HH) · M10 Dwelling (HH) · M11 Sanitation (HH) · M12 Utilities (HH) · M13 Assets (HH) · M14 Views (HH).
- Reference `CAPI/Analysis/DB/doc/WEIGHT_RATIONALE.md` for the module→weight rationale in a `refbox`.

- [ ] **Step 3: Compile and content-check**

Compile; `pdftotext … | grep -c "39 strata"` → ≥1.

- [ ] **Step 4: Commit**

```bash
git add CAPI/Analysis/SL/tex/manual/03_capi_sampling_quest.tex
git commit -m "manual: part II CAPI sampling + questionnaire modules"
```

---

### Task 5: Part II — CAPI Fieldwork + Post-Fieldwork pipeline

**Files:**
- Modify: `CAPI/Analysis/SL/tex/manual/04_capi_fieldwork_post.tex`

**Source before writing:** `CATI/Field Reports/L2PHL- Field Documentation Summary (Baseline & CATI R1) v2 17December2025.pdf` (read for baseline fieldwork dates, response, challenges); `CAPI/Round00/do/` do-file names (`ls CAPI/Round00/do/`) for the pipeline stages.

- [ ] **Step 1: Write Fieldwork Operations**

- `\section{Fieldwork Operations}`: baseline carried out face-to-face on tablet (SurveyCTO), Sep–Oct 2025. Summarize from the Baseline Field Documentation Summary: fieldwork window, completion/response, and any documented field challenges — 2–3 paragraphs. Cite the Field Report PDF in a `refbox`.

- [ ] **Step 2: Write Post-Fieldwork pipeline**

- `\section{Post-Fieldwork Processing}`: a `procbox` "Baseline Processing Pipeline" listing the Round00 stages in order — Stage 1 `stg2raw` (raw export → .dta), Stage 2 `raw2dta` (clean, rename, label, consistency), Stage 3 `psu2wgt` (sampling weights), Stage 4 `dta2smp` (analysis sample). Use the actual do-file names from `ls CAPI/Round00/do/`. Note raw data is never modified in place; cleaning runs through Stata do-files.
- `refbox` listing the Round00 do-file paths.

- [ ] **Step 3: Compile and content-check**

Compile; `pdftotext … | grep -c "Post-Fieldwork Processing"` → ≥1.

- [ ] **Step 4: Commit**

```bash
git add CAPI/Analysis/SL/tex/manual/04_capi_fieldwork_post.tex
git commit -m "manual: part II CAPI fieldwork + post-fieldwork pipeline"
```

---

### Task 6: Part II — S2S Income Imputation + CAPI Deliverables

**Files:**
- Modify: `CAPI/Analysis/SL/tex/manual/05_capi_s2s_deliverables.tex`

**Source before writing:** `CAPI/S2S/S2S_PHL_note.docx` (already summarized below — verify against the file); `CLAUDE.md` HTML deliverables table; `CAPI/.claude/skills/` (storyline-rebuild) and `.claude/docs/storyline-update-workflow.md` for the rebuild pipeline.

- [ ] **Step 1: Write Income Imputation (Survey-to-Survey / S2S)**

Write `\section{Income Imputation (Survey-to-Survey)}` using these verified facts (from `S2S_PHL_note.docx`, prepared by Sandra Segovia Juarez):
- **Purpose:** predict household welfare in L2Phl 2025 (which has no full consumption module) using FIES-LFS 2023 (source, welfare observed), then derive poverty.
- **Method (3 steps):** estimate a weighted OLS welfare model in FIES-LFS 2023 (dependent = log per-capita income; predictors = demographics, household size, assets, housing/sanitation, tenure, urban, region FE; N=162,687, R²=0.5108, RMSE=0.4798); apply coefficients to the harmonized L2Phl variables; resample source residuals and add to the prediction (stochastic imputation, to avoid compressing the distribution).
- **GDP adjustment:** intercept shift of ln(1.104) — cumulative real growth (1.057 × 1.044) — preserving household ranking.
- **Validation:** predicted 15.61% vs observed 15.50% poverty in the 2023 source. 2025 poverty 16.96% unadjusted → **13.20% GDP-adjusted (preferred)**.
- **Output & link to weighting:** the product is `target_hh_imputed.dta` holding `pcinc_imp_mean` (per-capita imputed household income). Stored in `CAPI/S2S/`, copied to `CATI/Analysis/HF/R00/target_hh_imputed.dta`. It is an **imputed-welfare input for income-quintile breakdowns, not part of weight construction** (Part III §Weighting shows how it is merged).
- `refbox`: `CAPI/S2S/S2S_PHL_note.docx` (method), `CAPI/S2S/s2s_diagnostics.xlsx` (diagnostics), `CAPI/S2S/target_hh_imputed.dta` (output).
- `notebox` "Caveat": 2023 regional poverty lines are used for 2025 (updated lines unavailable), which may modestly understate 2025 poverty.

- [ ] **Step 2: Write Deliverables and Analytical Outputs (CAPI)**

- `\section{Deliverables and Analytical Outputs}`: catalog with a `booktabs` table Deliverable | Type | Location/link (no findings):
  - 16-tab CAPI dashboard — `CAPI/Analysis/DB/html/l2phl_capi_dashboard.html`
  - 12-chapter baseline storyline — `CAPI/Analysis/SL/html/l2phl_baseline_story.html`
  - Wealth deep-dive chapter — `CAPI/Analysis/SL/html/l2phl_wealth_chapter.html`
  - 10 deep dives — `CAPI/Analysis/DD/*/html/…`
  (Use the GitHub Pages URLs from `CLAUDE.md`.)
- **Production/rebuild pipeline** subsection: do-file → results (`.md`/JSON) → self-contained HTML (Chart.js CDN + Google Fonts); the storyline-rebuild and replication-audit workflows regenerate a chapter from Stata output. Cite `.claude/docs/storyline-update-workflow.md` in a `refbox`.

- [ ] **Step 3: Compile and content-check**

Compile; `pdftotext … | grep -c "Survey-to-Survey"` → ≥1; `grep -c "13.20"` → ≥1.

- [ ] **Step 4: Commit**

```bash
git add CAPI/Analysis/SL/tex/manual/05_capi_s2s_deliverables.tex
git commit -m "manual: part II S2S income imputation + CAPI deliverables/rebuild"
```

---

### Task 7: Part III — CATI Panel Design + Questionnaire

**Files:**
- Modify: `CAPI/Analysis/SL/tex/manual/06_cati_design_quest.tex`

**Source before writing:** `CLAUDE.md` (CATI modules M00–M09, round dates, DQ authoritative variable lists); `.claude/docs/qc-pipeline.md` (module standardization); a Field Report from a later round for CATI fieldwork colour (e.g. R8).

- [ ] **Step 1: Write CATI intro + Panel Design**

- `\parttitle{Part III: High-Frequency Panel Survey (CATI)}` + intro (phone follow-up of the baseline households, repeated monthly).
- `\section{Panel Design}`: the CATI sample follows baseline households by phone; R1–R9 monthly. The panel is **attrition + replenishment** — not a closed cohort (households leave and new ones enter each round). Pooled harmonized masters live in `CATI/Analysis/HF/` (`l2phl_cati_individual.dta`, `l2phl_cati_household.dta`, and per-module `l2phl_M00…M09` files). `refbox` with those paths.

- [ ] **Step 2: Write CATI Questionnaire**

- `\section{Questionnaire and Round-Specific Modules}`: 10 core modules (M00 Passport, M01 Roster, M02 Education, M03 Shocks, M04 Employment, M05 Income, M06 Finance, M07 Health, M08 Food/FIES, M09 Views) with a `booktabs` table. Note round-specific evolution briefly: health full expansion R5/R8; Middle-East block M09 R6–R8; finance bank/mobile-money gates R5+; per-round Kobo XLSForms `L2PHL_CATI_R01…R09.xlsx` are the skip-logic ground truth. Cite `.claude/docs/qc-pipeline.md` and `CATI/KOBO/` in a `refbox`.

- [ ] **Step 3: Compile and content-check**

Compile; `pdftotext … | grep -c "attrition"` → ≥1.

- [ ] **Step 4: Commit**

```bash
git add CAPI/Analysis/SL/tex/manual/06_cati_design_quest.tex
git commit -m "manual: part III CATI panel design + questionnaire"
```

---

### Task 8: Part III — CATI Processing + Weighting (target_hh_imputed answer)

**Files:**
- Modify: `CAPI/Analysis/SL/tex/manual/07_cati_processing_weighting.tex`

**Source before writing:** `CATI/Analysis/do/hf_l2phl_analysis@AP@20260709.do` (read lines around the weighting block ~60–250 and the `target_hh_imputed` merge at line 69); `CAPI/Analysis/SL/tex/L2PHL_WEIGHTING_TECHNICAL_NOTE.tex` (CATI reweight section).

- [ ] **Step 1: Write Per-Round Processing**

- `\section{Per-Round Processing}`: each round is processed from its raw Kobo export through a round do-file into the pooled HF masters; the pooled masters are re-pooled (not merely appended) when the firm delivers revised round data. Note the Jun-2027 re-pool caveat only if still relevant; otherwise describe the append/replace behaviour generally.

- [ ] **Step 2: Write Weighting (deep) — including target_hh_imputed**

- `\section{Weighting}`: per-round individual weight recalibrated to census age×sex×stratum cells; population weight = sum of individual weights within household; household weight = mean individual weight within household, PSU-smoothed, rescaled to census household totals per stratum. Point to the weighting technical note for full formulas.
- `\subsection{The \texttt{target\_hh\_imputed.dta} file}` — the direct answer to the firm's question: it is the **S2S imputation product** (Part II §Income Imputation), stored in `CAPI/S2S/` and copied to `CATI/Analysis/HF/R00/target_hh_imputed.dta`. In the analysis do-file it is merged onto `final_weights.dta` by `hhid` with `keepusing(pcinc_imp_mean)` and `assert(3)`, attaching per-capita imputed household income labeled "PC HH imputed income". It supplies **imputed welfare for income-quintile breakdowns; it is not an input to weight construction**. `refbox` citing `CATI/Analysis/do/hf_l2phl_analysis@AP@20260709.do` (the merge) and `CAPI/S2S/S2S_PHL_note.docx` (the method).

- [ ] **Step 3: Compile and content-check**

Compile; `pdftotext … | grep -c "target_hh_imputed"` → ≥1.

- [ ] **Step 4: Commit**

```bash
git add CAPI/Analysis/SL/tex/manual/07_cati_processing_weighting.tex
git commit -m "manual: part III CATI processing + weighting + target_hh_imputed answer"
```

---

### Task 9: Part IV — QC Pipeline Architecture + Dashboard Panels

**Files:**
- Modify: `CAPI/Analysis/SL/tex/manual/08_qc_architecture.tex`

**Source before writing:** `CATI/Analysis/QC/README.md`; `CATI/Analysis/QC/update_pipeline.py` (the 6 STEP banners and `run_script` calls); `.claude/docs/qc-pipeline.md`.

- [ ] **Step 1: Write Pipeline Architecture**

- `\parttitle{Part IV: Quality Control and the DQ Dashboard}` + intro (the live, hand-over-critical workstream).
- `\section{Pipeline Architecture}`: one entry point — `python3 update_pipeline.py --all` — runs, in order: detect files → build DQ data (`build_dq.py`) → build panel (`build_panel.py`) → build interviewer (`build_interviewer.py`) → parse do-files → build issues (`build_issues.py`) → generate dashboard (`gen_dashboard.py`) → build Excel cross-round report (`build_report.py`); `parse_kobo.py` supplies skip logic. Intermediates cache to `CATI/Analysis/QC/cache/*.json`; outputs are `output/l2phl_dq_dashboard.html` and `output/L2PHL_Questionnaire_Cross_Round_Report.xlsx`.
- A `procbox` "Full pipeline run" with the six steps and the single command. A `booktabs` script-map table Script | Role.
- `refbox` citing `CATI/Analysis/QC/update_pipeline.py`, `scripts/`, `README.md`.

- [ ] **Step 2: Write What the Dashboard Shows**

- `\section{Dashboard Panels}`: bullet list of panels — completion tracker, per-module DQ heatmap, Kobo skip-logic, issue intelligence, interviewer/operator performance, cross-round questionnaire report. One sentence each.

- [ ] **Step 3: Compile and content-check**

Compile; `pdftotext … | grep -c "update_pipeline"` → ≥1.

- [ ] **Step 4: Commit**

```bash
git add CAPI/Analysis/SL/tex/manual/08_qc_architecture.tex
git commit -m "manual: part IV QC pipeline architecture + dashboard panels"
```

---

### Task 10: Part IV — Maintenance Playbook (procedure boxes)

**Files:**
- Modify: `CAPI/Analysis/SL/tex/manual/09_qc_playbook.tex`

**Source before writing:** the recent R9 commit (`git show --stat HEAD~N` or `git log --oneline | grep "add R9"`) — the exact files changed; `CATI/Analysis/QC/scripts/gen_dashboard.py`, `build_dq.py`, `parse_kobo.py`, `update_pipeline.py`.

- [ ] **Step 1: Write "Adding a New Round" (worked R9 demonstration)**

- `\section{Maintenance Playbook}` intro.
- `\subsection{Adding a New Round}` with a `procbox` "Add a round (worked example: R9)" listing the exact edits (this is the procedure just executed for R9):
  1. Bump the round constant in `build_dq.py`, `build_panel.py`, `build_interviewer.py`, `build_report.py` (`ROUNDS` list) — add the new round number/label.
  2. In `gen_dashboard.py` and `issue_rollup.py` bump `range(1, N)` → `range(1, N+1)`; in `gen_dashboard.py` extend the JS round arrays, `RLABELS`, the CSV export header/rows, and the M00 skip-fallback `_ROUNDS`.
  3. Add the round's real form to `parse_kobo.py` (`KOBO_FILES`) and to `update_pipeline.py` (`ROUND_MAP`).
  4. Run `python3 update_pipeline.py --all`.
  5. Verify: `dq_data.json` rounds include the new round; `pdftotext`/grep or a JSON check confirms `in_R<N>` and the new label render in `output/l2phl_dq_dashboard.html`.
- Note: the pooled `.dta` is data-driven by a `round` column, so most of the pipeline needs no change beyond the round-count constants; a partial in-progress round (e.g. R9 = 558 HHs) shows as provisional.

- [ ] **Step 2: Write "New or Removed Questions" and "Updating Filters"**

- `\subsection{New or Removed Questions}` `procbox`: update the module's authoritative variable list and heatmap rows in `build_dq.py`; standardize the variable in `gen_dashboard.py` module standardization; annotate preload-gated variables; the Kobo form is the ground truth for what exists in a round.
- `\subsection{Updating Filters When Questionnaire Logic Changes}` `procbox`: `parse_kobo.py` folds each variable's enclosing repeat/group `relevant` condition into the variable, so a changed skip rule flows into the dashboard's skip-logic panel automatically once the new Kobo form is added; re-run `--all`.

- [ ] **Step 3: Compile and content-check**

Compile; `pdftotext … | grep -c "Add a round"` → ≥1.

- [ ] **Step 4: Commit**

```bash
git add CAPI/Analysis/SL/tex/manual/09_qc_playbook.tex
git commit -m "manual: part IV maintenance playbook (new round, questions, filters)"
```

---

### Task 11: Part IV — Verifying Flags, Tracing Numbers, Conventions

**Files:**
- Modify: `CAPI/Analysis/SL/tex/manual/10_qc_verify_conventions.tex`

**Source before writing:** `.claude/rules/survey-methodology.md` (the trace chain), `.claude/rules/file-organization.md` (naming), the DQ heatmap curation notes in `.claude/docs/qc-pipeline.md`.

- [ ] **Step 1: Write Verifying Flags and Tracing Numbers**

- `\section{Verifying Flags and Tracing Numbers}`.
- `\subsection{Tracing a Number to Source}`: the chain do-file → Stata log → Excel results → HTML/dashboard; every dashboard number traces back through `cache/*.json` to a `.dta` variable and the check that produced it; the `cross-checker` agent automates this. `procbox` "Trace a number" with the ordered steps.
- `\subsection{Real Issue vs Filtering Artifact}`: a red cell can be a true data problem or a skip-gate mismatch; the pipeline gates checks by the Kobo `relevant` condition and annotates preload-gated variables, so an unexpected flag is checked against the skip logic first. Give the issue-intelligence taxonomy (A1/A2/B/C/D) in one line each.
- `\subsection{Real-Time Fieldwork Monitoring}`: yes — re-running `--all` on the latest pooled masters refreshes completion counts and flags mid-round; a partial round shows provisional counts.
- `\subsection{Common Causes of Incorrect Flags or Counts}`: bullet list — cross-module variables absent from the pooled `.dta` (cannot apply the gate); preload/pre-filled variables gated upstream; FIES R6+ items added mid-panel (false "missing" before introduction); case-normalized variable names; derived/`_oth` variables excluded; skip-gate drift between rounds.
- `\subsection{Most Frequent Dashboard Issues}`: short list (stale cache, a new round's form not added to `parse_kobo`, a variable renamed in a later round, a partial round read as attrition).

- [ ] **Step 2: Write Conventions and Which Files to Modify Most**

- `\section{Conventions and File Maintenance}`: `@AP@` do-file naming (`L2PHL_<MODE>@<ROUND>@AP@YYYYMMDD.ext`), one-live-file-per-slot, `_attic/` archiving, forward-slash paths. **Files edited most often:** `build_dq.py` (checks), `gen_dashboard.py` (rendering), `parse_kobo.py` (skip logic), `update_pipeline.py` (`ROUND_MAP`). `refbox` citing `.claude/rules/file-organization.md`.

- [ ] **Step 3: Compile and content-check**

Compile; `pdftotext … | grep -c "Tracing a Number"` → ≥1.

- [ ] **Step 4: Commit**

```bash
git add CAPI/Analysis/SL/tex/manual/10_qc_verify_conventions.tex
git commit -m "manual: part IV verifying flags, tracing, common causes, conventions"
```

---

### Task 12: Annex A — Replicability Package

**Files:**
- Modify: `CAPI/Analysis/SL/tex/manual/11_annex_a.tex`

**Source before writing:** `ls CAPI/Round00/do/`, `ls CATI/Analysis/QC/scripts/`, `ls CATI/Analysis/do/`, `CLAUDE.md` repository layout.

- [ ] **Step 1: Write Annex A**

- `\parttitle{Annex A: Replicability Package}` + intro (every key file/folder by stage; paths relative to the repo root).
- Subsections with `booktabs` tables Script/Folder | Purpose | Input | Output:
  - CAPI baseline (Round00 pipeline stages).
  - CATI per-round processing + HF pooling.
  - QC pipeline (`update_pipeline.py` + `scripts/`).
  - Storylines/dashboards/deep dives (SL/DB/DD).
  - Cross-round analysis (`CATI/Analysis/do/`).
- `\section{Key Conventions}`: date-stamped folders, `@AP@` do-file naming, three-stage flow, path conventions, data preservation (raw never modified in place).

- [ ] **Step 2: Compile and content-check**

Compile; `pdftotext … | grep -c "Replicability Package"` → ≥1.

- [ ] **Step 3: Commit**

```bash
git add CAPI/Analysis/SL/tex/manual/11_annex_a.tex
git commit -m "manual: annex A replicability package"
```

---

### Task 13: Annex B — Turnover Questions, Answered (crosswalk)

**Files:**
- Modify: `CAPI/Analysis/SL/tex/manual/12_annex_b.tex`

**Source before writing:** the turnover PDF questions (reproduced below — all 13) and the coverage map in the design spec.

- [ ] **Step 1: Write the crosswalk**

`\parttitle{Annex B: Turnover Questions --- Answered}` + a `longtable` with columns **Question** | **Short answer** | **See section**. One row per firm question (write the full 1–2 sentence answer in each row):

1. Continued QC dashboard access after turnover? → The dashboard is a self-contained HTML regenerated from the repo pipeline; the receiving team runs and owns it going forward. → Part IV; Annex C.
2. Team takes ownership / walkthrough of generating & maintaining QC? → Yes; the full generate-and-maintain process is Part IV (architecture + playbook). → Part IV.
3. Where does `target_hh_imputed.dta` come from / its purpose? → It is the S2S survey-to-survey imputation output (per-capita imputed income), merged for income-quintile breakdowns, not part of weight construction. → Part II §Income Imputation; Part III §Weighting.
4. Edits when a new round is uploaded? → Bump the round-count constants in five scripts, add the round form to `parse_kobo`/`ROUND_MAP`, run `--all`; the worked R9 example is in the playbook. → Part IV §Playbook.
5. Edits for rounds with new/removed questions? → Update the module's authoritative variable list + heatmap and standardization in `build_dq`/`gen_dashboard`; the Kobo form is ground truth. → Part IV §Playbook.
6. Efficiently update dashboard filters when questionnaire logic changes? → Add the new Kobo form; `parse_kobo` folds enclosing `relevant` conditions into each variable automatically; re-run `--all`. → Part IV §Playbook.
7. Full process from data prep to dashboard output? → `update_pipeline.py --all` runs the six-step pipeline from pooled `.dta` to HTML + Excel. → Part IV §Architecture.
8. Trace a dashboard number back to source data? → Follow do-file → Stata log → Excel → HTML; the `cross-checker` agent automates it. → Part IV §Verifying.
9. Verify a flag is a real issue vs a filtering-condition problem? → Checks are gated by the Kobo `relevant` condition; compare the flag against skip logic and preload gating first. → Part IV §Verifying.
10. Monitor fieldwork progress & DQ in real time? → Yes; re-running `--all` on the latest masters refreshes counts and flags mid-round. → Part IV §Verifying.
11. Which files to modify most often? → `build_dq.py`, `gen_dashboard.py`, `parse_kobo.py`, `update_pipeline.py`. → Part IV §Conventions.
12. Coding standards / naming conventions? → `@AP@` do-file naming, one-live-file-per-slot, `_attic/`, forward-slash paths. → Part IV §Conventions; Annex A.
13. Common causes of incorrect flags/counts & most frequent issues? → Cross-module vars absent from `.dta`, preload-gated vars, mid-panel FIES items, renamed/derived vars, partial rounds. → Part IV §Verifying.

- [ ] **Step 2: Compile and content-check**

Compile; `pdftotext … | grep -c "Turnover Questions"` → ≥1.

- [ ] **Step 3: Commit**

```bash
git add CAPI/Analysis/SL/tex/manual/12_annex_b.tex
git commit -m "manual: annex B turnover questions answered crosswalk"
```

---

### Task 14: Annex C, final compile, verification script

**Files:**
- Modify: `CAPI/Analysis/SL/tex/manual/13_annex_c.tex`
- Create: `CAPI/Analysis/SL/tex/check_manual.py`

- [ ] **Step 1: Write Annex C — Data Access and Security**

`\parttitle{Annex C: Data Access and Security}`: replication requires WB authorization for the household-level datasets; sensitive materials (identifiers, phone numbers, GPS) are kept out of shared/replicability paths per WB P&E data-protection protocol; the dashboards are self-contained HTML safe to share; the pooled `.dta` masters are not. Steps to replicate: obtain repo access, install Stata + Python deps, run each stage in sequence, use the procedure boxes and Annex A as the script reference.

- [ ] **Step 2: Write `check_manual.py` — verify paths + turnover coverage**

Create `CAPI/Analysis/SL/tex/check_manual.py`:

```python
#!/usr/bin/env python3
"""Verify the L2PHL Operational Manual: every repo path cited in the .tex
exists, and all 13 turnover questions are represented in Annex B."""
import re, sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[4]   # .../L2PHL
MANUAL = Path(__file__).resolve().parent / "manual"

# 1. Collect \rd{...} and \texttt{...} paths that look like repo paths
paths = set()
for tex in MANUAL.glob("*.tex"):
    txt = tex.read_text()
    for m in re.findall(r'\\rd\{([^}]+)\}', txt):
        if "/" in m and not m.startswith("http"):
            paths.add(m.strip())

missing = []
for p in sorted(paths):
    # strip trailing punctuation, wildcards
    clean = p.rstrip(".,;").replace("\\_", "_")
    if "*" in clean:
        base = clean.split("*")[0]
        if not list(REPO.glob(clean)) and not (REPO / base).exists():
            missing.append(clean)
    elif not (REPO / clean).exists():
        missing.append(clean)

# 2. Annex B must mention target_hh_imputed and update_pipeline (proxy for coverage)
annex_b = (MANUAL / "12_annex_b.tex").read_text()
required = ["target", "update_pipeline", "parse_kobo", "cross-checker", "ROUND_MAP"]
missing_terms = [t for t in required if t.lower() not in annex_b.lower()]

ok = True
if missing:
    ok = False
    print("MISSING PATHS:")
    for p in missing: print("  ", p)
if missing_terms:
    ok = False
    print("ANNEX B missing terms:", missing_terms)
print("OK" if ok else "FAIL")
sys.exit(0 if ok else 1)
```

- [ ] **Step 3: Run the verification script**

Run: `python3 CAPI/Analysis/SL/tex/check_manual.py`
Expected: prints `OK`, exit 0. If it lists MISSING PATHS, fix the offending `\rd{}` path in the relevant section file (a real typo) and re-run.

- [ ] **Step 4: Final full compile + PDF sanity**

Run: `cd CAPI/Analysis/SL/tex && tectonic L2PHL_Operational_Manual.tex && cd -`
Then confirm page count and that all parts render:
```bash
pdftotext CAPI/Analysis/SL/tex/L2PHL_Operational_Manual.pdf - | \
  grep -c -E "Motivation|Part I|Part II|Part III|Part IV|Annex A|Annex B|Annex C"
```
Expected: compile exit 0; grep count ≥ 8.

- [ ] **Step 5: Commit and update .gitignore for the PDF**

Ensure the compiled PDF is tracked (it is the hand-over artifact); ensure `check_manual.py` is tracked. Commit:
```bash
git add CAPI/Analysis/SL/tex/manual/13_annex_c.tex CAPI/Analysis/SL/tex/check_manual.py CAPI/Analysis/SL/tex/L2PHL_Operational_Manual.pdf
git commit -m "manual: annex C data access/security + verification script + compiled PDF"
```

---

## Final review (after all tasks)

Dispatch a final reviewer to read the compiled PDF end-to-end against the design spec and the turnover PDF, checking: (1) every turnover question is answered in the operational sections AND the Annex B crosswalk; (2) the S2S / `target_hh_imputed` chain is correct and consistent between Part II and Part III; (3) no fabricated numbers or dead file paths; (4) WB voice and branding are consistent; (5) the R9 worked example matches what was actually done. Fix any gaps, recompile, re-run `check_manual.py`.

Then use superpowers:finishing-a-development-branch.
