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
    if len(parts) != 4:
        return None
    head, rnd, author, date = parts
    if not re.fullmatch(r"\d{8}", date):
        return None
    return ParsedName(head=head, round=rnd, author=author, date=date, ext=ext)
