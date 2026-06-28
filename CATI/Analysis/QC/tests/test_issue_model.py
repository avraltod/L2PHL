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

def test_slugify_edge_cases():
    assert slugify(None) == ""
    assert slugify("") == ""
    assert len(slugify("a" * 100)) == 60

def test_flag_total_edge_cases():
    from issue_model import Flag
    assert Flag("M","v","r","skip",{}).total == 0
    assert Flag("M","v","r","skip",{"1":0,"2":5}).total == 5

def test_issue_effective_verdict():
    from issue_model import Flag, Evidence, Issue
    f = Flag("M","v","r","skip",{"8":1})
    i = Issue(key=f.key, flag=f, evidence=Evidence(), proposed_verdict="A1", confidence="med", rule_fired="x")
    assert i.effective_verdict == "A1"          # falls back to proposed
    i.verdict = "B"
    assert i.effective_verdict == "B"           # confirmed wins
