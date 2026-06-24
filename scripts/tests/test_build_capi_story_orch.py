import sys, os, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.dirname(HERE)
REPO = os.path.dirname(SCRIPTS)

def test_check_runs(tmp_path):
    # After the HTML refactor (Task 7) the real story is in sync, so --check returns 0.
    r = subprocess.run([sys.executable, os.path.join(SCRIPTS, "build_capi_story.py"), "--check"],
                       capture_output=True, text=True, cwd=REPO)
    assert r.returncode == 0, r.stdout + r.stderr
    assert "CHECK OK" in r.stdout
