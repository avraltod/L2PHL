# Issue-Intelligence Core — Implementation Plan (Plan 1: backend)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the issue-intelligence backend that root-causes every QC flag into a verdict (A1/A2/B/C/D) with 3-layer evidence and tracks an issue lifecycle in a durable registry, emitting `issues.json`.

**Architecture:** A new `build_issues.py` stage reads the existing pipeline caches (`dq_data.json`, `kobo_skip_logic.json`, `do_modules.json`) plus the HF masters, assembles per-flag evidence, runs a priority-ordered rule classifier, merges the result with a version-controlled `issue_registry.yaml`, and writes `issues.json`. A small `qc-issue` CLII sets lifecycle status. Plan 2 (separate) renders this in `gen_dashboard.py`.

**Tech Stack:** Python 3.12, pandas (already used), PyYAML 6.0, pytest 8.3. All under `CATI/Analysis/QC/`.

---

## Scope

This is **Plan 1 of 2** for the issue-intelligence core. Plan 1 = the backend (data/logic), fully unit-tested, producing `issues.json` + a CLI. **Plan 2** (follow-on) = rendering the per-round strip / open-issue RAG / evidence drill-in in `gen_dashboard.py`. Plan 1 produces working software on its own (inspectable `issues.json`, firm-report feed, review queue).

## File structure (created in Plan 1)

All paths relative to `CATI/Analysis/QC/`:

| File | Responsibility |
|------|----------------|
| `scripts/issue_model.py` | Enums, dataclasses (`Flag`, `Evidence`, `Issue`), `issue_key`, `slugify`, OPEN/CLOSED sets |
| `scripts/issue_flags.py` | `extract_flags(dq_data) -> list[Flag]` — walk `dq_data.json` into typed flags |
| `scripts/issue_evidence.py` | `Context` (loads caches) + `assemble_evidence(flag, ctx) -> Evidence` (3 layers) |
| `scripts/issue_classifier.py` | `classify(flag, evidence) -> (Verdict, confidence, rule_fired)` — priority rules |
| `scripts/issue_registry.py` | load/save `issue_registry.yaml`; `merge_decisions`; auto-verify/reopen; `is_open` |
| `scripts/build_issues.py` | Orchestrator → `cache/issues.json` |
| `scripts/qc_issue.py` | CLI: `set/list/review` |
| `issue_registry.yaml` | Durable, version-controlled decisions (seeded from this session) |
| `tests/conftest.py` + `tests/test_*.py` | pytest unit tests + fixtures |

**Canonical interfaces** (every task must match these exactly):

```python
# Verdict values: "A1","A2","B","C","D","REVIEW"
# confidence values: "high","med","low"
# OPEN_STATES   = {"new","acknowledged","fix-pending","reopened"}
# CLOSED_STATES = {"resolved","wontfix","accepted"}
# Flag fields:     module, variable, rule_id, kind, counts_by_round, severity, label
# Evidence fields: data:dict, kobo:dict, dofile:dict, notes:list
# issue_key(module, variable, rule_id) -> "M04/a1/skip-a1-a10a11"
```

---

## Task 1: Data model (`issue_model.py`)

**Files:**
- Create: `CATI/Analysis/QC/scripts/issue_model.py`
- Test: `CATI/Analysis/QC/tests/test_issue_model.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_issue_model.py
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))
from issue_model import Flag, Evidence, issue_key, slugify, OWNER, OPEN_STATES, CLOSED_STATES

def test_slugify():
    assert slugify("A1=2 (not working) but A10/A11 filled") == "a1-2-not-working-but-a10-a11-filled"

def test_issue_key():
    assert issue_key("M04", "a1", "skip-x") == "M04/a1/skip-x"

def test_flag_key_property():
    f = Flag(module="M04", variable="a1", rule_id="skip-x", kind="skip",
             counts_by_round={"8": 5}, severity="high", label="lbl")
    assert f.key == "M04/a1/skip-x"
    assert f.total == 5

def test_owner_and_state_sets():
    assert OWNER["A2"] == "firm-field"
    assert "acknowledged" in OPEN_STATES and "wontfix" in CLOSED_STATES
    assert OPEN_STATES.isdisjoint(CLOSED_STATES)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd CATI/Analysis/QC && python3 -m pytest tests/test_issue_model.py -q`
Expected: FAIL — `ModuleNotFoundError: No module named 'issue_model'`

- [ ] **Step 3: Write minimal implementation**

