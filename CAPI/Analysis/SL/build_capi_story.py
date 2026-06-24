#!/usr/bin/env python3
"""Build (inject) or verify the CAPI baseline storyline HTML from the
storyline_results_stata.md ID|Value export. Prose-only (charts untouched).

  build_capi_story.py --html l2phl_baseline_story.html --md storyline_results_stata.md
  build_capi_story.py ... --check          # verify only; non-zero on drift
"""
import argparse, os, sys

_HERE = os.path.dirname(os.path.abspath(__file__))                  # CAPI/Analysis/SL
_REPO = os.path.dirname(os.path.dirname(os.path.dirname(_HERE)))    # repo root
sys.path.insert(0, os.path.join(_REPO, "scripts"))
from sl_build.injector import inject, InjectError
from sl_build.md_parser import parse_md

DEFAULT_HTML = os.path.join(_HERE, "html", "l2phl_baseline_story.html")
DEFAULT_MD = os.path.join(_HERE, "results", "storyline_results_stata.md")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--html", default=DEFAULT_HTML)
    ap.add_argument("--md", default=DEFAULT_MD)
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    with open(args.md, encoding="utf-8") as f:
        data = parse_md(f.read())
    with open(args.html, encoding="utf-8") as f:
        original = f.read()

    try:
        built, report = inject(original, data, chart_key=None)
    except InjectError as e:
        print(f"BUILD FAILED: {e}")
        return 1

    unused = len(set(data) - report.used_stat_keys)

    if args.check:
        if unused:
            print(f"CHECK INFO: {unused} md IDs not shown in prose (the .md is a superset)")
        if built != original:
            print("CHECK FAILED:\n  drift: HTML does not match storyline_results_stata.md (rebuild needed)")
            return 1
        print("CHECK OK")
        return 0

    with open(args.html, "w", encoding="utf-8") as f:
        f.write(built)
    print(f"built {os.path.basename(args.html)}: {len(report.used_stat_keys)} bindings; {unused} md IDs unused")
    return 0


if __name__ == "__main__":
    sys.exit(main())
