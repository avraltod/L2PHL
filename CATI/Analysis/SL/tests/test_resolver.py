# CATI/Analysis/SL/tests/test_resolver.py
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import pytest
from sl_build.resolver import resolve, MissingKey

DATA = {"fies": {"mod_sev_r1": 41.0, "food_trend": [41.0, 18.2]}, "sample": {"total_hh": 1917}}

def test_resolve_nested_scalar():
    assert resolve(DATA, "fies.mod_sev_r1") == 41.0

def test_resolve_top_object():
    assert resolve(DATA, "sample.total_hh") == 1917

def test_resolve_array():
    assert resolve(DATA, "fies.food_trend") == [41.0, 18.2]

def test_missing_key_raises():
    with pytest.raises(MissingKey, match="fies.nope"):
        resolve(DATA, "fies.nope")

def test_missing_intermediate_raises():
    with pytest.raises(MissingKey, match="ghost.x"):
        resolve(DATA, "ghost.x")
