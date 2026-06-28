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

def test_C_dormant_no_autoclassify():
    # rule_C is DORMANT (Stata-verified false-positive on a18/a19): a gate-set
    # mismatch between our check and Kobo no longer auto-classifies C.
    f = Flag("M04","a18","a18-gate","skip",{"5":9})
    e = ev(kobo={"relevant_by_round":{"5":"${A6}=1 or ${A16}=3"},"gate_refs_missing":[]})
    e.data = {"check_gate_refs":["a6"]}
    v,c,r = classify(f, e)
    assert v != "C"

def test_B_var_absent_from_data():
    f = Flag("M05","ia7","rid","missing",{"8":100})
    e = ev(kobo={"in_kobo":True,"gate_refs_missing":["a9"]}, dofile={"ever_touched":False})
    v,c,r = classify(f, e)
    assert v=="B" and r=="gate-ref-absent"

def test_A2_gate_correct_but_violated():
    f = Flag("M04","a10","rid","skip",{"8":59})
    e = ev(kobo={"in_kobo":True,"relevant_by_round":{"8":"${A1}=1"},"gate_refs_missing":[]},
           dofile={"ever_touched":False})
    e.data = {"check_gate_refs":["a1"]}
    v,c,r = classify(f, e)
    assert v=="A2" and r=="gate-correct-violated"

def test_A1_gate_missing_in_kobo():
    f = Flag("M04","a10","rid","skip",{"8":5})
    e = ev(kobo={"in_kobo":True,"relevant_by_round":{"8":None},"gate_refs_missing":[]})
    v,c,r = classify(f, e)
    assert v=="A1" and r=="gate-missing"

def test_D_beats_B_priority():
    # qualifies for B (in_kobo, gate_refs_missing, never touched) AND D (preload token) -> D must win
    f = Flag("M05","ia3","rid","missing",{"8":10})
    e = ev(kobo={"in_kobo":True,"gate_refs_missing":["round_lastint_ia"]}, dofile={"ever_touched":False})
    v,c,r = classify(f, e)
    assert v=="D" and r=="structural-preload"

def test_review_when_unknown():
    f = Flag("MX","zz","rid","skip",{"8":1})
    v,c,r = classify(f, ev())
    assert v=="REVIEW"