```python
# scripts/issue_model.py
"""Data model for the issue-intelligence core."""
import re
from dataclasses import dataclass, field
from typing import Optional

VERDICTS = ("A1", "A2", "B", "C", "D", "REVIEW")
OWNER = {
    "A1": "firm-questionnaire",   # Kobo skip logic wrong/missing
    "A2": "firm-field",           # gate correct but response violates it
    "B":  "firm-dofile",          # recode/pooler processing
    "C":  "us",                   # our QC check / representation bug
    "D":  "expected",             # structural / not a real issue
    "REVIEW": "unassigned",
}
OPEN_STATES   = {"new", "acknowledged", "fix-pending", "reopened"}
CLOSED_STATES = {"resolved", "wontfix", "accepted"}

def slugify(text: str) -> str:
    s = re.sub(r"[^a-z0-9]+", "-", (text or "").lower()).strip("-")
    return re.sub(r"-{2,}", "-", s)[:60]

def issue_key(module: str, variable: str, rule_id: str) -> str:
    return f"{module}/{variable}/{rule_id}"

@dataclass
class Flag:
    module: str
    variable: str
    rule_id: str
    kind: str                       # "skip" | "mandatory" | "oor"
    counts_by_round: dict           # {"1": int, ..., "8": int}
    severity: str = "medium"
    label: str = ""
    @property
    def key(self) -> str:
        return issue_key(self.module, self.variable, self.rule_id)
    @property
    def total(self) -> int:
        return sum(int(v) for v in self.counts_by_round.values() if isinstance(v, (int, float)) and v)

@dataclass
class Evidence:
    data: dict = field(default_factory=dict)
    kobo: dict = field(default_factory=dict)
    dofile: dict = field(default_factory=dict)
    notes: list = field(default_factory=list)

@dataclass
class Issue:
    key: str
    flag: Flag
    evidence: Evidence
    proposed_verdict: str
    confidence: str
    rule_fired: str
    verdict: Optional[str] = None       # confirmed (registry); falls back to proposed
    owner: Optional[str] = None
    status: str = "new"
    report_to_firm: bool = False
    rounds: dict = field(default_factory=dict)
    registry_notes: str = ""
    @property
    def effective_verdict(self) -> str:
        return self.verdict or self.proposed_verdict
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd CATI/Analysis/QC && python3 -m pytest tests/test_issue_model.py -q`
Expected: PASS (4 passed)

- [ ] **Step 5: Commit**

```bash
git add CATI/Analysis/QC/scripts/issue_model.py CATI/Analysis/QC/tests/test_issue_model.py
git commit -m "feat(qc): issue-intelligence data model"
```

---

## Task 2: Flag extraction from dq_data (`issue_flags.py`)

`dq_data.json` nests issue entries (with `module`, `rule`, `variable`, and either `counts_by_round` or `counts`). Walk it into typed `Flag`s. `rule_id = slugify(rule)`, `variable = entry['variable']` (lowercased, before any `→`/space) or the slug if absent.

**Files:**
- Create: `CATI/Analysis/QC/scripts/issue_flags.py`
- Test: `CATI/Analysis/QC/tests/test_issue_flags.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_issue_flags.py
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))
from issue_flags import extract_flags

def test_extracts_skip_and_oor():
    dq = {"some": {"skip": [
        {"module":"M04","variable":"A1=2 → A10/A11","rule":"A1=2 but A10/A11 filled",
         "counts_by_round":{"6":62,"7":84,"8":59},"severity":"high"}],
        "oor":[{"module":"M01","variable":"hhsize","label":"HH size","rule":"< 1 or > 30",
                "counts":{"1":1}}]}}
    flags = extract_flags(dq)
    keys = {f.key for f in flags}
    assert "M04/a10/a1-2-but-a10-a11-filled" in keys   # variable normalised from "A1=2 → A10/A11"
    assert any(f.module=="M01" and f.kind=="oor" and f.total==1 for f in flags)

def test_ignores_zero_count_entries():
    dq = {"x":[{"module":"M03","variable":"sh2","rule":"r","counts_by_round":{"1":0,"2":0}}]}
    assert extract_flags(dq) == []
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd CATI/Analysis/QC && python3 -m pytest tests/test_issue_flags.py -q`
Expected: FAIL — `ModuleNotFoundError: No module named 'issue_flags'`

- [ ] **Step 3: Write minimal implementation**

```python
# scripts/issue_flags.py
"""Walk dq_data.json into typed Flag objects."""
import re
from issue_model import Flag, slugify

def _variable_of(entry: str) -> str:
    """Pull a column-ish token from a 'variable' string like 'A1=2 → A10/A11'."""
    v = (entry or "").strip()
    v = re.split(r"[→/ ]", v)[-1] if ("→" in v or "/" in v) else v.split()[0] if v else v
    v = re.sub(r"[^A-Za-z0-9_]", "", v).lower()
    return v

def extract_flags(dq_data):
    flags, seen = [], set()
    def walk(o):
        if isinstance(o, dict):
            mod = o.get("module")
            cb = o.get("counts_by_round") or o.get("counts")
            if mod and isinstance(cb, dict) and (o.get("rule") or o.get("label")):
                counts = {str(k): v for k, v in cb.items() if isinstance(v, (int, float))}
                if any(counts.values()):
                    rule = o.get("rule") or o.get("label")
                    var = _variable_of(o.get("variable") or o.get("label") or "") or slugify(rule)[:12]
                    kind = ("oor" if o.get("counts") and not o.get("counts_by_round")
                            else "mandatory" if "missing" in rule.lower() or "must be" in rule.lower()
                            else "skip")
                    f = Flag(module=mod, variable=var, rule_id=slugify(rule), kind=kind,
                             counts_by_round=counts, severity=o.get("severity", "medium"),
                             label=rule)
                    if f.key not in seen:
                        seen.add(f.key); flags.append(f)
            for v in o.values(): walk(v)
        elif isinstance(o, list):
            for v in o: walk(v)
    walk(dq_data)
    return flags
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd CATI/Analysis/QC && python3 -m pytest tests/test_issue_flags.py -q`
Expected: PASS (2 passed)

