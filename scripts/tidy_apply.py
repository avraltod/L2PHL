"""Execute a tidy manifest CSV. git-aware, collision-safe, idempotent, logged."""
import csv, os, shutil, subprocess


def _is_tracked(path, root):
    r = subprocess.run(["git", "ls-files", "--error-unmatch", path],
                       cwd=root, capture_output=True, text=True)
    return r.returncode == 0


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


def apply_manifest(csv_path, root):
    in_git = _git_root(root)
    with open(csv_path) as f:
        rows = list(csv.DictReader(f))

    # Files first (so dir renames don't move targets out from under them),
    # then directory renames, deepest first.
    file_rows = [r for r in rows if r["action"] in ("ARCHIVE", "RENAME")]
    dir_rows = sorted([r for r in rows if r["action"] == "RENAME-DIR"],
                      key=lambda r: r["path"].count(os.sep), reverse=True)

    moved = 0
    for r in file_rows:
        src, dst = r["path"], r["target"]
        if not os.path.exists(src):
            continue  # already done; keep idempotent
        final = _move(src, dst, root, in_git)
        if r["action"] == "ARCHIVE":
            _log(os.path.dirname(dst), src, final, root)
        moved += 1

    for r in dir_rows:
        src, dst = r["path"], r["target"]
        if not os.path.exists(src):
            continue
        dst = _unique_target(dst) if os.path.exists(dst) else dst
        if in_git and _is_tracked_dir(src, root):
            subprocess.run(["git", "mv", src, dst], cwd=root, check=True)
        else:
            shutil.move(src, dst)
        moved += 1

    print(f"applied {moved} actions")
    return 0


def _is_tracked_dir(path, root):
    r = subprocess.run(["git", "ls-files", path], cwd=root,
                       capture_output=True, text=True)
    return bool(r.stdout.strip())
