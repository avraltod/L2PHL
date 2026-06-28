# Firm QC Tracker — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Generate a firm-actionable Excel QC tracker (`output/L2PHL_CATI_Firm_QC_Tracker_<YYYYMMDD>.xlsx`) from the open, firm-owned issues in `issues.json`.

**Architecture:** A pure `firm_rows(records)` shaper (TDD) + a `build_firm_report.py` openpyxl writer (verified by generate-then-read-back) + a `qc_issue.py firm-report` CLI hook. On-demand deliverable, not wired into the pipeline.

**Tech Stack:** Python 3.12, openpyxl (already a dependency), pytest. All under `CATI/Analysis/QC/`.

---

## File structure

| File | Change |
|------|--------|
| `scripts/firm_report.py` | NEW — `firm_rows(records) -> list[dict]` |
| `tests/test_firm_report.py` | NEW |
| `scripts/build_firm_report.py` | NEW — `build(records, today)` + `main()` → xlsx |
| `tests/test_build_firm_report.py` | NEW |
| `scripts/qc_issue.py` | MODIFY — add `firm-report` subcommand |

---

## Task 1: Row shaper (`firm_report.py`)

**Files:** Create `scripts/firm_report.py`, `tests/test_firm_report.py`.

- [ ] **Step 1: Write the failing test** — `tests/test_firm_report.py`:
```python
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))
from firm_report import firm_rows

def rec(**kw):
    base = {"report_to_firm": True, "status": "acknowledged", "verdict": "A2",
            "module": "M04", "variable": "a18", "label": "rule", "owner": "firm-field",
            "counts_by_round": {"6": 12, "5": 9}, "evidence": {}, "notes": ""}
    base.update(kw); return base

def test_includes_only_open_firm():
    recs = [rec(),                          # open firm -> in
            rec(report_to_firm=False),      # not firm -> out
            rec(status="wontfix"),          # closed -> out
            rec(status="resolved")]         # closed -> out
    rows = firm_rows(recs)
    assert len(rows) == 1 and rows[0]["module"] == "M04"

def test_row_shape():
    ev = {"kobo": {"relevant_by_round": {"5": "${A6}=1", "6": "${A6}=1 or ${A16}=3"},
                   "gate_refs_missing": ["fmida1"]},
          "dofile": {"ever_touched": False}}
    rows = firm_rows([rec(evidence=ev, notes="extend the recode to R6-R8")])
    r = rows[0]
    assert r["rounds"] == "R5:9, R6:12"               # round-sorted, nonzero
    assert r["total"] == 21
    assert r["root_cause"] == "Field / interviewer"   # A2
    assert "${A6}=1 or ${A16}=3" in r["kobo_gate"]     # latest relevant
    assert "fmida1" in r["kobo_gate"]                  # missing refs appended
    assert r["dofile"] == "not touched"
    assert r["fix"] == "extend the recode to R6-R8"

def test_sorted_by_owner_module_variable():
    recs = [rec(owner="firm-field", module="M04", variable="a19"),
            rec(owner="firm-dofile", module="M01", variable="d26_2"),
            rec(owner="firm-field", module="M04", variable="a18")]
    rows = firm_rows(recs)
    assert [(r["owner"], r["variable"]) for r in rows] == \
           [("firm-dofile","d26_2"),("firm-field","a18"),("firm-field","a19")]
```

- [ ] **Step 2: Run, expect FAIL.** `cd CATI/Analysis/QC && python3 -m pytest tests/test_firm_report.py -q` → ModuleNotFoundError.

- [ ] **Step 3: Implement** `scripts/firm_report.py`:
```python
"""Shape open firm-owned issue records into firm-report rows."""
from issue_model import OPEN_STATES

LAYER = {"A1": "Questionnaire / Kobo skip logic",
         "A2": "Field / interviewer",
         "B":  "Do-file / pooler processing"}

def _rounds(cb):
    items = sorted(((k, v) for k, v in (cb or {}).items() if v),
                   key=lambda kv: int(kv[0]))
    return ", ".join(f"R{k}:{v}" for k, v in items)

def _total(cb):
    return sum(int(v) for v in (cb or {}).values() if isinstance(v, (int, float)))

def _kobo_gate(ev):
    k = (ev or {}).get("kobo", {}) or {}
    rbr = k.get("relevant_by_round") or {}
    latest = None
    for rd in sorted(rbr, key=lambda x: int(x)):
        if rbr[rd]:
            latest = rbr[rd]
    miss = k.get("gate_refs_missing") or []
    base = latest or "(var not in Kobo)"
    return base + (f"  ·  missing refs: {', '.join(miss)}" if miss else "")

def firm_rows(records):
    rows = []
    for r in records:
        if not r.get("report_to_firm"):
            continue
        if r.get("status") not in OPEN_STATES:
            continue
        ev = r.get("evidence", {}) or {}
        rows.append({
            "module": r.get("module", ""),
            "variable": r.get("variable", ""),
            "issue": r.get("label", ""),
            "rounds": _rounds(r.get("counts_by_round")),
            "total": _total(r.get("counts_by_round")),
            "root_cause": LAYER.get(r.get("verdict"), r.get("verdict") or ""),
            "owner": r.get("owner", ""),
            "kobo_gate": _kobo_gate(ev),
            "dofile": "touched by a round do-file" if (ev.get("dofile") or {}).get("ever_touched") else "not touched",
            "fix": r.get("notes", "") or "",
            "status": r.get("status", ""),
        })
    rows.sort(key=lambda x: (x["owner"] or "", x["module"] or "", x["variable"] or ""))
    return rows
```

