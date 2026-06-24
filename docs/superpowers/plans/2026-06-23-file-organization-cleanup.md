# File-Organization Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a re-runnable `tidy.py` tool plus a convention rule that collapse L2PHL's version sprawl into one live file per slot, archive the rest into local `_attic/` folders, and fix naming drift — driven by a reviewable dry-run manifest.

**Architecture:** A pure, unit-testable core (`scripts/tidy_core.py`) does all classification with no disk/git side effects: it parses `@`-pattern filenames, groups files into logical "slots," picks the latest-dated `@AP@` file as live, and labels everything else. A thin CLI (`scripts/tidy.py`) walks the tree, writes a markdown+CSV manifest on `--dry-run`, and executes an approved manifest on `--apply` (git-aware moves, collision-safe, idempotent, with an undo log). A rule doc and a one-line `.gitignore` change lock the convention in.

**Tech Stack:** Python 3.12, standard library only (`argparse`, `pathlib`, `csv`, `re`, `subprocess`, `shutil`, `dataclasses`); `pytest` for tests. No third-party deps.

**Why top-level `scripts/`:** `CATI/Analysis/QC/scripts/` is deliberately untracked (commit `e642fac`). This tooling must be version-controlled and is tree-wide (not QC-specific), so it lives in a new tracked `scripts/` at the repo root.

---

## File Structure

- Create: `scripts/tidy_core.py` — pure classification logic (no I/O). One responsibility: decide what should happen to each file/dir.
- Create: `scripts/tidy.py` — CLI: tree walk, manifest write (`--dry-run`), manifest execute (`--apply`).
- Create: `scripts/tests/test_tidy_core.py` — unit tests for the core.
- Create: `scripts/tests/test_tidy_cli.py` — integration tests against temp trees.
- Create: `scripts/README.md` — how to run the tool.
- Create: `.claude/rules/file-organization.md` — the auto-loaded convention.
- Modify: `.gitignore` — replace 5 archive lines with `**/_attic/`.

---

## Task 1: Core constants and filename parser

**Files:**
- Create: `scripts/tidy_core.py`
- Test: `scripts/tests/test_tidy_core.py`

- [ ] **Step 1: Write the failing test**

```python
# scripts/tests/test_tidy_core.py
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from tidy_core import parse_at_name

def test_parse_canonical_name():
    p = parse_at_name("L2PHL_CATI@R02@AP@20251228.do")
    assert p is not None
    assert p.head == "L2PHL_CATI"
    assert p.round == "R02"
    assert p.author == "AP"
    assert p.date == "20251228"
    assert p.ext == "do"

def test_parse_typo_prefix():
    p = parse_at_name("L2PH_CATI@R02@BB@20251222.do")
    assert p.head == "L2PH_CATI"
    assert p.author == "BB"

def test_parse_roundless_name():
    # Many analysis files omit the round segment: HEAD@AUTHOR@DATE.ext
    p = parse_at_name("hf_l2phl_analysis@AP@20260119.do")
    assert p is not None
    assert p.head == "hf_l2phl_analysis"
    assert p.round == ""
    assert p.author == "AP"
    assert p.date == "20260119"
    assert p.ext == "do"

def test_parse_non_at_pattern_returns_none():
    assert parse_at_name("master_analysis.do") is None
    assert parse_at_name("sl_stats_v2.json") is None
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd scripts && python3 -m pytest tests/test_tidy_core.py -q`
Expected: FAIL — `ModuleNotFoundError: No module named 'tidy_core'`

- [ ] **Step 3: Write minimal implementation**