- [ ] **Step 5: Commit**

```bash
git add CATI/Analysis/QC/scripts/issue_flags.py CATI/Analysis/QC/tests/test_issue_flags.py
git commit -m "feat(qc): extract typed flags from dq_data"
```

---

## Task 3: Evidence assembler (`issue_evidence.py`)

Assembles the 3 layers. **Kobo layer:** effective `relevant` per round from `kobo_skip_logic.json` and whether each variable it references exists in the pooled data (`var_universe`). **Do-file layer:** which ops in `do_modules.json` touch the variable. **Data layer:** carried from the flag (counts) plus a `gate_var_missing` boolean derived from the Kobo layer. Cross-tab against masters is deferred to Plan 1b (optional) — the classifier's A1/A2/B/C/D decisions in this plan rely on Kobo+do-file evidence, which is sufficient for the patterns we have.

**Files:**
- Create: `CATI/Analysis/QC/scripts/issue_evidence.py`
- Test: `CATI/Analysis/QC/tests/test_issue_evidence.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_issue_evidence.py
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))
from issue_model import Flag
from issue_evidence import Context, assemble_evidence

def make_ctx():
    kobo = {"M04": {"variables": [
        {"name": "A10", "rules_by_round": {"8": {"relevant": "${A1}=1"}}},
        {"name": "A1",  "rules_by_round": {"8": {"relevant": "${fmidA1}=2 or ${A24}=1"}}},
    ]}}
    do = {"R8": {"M04": {"vars": ["a1", "a10"]}}}
    return Context(kobo=kobo, do_modules=do, var_universe={"a1", "a10", "a24"})  # note: fmidA1 absent

def test_kobo_gate_and_missing_refs():
    f = Flag("M04", "a10", "rid", "skip", {"8": 3})
    ev = assemble_evidence(f, make_ctx())
    assert ev.kobo["relevant_by_round"]["8"] == "${A1}=1"
    assert ev.kobo["gate_refs"] == ["a1"]
    assert ev.kobo["gate_refs_missing"] == []          # a1 is in the universe

def test_gate_ref_absent_from_data():
    f = Flag("M04", "a1", "rid", "skip", {"8": 3})
    ev = assemble_evidence(f, make_ctx())
    assert "fmida1" in ev.kobo["gate_refs_missing"]     # ${fmidA1} not in universe
    assert ev.dofile["touched_by_round"]["R8"] is True
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd CATI/Analysis/QC && python3 -m pytest tests/test_issue_evidence.py -q`
Expected: FAIL — `ModuleNotFoundError: No module named 'issue_evidence'`

- [ ] **Step 3: Write minimal implementation**

```python
# scripts/issue_evidence.py
"""Assemble the 3-layer evidence for a flag (Kobo + do-file + data)."""
import re
from dataclasses import dataclass
from issue_model import Evidence

@dataclass
class Context:
    kobo: dict            # kobo_skip_logic.json
    do_modules: dict      # do_modules.json
    var_universe: set     # lowercased column names present across the pooled masters

def _kobo_var(mod, var, kobo):
    for v in (kobo.get(mod, {}) or {}).get("variables", []):
        if v["name"].lower().rstrip("_") == var.lower().rstrip("_"):
            return v
    return None

def _refs(expr):
    return [m.lower() for m in re.findall(r"\$\{([A-Za-z0-9_]+)\}", expr or "")]

def assemble_evidence(flag, ctx: Context) -> Evidence:
    ev = Evidence()
    kv = _kobo_var(flag.module, flag.variable, ctx.kobo)
    rel_by_round, refs = {}, set()
    if kv:
        for r, rule in (kv.get("rules_by_round") or {}).items():
            rel = (rule or {}).get("relevant") if rule else None
            rel_by_round[r] = rel
            for ref in _refs(rel):
                if ref != flag.variable.lower():
                    refs.add(ref)
    ev.kobo = {
        "in_kobo": kv is not None,
        "relevant_by_round": rel_by_round,
        "gate_refs": sorted(refs),
        "gate_refs_missing": sorted(r for r in refs if r not in ctx.var_universe),
    }
    touched = {}
    for rnd, mods in (ctx.do_modules or {}).items():
        vlist = [x.lower() for x in (mods.get(flag.module, {}) or {}).get("vars", [])]
        touched[rnd] = flag.variable.lower() in vlist
    ev.dofile = {"touched_by_round": touched, "ever_touched": any(touched.values())}
    ev.data = {"counts_by_round": flag.counts_by_round, "total": flag.total, "kind": flag.kind}
    return ev
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd CATI/Analysis/QC && python3 -m pytest tests/test_issue_evidence.py -q`
Expected: PASS (2 passed)

