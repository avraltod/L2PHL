"""Roll up issue records into per-module per-round dashboard status.

The per-round strip is coloured by OPEN issues only, so wontfix/accepted issues
stop colouring past rounds. Status precedence per (module, round):
  red    if any OPEN issue with a firm verdict (A1/A2/B) has a count there
  yellow if any OPEN issue (any verdict) has a count there
  closed if only CLOSED issues have a count there
  green  if no issue has a count there
"""
from collections import Counter
from issue_model import OPEN_STATES   # single source of truth for lifecycle states

FIRM_VERDICTS = {"A1", "A2", "B"}


def rollup(records, rounds=range(1, 10)):
    out = {}
    by_mod = {}
    for r in records:
        by_mod.setdefault(r["module"], []).append(r)
    for mod, recs in by_mod.items():
        strip = {}
        for rd in rounds:
            k = str(rd)
            here = [r for r in recs if r.get("counts_by_round", {}).get(k)]
            open_here = [r for r in here if r.get("status") in OPEN_STATES]
            if any(r.get("verdict") in FIRM_VERDICTS for r in open_here):
                strip[k] = "red"
            elif open_here:
                strip[k] = "yellow"
            elif here:
                strip[k] = "closed"
            else:
                strip[k] = "green"
        present = [str(rd) for rd in rounds
                   if any(r.get("counts_by_round", {}).get(str(rd)) for r in recs)]
        headline = strip[present[-1]] if present else "green"
        if headline == "closed":
            headline = "green"
        open_issues = [r for r in recs if r.get("status") in OPEN_STATES]
        out[mod] = {
            "strip": strip,
            "headline": headline,
            "open": len(open_issues),
            "closed": len(recs) - len(open_issues),
            "by_owner": dict(Counter(r.get("owner") for r in open_issues if r.get("owner"))),
        }
    return out
