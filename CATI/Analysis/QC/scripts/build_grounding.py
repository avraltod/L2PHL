"""Generate the storyline data-quality grounding report (and --check gate)."""
import os, json, sys, datetime
from grounding import ground

_HERE = os.path.dirname(__file__)            # CATI/Analysis/QC/scripts
_QC = os.path.dirname(_HERE)
_CACHE = os.path.join(_QC, "cache")
_OUTPUT = os.path.join(_QC, "output")
_SL_STATS = os.path.join(_QC, "..", "SL", "sl_stats.json")

def _stat_keys(sl_stats):
    keys = []
    for group, val in sl_stats.items():
        if group in ("_meta", "charts") or not isinstance(val, dict):
            continue
        for sub in val:
            keys.append(f"{group}.{sub}")
    return keys

def build_report(rows, today):
    caveat = [r for r in rows if r.get("module") and not r.get("grounded")]
    unmapped = sorted({r["key"].split(".")[0] for r in rows if r["qc_status"] == "unmapped"})
    out = ["# L2PHL CATI — Storyline Data-Quality Grounding", "",
           f"**{today}** · {len(rows)} claims · {len(caveat)} resting on open firm issues", ""]
    if caveat:
        out.append("## ⚠ Claims to caveat (rest on an open firm issue)")
        for r in sorted(caveat, key=lambda x: x["key"]):
            rd = f" R{r['round']}" if r["round"] else ""
            out.append(f"- `{r['key']}` → {r['module']}{rd} ({r['qc_status']}): {', '.join(r['open_firm_issues'])}")
        out.append("")
    else:
        out.append("_No claims rest on open firm issues — the storyline is grounded._\n")
    if unmapped:
        out.append(f"## Unmapped storyline groups ({len(unmapped)})")
        out.append(", ".join(unmapped) + " — add to GROUP_TO_MODULE in grounding.py\n")
    return "\n".join(out)

def run(check=False):
    today = datetime.date.today().strftime("%Y%m%d")
    sl = json.load(open(_SL_STATS))
    isum = json.load(open(os.path.join(_CACHE, "issue_summary.json")))
    issues = json.load(open(os.path.join(_CACHE, "issues.json")))
    rows = ground(_stat_keys(sl), isum, issues)
    caveat = [r for r in rows if r.get("module") and not r.get("grounded")]
    if check:
        print(f"Storyline grounding: {len(caveat)} claim(s) rest on open firm issues")
        for r in caveat:
            print(f"  CAVEAT {r['key']} -> {r['module']} ({', '.join(r['open_firm_issues'])})")
        return 1 if caveat else 0
    md = build_report(rows, today)
    os.makedirs(_OUTPUT, exist_ok=True)
    path = os.path.join(_OUTPUT, f"L2PHL_CATI_Storyline_Grounding_{today}.md")
    open(path, "w").write(md)
    print(f"Storyline grounding: {len(rows)} claims, {len(caveat)} to caveat -> {os.path.basename(path)}")
    return 0

def main():
    sys.exit(run(check="--check" in sys.argv))

if __name__ == "__main__":
    main()
