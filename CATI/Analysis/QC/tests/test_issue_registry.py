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
