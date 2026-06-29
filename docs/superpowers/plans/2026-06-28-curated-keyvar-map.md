# Curated Key→Variable Map — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`).

**Goal:** Give aggregate storyline claims (no embedded variable) variable-level precision via a curated `KEY_VARS` map derived from `l2phl_master_analysis.do`.

**Architecture:** Add `KEY_VARS` + `_curated_vars` to `grounding.py`; in `ground()`, scope by embedded var, else curated vars (incl. `[]`), else module fallback. Regenerate badges (→ 0).

**Tech Stack:** Python 3.12, pytest. `CATI/Analysis/QC/`.

---

## Task 1: Curated map in `ground()` (`grounding.py`)

**Files:** Modify `scripts/grounding.py`, `tests/test_grounding.py`.

- [ ] **Step 1: Update + add tests** in `tests/test_grounding.py`.

  (a) **Replace** `test_ground_caveat_on_open_firm_issue_in_round` (emp_status is now curated to {a1, emp_status}; caveat it via an `a1` issue):
```python
def test_ground_caveat_on_open_firm_issue_in_round():
    isum = {"M04": {"strip": {"5": "red"}, "headline": "yellow"}}
    issues = [{"key":"M04/a1/r","module":"M04","variable":"a1","verdict":"A2",
               "status":"acknowledged","counts_by_round":{"5":9}}]
    rows = ground(["employment.emp_status_r5"], isum, issues)   # emp_status -> {a1, emp_status}
    r = rows[0]
    assert r["module"]=="M04" and r["round"]=="5" and r["qc_status"]=="red"
    assert r["open_firm_issues"]==["M04/a1/r"] and r["grounded"] is False
```

  (b) **Replace** `test_aggregate_claim_falls_back_to_module` with three tests:
```python
def test_curated_count_is_grounded():
    # sample.hh_r1 -> structural count (KEY_VARS=[]) -> NOT caveated by a migration issue
    isum = {"M01": {"strip": {"1":"red"}, "headline":"red"}}
    issues = [{"key":"M01/d26_2/r","module":"M01","variable":"d26_2","verdict":"B",
               "status":"acknowledged","counts_by_round":{"1":5}}]
    rows = ground(["sample.hh_r1"], isum, issues)
    assert rows[0]["grounded"] is True and rows[0]["open_firm_issues"] == []

def test_curated_fies_matches_f08_item():
    isum = {"M08": {"strip": {"5":"red"}, "headline":"red"}}
    issues = [{"key":"M08/f08_c/r","module":"M08","variable":"f08_c","verdict":"A2",
               "status":"new","counts_by_round":{"5":7}}]
    rows = ground(["fies.mod_sev_r5"], isum, issues)            # fies -> {f08_a..e}
    assert rows[0]["grounded"] is False and "M08/f08_c/r" in rows[0]["open_firm_issues"]

def test_unmapped_aggregate_falls_back_to_module():
    # 'philhealth_r5' has no embedded var AND no curated entry -> module-level fallback
    isum = {"M07": {"strip": {"5":"red"}, "headline":"red"}}
    issues = [{"key":"M07/h4/r","module":"M07","variable":"h4","verdict":"A2",
               "status":"new","counts_by_round":{"5":3}}]
    rows = ground(["health.philhealth_r5"], isum, issues)
    assert rows[0]["claim_var"] is None and rows[0]["grounded"] is False
```

- [ ] **Step 2: Run, expect FAIL.** `cd CATI/Analysis/QC && python3 -m pytest tests/test_grounding.py -q` (the curated tests fail; current code module-folds them).

