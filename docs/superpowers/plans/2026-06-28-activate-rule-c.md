# Activate rule_C — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`).

**Goal:** Populate `evidence.data["check_gate_refs"]` from the QC rule antecedent so the dormant **C** verdict fires; surface the check-gate in the dashboard evidence drill-in.

**Architecture:** A pure `_check_gate_refs(flag)` in `issue_evidence.py` + one line in `assemble_evidence` (TDD). Then a `gen_dashboard.py` evidence-drill-in tweak. End-to-end verified on real data.

**Tech Stack:** Python 3.12, pytest. `CATI/Analysis/QC/`.

---

## Task 1: Populate check_gate_refs (`issue_evidence.py`)

**Files:** Modify `scripts/issue_evidence.py`, `tests/test_issue_evidence.py`.

- [ ] **Step 1: Add failing tests** to `tests/test_issue_evidence.py` (append):
```python
def test_check_gate_refs_from_rule_antecedent():
    from issue_evidence import _check_gate_refs
    from issue_model import Flag
    f = Flag("M04", "a18", "rid", "skip", {"8": 5},
             label="A1=1, not eligible for A18 (A6 not in {1,2,3}; R4+ also A16 not in {3,99}) but A18 is filled")
    refs = _check_gate_refs(f)
    assert "a1" in refs and "a6" in refs and "a16" in refs    # gate vars
    assert "a18" not in refs                                   # the variable itself excluded
    assert "r4" not in refs                                    # round token excluded

def test_assemble_evidence_sets_check_gate_refs():
    f = Flag("M04", "a18", "rid", "skip", {"8": 5}, label="A1=1 but A18 filled")
    ev = assemble_evidence(f, make_ctx())
    assert ev.data["check_gate_refs"] == ["a1"]
```

- [ ] **Step 2: Run, expect FAIL.** `cd CATI/Analysis/QC && python3 -m pytest tests/test_issue_evidence.py -q` (ImportError / KeyError).

- [ ] **Step 3: Implement.** In `scripts/issue_evidence.py`, the module already `import re`. Add the helper above `assemble_evidence`:
```python
def _check_gate_refs(flag):
    """Gate variables our QC check declares, parsed from the rule antecedent (before 'but')."""
    ant = re.split(r"\bbut\b", flag.label or "", maxsplit=1)[0]
    own = flag.variable.lower().rstrip("_")
    refs = set()
    for tok in re.findall(r"\b([A-Za-z]{1,6}\d[A-Za-z0-9_]*)\b", ant):
        t = tok.lower()
        if re.fullmatch(r"r\d+", t):          # round token e.g. R4
            continue
        if t.rstrip("_") == own:              # the variable being checked itself
            continue
        refs.add(t)
    return sorted(refs)
```
And change the `ev.data = {...}` line in `assemble_evidence` to add the key:
```python
    ev.data = {"counts_by_round": flag.counts_by_round, "total": flag.total, "kind": flag.kind,
               "check_gate_refs": _check_gate_refs(flag)}
```

- [ ] **Step 4: Run, expect PASS.** `cd CATI/Analysis/QC && python3 -m pytest tests/test_issue_evidence.py -q` (all pass).

- [ ] **Step 5: Verify rule_C activates end-to-end on real data.**
```bash
cd CATI/Analysis/QC && python3 scripts/build_issues.py >/dev/null
python3 -c "
import json
d=json.load(open('cache/issues.json'))
for r in d:
    if r['rule_fired']=='check-vs-kobo':
        ig=set((r['evidence']['kobo'].get('gate_refs') or []))-set(r['evidence']['data'].get('check_gate_refs') or [])
        print(r['module'], r['variable'], 'proposed', r['proposed_verdict'], '| check ignores Kobo refs:', sorted(ig))
"
python3 -m pytest tests/ -q 2>&1 | tail -1
```
Expected: a18 and a19 print with `proposed C` and the ignored refs (a24/a26/a27); full suite green.

- [ ] **Step 6: Commit.**
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git add CATI/Analysis/QC/scripts/issue_evidence.py CATI/Analysis/QC/tests/test_issue_evidence.py
git commit -m "feat(qc): populate check_gate_refs from rule antecedent (activates rule_C)"
```

---

## Task 2: Surface the check-gate in the dashboard evidence drill-in

**Files:** Modify `scripts/gen_dashboard.py` (`renderIssues()` evbox).

- [ ] **Step 1: Add a "Check" line** to the evidence panel showing the check's gate and (for C) the refs it ignores. Find in `renderIssues()`:
```javascript
      const miss = (k.gate_refs_missing||[]).length ? '  ·  gate refs absent from data: '+k.gate_refs_missing.join(', ') : '';