```python
# scripts/tidy_core.py
"""Pure classification logic for the L2PHL tidy tool. No disk or git side effects."""
import re
from dataclasses import dataclass

PROJECT_PREFIX = "L2PHL"
CANONICAL_AUTHOR = "AP"
ARCHIVE_DIR = "_attic"

# Archive-folder spellings to retire (exact names; "Attic*" handled by prefix match).
ARCHIVE_ALIASES = {"zzz", "zArc", "arch", "arc", "_arc", "_DA", "archive"}

# Version suffixes that mark a non-@-pattern file as superseded.
SUPERSEDED_SUFFIX_RE = re.compile(r"_(v\d+|old|new|backup)$", re.IGNORECASE)


@dataclass(frozen=True)
class ParsedName:
    head: str    # first @-segment, e.g. "L2PHL_CATI" (prefix+mode)
    round: str   # e.g. "R02"
    author: str  # e.g. "AP"
    date: str    # e.g. "20251228"
    ext: str     # e.g. "do"


def parse_at_name(filename):
    """Return ParsedName for `HEAD@ROUND@AUTHOR@DATE.ext`, else None."""
    if "@" not in filename or "." not in filename:
        return None
    stem, _, ext = filename.rpartition(".")
    parts = stem.split("@")
    # 4 segments = HEAD@ROUND@AUTHOR@DATE; 3 = roundless HEAD@AUTHOR@DATE.
    if len(parts) == 4:
        head, rnd, author, date = parts
    elif len(parts) == 3:
        head, author, date = parts
        rnd = ""
    else:
        return None
    if not re.fullmatch(r"\d{8}", date):
        return None
    return ParsedName(head=head, round=rnd, author=author, date=date, ext=ext)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd scripts && python3 -m pytest tests/test_tidy_core.py -q`
Expected: PASS (4 passed)

- [ ] **Step 5: Commit**

```bash
git add scripts/tidy_core.py scripts/tests/test_tidy_core.py
git commit -m "add tidy_core filename parser"
```

---

## Task 2: Slot identity and prefix-typo detection

**Files:**
- Modify: `scripts/tidy_core.py`
- Test: `scripts/tests/test_tidy_core.py`

- [ ] **Step 1: Write the failing test**

```python
# append to scripts/tests/test_tidy_core.py
from tidy_core import slot_key, needs_prefix_fix, normalize_head

def test_normalize_head_fixes_typo():
    assert normalize_head("L2PH_CATI") == "L2PHL_CATI"
    assert normalize_head("L2PHL_CATI") == "L2PHL_CATI"
    assert normalize_head("hf_l2phl_analysis") == "hf_l2phl_analysis"

def test_slot_key_ignores_author_and_date():
    a = parse_at_name("L2PHL_CATI@R02@AP@20251228.do")
    b = parse_at_name("L2PH_CATI@R02@BB@20251222.do")
    assert slot_key(a) == slot_key(b)  # same round/ext/normalized head = same slot

def test_needs_prefix_fix():
    assert needs_prefix_fix(parse_at_name("L2PH_CATI@R02@AP@20251228.do")) is True
    assert needs_prefix_fix(parse_at_name("L2PHL_CATI@R02@AP@20251228.do")) is False
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd scripts && python3 -m pytest tests/test_tidy_core.py -q`
Expected: FAIL — `ImportError: cannot import name 'slot_key'`

- [ ] **Step 3: Write minimal implementation**

```python
# append to scripts/tidy_core.py

def normalize_head(head):
    """Fix the L2PH -> L2PHL prefix typo; leave other heads untouched."""
    if head.startswith("L2PH_") and not head.startswith("L2PHL_"):
        return "L2PHL_" + head[len("L2PH_"):]
    return head


def needs_prefix_fix(parsed):
    return normalize_head(parsed.head) != parsed.head


def slot_key(parsed):
    """Identity of a logical slot, ignoring author and date."""
    return (normalize_head(parsed.head), parsed.round, parsed.ext)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd scripts && python3 -m pytest tests/test_tidy_core.py -q`
Expected: PASS (7 passed)

- [ ] **Step 5: Commit**

```bash
git add scripts/tidy_core.py scripts/tests/test_tidy_core.py
git commit -m "add slot identity and prefix-typo detection"
```

---

## Task 3: Directory classification (archive aliases -> _attic)

**Files:**
- Modify: `scripts/tidy_core.py`
- Test: `scripts/tests/test_tidy_core.py`

- [ ] **Step 1: Write the failing test**

```python
# append to scripts/tests/test_tidy_core.py
from tidy_core import classify_dir

def test_classify_dir_aliases():
    assert classify_dir("zzz") == "_attic"
    assert classify_dir("zArc") == "_attic"
    assert classify_dir("arch") == "_attic"
    assert classify_dir("_DA") == "_attic"
    assert classify_dir("Attic (Old versions)") == "_attic"

def test_classify_dir_keeps_normal():
    assert classify_dir("do") is None
    assert classify_dir("_attic") is None  # already correct

def test_classify_dir_attic_not_overbroad():
    assert classify_dir("AtticHelper") is None
    assert classify_dir("Attican") is None
    assert classify_dir("Attic") == "_attic"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd scripts && python3 -m pytest tests/test_tidy_core.py -q`
