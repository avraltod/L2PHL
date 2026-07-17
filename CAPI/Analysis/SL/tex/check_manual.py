#!/usr/bin/env python3
"""Verify the L2PHL Operational Manual: every repo path cited in the section
.tex files exists, and Annex B mentions the key QC mechanisms."""
import re, sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[4]   # .../L2PHL
MANUAL = Path(__file__).resolve().parent / "manual"

# 1. Collect \rd{...} tokens that look like repo paths (contain "/")
paths = set()
for tex in sorted(MANUAL.glob("*.tex")):
    for m in re.findall(r'\\rd\{([^}]+)\}', tex.read_text()):
        if "/" in m and not m.startswith("http"):
            paths.add(m.strip())

missing = []
for p in sorted(paths):
    clean = p.rstrip(".,;")
    if "*" in clean:
        if not list(REPO.glob(clean)):
            missing.append(clean)
    elif not (REPO / clean).exists():
        missing.append(clean)

# 2. Annex B must mention the key mechanisms (normalize LaTeX escaping first)
annex_b = (MANUAL / "12_annex_b.tex").read_text()
annex_norm = annex_b.replace("\\_", "_").replace("{}", "").lower()
required = ["target", "update_pipeline", "parse_kobo", "cross-checker", "build_dq"]
missing_terms = [t for t in required if t not in annex_norm]

ok = True
if missing:
    ok = False
    print("MISSING PATHS (%d):" % len(missing))
    for p in missing:
        print("  ", p)
if missing_terms:
    ok = False
    print("ANNEX B missing terms:", missing_terms)
print("OK" if ok else "FAIL")
sys.exit(0 if ok else 1)