- [ ] **Step 4: Run, expect PASS (3 passed).** `cd CATI/Analysis/QC && python3 -m pytest tests/test_firm_report.py -q`

- [ ] **Step 5: Commit.**
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git add CATI/Analysis/QC/scripts/firm_report.py CATI/Analysis/QC/tests/test_firm_report.py
git commit -m "feat(qc): firm-report row shaper"
```

---

## Task 2: Excel writer (`build_firm_report.py`)

**Files:** Create `scripts/build_firm_report.py`, `tests/test_build_firm_report.py`.

- [ ] **Step 1: Write the failing test** — `tests/test_build_firm_report.py`:
```python
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))
from build_firm_report import build, HEADERS
from openpyxl import load_workbook

def rec(**kw):
    base = {"report_to_firm": True, "status": "acknowledged", "verdict": "A2",
            "module":"M04","variable":"a18","label":"A1=2 but A18 filled","owner":"firm-field",
            "counts_by_round":{"6":12},"evidence":{"kobo":{},"dofile":{"ever_touched":False}},
            "notes":"fix it"}
    base.update(kw); return base

def test_workbook_structure(tmp_path):
    wb = build([rec(), rec(report_to_firm=False)], "20260628")
    p = tmp_path/"t.xlsx"; wb.save(p)
    ws = load_workbook(p).active
    headers = [ws.cell(4, c).value for c in range(1, len(HEADERS)+1)]
    assert headers == HEADERS                              # header row at row 4
    assert ws.cell(5, 2).value == "M04" and ws.cell(5, 3).value == "a18"  # 1 data row
    assert ws.cell(6, 2).value is None                    # only the open firm one
    assert ws.cell(4, 13).value == "Firm response / fixed?"
    assert ws.cell(5, 13).value in (None, "")             # response col empty
    assert "Firm Data Quality Tracker" in ws.cell(1, 1).value
    assert "1 open firm issue" in ws.cell(2, 1).value
```

- [ ] **Step 2: Run, expect FAIL.** `cd CATI/Analysis/QC && python3 -m pytest tests/test_build_firm_report.py -q` → ModuleNotFoundError.

- [ ] **Step 3: Implement** `scripts/build_firm_report.py`:
```python
"""Generate the firm-actionable Excel QC tracker from issues.json."""
import os, json, datetime
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter
from firm_report import firm_rows

_HERE = os.path.dirname(__file__)
_CACHE = os.path.join(_HERE, "..", "cache")
_OUTPUT = os.path.join(_HERE, "..", "output")

HEADERS = ["#", "Module", "Variable", "Issue", "Rounds affected", "Total flagged",
           "Root cause", "Owner", "Evidence — Kobo gate", "Evidence — Do-file",
           "Recommended fix", "Status", "Firm response / fixed?", "Date fixed"]
WIDTHS  = [4, 8, 10, 40, 16, 8, 26, 16, 40, 22, 40, 14, 26, 14]
WRAP    = {"Issue", "Evidence — Kobo gate", "Recommended fix"}
RESP    = {"Firm response / fixed?", "Date fixed"}
NAVY = "FF002244"; CREAM = "FFFFF8DC"

def build(records, today):
    wb = Workbook(); ws = wb.active; ws.title = "Firm QC Tracker"
    rows = firm_rows(records)
    ws.cell(1, 1, "L2PHL CATI — Firm Data Quality Tracker").font = Font(size=14, bold=True)
    ws.cell(2, 1, f"Generated {today} · {len(rows)} open firm issue(s) · please fill the two right-hand columns")
    hdr = 4
    thin = Side(style="thin", color="FFBFBFBF")
    border = Border(left=thin, right=thin, top=thin, bottom=thin)
    for c, h in enumerate(HEADERS, 1):
        cell = ws.cell(hdr, c, h)
        cell.font = Font(bold=True, color="FFFFFFFF")
        cell.fill = PatternFill("solid", fgColor=NAVY)
        cell.alignment = Alignment(vertical="center", wrap_text=True)
        cell.border = border
    for i, r in enumerate(rows, 1):
        vals = [i, r["module"], r["variable"], r["issue"], r["rounds"], r["total"],
                r["root_cause"], r["owner"], r["kobo_gate"], r["dofile"],
                r["fix"], r["status"], "", ""]
        rr = hdr + i
        for c, v in enumerate(vals, 1):
            cell = ws.cell(rr, c, v)
            cell.alignment = Alignment(vertical="top", wrap_text=HEADERS[c-1] in WRAP)
            cell.border = border
            if HEADERS[c-1] in RESP:
                cell.fill = PatternFill("solid", fgColor=CREAM)
    for c, w in enumerate(WIDTHS, 1):
        ws.column_dimensions[get_column_letter(c)].width = w
    ws.freeze_panes = ws.cell(hdr + 1, 1)
    return wb