Expected: FAIL — `ImportError: cannot import name 'classify_dir'`

- [ ] **Step 3: Write minimal implementation**

```python
# append to scripts/tidy_core.py

def classify_dir(dirname):
    """Return '_attic' if this dir is an archive alias to rename, else None."""
    if dirname == ARCHIVE_DIR:
        return None
    if dirname in ARCHIVE_ALIASES:
        return ARCHIVE_DIR
    # "Attic" archives always have a separator after the word (e.g. "Attic (Old versions)").
    # Anchor on that so unrelated names like "AtticHelper" are not misclassified.
    if dirname == "Attic" or dirname.startswith(("Attic ", "Attic_", "Attic(")):
        return ARCHIVE_DIR
    return None
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd scripts && python3 -m pytest tests/test_tidy_core.py -q`
Expected: PASS (10 passed)

- [ ] **Step 5: Commit**

```bash
git add scripts/tidy_core.py scripts/tests/test_tidy_core.py
git commit -m "add archive-folder alias classification"
```

---

## Task 4: File-set classification (live selection + actions)

**Files:**
- Modify: `scripts/tidy_core.py`
- Test: `scripts/tests/test_tidy_core.py`

This is the heart of the tool. Given the list of filenames in one directory, decide an `Action` per file.

- [ ] **Step 1: Write the failing test**

```python
# append to scripts/tests/test_tidy_core.py
from tidy_core import classify_dir_files

def actions_by_name(results):
    return {r.name: (r.action, r.reason) for r in results}

def test_latest_ap_is_live_others_archived():
    files = [
        "hf_l2phl_analysis@AP@20260119.do",
        "hf_l2phl_analysis@AP@20260520.do",
        "hf_l2phl_analysis@Claude@20260520.do",
    ]
    res = actions_by_name(classify_dir_files(files))
    assert res["hf_l2phl_analysis@AP@20260520.do"][0] == "KEEP"
    assert res["hf_l2phl_analysis@AP@20260119.do"] == ("ARCHIVE", "superseded-date")
    assert res["hf_l2phl_analysis@Claude@20260520.do"] == ("ARCHIVE", "non-ap-author")

def test_prefix_typo_rename():
    files = ["L2PH_CATI@R02@AP@20251228.do"]
    res = actions_by_name(classify_dir_files(files))
    assert res["L2PH_CATI@R02@AP@20251228.do"][0] == "RENAME"
    assert res["L2PH_CATI@R02@AP@20251228.do"][1] == "prefix-typo"

def test_version_suffix_archived():
    files = ["sl_stats.json", "sl_stats_v2.json"]
    res = actions_by_name(classify_dir_files(files))
    assert res["sl_stats.json"][0] == "KEEP"
    assert res["sl_stats_v2.json"] == ("ARCHIVE", "version-suffix")

def test_version_suffix_kept_without_base():
    # A lone _v2 with no base sibling is NOT archived (don't empty the slot).
    res = actions_by_name(classify_dir_files(["report_v2.do"]))
    assert res["report_v2.do"][0] == "KEEP"

def test_legit_names_not_treated_as_version_suffix():
    files = ["interview.do", "renew.do", "survey_v2_final.do"]
    res = actions_by_name(classify_dir_files(files))
    assert all(v[0] == "KEEP" for v in res.values())

def test_slot_with_no_ap_is_flagged():
    files = ["L2PHL_CATI@R02@BB@20251222.do", "L2PHL_CATI@R02@CV@20251231.do"]
    res = actions_by_name(classify_dir_files(files))
    assert all(v[0] == "FLAG" for v in res.values())

def test_two_live_same_date_flagged():
    files = ["x@R01@AP@20260101.do", "x@R01@AP@20260101.R"]  # diff ext = diff slot, both live
    res = actions_by_name(classify_dir_files(files))
    assert res["x@R01@AP@20260101.do"][0] == "KEEP"
    assert res["x@R01@AP@20260101.R"][0] == "KEEP"

def test_plain_file_kept():
    files = ["00_setup.do", "README.md"]
    res = actions_by_name(classify_dir_files(files))
    assert res["00_setup.do"][0] == "KEEP"
    assert res["README.md"][0] == "KEEP"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd scripts && python3 -m pytest tests/test_tidy_core.py -q`
