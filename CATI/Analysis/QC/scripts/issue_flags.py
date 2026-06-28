"""Walk dq_data.json into typed Flag objects."""
import re
from issue_model import Flag, slugify

def _variable_of(entry: str) -> str:
    """Pull the follow-up column token from a 'variable' string like 'A1=2 → A10/A11'."""
    v = (entry or "").strip()
    if "→" in v:
        v = v.split("→")[-1].strip()        # the consequent (the gated / follow-up var)
    tok = re.split(r"[ /,]", v)[0] if v else v
    return re.sub(r"[^A-Za-z0-9_]", "", tok).lower()

def extract_flags(dq_data):
    flags, seen = [], set()
    def walk(o):
        if isinstance(o, dict):
            mod = o.get("module")
            cb = o.get("counts_by_round") or o.get("counts")
            if mod and isinstance(cb, dict) and (o.get("rule") or o.get("label")):
                counts = {str(k): v for k, v in cb.items() if isinstance(v, (int, float))}
                if any(counts.values()):
                    rule = o.get("rule") or o.get("label")
                    var = _variable_of(o.get("variable") or o.get("label") or "") or slugify(rule)[:12]
                    kind = ("oor" if o.get("counts") and not o.get("counts_by_round")
                            else "mandatory" if "missing" in rule.lower() or "must be" in rule.lower()
                            else "skip")
                    f = Flag(module=mod, variable=var, rule_id=slugify(rule), kind=kind,
                             counts_by_round=counts, severity=o.get("severity", "medium"),
                             label=rule)
                    if f.key not in seen:
                        seen.add(f.key); flags.append(f)
            for v in o.values(): walk(v)
        elif isinstance(o, list):
            for v in o: walk(v)
    walk(dq_data)
    return flags
