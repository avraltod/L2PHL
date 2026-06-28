# QC → Storyline Grounding — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`).

**Goal:** Author-facing report grounding storyline claims in QC issue state per module/round, via `grounding.py` + `build_grounding.py` + a `qc_issue.py grounding` hook.

**Architecture:** Pure `grounding.ground()` (group→module + `_rN`→round join against `issue_summary.json`/`issues.json`, TDD) + a report/`--check` writer + CLI hook.

**Tech Stack:** Python 3.12, pytest. All under `CATI/Analysis/QC/`. Reads `../SL/sl_stats.json`.

---

## File structure

| File | Change |
|------|--------|
| `scripts/grounding.py` | NEW — `GROUP_TO_MODULE`, `_round_of`, `ground` |
| `tests/test_grounding.py` | NEW |
| `scripts/build_grounding.py` | NEW — `build_report`, `run(check)` + `main` |
| `scripts/qc_issue.py` | MODIFY — add `grounding [--check]` |

---

## Task 1: Grounding engine (`grounding.py`)

**Files:** Create `scripts/grounding.py`, `tests/test_grounding.py`.

- [ ] **Step 1: Write the failing test** — `tests/test_grounding.py`:
```python
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))
from grounding import ground, _round_of

def test_round_of():
    assert _round_of("emp_status_r5") == "5"
    assert _round_of("any_shock_r3") == "3"
    assert _round_of("change_ppt") is None
    assert _round_of("bank_acc_f17") is None     # f17 is not a round

def test_ground_caveat_on_open_firm_issue_in_round():
    isum = {"M04": {"strip": {"5": "red"}, "headline": "yellow"}}
    issues = [{"key": "M04/a18/r", "module": "M04", "verdict": "A2",
               "status": "acknowledged", "counts_by_round": {"5": 9}}]
    rows = ground(["employment.emp_status_r5"], isum, issues)
    r = rows[0]
    assert r["module"] == "M04" and r["round"] == "5" and r["qc_status"] == "red"
    assert r["open_firm_issues"] == ["M04/a18/r"] and r["grounded"] is False

def test_ground_clean_claim():
    isum = {"M08": {"strip": {"5": "green"}, "headline": "green"}}
    rows = ground(["fies.mod_sev_r5"], isum, [])
    assert rows[0]["module"] == "M08" and rows[0]["grounded"] is True
    assert rows[0]["open_firm_issues"] == []

def test_ground_non_firm_issue_does_not_caveat():
    isum = {"M00": {"strip": {"5": "yellow"}, "headline": "yellow"}}
    issues = [{"key": "M00/dur/r", "module": "M00", "verdict": "D",
               "status": "new", "counts_by_round": {"5": 9}}]           # structural, not firm
    rows = ground(["sample.hh_r5"], isum, issues)   # note: sample->M01, so M00 issue is irrelevant here
    # use a key that maps to M00? sample->M01. Construct a direct check instead:
    rows2 = ground(["health.x_r5"], {"M07": {"strip": {"5": "yellow"}}},
                   [{"key": "M07/d/r", "module": "M07", "verdict": "D",
                     "status": "new", "counts_by_round": {"5": 1}}])
    assert rows2[0]["grounded"] is True             # D issue does not caveat

def test_ground_unmapped_group():
    rows = ground(["mystery.foo_r2"], {}, [])
    assert rows[0]["qc_status"] == "unmapped" and rows[0]["module"] is None

def test_ground_non_round_uses_headline():
    isum = {"M06": {"strip": {}, "headline": "yellow"}}
    rows = ground(["finance.bank_acc_f17"], isum, [])
    assert rows[0]["round"] is None and rows[0]["qc_status"] == "yellow"
```

- [ ] **Step 2: Run, expect FAIL.** `cd CATI/Analysis/QC && python3 -m pytest tests/test_grounding.py -q` → ModuleNotFoundError.

