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

def _run(args, cwd):
    return subprocess.run([sys.executable, os.path.join(SCRIPTS, "tidy.py")] + args,
                          capture_output=True, text=True, cwd=cwd)

def test_apply_moves_and_is_idempotent(tmp_path):
    root = _make_tree(str(tmp_path))
    subprocess.run(["git", "init", "-q"], cwd=root, check=True)
    subprocess.run(["git", "add", "-A"], cwd=root, check=True)
    subprocess.run(["git", "-c", "user.email=t@t", "-c", "user.name=t",
                    "commit", "-qm", "init"], cwd=root, check=True)

    csv_out = os.path.join(root, "m.csv")
    _run(["--dry-run", "--root", root, "--csv", csv_out, "--md", os.path.join(root, "m.md")], root)
    r = _run(["--apply", "--root", root, "--csv", csv_out], root)
    assert r.returncode == 0, r.stderr

    do = os.path.join(root, "CATI", "Round02", "do")
    assert os.path.exists(os.path.join(do, "L2PHL_CATI@R02@AP@20251228.do"))   # live stays
    assert os.path.exists(os.path.join(do, "_attic", "L2PHL_CATI@R02@Claude@20251228.do"))
    assert os.path.exists(os.path.join(do, "_attic", "L2PH_CATI@R02@BB@20251222.do"))
    assert not os.path.exists(os.path.join(root, "CATI", "Round02", "zzz"))
    assert os.path.exists(os.path.join(root, "CATI", "Round02", "_attic"))
    assert os.path.exists(os.path.join(do, "_attic", ".tidy-log.csv"))

    # Idempotent: a fresh dry-run now yields zero non-KEEP actions.
    csv2 = os.path.join(root, "m2.csv")
    _run(["--dry-run", "--root", root, "--csv", csv2, "--md", os.path.join(root, "m2.md")], root)
    with open(csv2) as f:
        rows = [row for row in csv.DictReader(f) if row["action"] != "KEEP"]
    assert rows == []

def test_apply_skips_malformed_rows(tmp_path):
    # A hand-edited manifest with a blank target must not crash; the file stays put.
    root = str(tmp_path)
    do = os.path.join(root, "CATI", "Round02", "do")
    os.makedirs(do)
    open(os.path.join(do, "keep.do"), "w").close()
    csv_out = os.path.join(root, "m.csv")
    with open(csv_out, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["action", "reason", "path", "target"])
        w.writerow(["ARCHIVE", "non-ap-author", os.path.join(do, "keep.do"), ""])
    r = _run(["--apply", "--root", root, "--csv", csv_out], root)
    assert r.returncode == 0, r.stderr
    assert os.path.exists(os.path.join(do, "keep.do"))   # not moved
    assert "skip" in r.stdout.lower()

def test_apply_merges_into_existing_attic(tmp_path):
    # RENAME-DIR into an existing _attic merges contents; no _attic_1 fragment.
    root = str(tmp_path)
    base = os.path.join(root, "CATI", "Round03")
    zzz = os.path.join(base, "zzz")
    attic = os.path.join(base, "_attic")
    os.makedirs(zzz); os.makedirs(attic)
    open(os.path.join(zzz, "old1.do"), "w").close()
    open(os.path.join(attic, "old0.do"), "w").close()
    csv_out = os.path.join(root, "m.csv")
    with open(csv_out, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["action", "reason", "path", "target"])
        w.writerow(["RENAME-DIR", "archive-alias", zzz, attic])
    r = _run(["--apply", "--root", root, "--csv", csv_out], root)
    assert r.returncode == 0, r.stderr
    assert not os.path.exists(zzz)                     # alias dir gone
    assert not os.path.exists(attic + "_1")            # no fragmented archive
    assert os.path.exists(os.path.join(attic, "old0.do"))  # pre-existing kept
    assert os.path.exists(os.path.join(attic, "old1.do"))  # merged in

def test_apply_collision_suffix_and_log(tmp_path):
    # Archiving onto an existing name suffixes; the undo log records the real path.
    root = str(tmp_path)
    do = os.path.join(root, "CATI", "Round04", "do")
    attic = os.path.join(do, "_attic")
    os.makedirs(do); os.makedirs(attic)
    open(os.path.join(do, "x@Claude@20260101.do"), "w").close()    # to archive
    open(os.path.join(attic, "x@Claude@20260101.do"), "w").close() # collision
    csv_out = os.path.join(root, "m.csv")
    with open(csv_out, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["action", "reason", "path", "target"])
        w.writerow(["ARCHIVE", "non-ap-author",
                    os.path.join(do, "x@Claude@20260101.do"),
                    os.path.join(attic, "x@Claude@20260101.do")])
    r = _run(["--apply", "--root", root, "--csv", csv_out], root)
    assert r.returncode == 0, r.stderr
    assert os.path.exists(os.path.join(attic, "x@Claude@20260101_1.do"))
    with open(os.path.join(attic, ".tidy-log.csv")) as f:
        logrows = list(csv.DictReader(f))
    assert any(row["to"].endswith("_1.do") for row in logrows)