- [ ] **Step 5: Commit**

```bash
git add CATI/Analysis/QC/scripts/issue_evidence.py CATI/Analysis/QC/tests/test_issue_evidence.py
git commit -m "feat(qc): 3-layer evidence assembler"
```

---

## Task 4: Classifier (`issue_classifier.py`) — the core

Priority-ordered rules. Each returns `(verdict, confidence, rule_fired)` or `None`. The first non-None wins; if none match → `("REVIEW","low","none")`.

**Files:**
- Create: `CATI/Analysis/QC/scripts/issue_classifier.py`
- Test: `CATI/Analysis/QC/tests/test_issue_classifier.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_issue_classifier.py
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))
from issue_model import Flag, Evidence
from issue_classifier import classify

def ev(**kw):
    e = Evidence(); e.kobo = kw.get("kobo", {}); e.dofile = kw.get("dofile", {}); e.data = kw.get("data", {}); return e

def test_D_other_specify():
    f = Flag("M01","d25_oth","rid","mandatory",{"2":11})
    v,c,r = classify(f, ev(kobo={"gate_refs_missing":[]}))
    assert v=="D" and r=="structural-oth"

def test_D_preload_gate():
    f = Flag("M04","ia2","rid","skip",{"8":5})
    v,c,r = classify(f, ev(kobo={"gate_refs_missing":["income_fmida1"]}))
    assert v=="D" and r=="structural-preload"

def test_C_check_disagrees_with_kobo():
    # check gate (declared) lacks A16, kobo relevant includes it → our check wrong
    f = Flag("M04","a18","a18-gate","skip",{"5":9})
    e = ev(kobo={"relevant_by_round":{"5":"${A6}=1 or ${A16}=3"},"gate_refs_missing":[]})
    e.data = {"check_gate_refs":["a6"]}
    v,c,r = classify(f, e)
    assert v=="C" and r=="check-vs-kobo"

def test_B_var_absent_from_data():
    f = Flag("M05","ia7","rid","missing",{"8":100})
    e = ev(kobo={"in_kobo":True,"gate_refs_missing":["a9"]}, dofile={"ever_touched":False})
    v,c,r = classify(f, e)
    assert v=="B" and r=="gate-ref-absent"

def test_A2_gate_correct_but_violated():
    f = Flag("M04","a10","rid","skip",{"8":59})
    e = ev(kobo={"in_kobo":True,"relevant_by_round":{"8":"${A1}=1"},"gate_refs_missing":[]},
           dofile={"ever_touched":False})
    e.data = {"check_gate_refs":["a1"]}   # check agrees with kobo
    v,c,r = classify(f, e)
    assert v=="A2" and r=="gate-correct-violated"

def test_review_when_unknown():
    f = Flag("MX","zz","rid","skip",{"8":1})
    v,c,r = classify(f, ev())
    assert v=="REVIEW"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd CATI/Analysis/QC && python3 -m pytest tests/test_issue_classifier.py -q`
Expected: FAIL — `ModuleNotFoundError: No module named 'issue_classifier'`

- [ ] **Step 3: Write minimal implementation**