def main():
    issues = json.load(open(os.path.join(_CACHE, "issues.json")))
    today = datetime.date.today().strftime("%Y%m%d")
    wb = build(issues, today)
    os.makedirs(_OUTPUT, exist_ok=True)
    path = os.path.join(_OUTPUT, f"L2PHL_CATI_Firm_QC_Tracker_{today}.xlsx")
    wb.save(path)
    print(f"Firm QC Tracker: {len(firm_rows(issues))} open firm issue(s) -> {os.path.basename(path)}")

if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run, expect PASS (1 passed).** `cd CATI/Analysis/QC && python3 -m pytest tests/test_build_firm_report.py -q`

- [ ] **Step 5: Smoke-test against the real cache.** `cd CATI/Analysis/QC && python3 scripts/build_firm_report.py`
Expected: prints `Firm QC Tracker: 3 open firm issue(s) -> L2PHL_CATI_Firm_QC_Tracker_<date>.xlsx`; the file exists in `output/`. Read it back: `python3 -c "from openpyxl import load_workbook; import glob; ws=load_workbook(sorted(glob.glob('output/L2PHL_CATI_Firm_QC_Tracker_*.xlsx'))[-1]).active; print(ws.cell(2,1).value); [print(ws.cell(5+i,2).value, ws.cell(5+i,3).value, '|', ws.cell(5+i,7).value) for i in range(3)]"`. Expected: summary line + the 3 rows (M01 d26_2 Do-file/pooler, M04 a18 Field, M04 a19 Field).

- [ ] **Step 6: Commit** (the generated .xlsx is a dated deliverable in `output/` — commit it too if `output/*.xlsx` is tracked; check `git check-ignore` first and only add if not ignored):
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git add CATI/Analysis/QC/scripts/build_firm_report.py CATI/Analysis/QC/tests/test_build_firm_report.py
git commit -m "feat(qc): firm QC tracker xlsx writer"
```

---

## Task 3: CLI hook (`qc_issue.py firm-report`)

**Files:** Modify `scripts/qc_issue.py`.

- [ ] **Step 1: Add the subcommand.** In `scripts/qc_issue.py`, in `main()` where the subparsers are declared (near `sub.add_parser("review")`), add:
```python
    sub.add_parser("firm-report")
```
and in the command dispatch (the `if a.cmd == ... elif ...` chain), add a branch:
```python
    elif a.cmd == "firm-report":
        import build_firm_report
        build_firm_report.main()
```

- [ ] **Step 2: Verify existing tests still pass.** `cd CATI/Analysis/QC && python3 -m pytest tests/test_qc_issue.py -q` → expect 2 passed (unchanged).

- [ ] **Step 3: Smoke-test the CLI.** `cd CATI/Analysis/QC && python3 scripts/qc_issue.py firm-report`
Expected: prints `Firm QC Tracker: 3 open firm issue(s) -> …xlsx` with no error.

- [ ] **Step 4: Commit.**
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git add CATI/Analysis/QC/scripts/qc_issue.py
git commit -m "feat(qc): qc-issue firm-report subcommand"
```

---

## Self-review

**Spec coverage:** filter open+report_to_firm (T1) ✓; all columns sourced from existing record fields (T1 shaper, T2 writer) ✓; root-cause mapping ✓; rounds string ✓; evidence Kobo+Do-file ✓; fix from notes ✓; sorted owner→module→variable ✓; styled xlsx with tinted response cols + frozen header + title/summary (T2) ✓; dated filename in output/ ✓; CLI hook (T3) ✓; NOT pipeline-wired ✓.

**Placeholder scan:** none — full code in every step.

**Type consistency:** `firm_rows` returns dicts with keys `module/variable/issue/rounds/total/root_cause/owner/kobo_gate/dofile/fix/status`; `build_firm_report.build` reads exactly those keys; `HEADERS` order matches the `vals` list order in T2. The two trailing response columns (indices 13–14) are written empty and tinted.

**Edge note:** `firm_rows` is resilient to missing `evidence`/`counts_by_round`/`notes` via `.get(...) or {}` / `or ""`. `severity` deliberately omitted (not on the record).
