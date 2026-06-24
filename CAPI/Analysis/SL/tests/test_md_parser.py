from sl_build.md_parser import parse_md

SAMPLE = """# L2Phl Storyline Results
Generated: 1 Apr 2026

| ID | Label | Value |
|:---|:------|------:|

## §1 Roster (M01)

| R01_N | Total household members | 10496 |
| R01_POP | Weighted population | 108667043 |
| R01_UNDER20 | % under 20 | 40.56 |
| R01_MEDIAN_AGE | Median age | 25.0 |
| R07_NOTE | Some text value | n/a |
"""

def test_parses_ids_to_values():
    d = parse_md(SAMPLE)
    assert d["R01_N"] == 10496
    assert d["R01_POP"] == 108667043
    assert d["R01_UNDER20"] == 40.56
    assert d["R01_MEDIAN_AGE"] == 25          # 25.0 collapses to int
    assert d["R07_NOTE"] == "n/a"             # non-numeric stays string

def test_skips_header_separator_headings():
    d = parse_md(SAMPLE)
    assert "ID" not in d
    assert all(not k.startswith(":") for k in d)
    assert "## §1 Roster (M01)" not in d
    assert len(d) == 5

def test_pipe_in_label_keeps_id_and_value():
    md = "| A03_X | broad (a1|a2) rate | 52.05 |\n"
    assert parse_md(md) == {"A03_X": 52.05}

def test_duplicate_id_raises():
    import pytest
    md = "| R01_POP | a | 1 |\n| R01_POP | b | 2 |\n"
    with pytest.raises(ValueError, match="duplicate"):
        parse_md(md)
