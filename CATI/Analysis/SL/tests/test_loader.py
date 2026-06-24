# CATI/Analysis/SL/tests/test_loader.py
import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from sl_build.loader import unflatten


def test_unflatten_dotted():
    flat = {"fies.mod_sev_r1": 41.0, "charts.food_trend": [1, 2], "sample.total_hh": 1917}
    out = unflatten(flat)
    assert out == {"fies": {"mod_sev_r1": 41.0},
                   "charts": {"food_trend": [1, 2]},
                   "sample": {"total_hh": 1917}}


def test_unflatten_passthrough_nested():
    # already-nested JSON (Stage 1 hand-built) is returned unchanged
    nested = {"fies": {"mod_sev_r1": 41.0}}
    assert unflatten(nested) == nested
