"""Apply QC grounding badges to the CATI storyline (in place, idempotent)."""
import os, json, sys
from grounding import ground
from build_grounding import _stat_keys
from storyline_badges import apply_badges

_HERE = os.path.dirname(__file__)
_QC = os.path.dirname(_HERE)
_CACHE = os.path.join(_QC, "cache")
_STORY = os.path.join(_QC, "..", "SL", "l2p_cati_story.html")
_SL_STATS = os.path.join(_QC, "..", "SL", "sl_stats.json")

def _caveats():
    sl = json.load(open(_SL_STATS))
    isum = json.load(open(os.path.join(_CACHE, "issue_summary.json")))
    issues = json.load(open(os.path.join(_CACHE, "issues.json")))
    out = {}
    for r in ground(_stat_keys(sl), isum, issues):
        if r.get("module") and not r["grounded"]:
            out[r["key"]] = "Rests on open firm issue(s): " + ", ".join(r["open_firm_issues"])
    return out

def run(clear=False):
    html = open(_STORY, encoding="utf-8").read()
    caveats = {} if clear else _caveats()
    open(_STORY, "w", encoding="utf-8").write(apply_badges(html, caveats))
    print(f"Storyline badges: {'cleared' if clear else str(len(caveats)) + ' caveat key(s) marked'} -> {os.path.basename(_STORY)}")

def main():
    run(clear="--clear" in sys.argv)

if __name__ == "__main__":
    main()
