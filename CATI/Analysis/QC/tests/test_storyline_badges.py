import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))
from storyline_badges import apply_badges

SPAN = '<span data-stat="employment.no_contract_a16eq2" data-fmt="pct1">71.7%</span>'

def test_marks_caveat_span():
    html = f'<style>body{{}}</style><p>x {SPAN} y</p>'
    out = apply_badges(html, {"employment.no_contract_a16eq2": "rests on M04/a18"})
    assert '</span><sup class="qc-caveat"' in out      # badge right after the span
    assert '.qc-caveat{' in out                         # CSS injected once
    assert 'title="rests on M04/a18"' in out

def test_skips_non_caveat_span():
    html = '<style></style>' + '<span data-stat="fies.mod_sev_r5" data-fmt="pct1">18%</span>'
    out = apply_badges(html, {"employment.x": "tip"})    # fies not a caveat
    assert 'qc-caveat' not in out                        # no badge, no CSS

def test_idempotent():
    html = '<style></style><span data-stat="a.b" data-fmt="x">1</span>'
    once = apply_badges(html, {"a.b": "tip"})
    twice = apply_badges(once, {"a.b": "tip"})
    assert once == twice
    assert once.count('class="qc-caveat"') == 1

def test_clear_removes_badges():
    html = '<style></style><span data-stat="a.b" data-fmt="x">1</span>'
    badged = apply_badges(html, {"a.b": "tip"})
    cleared = apply_badges(badged, {})                   # no caveats
    assert '<sup class="qc-caveat"' not in cleared
