"""Assemble the 3-layer evidence for a flag (Kobo + do-file + data)."""
import re
from dataclasses import dataclass
from issue_model import Evidence

@dataclass
class Context:
    kobo: dict            # kobo_skip_logic.json
    do_modules: dict      # do_modules.json
    var_universe: set     # lowercased column names present across the pooled masters

def _kobo_var(mod, var, kobo):
    for v in (kobo.get(mod, {}) or {}).get("variables", []):
        if v["name"].lower().rstrip("_") == var.lower().rstrip("_"):
            return v
    return None

def _refs(expr):
    return [m.lower() for m in re.findall(r"\$\{([A-Za-z0-9_]+)\}", expr or "")]

def _check_gate_refs(flag):
    """Gate variables our QC check declares, parsed from the rule antecedent (before 'but')."""
    ant = re.split(r"\bbut\b", flag.label or "", maxsplit=1)[0]
    own = flag.variable.lower().rstrip("_")
    refs = set()
    for tok in re.findall(r"\b([A-Za-z]{1,6}\d[A-Za-z0-9_]*)\b", ant):
        t = tok.lower()
        if re.fullmatch(r"r\d+", t):          # round token e.g. R4
            continue
        if t.rstrip("_") == own:              # the variable being checked itself
            continue
        refs.add(t)
    return sorted(refs)

def assemble_evidence(flag, ctx: Context) -> Evidence:
    ev = Evidence()
    kv = _kobo_var(flag.module, flag.variable, ctx.kobo)
    rel_by_round, refs = {}, set()
    if kv:
        for r, rule in (kv.get("rules_by_round") or {}).items():
            rel = (rule or {}).get("relevant") if rule else None
            rel_by_round[r] = rel
            for ref in _refs(rel):
                if ref != flag.variable.lower().rstrip("_"):
                    refs.add(ref)
    ev.kobo = {
        "in_kobo": kv is not None,
        "relevant_by_round": rel_by_round,
        "gate_refs": sorted(refs),
        "gate_refs_missing": sorted(g for g in refs if g not in ctx.var_universe),
    }
    touched = {}
    for rnd, mods in (ctx.do_modules or {}).items():
        vlist = [x.lower() for x in (mods.get(flag.module, {}) or {}).get("vars", [])]
        touched[rnd] = flag.variable.lower() in vlist
    ev.dofile = {"touched_by_round": touched, "ever_touched": any(touched.values())}
    ev.data = {"counts_by_round": flag.counts_by_round, "total": flag.total, "kind": flag.kind,
               "check_gate_refs": _check_gate_refs(flag)}
    return ev
