# L2PHL CATI — Data Quality Pipeline

Automated QC pipeline for the **L2PHL (Project TIPON) CATI Panel Survey** (Rounds 1–5+).

Generates two outputs from the actual project data:
- **`output/l2ph_dq_dashboard.html`** — interactive data quality dashboard
- **`output/L2PHL_Questionnaire_Cross_Round_Report.xlsx`** — cross-round questionnaire comparison

---

## Folder layout

```
CATI/
├── Questionnaire/          ← master questionnaire Excel files (R1–R5)
├── Round01/ … Round05/
│   └── do/                 ← Stata processing do-files
├── Analysis/
│   ├── HF/                 ← pooled panel datasets (M00–M09, all rounds)
│   │   ├── l2phl_M00_passport.dta
│   │   ├── … M01–M09 …
│   │   ├── l2phl_cati_household.dta
│   │   ├── l2phl_cati_individual.dta
│   │   ├── R01/  ← round-specific files
│   │   └── R05/
│   └── QC/                 ← this folder
│       ├── update_pipeline.py   ← run this
│       ├── scripts/
│       │   ├── build_dq.py
│       │   ├── gen_dashboard.py
│       │   └── build_report.py
│       ├── cache/           ← intermediate JSON (gitignored)
│       └── output/          ← generated outputs (gitignored)
```

---

## Requirements

```bash
pip install pandas pyreadstat openpyxl numpy
```

---

## Running the pipeline

From anywhere on your machine:

```bash
cd ~/iDrive/GitHub/PHL/L2PHL/CATI/Analysis/QC
python3 update_pipeline.py --all
```

### Flags

| Flag | What it does | When to use |
|------|-------------|-------------|
| `--dta` | Re-runs DQ checks from pooled `.dta` files in `Analysis/HF/` | New survey data pooled |
| `--questionnaire` | Re-parses questionnaire Excel files from `CATI/Questionnaire/` | New questionnaire version |
| `--dofiles` | Re-parses `.do` files from `CATI/Round*/do/` | New processing script |
| `--all` | All of the above | Easiest option / when unsure |

Without any flag, only the HTML and Excel outputs are regenerated from the existing cache.

### Example — new round added (e.g., R6)

1. Pool the R6 data into `Analysis/HF/l2phl_M*.dta` as usual
2. Place the R6 questionnaire in `CATI/Questionnaire/`
3. Place the R6 do-file in `CATI/Round06/do/`
4. Run: `python3 update_pipeline.py --all`

No code changes required — round numbers and modules are auto-detected.

---

## What the pipeline checks

**Data quality (from pooled .dta):**
- Skip logic violations — follow-up answered when gate says skip
- Mandatory field missing — required questions left blank
- Out-of-range values — responses outside valid code lists
- Interview duration anomalies

**Questionnaire tracking (from Excel questionnaires):**
- New questions per round
- Dropped questions
- Title changes
- Skip logic changes
- Data check rule changes

---

## Data confidentiality

All `.dta` files are gitignored. The repository contains only code and questionnaire Excel files. Do not commit raw data, sample frames, or fix records.