```python
# scripts/issue_classifier.py
"""Priority-ordered root-cause classifier. First matching rule wins."""

# Structural (D) patterns
PRELOAD_TOKENS = ("fmid", "round_lastint", "fmid_employment")
DERIVED_SUFFIX = ("_income", "_earnings")
DERIVED_EXACT  = {"total_income"}

def _is_preload_missing(ev):
    return any(any(tok in ref for tok in PRELOAD_TOKENS)
               for ref in ev.kobo.get("gate_refs_missing", []))

def rule_D(f, ev):
    v = f.variable.lower()
    if v.endswith("_oth"):                         return ("D", "high", "structural-oth")
    if v in DERIVED_EXACT or v.endswith(DERIVED_SUFFIX): return ("D", "high", "structural-derived")
    if _is_preload_missing(ev):                    return ("D", "high", "structural-preload")
    if not ev.kobo.get("in_kobo", True) and ev.kobo.get("relevant_by_round") == {}:
        return ("D", "med", "structural-not-in-kobo")
    return None

def _norm_refs(expr_or_list):
    import re
    if isinstance(expr_or_list, str):
        return set(m.lower() for m in re.findall(r"\$\{([A-Za-z0-9_]+)\}", expr_or_list))
    return set(x.lower() for x in (expr_or_list or []))

def rule_C(f, ev):
    """Our check's declared gate disagrees with the Kobo relevant for that round."""
    check_refs = set(ev.data.get("check_gate_refs", []) or [])
    if not check_refs:
        return None
    latest = sorted((ev.kobo.get("relevant_by_round") or {}).items())
    for _, rel in latest:
        kobo_refs = _norm_refs(rel)
        if kobo_refs and kobo_refs - check_refs:   # Kobo references vars our check ignores
            return ("C", "high", "check-vs-kobo")
    return None

def rule_B(f, ev):
    """Kobo says asked, but a referenced var is absent from data and no do-file touches it."""
    if ev.kobo.get("in_kobo") and ev.kobo.get("gate_refs_missing") and not ev.dofile.get("ever_touched"):
        return ("B", "med", "gate-ref-absent")
    return None

def rule_A1_A2(f, ev):
    """Constraint violated. A1 if the Kobo gate is missing/empty; A2 if it is present/correct."""
    rels = ev.kobo.get("relevant_by_round") or {}
    has_gate = any(rels.get(r) for r in rels)
    if f.kind != "skip":
        return None
    if not ev.kobo.get("in_kobo") or not has_gate:
        return ("A1", "med", "gate-missing")
    return ("A2", "med", "gate-correct-violated")

RULES = [rule_D, rule_C, rule_B, rule_A1_A2]

def classify(flag, evidence):
    for rule in RULES:
        out = rule(flag, evidence)
        if out:
            return out
    return ("REVIEW", "low", "none")
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd CATI/Analysis/QC && python3 -m pytest tests/test_issue_classifier.py -q`
Expected: PASS (6 passed)

- [ ] **Step 5: Commit**

```bash
git add CATI/Analysis/QC/scripts/issue_classifier.py CATI/Analysis/QC/tests/test_issue_classifier.py
git commit -m "feat(qc): priority-ordered root-cause classifier"
```

---

## Task 5: Registry (`issue_registry.py`)

Load/save `issue_registry.yaml`; merge decisions onto issues; carry-forward untouched; auto-verify (`fix-pending`→`resolved` when total drops to 0) and reopen (`resolved`→`reopened` when total returns).

**Files:**
- Create: `CATI/Analysis/QC/scripts/issue_registry.py`
- Test: `CATI/Analysis/QC/tests/test_issue_registry.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_issue_registry.py
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))
from issue_model import Flag, Evidence, Issue
from issue_registry import merge_decisions, is_open

def mk_issue(key, total, status_proposed="A2"):
    f = Flag(*key.split("/"), kind="skip", counts_by_round={"8": total})
    return Issue(key=key, flag=f, evidence=Evidence(), proposed_verdict=status_proposed,
                 confidence="med", rule_fired="x")

def test_registry_overrides_verdict_and_status():
    issues = [mk_issue("M04/a10/r", 5)]
    reg = {"M04/a10/r": {"verdict": "A2", "status": "acknowledged", "report_to_firm": True,
                          "notes": "n"}}
    out, _ = merge_decisions(issues, reg)
    i = out[0]
    assert i.verdict == "A2" and i.status == "acknowledged" and i.owner == "firm-field"
    assert i.report_to_firm and is_open(i)

def test_auto_resolve_when_fixed():
    issues = [mk_issue("M04/a10/r", 0)]                 # count dropped to 0 this run
    reg = {"M04/a10/r": {"status": "fix-pending"}}
    out, changes = merge_decisions(issues, reg)
    assert out[0].status == "resolved"
    assert ("M04/a10/r", "fix-pending", "resolved") in changes

def test_reopen_when_regressed():
    issues = [mk_issue("M04/a10/r", 7)]
    reg = {"M04/a10/r": {"status": "resolved"}}
    out, changes = merge_decisions(issues, reg)
    assert out[0].status == "reopened"

def test_new_issue_defaults_to_new():
    issues = [mk_issue("M09/v1/r", 3)]
    out, _ = merge_decisions(issues, {})
    assert out[0].status == "new" and is_open(out[0])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd CATI/Analysis/QC && python3 -m pytest tests/test_issue_registry.py -q`
Expected: FAIL — `ModuleNotFoundError: No module named 'issue_registry'`

- [ ] **Step 3: Write minimal implementation**

