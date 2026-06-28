import sys, os, json
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))
from build_issues import build

def test_build_emits_issue_records():
    dq = {"x":[{"module":"M01","variable":"d25_oth","rule":"D25=96 but D25_oth missing",
                "counts_by_round":{"2":11},"severity":"medium"}]}
    kobo = {"M01":{"variables":[]}}
    out = build(dq_data=dq, kobo=kobo, do_modules={}, var_universe=set(), registry={})
    rec = out["issues"][0]
    assert rec["module"] == "M01"
    assert rec["proposed_verdict"] == "D"          # _oth → structural
    assert rec["status"] == "new"
    assert "kobo" in rec["evidence"]

def test_build_returns_structure():
    dq = {"x":[{"module":"M04","variable":"a10","rule":"A1=2 but A10 filled",
                "counts_by_round":{"2":5},"severity":"high"}]}
    out = build(dq_data=dq, kobo={}, do_modules={}, var_universe=set(), registry={})
    assert "issues" in out
    assert "changes" in out
    assert isinstance(out["issues"], list)
    assert isinstance(out["changes"], list)

def test_build_with_registry_decision():
    dq = {"x":[{"module":"M01","variable":"d5","rule":"D5 missing",
                "counts_by_round":{"2":3},"severity":"medium"}]}
    registry = {
        "M01/d5/d5-missing": {"verdict": "A1", "status": "acknowledged", "notes": "confirmed skip logic gap"}
    }
    out = build(dq_data=dq, kobo={}, do_modules={}, var_universe=set(), registry=registry)
    rec = out["issues"][0]
    assert rec["verdict"] == "A1"
    assert rec["status"] == "acknowledged"
    assert rec["notes"] == "confirmed skip logic gap"
