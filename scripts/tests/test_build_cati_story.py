import sys, os, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.dirname(HERE)


def test_check_mode_runs_build_story_check(tmp_path, monkeypatch):
    # Smoke test: --check on the real repo returns 0 (story is in sync).
    repo = os.path.dirname(SCRIPTS)
    r = subprocess.run([sys.executable, os.path.join(SCRIPTS, "build_cati_story.py"), "--check"],
                       capture_output=True, text=True, cwd=repo)
    assert r.returncode == 0, r.stdout + r.stderr
    assert "CHECK OK" in r.stdout
