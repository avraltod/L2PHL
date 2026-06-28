"""Shape open firm-owned issue records into firm-report rows."""
from issue_model import OPEN_STATES

LAYER = {"A1": "Questionnaire / Kobo skip logic",
         "A2": "Field / interviewer",
         "B":  "Do-file / pooler processing"}

def _rounds(cb):
    items = sorted(((k, v) for k, v in (cb or {}).items() if v),
                   key=lambda kv: int(kv[0]))
    return ", ".join(f"R{k}:{v}" for k, v in items)

def _total(cb):
    return sum(int(v) for v in (cb or {}).values() if isinstance(v, (int, float)))

def _kobo_gate(ev):
    k = (ev or {}).get("kobo", {}) or {}
    rbr = k.get("relevant_by_round") or {}
    latest = None
    for rd in sorted(rbr, key=lambda x: int(x)):
        if rbr[rd]:
            latest = rbr[rd]
    miss = k.get("gate_refs_missing") or []
    base = latest or "(var not in Kobo)"
    return base + (f"  ·  missing refs: {', '.join(miss)}" if miss else "")

def firm_rows(records):
    rows = []
    for r in records:
        if not r.get("report_to_firm"):
            continue
        if r.get("status") not in OPEN_STATES:
            continue
        ev = r.get("evidence", {}) or {}
        rows.append({
            "module": r.get("module", ""),
            "variable": r.get("variable", ""),
            "issue": r.get("label", ""),
            "rounds": _rounds(r.get("counts_by_round")),
            "total": _total(r.get("counts_by_round")),
            "root_cause": LAYER.get(r.get("verdict"), r.get("verdict") or ""),
            "owner": r.get("owner", ""),
            "kobo_gate": _kobo_gate(ev),
            "dofile": "touched by a round do-file" if (ev.get("dofile") or {}).get("ever_touched") else "not touched",
            "fix": r.get("notes", "") or "",
            "status": r.get("status", ""),
        })
    rows.sort(key=lambda x: (x["owner"] or "", x["module"] or "", x["variable"] or ""))
    return rows