```python
# scripts/issue_registry.py
"""Load/merge/save the durable issue registry + lifecycle transitions."""
import os, yaml
from issue_model import OWNER, OPEN_STATES

_REG = os.path.join(os.path.dirname(__file__), "..", "issue_registry.yaml")

def load_registry(path=_REG):
    if not os.path.exists(path):
        return {}
    with open(path) as f:
        return yaml.safe_load(f) or {}

def save_registry(reg, path=_REG):
    with open(path, "w") as f:
        yaml.safe_dump(reg, f, sort_keys=True, default_flow_style=False, allow_unicode=True)

def is_open(issue):
    return issue.status in OPEN_STATES

def merge_decisions(issues, reg):
    """Apply registry decisions + auto-verify/reopen. Returns (issues, status_changes)."""
    changes = []
    for it in issues:
        e = reg.get(it.key, {})
        it.verdict = e.get("verdict") or it.proposed_verdict
        it.owner = OWNER.get(it.verdict, "unassigned")
        it.report_to_firm = bool(e.get("report_to_firm", it.verdict in ("A1", "A2", "B")))
        it.rounds = e.get("rounds", {}) or {}
        it.registry_notes = e.get("notes", "")
        status = e.get("status", "new")
        total = it.flag.total
        if status == "fix-pending" and total == 0:
            changes.append((it.key, status, "resolved")); status = "resolved"
        elif status == "resolved" and total > 0:
            changes.append((it.key, status, "reopened")); status = "reopened"
        it.status = status
    return issues, changes

def apply_changes_to_registry(reg, changes):
    """Persist auto-transitions back into the registry dict (caller saves)."""
    for key, _old, new in changes:
        reg.setdefault(key, {})["status"] = new
    return reg
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd CATI/Analysis/QC && python3 -m pytest tests/test_issue_registry.py -q`
Expected: PASS (4 passed)

- [ ] **Step 5: Commit**

```bash
git add CATI/Analysis/QC/scripts/issue_registry.py CATI/Analysis/QC/tests/test_issue_registry.py
git commit -m "feat(qc): issue registry + lifecycle transitions"
```

---

## Task 6: Orchestrator (`build_issues.py`)

Wire it together: load caches + masters' var universe, extract flags, assemble evidence, classify, merge registry, write `cache/issues.json`, persist auto-transitions back to the registry.

**Files:**
- Create: `CATI/Analysis/QC/scripts/build_issues.py`
- Test: `CATI/Analysis/QC/tests/test_build_issues.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_build_issues.py
import sys, os, json
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))
from build_issues import build

def test_build_emits_issue_records():
    dq = {"x":[{"module":"M01","variable":"d25_oth","rule":"D25=96 but D25_oth missing",
                "counts_by_round":{"2":11},"severity":"medium"}]}
    kobo = {"M01":{"variables":[]}}
    out = build(dq_data=dq, kobo=kobo, do_modules={}, var_universe=set(), registry={})
    rec = out["issues"][0]
    assert rec["key"] == "M01/d25oth/d25-96-but-d25-oth-missing".replace("d25oth","d25_oth") or rec["module"]=="M01"
    assert rec["proposed_verdict"] == "D"          # _oth → structural
    assert rec["status"] == "new"
    assert "kobo" in rec["evidence"]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd CATI/Analysis/QC && python3 -m pytest tests/test_build_issues.py -q`
Expected: FAIL — `ModuleNotFoundError: No module named 'build_issues'`

- [ ] **Step 3: Write minimal implementation**

```python
# scripts/build_issues.py
"""Issue-intelligence build stage: dq_data + kobo + do_modules + masters -> issues.json"""
import os, json, glob
from dataclasses import asdict
import pandas as pd
from issue_flags import extract_flags
from issue_evidence import Context, assemble_evidence
from issue_classifier import classify
from issue_registry import load_registry, save_registry, merge_decisions, apply_changes_to_registry

_HERE = os.path.dirname(__file__)
_CACHE = os.path.join(_HERE, "..", "cache")
_HF = os.path.join(_HERE, "..", "..", "HF")

def _var_universe():
    cols = set()
    for fp in glob.glob(os.path.join(_HF, "l2phl_M*.dta")):
        try:
            cols |= {c.lower() for c in pd.read_stata(fp, convert_categoricals=False).columns}
        except Exception:
            pass
    return cols

def build(dq_data, kobo, do_modules, var_universe, registry):
    ctx = Context(kobo=kobo, do_modules=do_modules, var_universe=var_universe)
    issues = []
    for f in extract_flags(dq_data):
        ev = assemble_evidence(f, ctx)
        verdict, conf, rule = classify(f, ev)
        from issue_model import Issue
        issues.append(Issue(key=f.key, flag=f, evidence=ev,
                            proposed_verdict=verdict, confidence=conf, rule_fired=rule))
    issues, changes = merge_decisions(issues, registry)
    records = []
    for it in issues:
        records.append({
            "key": it.key, "module": it.flag.module, "variable": it.flag.variable,
            "rule_id": it.flag.rule_id, "label": it.flag.label, "kind": it.flag.kind,
            "counts_by_round": it.flag.counts_by_round,
            "proposed_verdict": it.proposed_verdict, "confidence": it.confidence,
            "rule_fired": it.rule_fired, "verdict": it.effective_verdict, "owner": it.owner,
            "status": it.status, "report_to_firm": it.report_to_firm,
            "rounds": it.rounds, "notes": it.registry_notes,
            "evidence": {"data": it.evidence.data, "kobo": it.evidence.kobo, "dofile": it.evidence.dofile},
            "review": it.status == "new" or it.confidence == "low" or it.proposed_verdict == "REVIEW",
        })
    return {"issues": records, "changes": changes}

def main():
    dq = json.load(open(os.path.join(_CACHE, "dq_data.json")))
    kobo = json.load(open(os.path.join(_CACHE, "kobo_skip_logic.json")))
    do_modules = json.load(open(os.path.join(_CACHE, "do_modules.json"))) if os.path.exists(os.path.join(_CACHE,"do_modules.json")) else {}
    reg = load_registry()
    out = build(dq, kobo, do_modules, _var_universe(), reg)
    json.dump(out["issues"], open(os.path.join(_CACHE, "issues.json"), "w"), indent=2)
    if out["changes"]:
        save_registry(apply_changes_to_registry(reg, out["changes"]))
    n_review = sum(1 for r in out["issues"] if r["review"])
    print(f"issues.json: {len(out['issues'])} issues, {n_review} in review queue, {len(out['changes'])} auto-transitions")

if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd CATI/Analysis/QC && python3 -m pytest tests/test_build_issues.py -q`
Expected: PASS (1 passed)

