import sys, os, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
SL = os.path.dirname(HERE)

def _w(p, s): open(p, "w", encoding="utf-8").write(s)

HTML = 'pop <span data-stat="R01_POP" data-fmt="millions1word">OLD</span> people'
MD = ("| ID | Label | Value |\n|:---|:------|------:|\n"
      "| R01_POP | Weighted population | 108667043 |\n"
      "| R01_EXTRA | unused | 5 |\n")

def _run(args, cwd):
    return subprocess.run([sys.executable, os.path.join(SL, "build_capi_story.py")] + args,
                          capture_output=True, text=True, cwd=cwd)

def test_build_then_check(tmp_path):
    h = os.path.join(tmp_path, "s.html"); m = os.path.join(tmp_path, "s.md")
    _w(h, HTML); _w(m, MD)
    r = _run(["--html", h, "--md", m], str(tmp_path))
    assert r.returncode == 0, r.stderr
    assert ">108.7 million<" in open(h, encoding="utf-8").read()
    r2 = _run(["--html", h, "--md", m, "--check"], str(tmp_path))
    assert r2.returncode == 0, r2.stderr
    assert "CHECK OK" in r2.stdout

def test_check_fails_on_drift(tmp_path):
    h = os.path.join(tmp_path, "s.html"); m = os.path.join(tmp_path, "s.md")
    _w(h, HTML.replace("OLD", "999")); _w(m, MD)
    r = _run(["--html", h, "--md", m, "--check"], str(tmp_path))
    assert r.returncode == 1
    assert "drift" in (r.stdout + r.stderr).lower()
