import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))
from issue_rollup import rollup

def rec(module, verdict, status, counts):
    return {"module":module,"verdict":verdict,"status":status,"counts_by_round":counts,
            "owner":{"A1":"firm-questionnaire","A2":"firm-field","B":"firm-dofile",
                     "C":"us","D":"expected","REVIEW":"unassigned"}.get(verdict)}

def test_open_firm_issue_reds_the_round():
    recs = [rec("M04","A2","acknowledged",{"7":80,"8":59})]
    out = rollup(recs)
    assert out["M04"]["strip"]["8"] == "red"      # open A2 with count in R8
    assert out["M04"]["strip"]["7"] == "red"
    assert out["M04"]["strip"]["1"] == "green"     # no count there
    assert out["M04"]["headline"] == "red"         # last round present = R8
    assert out["M04"]["open"] == 1 and out["M04"]["by_owner"] == {"firm-field": 1}

def test_closed_issue_is_grey_not_red():
    recs = [rec("M01","A2","wontfix",{"3":12})]
    out = rollup(recs)
    assert out["M01"]["strip"]["3"] == "closed"    # closed -> not coloured
    assert out["M01"]["open"] == 0 and out["M01"]["closed"] == 1
    assert out["M01"]["headline"] == "green"        # latest present round (R3) is closed -> green headline

def test_open_nonfirm_is_yellow():
    recs = [rec("M00","D","new",{"5":9})]
    out = rollup(recs)
    assert out["M00"]["strip"]["5"] == "yellow"    # open but verdict D (not A1/A2/B)

def test_red_beats_yellow_and_closed_same_round():
    recs = [rec("M04","A2","acknowledged",{"8":5}),
            rec("M04","D","new",{"8":3}),
            rec("M04","B","resolved",{"8":1})]
    out = rollup(recs)
    assert out["M04"]["strip"]["8"] == "red"       # worst wins
    assert out["M04"]["open"] == 2 and out["M04"]["closed"] == 1
