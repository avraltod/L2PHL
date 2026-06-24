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

def test_fmt_before_stat_order():
    # attribute order must not matter (silent-skip is a gate failure)
    h = ('<script id="sl-data" type="application/json">{}</script>'
         ' <span data-fmt="pct1" data-stat="fies.mod_sev_r5">OLD</span>')
    out, rep = inject(h, DATA, chart_key="charts")
    assert ">18.2%<" in out
    assert "fies.mod_sev_r5" in rep.used_stat_keys

def test_span_missing_fmt_raises():
    h = ('<script id="sl-data" type="application/json">{}</script>'
         ' <span data-stat="fies.mod_sev_r1">OLD</span>')
    with pytest.raises(InjectError, match="data-fmt"):
        inject(h, DATA, chart_key="charts")

def test_unbound_span_sweep_raises():
    # a data-stat span the matcher can't fully parse must ERROR, not silently skip
    h = ('<script id="sl-data" type="application/json">{}</script>'
         ' <span data-stat="fies.mod_sev_r1" data-fmt="pct0">OK</span>'
         ' <span data-stat="fies.mod_sev_r5" data-fmt="pct1">NOCLOSE')
    with pytest.raises(InjectError, match="did not bind"):
        inject(h, DATA, chart_key="charts")

def test_missing_chart_key_raises():
    with pytest.raises(InjectError, match="chart-key"):
        inject(HTML, DATA, chart_key="nope")

def test_script_close_in_chart_data_escaped():
    data = {"charts": {"lab": "x </script> y"}, "fies": {"mod_sev_r1": 1, "mod_sev_r5": 1}}
    out, _ = inject(HTML, data, chart_key="charts")
    assert "</script> y" not in out      # the data's </ was neutralized
    assert "<\\/script> y" in out

def test_idempotent_with_comma_value():
    data = {"charts": {}, "fies": {"mod_sev_r1": 2470, "mod_sev_r5": 18.2}}
    h = ('<script id="sl-data" type="application/json">{}</script>'
         ' <span data-stat="fies.mod_sev_r1" data-fmt="intcomma">x</span>'
         ' <span data-stat="fies.mod_sev_r5" data-fmt="pct1">y</span>')
    o1, _ = inject(h, data, chart_key="charts")
    o2, _ = inject(o1, data, chart_key="charts")
    assert ">2,470<" in o1 and o1 == o2

def test_inject_no_chart_key_prose_only():
    # No #sl-data block at all; chart_key=None must still bind spans and not error.
    h = 'pop <span data-stat="R01_POP" data-fmt="millions1word">x</span> people'
    out, rep = inject(h, {"R01_POP": 108667043}, chart_key=None)
    assert ">108.7 million<" in out
    assert rep.used_stat_keys == {"R01_POP"}

def test_inject_no_chart_key_still_sweeps_unbound():
    h = 'a <span data-stat="MISSING" data-fmt="int">x</span>'
    import pytest
    with pytest.raises(InjectError):
        inject(h, {}, chart_key=None)
