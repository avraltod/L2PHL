"""Load/merge/save the durable issue registry + lifecycle transitions."""
import os, yaml
from issue_model import OWNER, OPEN_STATES

_REG = os.path.join(os.path.dirname(__file__), "..", "issue_registry.yaml")

def load_registry(path=_REG):
    if not os.path.exists(path):
        return {}
    with open(path) as f:
        return yaml.safe_load(f) or {}

def save_registry(reg, path=_REG):
    with open(path, "w") as f:
        yaml.safe_dump(reg, f, sort_keys=True, default_flow_style=False, allow_unicode=True)

def is_open(issue):
    return issue.status in OPEN_STATES

def merge_decisions(issues, reg):
    """Apply registry decisions + auto-verify/reopen. Returns (issues, status_changes)."""
    changes = []
    for it in issues:
        e = reg.get(it.key, {})
        it.verdict = e.get("verdict") or it.proposed_verdict
        it.owner = OWNER.get(it.verdict, "unassigned")
        it.report_to_firm = bool(e.get("report_to_firm", it.verdict in ("A1", "A2", "B")))
        it.rounds = e.get("rounds", {}) or {}
        it.registry_notes = e.get("notes", "")
        status = e.get("status", "new")
        total = it.flag.total
        if status == "fix-pending" and total == 0:
            changes.append((it.key, status, "resolved")); status = "resolved"
        elif status == "resolved" and total > 0:
            changes.append((it.key, status, "reopened")); status = "reopened"
        it.status = status
    return issues, changes

def apply_changes_to_registry(reg, changes):
    """Persist auto-transitions back into the registry dict (caller saves)."""
    for key, _old, new in changes:
        reg.setdefault(key, {})["status"] = new
    return reg
