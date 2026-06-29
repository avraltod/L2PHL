"""CLI to set issue lifecycle status. Usage:
   python3 scripts/qc_issue.py set <key> <status> [--notes "..."] [--verdict A2] [--report]
   python3 scripts/qc_issue.py review        # list issues needing adjudication
   python3 scripts/qc_issue.py list [--open]  # list issues
"""
import sys, os, json, argparse
from issue_model import OPEN_STATES, CLOSED_STATES
from issue_registry import load_registry, save_registry, _REG

VALID = OPEN_STATES | CLOSED_STATES

def set_status(key, status, notes=None, verdict=None, report=None, path=_REG):
    if status not in VALID:
        raise ValueError(f"status must be one of {sorted(VALID)}")
    reg = load_registry(path)
    e = reg.setdefault(key, {})
    e["status"] = status
    if notes is not None:   e["notes"] = notes
    if verdict is not None:  e["verdict"] = verdict
    if report is not None:   e["report_to_firm"] = bool(report)
    save_registry(reg, path)
    return e

def _issues():
    p = os.path.join(os.path.dirname(__file__), "..", "cache", "issues.json")
    return json.load(open(p)) if os.path.exists(p) else []

def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("set"); s.add_argument("key"); s.add_argument("status")
    s.add_argument("--notes"); s.add_argument("--verdict"); s.add_argument("--report", action="store_true")
    sub.add_parser("review"); lp = sub.add_parser("list"); lp.add_argument("--open", action="store_true")
    sub.add_parser("firm-report")
    dp = sub.add_parser("delivery"); dp.add_argument("--rebuild", action="store_true")
    gp = sub.add_parser("grounding"); gp.add_argument("--check", action="store_true")
    bp = sub.add_parser("storyline-badges"); bp.add_argument("--clear", action="store_true")
    a = ap.parse_args()
    if a.cmd == "set":
        set_status(a.key, a.status, a.notes, a.verdict, a.report or None)
        print(f"set {a.key} -> {a.status}")
    elif a.cmd == "review":
        for r in _issues():
            if r.get("review"):
                print(f"  [{r['proposed_verdict']}/{r['confidence']}] {r['key']} — {r['label'][:50]}")
    elif a.cmd == "list":
        for r in _issues():
            if a.open and r["status"] not in OPEN_STATES: continue
            print(f"  {r['status']:12} {r['verdict']:3} {r['key']}")
    elif a.cmd == "firm-report":
        import build_firm_report
        build_firm_report.main()
    elif a.cmd == "delivery":
        import new_delivery
        new_delivery.run(rebuild=a.rebuild)
    elif a.cmd == "grounding":
        import build_grounding
        sys.exit(build_grounding.run(check=a.check))
    elif a.cmd == "storyline-badges":
        import build_storyline_badges
        build_storyline_badges.run(clear=a.clear)

if __name__ == "__main__":
    main()
