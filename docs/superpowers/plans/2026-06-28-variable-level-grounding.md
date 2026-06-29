# Variable-Level Grounding — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`).

**Goal:** Caveat a storyline claim only by open firm issues on its *underlying variable* (when the stat key embeds one); module-level fallback otherwise.

**Architecture:** Add `_var_of`/`_base` to `grounding.py` and restructure `ground()` to filter candidate firm issues per claim. Regenerate grounding report + storyline badges.

**Tech Stack:** Python 3.12, pytest. `CATI/Analysis/QC/`.

---

## Task 1: Variable-level `ground()` (`grounding.py`)

**Files:** Modify `scripts/grounding.py`, `tests/test_grounding.py`.

- [ ] **Step 1: Add failing tests** to `tests/test_grounding.py` (append):
```python
def test_variable_level_excludes_mismatched_var():
    # claim about a16 (contract type); open firm issue is on a18 (pension) -> NOT a caveat
    isum = {"M04": {"strip": {}, "headline": "yellow"}}
    issues = [{"key":"M04/a18/r","module":"M04","verdict":"A2","status":"acknowledged","counts_by_round":{"8":9}}]
    rows = ground(["employment.no_contract_a16eq2"], isum, issues)
    assert rows[0]["claim_var"] == "a16"
    assert rows[0]["grounded"] is True and rows[0]["open_firm_issues"] == []

def test_variable_level_matches_same_var():
    # an open firm issue on a16 DOES caveat an a16 claim
    isum = {"M04": {"strip": {}, "headline": "yellow"}}
    issues = [{"key":"M04/a16/r","module":"M04","verdict":"A1","status":"new","counts_by_round":{"8":4}}]
    rows = ground(["employment.no_contract_a16eq2"], isum, issues)
    assert rows[0]["grounded"] is False and rows[0]["open_firm_issues"] == ["M04/a16/r"]

def test_aggregate_claim_falls_back_to_module():
    # 'hh_r1' embeds no variable -> module-level: any open firm issue in M01/R1 caveats it
    isum = {"M01": {"strip": {"1":"red"}, "headline":"red"}}
    issues = [{"key":"M01/d26_2/r","module":"M01","verdict":"B","status":"acknowledged","counts_by_round":{"1":5}}]
    rows = ground(["sample.hh_r1"], isum, issues)
    assert rows[0]["claim_var"] is None and rows[0]["grounded"] is False
```

- [ ] **Step 2: Run, expect FAIL.** `cd CATI/Analysis/QC && python3 -m pytest tests/test_grounding.py -q` (KeyError `claim_var` / assertion failures — the current module-level `ground()` would caveat the a16-vs-a18 case).

- [ ] **Step 3: Rewrite** `scripts/grounding.py` to:
```python
"""Ground storyline stat claims in the QC issue state (per module / round / variable)."""
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

def _var_of(subkey):
    """Underlying Kobo variable embedded in a stat subkey, e.g. 'no_contract_a16eq2'
    -> 'a16'; None for derived/aggregate keys ('hh_r1', 'mod_sev_r5')."""
    s = re.sub(r"eq\d+", "", subkey or "")               # drop eq<value> conditions
    toks = [t for t in re.findall(r"[a-z]+\d+", s) if not re.fullmatch(r"r\d+", t)]
    return toks[-1] if toks else None

def _base(v):
    return re.sub(r"_\d+$", "", (v or "").lower())

def ground(stat_keys, issue_summary, issues=None):
    """stat_keys: iterable of 'group.subkey'. -> one grounding row per key.

    A claim is a caveat iff an OPEN FIRM issue (A1/A2/B) touches its module AND round
    AND — when the claim embeds an underlying variable — that variable. Claims with no
    embedded variable fall back to module/round-level (conservative)."""
    firm_issues = [r for r in (issues or [])
                   if r.get("verdict") in FIRM_VERDICTS and r.get("status") in OPEN_STATES]
    rows = []
    for key in stat_keys:
        group, _, sub = key.partition(".")
        mod = GROUP_TO_MODULE.get(group)
        rd = _round_of(sub)
        if not mod:
            rows.append({"key": key, "module": None, "round": rd, "claim_var": None,
                         "qc_status": "unmapped", "open_firm_issues": [], "grounded": True})
            continue
        cvar = _var_of(sub)
        hits = []
        for r in firm_issues:
            if r["module"] != mod:
                continue
            cb = r.get("counts_by_round") or {}
            if rd and not cb.get(rd):
                continue
            if not rd and not any(cb.values()):
                continue
            if cvar and _base(r.get("variable")) != _base(cvar):   # variable-level filter
                continue
            hits.append(r["key"])
        firm = sorted(set(hits))
        summ = issue_summary.get(mod, {})
        status = (summ.get("strip") or {}).get(rd, "green") if rd else summ.get("headline", "green")
        rows.append({"key": key, "module": mod, "round": rd, "claim_var": cvar,
                     "qc_status": status, "open_firm_issues": firm, "grounded": not firm})
    return rows
```

