# scripts/tests/test_tidy_core.py
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from tidy_core import parse_at_name

def test_parse_canonical_name():
    p = parse_at_name("L2PHL_CATI@R02@AP@20251228.do")
    assert p is not None
    assert p.head == "L2PHL_CATI"
    assert p.round == "R02"
    assert p.author == "AP"
    assert p.date == "20251228"
    assert p.ext == "do"

def test_parse_typo_prefix():
    p = parse_at_name("L2PH_CATI@R02@BB@20251222.do")
    assert p.head == "L2PH_CATI"
    assert p.author == "BB"

def test_parse_non_at_pattern_returns_none():
    assert parse_at_name("master_analysis.do") is None
    assert parse_at_name("sl_stats_v2.json") is None