Expected: FAIL — `ImportError: cannot import name 'classify_dir_files'`

- [ ] **Step 3: Write minimal implementation**

```python
# append to scripts/tidy_core.py
from collections import defaultdict

@dataclass(frozen=True)
class FileAction:
    name: str       # original filename
    action: str     # KEEP | RENAME | ARCHIVE | FLAG
    reason: str     # machine tag, e.g. "non-ap-author"
    new_name: str   # target filename when action == RENAME, else ""


def _version_suffix_stem(filename):
    """If filename is a version-suffixed variant, return its base filename, else None."""
    if "." not in filename:
        return None
    stem, _, ext = filename.rpartition(".")
    if SUPERSEDED_SUFFIX_RE.search(stem):
        base_stem = SUPERSEDED_SUFFIX_RE.sub("", stem)
        return f"{base_stem}.{ext}"
    return None


def classify_dir_files(filenames):
    """Classify every filename in a single directory. Returns list[FileAction]."""
    parsed = {f: parse_at_name(f) for f in filenames}

    # Group @-pattern files into slots.
    slots = defaultdict(list)
    for f, p in parsed.items():
        if p is not None:
            slots[slot_key(p)].append((f, p))

    # Decide the live file per slot: latest date among canonical (AP) authors.
    live = {}   # slot_key -> filename chosen as live
    flagged_slots = set()
    for key, members in slots.items():
        ap = [(f, p) for f, p in members if p.author == CANONICAL_AUTHOR]
        if not ap:
            flagged_slots.add(key)        # no canonical file exists
            continue
        max_date = max(p.date for _, p in ap)
        winners = [f for f, p in ap if p.date == max_date]
        if len(winners) > 1:
            flagged_slots.add(key)        # ambiguous: two AP files same date
            continue
        live[key] = winners[0]

    results = []
    for f, p in parsed.items():
        if p is not None:
            key = slot_key(p)
            if key in flagged_slots:
                results.append(FileAction(f, "FLAG", "ambiguous-slot", ""))
            elif f == live.get(key):
                if needs_prefix_fix(p):
                    new = f"{normalize_head(p.head)}@{p.round}@{p.author}@{p.date}.{p.ext}"
                    results.append(FileAction(f, "RENAME", "prefix-typo", new))
                else:
                    results.append(FileAction(f, "KEEP", "live", ""))
            elif p.author != CANONICAL_AUTHOR:
                results.append(FileAction(f, "ARCHIVE", "non-ap-author", ""))
            else:
                results.append(FileAction(f, "ARCHIVE", "superseded-date", ""))
        else:
            # Non-@-pattern file: archive a version-suffixed variant ONLY when its
            # base file is also present (never archive a sole survivor).
            base = _version_suffix_stem(f)
            if base is not None and base in parsed:
                results.append(FileAction(f, "ARCHIVE", "version-suffix", ""))
            else:
                results.append(FileAction(f, "KEEP", "plain", ""))
    return results
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd scripts && python3 -m pytest tests/test_tidy_core.py -q`
Expected: PASS (17 passed)

- [ ] **Step 5: Commit**

```bash
git add scripts/tidy_core.py scripts/tests/test_tidy_core.py
git commit -m "add per-directory file classification with live selection"
```

---

## Task 5: CLI dry-run — tree walk and manifest writer

**Files:**
- Create: `scripts/tidy.py`
- Test: `scripts/tests/test_tidy_cli.py`

- [ ] **Step 1: Write the failing test**

```python
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd scripts && python3 -m pytest tests/test_tidy_cli.py -q`
Expected: FAIL — tidy.py does not exist (non-zero return, error in stderr)

- [ ] **Step 3: Write minimal implementation**

```python
# scripts/tidy.py
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd scripts && python3 -m pytest tests/test_tidy_cli.py -q`
Expected: PASS (1 passed)

- [ ] **Step 5: Commit**

```bash
git add scripts/tidy.py scripts/tests/test_tidy_cli.py
git commit -m "add tidy dry-run tree walk and manifest writer"
```

