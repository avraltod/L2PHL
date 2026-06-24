#!/usr/bin/env python3
"""L2PHL tidy tool. Dry-run produces a review manifest; apply executes it.

Usage:
  tidy.py --dry-run [--root .] [--csv manifest.csv] [--md manifest.md]
  tidy.py --apply --csv manifest.csv [--root .]
"""
import argparse, csv, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from tidy_core import classify_dir_files, classify_dir, ARCHIVE_DIR

# Directories we never descend into (data/binaries; already gitignored).
SKIP_DIRS = {".git", "raw", "aud", "call", "kobo", "Kobo", "dta", "tab",
             "sample", "tpn", ARCHIVE_DIR, "__pycache__"}


def walk_actions(root):
    """Yield dict rows for every file/dir action across the tree."""
    rows = []
    for dirpath, dirnames, filenames in os.walk(root):
        # Record dir renames, then prune skipped dirs from descent.
        for d in list(dirnames):
            tgt = classify_dir(d)
            if tgt is not None:
                rows.append({"action": "RENAME-DIR", "reason": "archive-alias",
                             "path": os.path.join(dirpath, d),
                             "target": os.path.join(dirpath, tgt)})
        dirnames[:] = [d for d in dirnames
                       if d not in SKIP_DIRS and classify_dir(d) is None]

        for fa in classify_dir_files(filenames):
            full = os.path.join(dirpath, fa.name)
            if fa.action == "KEEP":
                continue
            if fa.action == "RENAME":
                target = os.path.join(dirpath, fa.new_name)
            elif fa.action == "ARCHIVE":
                target = os.path.join(dirpath, ARCHIVE_DIR, fa.name)
            else:  # FLAG
                target = ""
            rows.append({"action": fa.action, "reason": fa.reason,
                         "path": full, "target": target})
    return rows


def write_manifest(rows, csv_path, md_path, root):
    with open(csv_path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["action", "reason", "path", "target"])
        w.writeheader()
        for row in rows:
            row = dict(row)
            row.setdefault("target", "")
            w.writerow(row)
    by_action = {}
    for row in rows:
        by_action.setdefault(row["action"], []).append(row)
    with open(md_path, "w") as f:
        f.write(f"# Tidy migration manifest\n\nRoot: `{root}`\n\n")
        for action in ("FLAG", "RENAME-DIR", "RENAME", "ARCHIVE"):
            items = by_action.get(action, [])
            f.write(f"## {action} ({len(items)})\n\n")
            for row in items:
                rel = os.path.relpath(row["path"], root)
                tgt = os.path.relpath(row["target"], root) if row.get("target") else "—"
                f.write(f"- `{rel}` → `{tgt}`  _({row['reason']})_\n")
            f.write("\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--root", default=".")
    ap.add_argument("--csv", default="tidy-manifest.csv")
    ap.add_argument("--md", default="tidy-manifest.md")
    args = ap.parse_args()
    root = os.path.abspath(args.root)

    if args.dry_run:
        rows = walk_actions(root)
        write_manifest(rows, args.csv, args.md, root)
        n = sum(1 for r in rows if r["action"] != "KEEP")
        print(f"{n} actions written to {args.csv} and {args.md}")
        return 0
    if args.apply:
        from tidy_apply import apply_manifest
        return apply_manifest(args.csv, root)
    ap.error("specify --dry-run or --apply")


if __name__ == "__main__":
    sys.exit(main())
