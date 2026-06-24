# CATI/Analysis/SL/tests/test_injector.py
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import pytest
from sl_build.injector import inject, InjectError

HTML = (
    '<script id="sl-data" type="application/json">{}</script>\n'
    'Fell from <span data-stat="fies.mod_sev_r1" data-fmt="pct0">OLD</span> '
    'to <span data-stat="fies.mod_sev_r5" data-fmt="pct1">OLD</span>.'
)
DATA = {"charts": {"food_trend": [41.0, 18.2]},
        "fies": {"mod_sev_r1": 41.0, "mod_sev_r5": 18.2}}

def test_inject_fills_spans():
    out, report = inject(HTML, DATA, chart_key="charts")
    assert '>41%<' in out
    assert '>18.2%<' in out
    assert "OLD" not in out

def test_inject_writes_sl_data_block():
    out, _ = inject(HTML, DATA, chart_key="charts")
    assert '"food_trend"' in out
    assert '[41.0, 18.2]' in out or '[41.0,18.2]' in out

def test_report_lists_used_keys():
    _, report = inject(HTML, DATA, chart_key="charts")
    assert report.used_stat_keys == {"fies.mod_sev_r1", "fies.mod_sev_r5"}

def test_missing_stat_key_raises():
    bad = HTML.replace("fies.mod_sev_r5", "fies.ghost")
    with pytest.raises(InjectError, match="fies.ghost"):
        inject(bad, DATA, chart_key="charts")

def test_idempotent():
    out1, _ = inject(HTML, DATA, chart_key="charts")
    out2, _ = inject(out1, DATA, chart_key="charts")
    assert out1 == out2
