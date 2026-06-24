# CATI/Analysis/SL/tests/test_formatter.py
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import pytest
from sl_build.formatter import fmt

def test_int():           assert fmt(2470, "int") == "2470"
def test_intcomma():      assert fmt(2470, "intcomma") == "2,470"
def test_intcomma_float(): assert fmt(108667043.0, "intcomma") == "108,667,043"
def test_pct0():          assert fmt(41.0, "pct0") == "41%"
def test_pct0_rounds():   assert fmt(40.99, "pct0") == "41%"
def test_pct1():          assert fmt(18.2, "pct1") == "18.2%"
def test_millions1():     assert fmt(108667043, "millions1") == "108.7M"
def test_peso():          assert fmt(19497, "peso") == "₱19,497"
def test_ppt():           assert fmt(22.8, "ppt") == "23"
def test_raw():           assert fmt("Sep–Oct 2025", "raw") == "Sep–Oct 2025"
def test_unknown_fmt_raises():
    with pytest.raises(ValueError, match="unknown data-fmt"):
        fmt(1, "bogus")
def test_pct0word():     assert fmt(54.0, "pct0word") == "54 percent"
def test_pct1word():     assert fmt(40.56, "pct1word") == "40.6 percent"
def test_millions1word(): assert fmt(108667043, "millions1word") == "108.7 million"