```
Add right after it:
```javascript
      const cg = da.check_gate_refs || [];
      const ignored = (k.gate_refs||[]).filter(x=>!cg.includes(x));
      const checkLine = cg.length ? `\nCheck   · gate ${cg.join(', ')}${r.verdict==='C'&&ignored.length?'  ·  IGNORES Kobo refs: '+ignored.join(', '):''}` : '';
```
Then find the evbox template line beginning `Do-file · ` and insert `${checkLine}` immediately before the `Do-file` line. The evbox block is:
```javascript
        <div id="${did}" style="display:none"><div class="evbox">Data    · ${da.total||0} total · kind ${da.kind||''}
Kobo    · ${rel||'(var not in Kobo)'}${miss}
Do-file · ${d.ever_touched?'touched by a round do-file':'not touched by any do-file'}
```
Change the `Kobo …${miss}` line so the next line is the check line, i.e. replace `Kobo    · ${rel||'(var not in Kobo)'}${miss}` with `Kobo    · ${rel||'(var not in Kobo)'}${miss}${checkLine}`.

- [ ] **Step 2: Regenerate + verify (DOM-stub run).**
```bash
cd CATI/Analysis/QC && python3 scripts/gen_dashboard.py 2>&1 | grep -E "Generated|Error" | tail -1
python3 - <<'PY'
import re
h=open('output/l2ph_dq_dashboard.html').read()
js=next(x for x in re.findall(r'<script(?![^>]*src=)[^>]*>(.*?)</script>', h, re.S) if 'function renderIssues' in x)
i=js.index('function renderIssues(){'); d=0; st=False; e=i
for j in range(i,len(js)):
    c=js[j]
    if c=='{': d+=1; st=True
    elif c=='}':
        d-=1
        if st and d==0: e=j+1; break
open('/tmp/_ri.js','w').write(js[i:e])
PY
node -e '
const fs=require("fs");const ISSUES=JSON.parse(fs.readFileSync("cache/issues.json"));
const ISUM=JSON.parse(fs.readFileSync("cache/issue_summary.json"));const MOD_NAMES=new Proxy({},{get:()=>""});
let cap="";const cb={"iss-firm-only":{checked:false},"iss-review-only":{checked:false},"issues-body":{set innerHTML(v){cap=v;}}};
global.document={getElementById:id=>cb[id]||null};
eval(fs.readFileSync("/tmp/_ri.js","utf8"));renderIssues();
console.log("Check line present:", cap.includes("Check   · gate"), "| IGNORES present:", cap.includes("IGNORES Kobo refs"));
'
```
Expected: "Generated …"; "Check line present: true | IGNORES present: true" (the a18/a19 rows show the ignored refs — note: their *effective* verdict is A2 via the registry seed, so the IGNORES branch keys on `r.verdict` which is the effective A2; if it shows false, the check line still renders for the proposed-C signal via the gate text). If IGNORES shows false because effective verdict is A2, that is acceptable — the gate text still appears; note it in the report.

- [ ] **Step 3: Commit.**
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git add CATI/Analysis/QC/scripts/gen_dashboard.py
git commit -m "feat(qc): show check-gate (and ignored Kobo refs) in evidence drill-in"
```

---

## Self-review

**Spec coverage:** `_check_gate_refs` antecedent parse, round + self exclusion (T1) ✓; `assemble_evidence` populates `check_gate_refs` (T1) ✓; rule_C activates → a18/a19 proposed C (T1 step 5) ✓; dashboard surfaces check-gate (T2) ✓.

**Placeholder scan:** none.

**Consistency:** `_check_gate_refs` returns a sorted lowercased list; `rule_C` reads `ev.data["check_gate_refs"]` as a set; `gen_dashboard` reads `da.check_gate_refs` and `k.gate_refs` (both already in the record's evidence). The evbox change appends one line; existing Data/Kobo/Do-file/Verdict lines unchanged.

**Note for the controller:** after building, surface to the user that a18/a19 now *propose* C (our A18/A19 checks ignore A24/A26/A27 routing) and offer to re-seed them as C (which would drop them from the firm tracker). That is a user decision, out of plan scope.
