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
    return Context(kobo=kobo, do_modules=do, var_universe={"a1", "a10", "a24"})  # fmidA1 absent

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

def test_data_passthrough():
    f = Flag("M04", "a10", "rid", "skip", {"8": 3})
    ev = assemble_evidence(f, make_ctx())
    assert ev.data == {"counts_by_round": {"8": 3}, "total": 3, "kind": "skip"}