---

## Task 6: CLI apply — git-aware, collision-safe, idempotent, undo log

**Files:**
- Create: `scripts/tidy_apply.py`
- Test: `scripts/tests/test_tidy_cli.py`

- [ ] **Step 1: Write the failing test**

```python
# append to scripts/tests/test_tidy_cli.py

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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd scripts && python3 -m pytest tests/test_tidy_cli.py -q`
Expected: FAIL — `ModuleNotFoundError: No module named 'tidy_apply'`

- [ ] **Step 3: Write minimal implementation**

```python
# scripts/tidy_apply.py
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd scripts && python3 -m pytest tests/test_tidy_cli.py -q`
Expected: PASS (2 passed)

- [ ] **Step 5: Commit**

```bash
git add scripts/tidy_apply.py scripts/tests/test_tidy_cli.py
git commit -m "add tidy apply: git-aware moves, collision-safe, idempotent, undo log"
```

---

## Task 7: Convention rule and .gitignore change

**Files:**
- Create: `.claude/rules/file-organization.md`
- Modify: `.gitignore` (lines 39–43)
- Create: `scripts/README.md`

- [ ] **Step 1: Write the rule doc**

```markdown
<!-- .claude/rules/file-organization.md -->
# File-organization rules

**One live file per slot.** A *slot* is a logical role (a round master do-file,
an analysis script, a stats JSON, a deliverable). Exactly one live file per slot:
the latest-dated `@AP@` version. Everything else is superseded.

**Naming.** `L2PHL_<MODE>@<ROUND>@AP@YYYYMMDD.ext`. Prefix is always `L2PHL`
(never `L2PH`); author is always `AP`; date is the revision date. Bumping the
date moves the prior file to `_attic/`. Applies to `.do .R .json .html .docx .txt`.

**Archive.** Superseded files go to a `_attic/` folder local to their working
directory (e.g. `CATI/Round02/do/_attic/`). `_attic/` is the only archive name —
`zzz` `zArc` `arch` `arc` `_arc` `_DA` `Attic*` `archive` are retired.

**Maintenance.** Run `python3 scripts/tidy.py --dry-run`, review the manifest,
then `python3 scripts/tidy.py --apply --csv tidy-manifest.csv`. Re-run every round.
```

- [ ] **Step 2: Edit `.gitignore`**

Replace these five lines:

```
**/zzz/
**/zArc/
**/arch/
**/arc/
**/Attic*/
```

with this single line:

```
**/_attic/
```

- [ ] **Step 3: Write `scripts/README.md`**

```markdown
# scripts/

Tree-wide maintenance tooling (tracked, unlike `CATI/Analysis/QC/scripts/`).

## tidy.py — file-organization maintenance

```bash
python3 scripts/tidy.py --dry-run                 # writes tidy-manifest.{csv,md}
# review tidy-manifest.md; strike rows you disagree with in tidy-manifest.csv
python3 scripts/tidy.py --apply --csv tidy-manifest.csv
```

- One live file per slot (latest `@AP@`); others move to local `_attic/`.
- Fixes `L2PH`→`L2PHL` prefix typos; renames archive folders to `_attic/`.
- `FLAG` rows need a human decision (no canonical AP file, or two same-date AP files).
- Never deletes; writes a reversible `_attic/.tidy-log.csv`.

Run `python3 -m pytest scripts/tests/ -q` after editing.
```

- [ ] **Step 4: Verify rules + gitignore**

Run: `cd /Users/avraa/iDrive/GitHub/PHL/L2PHL && grep -n "_attic" .gitignore && grep -c "zzz\|zArc\|Attic" .gitignore`
Expected: shows `**/_attic/`; the second grep prints `0`.

- [ ] **Step 5: Commit**

```bash
git add .claude/rules/file-organization.md .gitignore scripts/README.md
git commit -m "add file-organization rule and collapse gitignore archive names to _attic"
```

---

## Task 8: Generate the real migration manifest for review

This task produces the deliverable you approve before any real move. It is a run, not new code.

- [ ] **Step 1: Run the full test suite**

Run: `cd /Users/avraa/iDrive/GitHub/PHL/L2PHL/scripts && python3 -m pytest tests/ -q`
Expected: PASS (19 passed)

