# CATI/Analysis/SL/tests/test_stat_emit.py
import os, json, subprocess, shutil, sys, pytest
HERE = os.path.dirname(os.path.abspath(__file__))
SL = os.path.dirname(HERE)
STATA = "/Applications/Stata/StataMP.app/Contents/MacOS/stata-mp"


@pytest.mark.skipif(not os.path.exists(STATA), reason="Stata not installed")
def test_emitter_roundtrip(tmp_path):
    do = os.path.join(tmp_path, "rt.do")
    out = os.path.join(tmp_path, "out.json")
    with open(do, "w") as f:
        f.write(f'''
include "{SL}/_stat_emit.do"
stat_open "{out}"
stat_put "fies.mod_sev_r1" = 41.0
stat_arr "charts.food_trend" 41 31 26.8 21.5 18.2
stat_obj "charts.sev_macro" NCR 66.3 Luzon 60.0
stat_close
''')
    r = subprocess.run([STATA, "-b", "do", do], cwd=str(tmp_path),
                       capture_output=True, text=True)
    assert os.path.exists(out), r.stdout
    raw = json.load(open(out))
    assert raw["fies.mod_sev_r1"] == 41.0
    assert raw["charts.food_trend"] == [41, 31, 26.8, 21.5, 18.2]
    assert raw["charts.sev_macro"] == {"NCR": 66.3, "Luzon": 60.0}
