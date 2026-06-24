# scripts/tidy_core.py
"""Pure classification logic for the L2PHL tidy tool. No disk or git side effects."""
import re
from collections import defaultdict
from dataclasses import dataclass

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
            # Non-@-pattern file: archive only if it is a version-suffixed variant
            # AND its base sibling is present (don't archive a sole survivor).
            base = _version_suffix_stem(f)
            if base is not None and base in parsed:
                results.append(FileAction(f, "ARCHIVE", "version-suffix", ""))
            else:
                results.append(FileAction(f, "KEEP", "plain", ""))
    return results