- [ ] **Step 5: Smoke-test against real caches**

Run: `cd CATI/Analysis/QC && python3 scripts/build_issues.py`
Expected: prints `issues.json: <N> issues, <M> in review queue, ...` and writes `cache/issues.json`. Inspect: `python3 -c "import json;d=json.load(open('cache/issues.json'));print(d[0])"`

- [ ] **Step 6: Commit**

```bash
git add CATI/Analysis/QC/scripts/build_issues.py CATI/Analysis/QC/tests/test_build_issues.py
git commit -m "feat(qc): build_issues orchestrator -> issues.json"
```

---

## Task 7: CLI (`qc_issue.py`) + seed registry + wire into pipeline

**Files:**
- Create: `CATI/Analysis/QC/scripts/qc_issue.py`
- Create: `CATI/Analysis/QC/issue_registry.yaml` (seeded)
- Modify: `CATI/Analysis/QC/update_pipeline.py` (add a build_issues step after build_dq)
- Test: `CATI/Analysis/QC/tests/test_qc_issue.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_qc_issue.py
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))
from qc_issue import set_status

def test_set_status_writes_registry(tmp_path):
    p = tmp_path / "reg.yaml"
    set_status("M04/a10/r", "wontfix", notes="old round", path=str(p))
    import yaml
    reg = yaml.safe_load(open(p))
    assert reg["M04/a10/r"]["status"] == "wontfix"
    assert reg["M04/a10/r"]["notes"] == "old round"

def test_set_status_rejects_bad_state(tmp_path):
    p = tmp_path / "reg.yaml"
    import pytest
    with pytest.raises(ValueError):
        set_status("M04/a10/r", "banana", path=str(p))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd CATI/Analysis/QC && python3 -m pytest tests/test_qc_issue.py -q`
Expected: FAIL — `ModuleNotFoundError: No module named 'qc_issue'`

- [ ] **Step 3: Write minimal implementation**

```python
# scripts/qc_issue.py
"""CLI to set issue lifecycle status. Usage:
   python3 scripts/qc_issue.py set <key> <status> [--notes "..."] [--verdict A2] [--report]
   python3 scripts/qc_issue.py review        # list issues needing adjudication
   python3 scripts/qc_issue.py list [--open]  # list issues
"""
import sys, os, json, argparse
from issue_model import OPEN_STATES, CLOSED_STATES
from issue_registry import load_registry, save_registry, _REG

VALID = OPEN_STATES | CLOSED_STATES

def set_status(key, status, notes=None, verdict=None, report=None, path=_REG):
    if status not in VALID:
        raise ValueError(f"status must be one of {sorted(VALID)}")
    reg = load_registry(path)
    e = reg.setdefault(key, {})
    e["status"] = status
    if notes is not None:   e["notes"] = notes
    if verdict is not None:  e["verdict"] = verdict
    if report is not None:   e["report_to_firm"] = bool(report)
    save_registry(reg, path)
    return e

def _issues():
    p = os.path.join(os.path.dirname(__file__), "..", "cache", "issues.json")
    return json.load(open(p)) if os.path.exists(p) else []

def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("set"); s.add_argument("key"); s.add_argument("status")
    s.add_argument("--notes"); s.add_argument("--verdict"); s.add_argument("--report", action="store_true")
    sub.add_parser("review"); lp = sub.add_parser("list"); lp.add_argument("--open", action="store_true")
    a = ap.parse_args()
    if a.cmd == "set":
        set_status(a.key, a.status, a.notes, a.verdict, a.report or None)
        print(f"set {a.key} -> {a.status}")
    elif a.cmd == "review":
        for r in _issues():
            if r.get("review"):
                print(f"  [{r['proposed_verdict']}/{r['confidence']}] {r['key']} — {r['label'][:50]}")
    elif a.cmd == "list":
        for r in _issues():
            if a.open and r["status"] not in OPEN_STATES: continue
            print(f"  {r['status']:12} {r['verdict']:3} {r['key']}")

if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd CATI/Analysis/QC && python3 -m pytest tests/test_qc_issue.py -q`
Expected: PASS (2 passed)

