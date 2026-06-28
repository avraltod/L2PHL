"""Ground storyline stat claims in the QC issue state (per module / round)."""
import re
from issue_model import OPEN_STATES

GROUP_TO_MODULE = {
    "sample": "M01", "fies": "M08", "shocks": "M03", "finance": "M06",
    "health": "M07", "employment": "M04", "views": "M09",
}
FIRM_VERDICTS = {"A1", "A2", "B"}

def _round_of(subkey):
    """'emp_status_r5' -> '5'; 'bank_acc_f17' -> None."""
    m = re.search(r"_r(\d+)", subkey or "")
    return m.group(1) if m else None

def ground(stat_keys, issue_summary, issues=None):
    """stat_keys: iterable of 'group.subkey'. -> one grounding row per key."""
    issues = issues or []
    by_mod_round = {}            # (module, round) -> [open firm issue keys]
    by_mod = {}                  # module -> [open firm issue keys] (any round)
    for r in issues:
        if r.get("verdict") in FIRM_VERDICTS and r.get("status") in OPEN_STATES:
            for rd, n in (r.get("counts_by_round") or {}).items():
                if n:
                    by_mod_round.setdefault((r["module"], rd), []).append(r["key"])
                    by_mod.setdefault(r["module"], []).append(r["key"])
    rows = []
    for key in stat_keys:
        group, _, sub = key.partition(".")
        mod = GROUP_TO_MODULE.get(group)
        rd = _round_of(sub)
        if not mod:
            rows.append({"key": key, "module": None, "round": rd,
                         "qc_status": "unmapped", "open_firm_issues": [], "grounded": True})
            continue
        summ = issue_summary.get(mod, {})
        if rd:
            status = (summ.get("strip") or {}).get(rd, "green")
            firm = by_mod_round.get((mod, rd), [])
        else:
            status = summ.get("headline", "green")
            firm = by_mod.get(mod, [])
        firm = sorted(set(firm))
        rows.append({"key": key, "module": mod, "round": rd, "qc_status": status,
                     "open_firm_issues": firm, "grounded": not firm})
    return rows
