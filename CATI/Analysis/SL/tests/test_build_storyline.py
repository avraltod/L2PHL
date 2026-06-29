import os, json, subprocess, sys, pytest
SL = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

def _run(args):
    return subprocess.run([sys.executable, os.path.join(SL,"build_storyline.py"), *args],
                          cwd=SL, capture_output=True, text=True)

def test_build_topic_selfcontained_and_bound(tmp_path):
    r = _run(["--topic","recovery","--outdir",str(tmp_path)])
    assert r.returncode==0, r.stderr
    html = open(os.path.join(tmp_path,"l2p_cati_recovery.html"),encoding="utf-8").read()
    # self-contained: engine + baseline theme + fonts + chart lib + series all inlined
    assert "scrollytelling engine" in html
    assert "--ink:#002244" in html                   # baseline editorial theme inlined
    assert "Playfair+Display" in html                # baseline display font
    assert "chart.umd.js" in html                    # Chart.js CDN
    assert 'id="sl-series"' in html                  # series JSON embedded
    assert "export function availableBreakdowns" not in html
    assert "import assert" not in html
    assert ">OLD<" not in html                       # data-stat bound

def test_build_hub_has_nine_cards(tmp_path):
    r = _run(["--hub","--outdir",str(tmp_path)])
    assert r.returncode==0, r.stderr
    html = open(os.path.join(tmp_path,"l2p_cati_hub.html"),encoding="utf-8").read()
    assert html.count('class="tcard') == 9
    assert 'href="l2p_cati_recovery.html"' in html   # live topic linked
    assert html.count("soon") >= 8                    # 8 not-yet-live

def test_check_passes_after_build(tmp_path):
    _run(["--topic","recovery","--outdir",str(tmp_path)])
    r = _run(["--topic","recovery","--outdir",str(tmp_path),"--check"])
    assert r.returncode==0, r.stderr
    assert "CHECK OK" in r.stdout