- [ ] **Step 3: Edit** `scripts/grounding.py`. Add the map after `FIRM_VERDICTS`:
```python
# Underlying Kobo variable(s) for aggregate stat keys that embed none
# (from l2phl_master_analysis.do). [] = a structural count (no data variable).
KEY_VARS = {
    "sample": [],
    "fies": ["f08_a", "f08_b", "f08_c", "f08_d", "f08_e"],
    "views": ["v1"],
    "employment.emp_status": ["a1", "emp_status"],
    "shocks.any_shock": ["sh1"],
    "shocks.water_disruption": ["sh3"],
    "shocks.mean_water_days": ["sh3"],
    "health.total_individuals": [],
}
```
Add the helper after `_base`:
```python
def _curated_vars(key):
    """Longest-prefix match in KEY_VARS -> var list (possibly []); None if unmapped."""
    best_p, best_v = None, None
    for p, vs in KEY_VARS.items():
        if (key == p or key.startswith(p + ".") or key.startswith(p + "_")) \
                and (best_p is None or len(p) > len(best_p)):
            best_p, best_v = p, vs
    return best_v
```
Replace the body of the per-key loop in `ground()` (the part computing `cvar`/`hits`) with the embedded-else-curated-else-fallback logic:
```python
        cvar = _var_of(sub)
        if cvar:
            match_vars, scoped = {_base(cvar)}, True
        else:
            cv = _curated_vars(key)
            if cv is not None:
                match_vars, scoped = {_base(v) for v in cv}, True
            else:
                match_vars, scoped = None, False
        hits = []
        for r in firm_issues:
            if r["module"] != mod:
                continue
            cb = r.get("counts_by_round") or {}
            if rd and not cb.get(rd):
                continue
            if not rd and not any(cb.values()):
                continue
            if scoped and _base(r.get("variable")) not in match_vars:
                continue
            hits.append(r["key"])
```
(Keep the `firm = sorted(set(hits))`, `summ`/`status`, and the `rows.append({... "claim_var": cvar ...})` lines unchanged.)

- [ ] **Step 4: Run, expect PASS** (all grounding tests). `cd CATI/Analysis/QC && python3 -m pytest tests/test_grounding.py -q`

- [ ] **Step 5: Full suite + commit.**
```bash
cd CATI/Analysis/QC && python3 -m pytest tests/ -q | tail -1
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git add CATI/Analysis/QC/scripts/grounding.py CATI/Analysis/QC/tests/test_grounding.py
git commit -m "feat(qc): curated key->variable map for aggregate storyline claims"
```

---

## Task 2: Regenerate grounding + badges

**Files:** Modify `CATI/Analysis/SL/l2p_cati_story.html`.

- [ ] **Step 1: Regenerate + verify (expect 0 caveats / 0 badges).**
```bash
cd CATI/Analysis/QC && python3 scripts/build_issues.py >/dev/null
python3 scripts/qc_issue.py grounding
python3 -c "
import json,sys; sys.path.insert(0,'scripts')
from grounding import ground; from build_grounding import _stat_keys
sl=json.load(open('../SL/sl_stats.json')); isum=json.load(open('cache/issue_summary.json')); iss=json.load(open('cache/issues.json'))
print('caveats:', [r['key'] for r in ground(_stat_keys(sl),isum,iss) if r.get('module') and not r['grounded']])
"
python3 scripts/qc_issue.py storyline-badges
echo "badge count: $(python3 -c "print(open('../SL/l2p_cati_story.html').read().count('class=\"qc-caveat\"'))")"
cd ../SL && python3 build_story.py --check 2>&1 | tail -1
```
Expected: `0 to caveat`; caveats `[]`; badge count `0`; `build_story.py --check` → CHECK OK.

- [ ] **Step 2: Commit the regenerated storyline.**
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git add CATI/Analysis/SL/l2p_cati_story.html
git commit -m "build(qc): curated map grounds sample counts -> storyline fully grounded (0 badges)"
```

---

## Self-review

**Spec coverage:** `KEY_VARS` from the do-file (T1) ✓; `_curated_vars` longest-prefix (T1) ✓; embedded→curated→fallback precedence (T1) ✓; `[]` count never caveated, fies/emp_status matched, unmapped falls back (T1 tests) ✓; regenerate → 0 caveats/badges, drift-safe (T2) ✓.

**Placeholder scan:** none.

**Consistency:** `ground()` still returns `key/module/round/claim_var/qc_status/open_firm_issues/grounded`; `claim_var` stays the embedded var (None for aggregates); `build_grounding`/`build_storyline_badges` read only `module`/`grounded`/`open_firm_issues`/`key` — unchanged. The two updated tests reflect that emp_status and sample are now curated, not module-folded.
