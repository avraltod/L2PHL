#!/usr/bin/env python3
"""Build (inject) or verify the CATI storyline HTML from sl_stats.json.

  build_story.py --html l2p_cati_story.html --json sl_stats.json --chart-key charts
  build_story.py ... --check          # verify only; non-zero on drift/orphans
"""
import argparse, json, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sl_build.injector import inject, InjectError
from sl_build.loader import unflatten

DEFAULT_HTML = "l2p_cati_story.html"
DEFAULT_JSON = "sl_stats.json"
DEFAULT_CHART_KEY = "charts"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--html", default=DEFAULT_HTML)
    ap.add_argument("--json", default=DEFAULT_JSON)
    ap.add_argument("--chart-key", default=DEFAULT_CHART_KEY)
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    with open(args.json, encoding="utf-8") as f:
        data = unflatten(json.load(f))
    with open(args.html, encoding="utf-8") as f:
        original = f.read()

    try:
        built, report = inject(original, data, chart_key=args.chart_key)
    except InjectError as e:
        print(f"BUILD FAILED: {e}")
        return 1

    # Orphan detection: chart_key sub-keys + used stat keys must cover the JSON.
    used = set(report.used_stat_keys)
    orphans = _orphans(data, used, args.chart_key)

    if args.check:
        # Orphans (computed but not surfaced as prose — often shown only in a
        # chart) are a WARNING, not a failure. Drift is the real error.
        if orphans:
            print(f"CHECK WARNING: {len(orphans)} orphan key(s) not shown in HTML:")
            for o in orphans:
                print("  orphan: " + o)
        if built != original:
            print("CHECK FAILED:")
            print("  drift: HTML does not match sl_stats.json (rebuild needed)")
            return 1
        print("CHECK OK")
        return 0

    with open(args.html, "w", encoding="utf-8") as f:
        f.write(built)
    print(f"built {args.html}: {len(report.used_stat_keys)} stat bindings"
          + (f"; WARNING {len(orphans)} orphan keys" if orphans else ""))
    return 0


def _orphans(data, used_stat_keys, chart_key):
    """Top-level leaf keys (outside chart_key and _meta) not referenced by any span.
    Uses dotted prefixes: a key is covered if any used key starts with its path.
    Assumes one level of nesting under each top-level group (e.g. fies.mod_sev_r1)."""
    out = []
    for top, val in data.items():
        if top in (chart_key, "_meta"):
            continue
        if isinstance(val, dict):
            for sub in val:
                dotted = f"{top}.{sub}"
                if not any(u == dotted or u.startswith(dotted + ".") for u in used_stat_keys):
                    out.append(dotted)
        else:
            if top not in used_stat_keys:
                out.append(top)
    return out


if __name__ == "__main__":
    sys.exit(main())
