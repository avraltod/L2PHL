"""Ground storyline stat claims in the QC issue state (per module / round / variable)."""
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

def _var_of(subkey):
    """Underlying Kobo variable embedded in a stat subkey, e.g. 'no_contract_a16eq2'
    -> 'a16'; None for derived/aggregate keys ('hh_r1', 'mod_sev_r5')."""
    s = re.sub(r"eq\d+", "", subkey or "")               # drop eq<value> conditions
    toks = [t for t in re.findall(r"[a-z]+\d+", s) if not re.fullmatch(r"r\d+", t)]
    return toks[-1] if toks else None

def _base(v):
    return re.sub(r"_\d+$", "", (v or "").lower())

def ground(stat_keys, issue_summary, issues=None):
    """stat_keys: iterable of 'group.subkey'. -> one grounding row per key.

    A claim is a caveat iff an OPEN FIRM issue (A1/A2/B) touches its module AND round
    AND — when the claim embeds an underlying variable — that variable. Claims with no
    embedded variable fall back to module/round-level (conservative)."""
    firm_issues = [r for r in (issues or [])
                   if r.get("verdict") in FIRM_VERDICTS and r.get("status") in OPEN_STATES]
    rows = []
    for key in stat_keys:
        group, _, sub = key.partition(".")
        mod = GROUP_TO_MODULE.get(group)
        rd = _round_of(sub)
        if not mod:
            rows.append({"key": key, "module": None, "round": rd, "claim_var": None,
                         "qc_status": "unmapped", "open_firm_issues": [], "grounded": True})
            continue
        cvar = _var_of(sub)
        hits = []
        for r in firm_issues:
            if r["module"] != mod:
                continue
            cb = r.get("counts_by_round") or {}
            if rd and not cb.get(rd):
                continue
            if not rd and not any(cb.values()):
                continue
            if cvar and _base(r.get("variable")) != _base(cvar):   # variable-level filter
                continue
            hits.append(r["key"])
        firm = sorted(set(hits))
        summ = issue_summary.get(mod, {})
        status = (summ.get("strip") or {}).get(rd, "green") if rd else summ.get("headline", "green")
        rows.append({"key": key, "module": mod, "round": rd, "claim_var": cvar,
                     "qc_status": status, "open_firm_issues": firm, "grounded": not firm})
    return rows