- [ ] **Step 3: Implement** `scripts/grounding.py`:
```python
"""Ground storyline stat claims in the QC issue state (per module / round)."""
import re
from issue_model import OPEN_STATES

GROUP_TO_MODULE = {
    "sample": "M01", "fies": "M08", "shocks": "M03", "finance": "M06",
    "health": "M07", "employment": "M04", "views": "M09",
}
FIRM_VERDICTS = {"A1", "A2", "B"}

def _round_of(subkey):
    """'emp_status_r5' -> '5'; 'bank_acc_f17' -> None."""
    m = re.search(r"_r(\d+)", subkey or "")
    return m.group(1) if m else None

def ground(stat_keys, issue_summary, issues=None):
    """stat_keys: iterable of 'group.subkey'. -> one grounding row per key."""
    issues = issues or []
    by_mod_round = {}            # (module, round) -> [open firm issue keys]
    by_mod = {}                  # module -> [open firm issue keys] (any round)
    for r in issues:
        if r.get("verdict") in FIRM_VERDICTS and r.get("status") in OPEN_STATES:
            for rd, n in (r.get("counts_by_round") or {}).items():
                if n:
                    by_mod_round.setdefault((r["module"], rd), []).append(r["key"])
                    by_mod.setdefault(r["module"], []).append(r["key"])
    rows = []
    for key in stat_keys:
        group, _, sub = key.partition(".")
        mod = GROUP_TO_MODULE.get(group)
        rd = _round_of(sub)
        if not mod:
            rows.append({"key": key, "module": None, "round": rd,
                         "qc_status": "unmapped", "open_firm_issues": [], "grounded": True})
            continue
        summ = issue_summary.get(mod, {})
        if rd:
            status = (summ.get("strip") or {}).get(rd, "green")
            firm = by_mod_round.get((mod, rd), [])
        else:
            status = summ.get("headline", "green")
            firm = by_mod.get(mod, [])
        firm = sorted(set(firm))
        rows.append({"key": key, "module": mod, "round": rd, "qc_status": status,
                     "open_firm_issues": firm, "grounded": not firm})
    return rows
```

- [ ] **Step 4: Run, expect PASS (6 passed).** `cd CATI/Analysis/QC && python3 -m pytest tests/test_grounding.py -q`

- [ ] **Step 5: Commit.**
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git add CATI/Analysis/QC/scripts/grounding.py CATI/Analysis/QC/tests/test_grounding.py
git commit -m "feat(qc): storyline grounding engine (claim -> module/round -> QC state)"
```

---

## Task 2: Report writer (`build_grounding.py`)

**Files:** Create `scripts/build_grounding.py`.

- [ ] **Step 1: Implement** `scripts/build_grounding.py`:
```python
"""Generate the storyline data-quality grounding report (and --check gate)."""
import os, json, sys, datetime
from grounding import ground

_HERE = os.path.dirname(__file__)            # CATI/Analysis/QC/scripts
_QC = os.path.dirname(_HERE)
_CACHE = os.path.join(_QC, "cache")
_OUTPUT = os.path.join(_QC, "output")
_SL_STATS = os.path.join(_QC, "..", "SL", "sl_stats.json")

def _stat_keys(sl_stats):
    keys = []
    for group, val in sl_stats.items():
        if group in ("_meta", "charts") or not isinstance(val, dict):
            continue
        for sub in val:
            keys.append(f"{group}.{sub}")
    return keys

def build_report(rows, today):
    caveat = [r for r in rows if r.get("module") and not r.get("grounded")]
    unmapped = sorted({r["key"].split(".")[0] for r in rows if r["qc_status"] == "unmapped"})
    out = ["# L2PHL CATI — Storyline Data-Quality Grounding", "",
           f"**{today}** · {len(rows)} claims · {len(caveat)} resting on open firm issues", ""]
    if caveat:
        out.append("## ⚠ Claims to caveat (rest on an open firm issue)")
        for r in sorted(caveat, key=lambda x: x["key"]):
            rd = f" R{r['round']}" if r["round"] else ""
            out.append(f"- `{r['key']}` → {r['module']}{rd} ({r['qc_status']}): {', '.join(r['open_firm_issues'])}")
        out.append("")
    else:
        out.append("_No claims rest on open firm issues — the storyline is grounded._\n")
    if unmapped:
        out.append(f"## Unmapped storyline groups ({len(unmapped)})")
        out.append(", ".join(unmapped) + " — add to GROUP_TO_MODULE in grounding.py\n")
    return "\n".join(out)