- [ ] **Step 2: Generate the real dry-run manifest**

Run:
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
python3 scripts/tidy.py --dry-run --root . \
  --csv docs/superpowers/specs/2026-06-23-tidy-manifest.csv \
  --md  docs/superpowers/specs/2026-06-23-tidy-manifest.md
```
Expected: prints "N actions written..."; the two manifest files exist.

- [ ] **Step 3: Sanity-check the manifest counts**

Run:
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
python3 -c "import csv;r=list(csv.DictReader(open('docs/superpowers/specs/2026-06-23-tidy-manifest.csv')));import collections;print(collections.Counter(x['action'] for x in r))"
```
Expected: a `Counter` showing counts of `ARCHIVE`, `RENAME`, `RENAME-DIR`, `FLAG`. Cross-check against the spec's scale estimate (≈58 non-AP, 23 typos, 37 archive dirs) — same order of magnitude.

- [ ] **Step 4: STOP — human review gate**

Open `docs/superpowers/specs/2026-06-23-tidy-manifest.md`. Review every `FLAG`
row and spot-check `ARCHIVE`/`RENAME` rows. Strike any disagreed rows out of the
`.csv`. **Do not run `--apply` until the manifest is approved.**

- [ ] **Step 5: Commit the manifest**

```bash
git add docs/superpowers/specs/2026-06-23-tidy-manifest.csv docs/superpowers/specs/2026-06-23-tidy-manifest.md
git commit -m "generate file-organization migration manifest for review"
```

---

## Task 9: Execute the approved migration

- [ ] **Step 1: Apply the approved manifest**

Run:
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
python3 scripts/tidy.py --apply --root . \
  --csv docs/superpowers/specs/2026-06-23-tidy-manifest.csv
```
Expected: prints "applied N actions".

- [ ] **Step 2: Verify idempotency**

Run:
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
python3 scripts/tidy.py --dry-run --root . --csv /tmp/recheck.csv --md /tmp/recheck.md
python3 -c "import csv;print([r for r in csv.DictReader(open('/tmp/recheck.csv')) if r['action']!='KEEP'])"
```
Expected: `[]` (empty) — apart from any rows you intentionally struck.

- [ ] **Step 3: Review the moves**

Run: `cd /Users/avraa/iDrive/GitHub/PHL/L2PHL && git status --short | head -50`
Expected: renames (`R`) for tracked live-file typo fixes and tracked archived files; verify no live deliverable was archived by mistake.

- [ ] **Step 4: Commit the migration**

```bash
git add -A
git commit -m "apply file-organization cleanup: one live file per slot, archives unified to _attic"
```

---

## Self-Review

**Spec coverage:**
- Canonical `@AP@` + latest-date-wins → Task 4 (`classify_dir_files`).
- Disposition = archive never delete → Task 6 (`_move` only moves; no `os.remove`).
- Local `_attic/` → Task 5 (`ARCHIVE` target is `dirpath/_attic/name`).
- One archive name; retire the zoo → Task 3 + Task 6 dir renames + Task 7 gitignore.
- Naming pattern + prefix typo fix → Task 2 (`normalize_head`) + Task 4 (`RENAME`).
- Whole tree, all file types → Task 5 walk (no extension filter; SKIP_DIRS only excludes data/binaries).
- Doc + re-runnable script + reviewable manifest → Tasks 5/6 (script), 7 (doc), 8 (manifest), 9 (apply).
- Acceptance: idempotent empty re-run → Task 6 test + Task 9 Step 2; undo log → Task 6 `_log`.

**Placeholder scan:** none — every code step shows complete code; every run step shows command + expected output.

**Type consistency:** `ParsedName(head, round, author, date, ext)` used consistently in Tasks 1–4. `FileAction(name, action, reason, new_name)` consistent in Task 4 → consumed in Task 5 (`fa.name`, `fa.action`, `fa.new_name`). Manifest CSV columns `action, reason, path, target` written in Task 5, read in Task 6. `apply_manifest(csv_path, root)` defined in Task 6, called in Task 5 `main()`.

**Note on already-tracked archived files:** moving a tracked file into `_attic/` via `git mv` keeps it tracked (gitignore does not untrack existing files). This is intentional — history is preserved; only *newly created* archive content is ignored going forward.
