"""Execute a tidy manifest CSV. git-aware, collision-safe, idempotent, logged."""
import csv, os, shutil, subprocess

KNOWN_ACTIONS = {"KEEP", "FLAG", "ARCHIVE", "RENAME", "RENAME-DIR"}


def _is_tracked(path, root):
    r = subprocess.run(["git", "ls-files", "--error-unmatch", path],
                       cwd=root, capture_output=True, text=True)
    return r.returncode == 0


def _is_tracked_dir(path, root):
    r = subprocess.run(["git", "ls-files", path], cwd=root,
                       capture_output=True, text=True)
    return bool(r.stdout.strip())


def _git_root(root):
    r = subprocess.run(["git", "rev-parse", "--is-inside-work-tree"],
                       cwd=root, capture_output=True, text=True)
    return r.returncode == 0 and r.stdout.strip() == "true"


def _unique_target(target):
    """Avoid overwriting an existing file in _attic: suffix _1, _2, ..."""
    if not os.path.exists(target):
        return target
    base, ext = os.path.splitext(target)
    i = 1
    while os.path.exists(f"{base}_{i}{ext}"):
        i += 1
    return f"{base}_{i}{ext}"


def _move(src, dst, root, in_git):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    dst = _unique_target(dst)
    if in_git and _is_tracked(src, root):
        subprocess.run(["git", "mv", src, dst], cwd=root, check=True)
    else:
        shutil.move(src, dst)
    return dst


def _log(attic_dir, src, dst, root):
    os.makedirs(attic_dir, exist_ok=True)
    logf = os.path.join(attic_dir, ".tidy-log.csv")
    new = not os.path.exists(logf)
    with open(logf, "a", newline="") as f:
        w = csv.writer(f)
        if new:
            w.writerow(["from", "to"])
        w.writerow([os.path.relpath(src, root), os.path.relpath(dst, root)])


def _apply_dir_rename(src, dst, root, in_git):
    """Rename an archive-alias dir to _attic. If _attic already exists, MERGE the
    alias dir's contents into it (per-child, collision-safe) and drop the now-empty
    alias dir — never create a second `_attic_1` archive."""
    if not os.path.exists(dst):
        if in_git and _is_tracked_dir(src, root):
            subprocess.run(["git", "mv", src, dst], cwd=root, check=True)
        else:
            shutil.move(src, dst)
        return
    for child in os.listdir(src):
        child_src = os.path.join(src, child)
        final = _move(child_src, os.path.join(dst, child), root, in_git)
        _log(dst, child_src, final, root)
    if not os.listdir(src):
        os.rmdir(src)   # only ever removes a now-empty alias dir, never data


def apply_manifest(csv_path, root):
    in_git = _git_root(root)
    with open(csv_path) as f:
        rows = list(csv.DictReader(f))

    # Warn on unrecognized (e.g. typo'd) actions in a hand-edited manifest.
    for r in rows:
        if r.get("action") not in KNOWN_ACTIONS:
            print(f"  WARN unrecognized action {r.get('action')!r}: {r.get('path')}")

    # Files first (so dir renames don't move targets out from under them),
    # then directory renames, deepest first.
    file_rows = [r for r in rows if r.get("action") in ("ARCHIVE", "RENAME")]
    dir_rows = sorted([r for r in rows if r.get("action") == "RENAME-DIR"],
                      key=lambda r: r["path"].count(os.sep), reverse=True)

    moved = skipped = failed = present = 0

    def _process(r, is_dir):
        nonlocal moved, skipped, failed, present
        src, dst = r.get("path"), r.get("target")
        if not src or not dst:
            print(f"  skip (blank path/target): {r}")
            skipped += 1
            return
        if not os.path.exists(src):
            return  # idempotent: already moved
        present += 1
        try:
            if is_dir:
                _apply_dir_rename(src, dst, root, in_git)
            else:
                final = _move(src, dst, root, in_git)
                if r["action"] == "ARCHIVE":
                    _log(os.path.dirname(dst), src, final, root)
            moved += 1
        except Exception as e:
            print(f"  FAILED {src}: {e}")
            failed += 1

    for r in file_rows:
        _process(r, is_dir=False)
    for r in dir_rows:
        _process(r, is_dir=True)

    # Distinguish "already applied" from "wrong --root": actionable rows existed
    # but none of their sources were found on disk.
    if (len(file_rows) + len(dir_rows)) and present == 0:
        print("  WARNING: no source paths found — already applied, or wrong --root?")

    print(f"applied {moved} actions, {skipped} skipped, {failed} failed")
    return 1 if failed else 0
