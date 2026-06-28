import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))
from firm_report import firm_rows

def rec(**kw):
    base = {"report_to_firm": True, "status": "acknowledged", "verdict": "A2",
            "module": "M04", "variable": "a18", "label": "rule", "owner": "firm-field",
            "counts_by_round": {"6": 12, "5": 9}, "evidence": {}, "notes": ""}
    base.update(kw); return base

def test_includes_only_open_firm():
    recs = [rec(),                          # open firm -> in
            rec(report_to_firm=False),      # not firm -> out
            rec(status="wontfix"),          # closed -> out
            rec(status="resolved")]         # closed -> out
    rows = firm_rows(recs)
    assert len(rows) == 1 and rows[0]["module"] == "M04"

def test_row_shape():
    ev = {"kobo": {"relevant_by_round": {"5": "${A6}=1", "6": "${A6}=1 or ${A16}=3"},
                   "gate_refs_missing": ["fmida1"]},
          "dofile": {"ever_touched": False}}
    rows = firm_rows([rec(evidence=ev, notes="extend the recode to R6-R8")])
    r = rows[0]
    assert r["rounds"] == "R5:9, R6:12"               # round-sorted, nonzero
    assert r["total"] == 21
    assert r["root_cause"] == "Field / interviewer"   # A2
    assert "${A6}=1 or ${A16}=3" in r["kobo_gate"]     # latest relevant
    assert "fmida1" in r["kobo_gate"]                  # missing refs appended
    assert r["dofile"] == "not touched"
    assert r["fix"] == "extend the recode to R6-R8"

def test_sorted_by_owner_module_variable():
    recs = [rec(owner="firm-field", module="M04", variable="a19"),
            rec(owner="firm-dofile", module="M01", variable="d26_2"),
            rec(owner="firm-field", module="M04", variable="a18")]
    rows = firm_rows(recs)
    assert [(r["owner"], r["variable"]) for r in rows] == \
           [("firm-dofile","d26_2"),("firm-field","a18"),("firm-field","a19")]
