import os, subprocess, sys, pytest
SL = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

def _run(args):
    return subprocess.run([sys.executable, os.path.join(SL,"build_storyline.py"), *args],
                          cwd=SL, capture_output=True, text=True)

def test_build_story_single_file(tmp_path):
    r = _run(["--outdir", str(tmp_path)])
    assert r.returncode == 0, r.stderr
    html = open(os.path.join(tmp_path, "l2phl_cati_story.html"), encoding="utf-8").read()
    # self-contained, baseline theme + fonts + chart lib + engine + series inlined
    assert "scrollytelling engine" in html
    assert "--ink:#002244" in html
    assert "Playfair+Display" in html
    assert "chart.umd.js" in html
    assert 'id="sl-series"' in html
    assert "export function" not in html
    # tabbed masthead + hero + epilogue (baseline-comparable shell)
    assert '<header class="mast">' in html and 'class="mast-nav"' in html
    assert 'class="hero"' in html and 'class="epi"' in html
    # live topics are anchor tabs + chapters; pending topics are disabled tabs
    assert 'href="#ch-recovery"' in html and 'href="#ch-digital"' in html
    assert 'id="ch-recovery"' in html and 'id="ch-digital"' in html
    assert 'data-chapter="recovery"' in html and 'data-chapter="digital"' in html
    # one interactive chart per live chapter
    assert html.count("cbox sl-chart") >= 6
    # numbers bound, no placeholders
    assert ">OLD<" not in html

def test_story_check_passes(tmp_path):
    _run(["--outdir", str(tmp_path)])
    r = _run(["--outdir", str(tmp_path), "--check"])
    assert r.returncode == 0, r.stderr
    assert "CHECK OK" in r.stdout
