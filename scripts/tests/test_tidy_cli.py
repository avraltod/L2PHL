# scripts/tests/test_tidy_cli.py
import sys, os, subprocess, csv
HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.dirname(HERE)

def _make_tree(root):
    d = os.path.join(root, "CATI", "Round02", "do")
    os.makedirs(d)
    for name in [
        "L2PHL_CATI@R02@AP@20251228.do",
        "L2PH_CATI@R02@BB@20251222.do",
        "L2PHL_CATI@R02@Claude@20251228.do",
    ]:
        open(os.path.join(d, name), "w").close()
    os.makedirs(os.path.join(root, "CATI", "Round02", "zzz"))
    open(os.path.join(root, "CATI", "Round02", "zzz", "old.do"), "w").close()
    return root

def test_dry_run_writes_manifest(tmp_path):
    root = _make_tree(str(tmp_path))
    csv_out = os.path.join(root, "manifest.csv")
    r = subprocess.run(
        [sys.executable, os.path.join(SCRIPTS, "tidy.py"),
         "--dry-run", "--root", root, "--csv", csv_out, "--md", os.path.join(root, "manifest.md")],
        capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    with open(csv_out) as f:
        rows = list(csv.DictReader(f))
    actions = {(row["path"].split(os.sep)[-1]): row["action"] for row in rows if row["action"] != "KEEP"}
    assert actions["L2PH_CATI@R02@BB@20251222.do"] == "ARCHIVE"
    assert actions["L2PHL_CATI@R02@Claude@20251228.do"] == "ARCHIVE"
    # the zzz directory becomes a RENAME-DIR action
    dir_actions = [row for row in rows if row["action"] == "RENAME-DIR"]
    assert any(row["path"].endswith("zzz") for row in dir_actions)