- [ ] **Step 4: Run, expect PASS (9 passed — 6 existing + 3 new).** `cd CATI/Analysis/QC && python3 -m pytest tests/test_grounding.py -q`

- [ ] **Step 5: Commit.**
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git add CATI/Analysis/QC/scripts/grounding.py CATI/Analysis/QC/tests/test_grounding.py
git commit -m "feat(qc): variable-level grounding (claim's underlying var must match the issue)"
```

---

## Task 2: Regenerate grounding report + storyline badges

**Files:** Modify `CATI/Analysis/SL/l2p_cati_story.html` (regenerated badges).

- [ ] **Step 1: Regenerate + verify the precision change.**
```bash
cd CATI/Analysis/QC && python3 scripts/build_issues.py >/dev/null
echo "--- grounding (expect 3 caveats, sample only) ---"
python3 scripts/qc_issue.py grounding
python3 -c "
import json,sys; sys.path.insert(0,'scripts')
from grounding import ground; from build_grounding import _stat_keys
sl=json.load(open('../SL/sl_stats.json')); isum=json.load(open('cache/issue_summary.json')); iss=json.load(open('cache/issues.json'))
cav=[r['key'] for r in ground(_stat_keys(sl),isum,iss) if r.get('module') and not r['grounded']]
print('caveat keys:', cav)
"
echo "--- re-apply badges (employment ones should drop) ---"
python3 scripts/qc_issue.py storyline-badges
echo "badge count: $(python3 -c "print(open('../SL/l2p_cati_story.html').read().count('class=\"qc-caveat\"'))")"
echo "--- drift-check still OK ---"
cd ../SL && python3 build_story.py --check 2>&1 | tail -1
```
Expected: grounding → `3 to caveat`; caveat keys are the 3 `sample.*` only (no `employment.*`); badge count = 5; `build_story.py --check` → CHECK OK.

- [ ] **Step 2: Commit the regenerated storyline.**
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git add CATI/Analysis/SL/l2p_cati_story.html
git commit -m "build(qc): variable-level grounding removes false-alarm employment badges"
```

---

## Self-review

**Spec coverage:** `_var_of` extraction (T1) ✓; variable-level filter when claim embeds a var (T1) ✓; module fallback for aggregate keys (T1) ✓; `claim_var` on rows (T1) ✓; regenerate → 3 caveats / 5 badges, drift-safe (T2) ✓.

**Placeholder scan:** none.

**Consistency:** `ground()` still returns rows with `key/module/round/qc_status/open_firm_issues/grounded` plus the new `claim_var`; `build_grounding` and `build_storyline_badges` read only the unchanged fields (`module`, `grounded`, `open_firm_issues`, `key`), so they need no change. Existing 6 grounding tests rely on emp_status (no embedded var → module fallback) and fies/finance (no/clean issues) — all still pass.