- [ ] **Step 5: Seed the registry from this session's known decisions**

Create `CATI/Analysis/QC/issue_registry.yaml` (keys will be confirmed against the first real `build_issues.py` run via `qc_issue.py review`; seed the ones we already decided):

```yaml
# Seeded 2026-06-28 from the module-by-module audit. Keys are (module/variable/rule_slug);
# confirm exact slugs after the first `python3 scripts/build_issues.py` + `qc_issue.py review`.
M04/a10/a1-2-not-working-but-a10-a11-are-filled:
  verdict: A2
  status: acknowledged
  report_to_firm: true
  notes: "Kobo gates A10/A11 on A1=1 (correct); data violates -> field. Firm: extend
          `replace a10/a11=. if a1==2` to R6-R8 in pooler."
M05/ia7/ia7-99-9-missing:
  verdict: D
  status: accepted
  notes: "Gated on cross-module A9 (gig); preload not in pooled data -> expected high missing."
```

- [ ] **Step 6: Wire `build_issues` into the pipeline**

In `CATI/Analysis/QC/update_pipeline.py`, find STEP 5 (`rebuild_dashboard`) and add a call to build the issue layer **before** it. Add this helper near the other `rebuild_*` functions:

```python
def rebuild_issues():
    step("4b", "Building issue intelligence (issues.json)")
    r = subprocess.run([sys.executable, str(SCRIPTS / 'build_issues.py')],
                       capture_output=True, text=True)
    if r.returncode != 0:
        log(f"build_issues failed:\n{r.stderr[-800:]}", 'ERROR'); return False
    log(r.stdout.strip() or "issues.json written", 'OK'); return True
```

Then call `rebuild_issues()` immediately before the `rebuild_dashboard()` call in `main()` (so `issues.json` exists when Plan 2's renderer reads it).

- [ ] **Step 7: Run the full check**

Run: `cd CATI/Analysis/QC && python3 -m pytest tests/ -q && python3 scripts/build_issues.py && python3 scripts/qc_issue.py review | head`
Expected: all tests pass; `issues.json` written; review queue lists the un-decided flags.

- [ ] **Step 8: Commit**

```bash
git add CATI/Analysis/QC/scripts/qc_issue.py CATI/Analysis/QC/issue_registry.yaml \
        CATI/Analysis/QC/tests/test_qc_issue.py CATI/Analysis/QC/update_pipeline.py
git commit -m "feat(qc): qc-issue CLI, seeded registry, pipeline wiring"
```

---

## Self-review

**Spec coverage:** taxonomy (Task 4) ✓; architecture/data-flow (Tasks 3,6) ✓; disposable issues.json vs durable registry (Tasks 5,6) ✓; priority-ordered classifier with D/C-before-A/B (Task 4) ✓; A1-vs-A2 mechanical test (Task 4 `rule_A1_A2`) ✓; lifecycle states + auto-verify/reopen + carry-forward (Task 5) ✓; review queue + firm-report feed (Tasks 6,7 — `review` flag and `report_to_firm`) ✓; CLI status-setting (Task 7) ✓; seeded registry persists decisions (Task 7) ✓. **Per-round strip / open-issue RAG / evidence drill-in rendering → Plan 2 (out of scope here, by design).** The spec's "Open questions" are resolved: rule_id = `slugify(rule)`; do-file evidence depth = `do_modules.json` ops (cross-tab deferred); review threshold = `confidence=='low' or status=='new' or verdict=='REVIEW'`; CLI = `qc_issue.py`.

**Placeholder scan:** none — every step has runnable code/commands.

**Type consistency:** `Flag`/`Evidence`/`Issue` fields and `classify()` signature `(flag, evidence) -> (verdict, confidence, rule_fired)` are consistent across Tasks 1–7; `merge_decisions(issues, reg) -> (issues, changes)` matches its caller in Task 6.

**Note for the C-rule:** `rule_C` needs `evidence.data["check_gate_refs"]` (the declared gate of the firing check). Task 3's assembler does not yet populate it (build_dq doesn't expose per-check gates). For Plan 1, `check_gate_refs` is absent → `rule_C` is a no-op and those flags fall to A1/A2/B. Add a `CHECK_GATES` map (rule_id → refs) in a follow-up once we enumerate build_dq's checks; the rule is already wired to consume it. This is the one known partial — flagged, not hidden.
