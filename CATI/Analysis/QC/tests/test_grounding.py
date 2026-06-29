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
    isum = {"M07": {"strip": {"5": "yellow"}, "headline": "yellow"}}
    issues = [{"key": "M07/d/r", "module": "M07", "verdict": "D",
               "status": "new", "counts_by_round": {"5": 1}}]   # structural, not firm
    rows = ground(["health.philhealth_r5"], isum, issues)
    assert rows[0]["module"] == "M07" and rows[0]["grounded"] is True   # D does not caveat
    assert rows[0]["open_firm_issues"] == []

def test_ground_unmapped_group():
    rows = ground(["mystery.foo_r2"], {}, [])
    assert rows[0]["qc_status"] == "unmapped" and rows[0]["module"] is None

def test_ground_non_round_uses_headline():
    isum = {"M06": {"strip": {}, "headline": "yellow"}}
    rows = ground(["finance.bank_acc_f17"], isum, [])
    assert rows[0]["round"] is None and rows[0]["qc_status"] == "yellow"

def test_variable_level_excludes_mismatched_var():
    # claim about a16 (contract type); open firm issue is on a18 (pension) -> NOT a caveat
    isum = {"M04": {"strip": {}, "headline": "yellow"}}
    issues = [{"key":"M04/a18/r","module":"M04","variable":"a18","verdict":"A2","status":"acknowledged","counts_by_round":{"8":9}}]
    rows = ground(["employment.no_contract_a16eq2"], isum, issues)
    assert rows[0]["claim_var"] == "a16"
    assert rows[0]["grounded"] is True and rows[0]["open_firm_issues"] == []

def test_variable_level_matches_same_var():
    # an open firm issue on a16 DOES caveat an a16 claim
    isum = {"M04": {"strip": {}, "headline": "yellow"}}
    issues = [{"key":"M04/a16/r","module":"M04","variable":"a16","verdict":"A1","status":"new","counts_by_round":{"8":4}}]
    rows = ground(["employment.no_contract_a16eq2"], isum, issues)
    assert rows[0]["grounded"] is False and rows[0]["open_firm_issues"] == ["M04/a16/r"]

def test_aggregate_claim_falls_back_to_module():
    # 'hh_r1' embeds no variable -> module-level: any open firm issue in M01/R1 caveats it
    isum = {"M01": {"strip": {"1":"red"}, "headline":"red"}}
    issues = [{"key":"M01/d26_2/r","module":"M01","variable":"d26_2","verdict":"B","status":"acknowledged","counts_by_round":{"1":5}}]
    rows = ground(["sample.hh_r1"], isum, issues)
    assert rows[0]["claim_var"] is None and rows[0]["grounded"] is False
