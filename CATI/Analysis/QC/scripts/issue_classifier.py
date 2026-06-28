"""Priority-ordered root-cause classifier. First matching rule wins."""
import re

# Structural (D) patterns
PRELOAD_TOKENS = ("fmid", "round_lastint", "fmid_employment")
DERIVED_SUFFIX = ("_income", "_earnings")
DERIVED_EXACT  = {"total_income"}

def _is_preload_missing(ev):
    return any(any(tok in ref for tok in PRELOAD_TOKENS)
               for ref in ev.kobo.get("gate_refs_missing", []))

def rule_D(f, ev):
    v = f.variable.lower()
    if v.endswith("_oth"):                               return ("D", "high", "structural-oth")
    if v in DERIVED_EXACT or v.endswith(DERIVED_SUFFIX): return ("D", "high", "structural-derived")
    if _is_preload_missing(ev):                          return ("D", "high", "structural-preload")
    if not ev.kobo.get("in_kobo", True) and not ev.kobo.get("relevant_by_round"):
        return ("D", "med", "structural-not-in-kobo")
    return None

def _norm_refs(expr_or_list):
    if isinstance(expr_or_list, str):
        return set(m.lower() for m in re.findall(r"\$\{([A-Za-z0-9_]+)\}", expr_or_list))
    return set(x.lower() for x in (expr_or_list or []))

def rule_C(f, ev):
    """Our check's declared gate disagrees with the Kobo relevant for that round."""
    check_refs = set(ev.data.get("check_gate_refs", []) or [])
    if not check_refs:
        return None
    own_base = re.sub(r"_\d+$", "", f.variable.lower())   # d26_2 -> d26: a sibling sub-question is not a gate
    for _, rel in sorted((ev.kobo.get("relevant_by_round") or {}).items()):
        kobo_refs = _norm_refs(rel)
        extra = {r for r in (kobo_refs - check_refs) if re.sub(r"_\d+$", "", r) != own_base}
        if extra:                                    # Kobo gates on vars our check ignores
            return ("C", "high", "check-vs-kobo")
    return None

def rule_B(f, ev):
    """Kobo says asked, but a referenced var is absent from data and no do-file touches it."""
    if ev.kobo.get("in_kobo") and ev.kobo.get("gate_refs_missing") and not ev.dofile.get("ever_touched"):
        return ("B", "med", "gate-ref-absent")
    return None

def rule_A1_A2(f, ev):
    """Constraint violated. Only fires when the var is in Kobo (so the gate is knowable).
       A1 if the gate is missing/empty; A2 if it is present/correct."""
    if f.kind != "skip" or not ev.kobo.get("in_kobo"):
        return None
    rels = ev.kobo.get("relevant_by_round") or {}
    has_gate = any(rels.values())
    if not has_gate:
        return ("A1", "med", "gate-missing")
    return ("A2", "med", "gate-correct-violated")

RULES = [rule_D, rule_C, rule_B, rule_A1_A2]

def classify(flag, evidence):
    for rule in RULES:
        out = rule(flag, evidence)
        if out:
            return out
    return ("REVIEW", "low", "none")
