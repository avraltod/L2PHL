"""Issue-intelligence build stage: dq_data + kobo + do_modules + masters -> issues.json"""
import os, json, glob
import pandas as pd
from issue_model import Issue
from issue_flags import extract_flags
from issue_evidence import Context, assemble_evidence
from issue_classifier import classify
from issue_registry import load_registry, save_registry, merge_decisions, apply_changes_to_registry
from issue_rollup import rollup

_HERE = os.path.dirname(__file__)
_CACHE = os.path.join(_HERE, "..", "cache")
_HF = os.path.join(_HERE, "..", "..", "HF")

def _var_universe():
    cols = set()
    for fp in glob.glob(os.path.join(_HF, "l2phl_M*.dta")):
        try:
            cols |= {c.lower() for c in pd.read_stata(fp, convert_categoricals=False).columns}
        except Exception:
            pass
    return cols

def build(dq_data, kobo, do_modules, var_universe, registry):
    ctx = Context(kobo=kobo, do_modules=do_modules, var_universe=var_universe)
    issues = []
    for f in extract_flags(dq_data):
        ev = assemble_evidence(f, ctx)
        verdict, conf, rule = classify(f, ev)
        issues.append(Issue(key=f.key, flag=f, evidence=ev,
                            proposed_verdict=verdict, confidence=conf, rule_fired=rule))
    issues, changes = merge_decisions(issues, registry)
    records = []
    for it in issues:
        records.append({
            "key": it.key, "module": it.flag.module, "variable": it.flag.variable,
            "rule_id": it.flag.rule_id, "label": it.flag.label, "kind": it.flag.kind,
            "counts_by_round": it.flag.counts_by_round,
            "proposed_verdict": it.proposed_verdict, "confidence": it.confidence,
            "rule_fired": it.rule_fired, "verdict": it.effective_verdict, "owner": it.owner,
            "status": it.status, "report_to_firm": it.report_to_firm,
            "rounds": it.rounds, "notes": it.registry_notes,
            "evidence": {"data": it.evidence.data, "kobo": it.evidence.kobo, "dofile": it.evidence.dofile},
            # needs human review: an unadjudicated actionable issue, or genuinely uncertain.
            # Confident structural D is the suppression category, not a review item.
            "review": (it.effective_verdict in ("A1", "A2", "B", "C") and it.status == "new")
                      or it.confidence == "low" or it.effective_verdict == "REVIEW",
        })
    return {"issues": records, "changes": changes}

def main():
    dq = json.load(open(os.path.join(_CACHE, "dq_data.json")))
    kobo_path = os.path.join(_CACHE, "kobo_skip_logic.json")
    kobo = json.load(open(kobo_path)) if os.path.exists(kobo_path) else {}   # cold-cache: degrade gracefully
    do_path = os.path.join(_CACHE, "do_modules.json")
    do_modules = json.load(open(do_path)) if os.path.exists(do_path) else {}
    reg = load_registry()
    out = build(dq, kobo, do_modules, _var_universe(), reg)
    json.dump(out["issues"], open(os.path.join(_CACHE, "issues.json"), "w"), indent=2)
    summ = rollup(out["issues"])
    json.dump(summ, open(os.path.join(_CACHE, "issue_summary.json"), "w"), indent=2)
    if out["changes"]:
        save_registry(apply_changes_to_registry(reg, out["changes"]))
    n_review = sum(1 for r in out["issues"] if r["review"])
    print(f"issues.json: {len(out['issues'])} issues, {n_review} in review queue, {len(out['changes'])} auto-transitions")

if __name__ == "__main__":
    main()
