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

def test_parse_roundless_name():
    p = parse_at_name("hf_l2phl_analysis@AP@20260119.do")
    assert p is not None
    assert p.head == "hf_l2phl_analysis"
    assert p.round == ""
    assert p.author == "AP"
    assert p.date == "20260119"
    assert p.ext == "do"

def test_parse_non_at_pattern_returns_none():
    assert parse_at_name("master_analysis.do") is None
    assert parse_at_name("sl_stats_v2.json") is None

# append to scripts/tests/test_tidy_core.py
from tidy_core import slot_key, needs_prefix_fix, normalize_head

def test_normalize_head_fixes_typo():
    assert normalize_head("L2PH_CATI") == "L2PHL_CATI"
    assert normalize_head("L2PHL_CATI") == "L2PHL_CATI"
    assert normalize_head("hf_l2phl_analysis") == "hf_l2phl_analysis"

def test_slot_key_ignores_author_and_date():
    a = parse_at_name("L2PHL_CATI@R02@AP@20251228.do")
    b = parse_at_name("L2PH_CATI@R02@BB@20251222.do")
    assert slot_key(a) == slot_key(b)  # same round/ext/normalized head = same slot

def test_needs_prefix_fix():
    assert needs_prefix_fix(parse_at_name("L2PH_CATI@R02@AP@20251228.do")) is True
    assert needs_prefix_fix(parse_at_name("L2PHL_CATI@R02@AP@20251228.do")) is False

# append to scripts/tests/test_tidy_core.py
from tidy_core import classify_dir

def test_classify_dir_aliases():
    assert classify_dir("zzz") == "_attic"
    assert classify_dir("zArc") == "_attic"
    assert classify_dir("arch") == "_attic"
    assert classify_dir("_DA") == "_attic"
    assert classify_dir("Attic (Old versions)") == "_attic"

def test_classify_dir_keeps_normal():
    assert classify_dir("do") is None
    assert classify_dir("_attic") is None  # already correct

def test_classify_dir_attic_not_overbroad():
    assert classify_dir("AtticHelper") is None
    assert classify_dir("Attican") is None
    assert classify_dir("Attic") == "_attic"

# append to scripts/tests/test_tidy_core.py
from tidy_core import classify_dir_files

def actions_by_name(results):
    return {r.name: (r.action, r.reason) for r in results}

def test_latest_ap_is_live_others_archived():
    files = [
        "hf_l2phl_analysis@AP@20260119.do",
        "hf_l2phl_analysis@AP@20260520.do",
        "hf_l2phl_analysis@Claude@20260520.do",
    ]
    res = actions_by_name(classify_dir_files(files))
    assert res["hf_l2phl_analysis@AP@20260520.do"][0] == "KEEP"
    assert res["hf_l2phl_analysis@AP@20260119.do"] == ("ARCHIVE", "superseded-date")
    assert res["hf_l2phl_analysis@Claude@20260520.do"] == ("ARCHIVE", "non-ap-author")

def test_prefix_typo_rename():
    files = ["L2PH_CATI@R02@AP@20251228.do"]
    res = actions_by_name(classify_dir_files(files))
    assert res["L2PH_CATI@R02@AP@20251228.do"][0] == "RENAME"
    assert res["L2PH_CATI@R02@AP@20251228.do"][1] == "prefix-typo"

def test_version_suffix_archived():
    files = ["sl_stats.json", "sl_stats_v2.json"]
    res = actions_by_name(classify_dir_files(files))
    assert res["sl_stats.json"][0] == "KEEP"
    assert res["sl_stats_v2.json"] == ("ARCHIVE", "version-suffix")

def test_slot_with_no_ap_is_flagged():
    files = ["L2PHL_CATI@R02@BB@20251222.do", "L2PHL_CATI@R02@CV@20251231.do"]
    res = actions_by_name(classify_dir_files(files))
    assert all(v[0] == "FLAG" for v in res.values())

def test_two_live_same_date_flagged():
    files = ["x@R01@AP@20260101.do", "x@R01@AP@20260101.R"]  # diff ext = diff slot, both live
    res = actions_by_name(classify_dir_files(files))
    assert res["x@R01@AP@20260101.do"][0] == "KEEP"
    assert res["x@R01@AP@20260101.R"][0] == "KEEP"

def test_plain_file_kept():
    files = ["00_setup.do", "README.md"]
    res = actions_by_name(classify_dir_files(files))
    assert res["00_setup.do"][0] == "KEEP"
    assert res["README.md"][0] == "KEEP"

def test_version_suffix_kept_without_base():
    res = actions_by_name(classify_dir_files(["report_v2.do"]))
    assert res["report_v2.do"][0] == "KEEP"

def test_legit_names_not_treated_as_version_suffix():
    files = ["interview.do", "renew.do", "survey_v2_final.do"]
    res = actions_by_name(classify_dir_files(files))
    assert all(v[0] == "KEEP" for v in res.values())
