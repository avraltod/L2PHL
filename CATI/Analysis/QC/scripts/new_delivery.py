"""Process a firm data delivery: diff the issue state, regen tracker, write changelog."""
import os, json, glob, sys, datetime, subprocess
from delivery_diff import snapshot, diff, format_changelog
import build_firm_report

_HERE = os.path.dirname(__file__)
_CACHE = os.path.join(_HERE, "..", "cache")
_OUTPUT = os.path.join(_HERE, "..", "output")
_SNAPS = os.path.join(_CACHE, "issue_snapshots")

def _latest_snapshot():
    files = sorted(glob.glob(os.path.join(_SNAPS, "*.json")))
    if not files:
        return {}, None
    return json.load(open(files[-1])), os.path.basename(files[-1])[:8]

def run(rebuild=False, today=None):
    today = today or datetime.date.today().strftime("%Y%m%d")
    if rebuild:
        subprocess.run([sys.executable, os.path.join(_HERE, "..", "update_pipeline.py"), "--all"], check=False)
    prev, prev_date = _latest_snapshot()
    issues = json.load(open(os.path.join(_CACHE, "issues.json")))
    d = diff(prev, issues)
    os.makedirs(_SNAPS, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")   # microseconds avoid same-second collision
    json.dump(snapshot(issues), open(os.path.join(_SNAPS, f"{stamp}.json"), "w"), indent=2)
    build_firm_report.main()
    md = format_changelog(d, today, prev_date)
    os.makedirs(_OUTPUT, exist_ok=True)
    path = os.path.join(_OUTPUT, f"L2PHL_CATI_Delivery_Changelog_{today}.md")
    open(path, "w").write(md)
    print(f"Delivery {today}: {len(d['resolved'])} resolved · {len(d['new'])} new · "
          f"{len(d['regressed'])} regressed · {len(d['persisting'])} still open")
    print(f"  changelog -> {os.path.basename(path)}")
    return d

def main():
    run(rebuild="--rebuild" in sys.argv)

if __name__ == "__main__":
    main()