def run(check=False):
    today = datetime.date.today().strftime("%Y%m%d")
    sl = json.load(open(_SL_STATS))
    isum = json.load(open(os.path.join(_CACHE, "issue_summary.json")))
    issues = json.load(open(os.path.join(_CACHE, "issues.json")))
    rows = ground(_stat_keys(sl), isum, issues)
    caveat = [r for r in rows if r.get("module") and not r.get("grounded")]
    if check:
        print(f"Storyline grounding: {len(caveat)} claim(s) rest on open firm issues")
        for r in caveat:
            print(f"  CAVEAT {r['key']} -> {r['module']} ({', '.join(r['open_firm_issues'])})")
        return 1 if caveat else 0
    md = build_report(rows, today)
    os.makedirs(_OUTPUT, exist_ok=True)
    path = os.path.join(_OUTPUT, f"L2PHL_CATI_Storyline_Grounding_{today}.md")
    open(path, "w").write(md)
    print(f"Storyline grounding: {len(rows)} claims, {len(caveat)} to caveat -> {os.path.basename(path)}")
    return 0

def main():
    sys.exit(run(check="--check" in sys.argv))

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Smoke-test against the real caches.**
```bash
cd CATI/Analysis/QC && python3 scripts/build_issues.py >/dev/null
python3 scripts/build_grounding.py
echo "--- report head ---"; head -12 output/L2PHL_CATI_Storyline_Grounding_*.md
echo "--- check mode (exit code) ---"; python3 scripts/build_grounding.py --check; echo "exit=$?"
```
Expected: prints `Storyline grounding: 46 claims, N to caveat -> …md`; the report lists any claims resting on open firm issues (M04 employment claims if a18/a19 hit those rounds; else "storyline is grounded"); `--check` exits nonzero iff there are caveats.

- [ ] **Step 3: Commit.**
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git add CATI/Analysis/QC/scripts/build_grounding.py
git commit -m "feat(qc): storyline grounding report + --check gate"
```

---

## Task 3: CLI hook (`qc_issue.py grounding`)

**Files:** Modify `scripts/qc_issue.py`.

- [ ] **Step 1: Add the subcommand.** In `main()` after `dp = sub.add_parser("delivery"); …`, add:
```python
    gp = sub.add_parser("grounding"); gp.add_argument("--check", action="store_true")
```
and in the dispatch chain after the `delivery` branch:
```python
    elif a.cmd == "grounding":
        import build_grounding
        sys.exit(build_grounding.run(check=a.check))
```
(`sys` is already imported at the top of qc_issue.py.)

- [ ] **Step 2: Verify existing CLI tests still pass.** `cd CATI/Analysis/QC && python3 -m pytest tests/test_qc_issue.py -q` → 2 passed.

- [ ] **Step 3: Smoke-test the CLI.** `cd CATI/Analysis/QC && python3 scripts/qc_issue.py grounding`
Expected: prints `Storyline grounding: 46 claims, N to caveat -> …md`, no error.

- [ ] **Step 4: Commit.**
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git add CATI/Analysis/QC/scripts/qc_issue.py
git commit -m "feat(qc): qc-issue grounding subcommand"
```

---

## Self-review

**Spec coverage:** group→module + `_rN`→round join (T1) ✓; caveat = open firm issue in claim's round/module (T1) ✓; D/REVIEW do not caveat (T1 test) ✓; unmapped flagged (T1+T2) ✓; non-round → headline (T1) ✓; report md + console (T2) ✓; `--check` nonzero gate (T2) ✓; CLI hook (T3) ✓.

**Placeholder scan:** none.

**Consistency:** `ground` returns rows with `key/module/round/qc_status/open_firm_issues/grounded`; `build_grounding` reads exactly those; `_stat_keys` skips `_meta`/`charts` (matching build_story's chart_key/_meta exclusion). `GROUP_TO_MODULE` keys match the sl_stats.json top-level groups (sample/fies/shocks/finance/health/employment/views). `sys.exit(run())` propagates the `--check` gate.
