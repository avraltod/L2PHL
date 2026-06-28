"""Snapshot the issue state and diff two deliveries."""
from collections import Counter
from issue_model import OPEN_STATES

def snapshot(issues):
    """issues.json records -> {key: {status, verdict, total, open}}."""
    snap = {}
    for r in issues:
        k = r.get("key")
        if not k:
            continue
        total = sum(int(v) for v in (r.get("counts_by_round") or {}).values()
                    if isinstance(v, (int, float)))
        snap[k] = {"status": r.get("status"), "verdict": r.get("verdict"),
                   "total": total, "open": r.get("status") in OPEN_STATES}
    return snap

def diff(prev, issues):
    """prev snapshot dict + current issues.json records -> categorized issue lists."""
    prev = prev or {}
    curr = {r["key"]: r for r in issues if r.get("key")}
    curr_open = {k for k, r in curr.items() if r.get("status") in OPEN_STATES}
    prev_keys = set(prev)
    prev_open = {k for k, v in prev.items() if v.get("open")}

    def resolved_info(k):
        p = prev[k]
        now = curr[k].get("status") if k in curr else "gone (flag cleared)"
        return {"key": k, "verdict": p.get("verdict"), "prev_status": p.get("status"), "now": now}

    def recs(keys):
        return sorted((curr[k] for k in keys if k in curr), key=lambda r: r["key"])

    return {
        "resolved":   [resolved_info(k) for k in sorted(prev_open - curr_open)],
        "new":        recs(curr_open - prev_keys),
        "regressed":  recs(curr_open & (prev_keys - prev_open)),
        "persisting": recs(curr_open & prev_open),
    }

def format_changelog(d, today, prev_date):
    rs, nw, rg, ps = d["resolved"], d["new"], d["regressed"], d["persisting"]
    out = ["# L2PHL CATI — Delivery Changelog", "",
           f"**Delivery {today}** (vs prior {prev_date or 'baseline'}): "
           f"{len(rs)} resolved · {len(nw)} new · {len(rg)} regressed · {len(ps)} still open", ""]

    def block(title, items, render):
        out.append(f"## {title} ({len(items)})")
        out.extend([render(x) for x in items] or ["_none_"])
        out.append("")

    block("Resolved (firm fixed)", rs, lambda x: f"- `{x['key']}` (was {x['verdict']}) — {x['now']}")
    block("New", nw, lambda r: f"- `{r['key']}` ({r.get('verdict')} · {r.get('owner','')}) — {(r.get('label') or '')[:60]}")
    block("Regressed (reopened)", rg, lambda r: f"- `{r['key']}` ({r.get('verdict')}) — {(r.get('label') or '')[:60]}")
    bymod = Counter(r["module"] for r in ps)
    out.append(f"## Still open ({len(ps)})")
    out.append(", ".join(f"{m}:{n}" for m, n in sorted(bymod.items())) or "_none_")
    out.append("")
    return "\n".join(out)
