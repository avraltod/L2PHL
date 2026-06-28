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
    assert "M04/a10/a1-2-but-a10-a11-filled" in keys
    assert any(f.module=="M01" and f.kind=="oor" and f.total==1 for f in flags)

def test_ignores_zero_count_entries():
    dq = {"x":[{"module":"M03","variable":"sh2","rule":"r","counts_by_round":{"1":0,"2":0}}]}
    assert extract_flags(dq) == []

def test_kind_mandatory_and_dedup():
    dq = {"a":[
        {"module":"M01","variable":"d5","rule":"D5 must be filled for all members",
         "counts_by_round":{"3":4}},
        {"module":"M01","variable":"d5","rule":"D5 must be filled for all members",  # duplicate node
         "counts_by_round":{"3":4}},
    ]}
    flags = extract_flags(dq)
    assert len(flags) == 1                     # dedup by key
    assert flags[0].kind == "mandatory"        # "must be" -> mandatory
