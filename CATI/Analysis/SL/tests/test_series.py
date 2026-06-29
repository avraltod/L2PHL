import json, os, pytest
import sys; sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from series import load_series, validate_series, indicator_keys, SeriesError

GOOD = {
    "_meta": {"rounds": "R1-R8"},
    "series.food_insecurity.label": "Mod-sev food insecurity",
    "series.food_insecurity.unit": "pct",
    "series.food_insecurity.rounds": [1,2,3,4,5,6,7,8],
    "series.food_insecurity.overall": [41,31,26.8,21.5,18.2,17,16.4,18],
    "series.food_insecurity.by_quintile": {"Poorest":[60,55,50,46,44,43,42,45],
                                           "Richest":[20,15,12,10,9,8,8,9]},
}

def _write(tmp, obj):
    p = os.path.join(tmp, "sl_series.json"); open(p,"w").write(json.dumps(obj)); return p

def test_load_and_indicator_keys(tmp_path):
    d = load_series(_write(tmp_path, GOOD))
    assert indicator_keys(d) == ["food_insecurity"]
    assert d["series"]["food_insecurity"]["overall"][0] == 41

def test_validate_ok(tmp_path):
    validate_series(load_series(_write(tmp_path, GOOD)))  # no raise

def test_length_mismatch_raises(tmp_path):
    bad = json.loads(json.dumps(GOOD))
    bad["series.food_insecurity.overall"] = [1,2,3]  # wrong length
    with pytest.raises(SeriesError, match="length"):
        validate_series(load_series(_write(tmp_path, bad)))

def test_breakdown_length_mismatch_raises(tmp_path):
    bad = json.loads(json.dumps(GOOD))
    bad["series.food_insecurity.by_quintile"]["Poorest"] = [1,2]
    with pytest.raises(SeriesError, match="Poorest"):
        validate_series(load_series(_write(tmp_path, bad)))
