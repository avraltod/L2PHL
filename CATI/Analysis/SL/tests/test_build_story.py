# CATI/Analysis/SL/tests/test_build_story.py
import sys, os, json, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
SL = os.path.dirname(HERE)

def _write(p, s): open(p, "w", encoding="utf-8").write(s)

HTML = (
    '<script id="sl-data" type="application/json">{}</script>\n'
    'Fell to <span data-stat="fies.mod_sev_r5" data-fmt="pct1">OLD</span>.'
)
DATA = {"charts": {"t": [1, 2]}, "fies": {"mod_sev_r5": 18.2}}

def _run(args, cwd):
    return subprocess.run([sys.executable, os.path.join(SL, "build_story.py")] + args,
                          capture_output=True, text=True, cwd=cwd)

def test_build_then_check(tmp_path):
    h = os.path.join(tmp_path, "story.html"); j = os.path.join(tmp_path, "s.json")
    _write(h, HTML); _write(j, json.dumps(DATA))
    r = _run(["--html", h, "--json", j, "--chart-key", "charts"], str(tmp_path))
    assert r.returncode == 0, r.stderr
    assert ">18.2%<" in open(h, encoding="utf-8").read()
    # --check on the freshly built file passes
    r2 = _run(["--html", h, "--json", j, "--chart-key", "charts", "--check"], str(tmp_path))
    assert r2.returncode == 0, r2.stderr

def test_check_fails_on_drift(tmp_path):
    h = os.path.join(tmp_path, "story.html"); j = os.path.join(tmp_path, "s.json")
    _write(h, HTML.replace("OLD", "99.9%")); _write(j, json.dumps(DATA))
    r = _run(["--html", h, "--json", j, "--chart-key", "charts", "--check"], str(tmp_path))
    assert r.returncode == 1
    assert "drift" in (r.stdout + r.stderr).lower()
