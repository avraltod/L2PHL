# Delivery Changelog — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Per-delivery changelog (resolved / new / regressed issues since the last delivery) + firm-tracker regen, via `new_delivery.py`.

**Architecture:** A pure `delivery_diff.py` (snapshot + set-logic diff + changelog formatter, TDD) + a `new_delivery.py` orchestrator (snapshot history → optional rebuild → diff → save snapshot → regen tracker → write changelog) + a `qc_issue.py delivery` hook.

**Tech Stack:** Python 3.12, pytest. All under `CATI/Analysis/QC/`. `cache/` is gitignored (snapshots auto-ignore).

---

## File structure

| File | Change |
|------|--------|
| `scripts/delivery_diff.py` | NEW — `snapshot`, `diff`, `format_changelog` |
| `tests/test_delivery_diff.py` | NEW |
| `scripts/new_delivery.py` | NEW — `run(rebuild, today)` + `main()` |
| `scripts/qc_issue.py` | MODIFY — add `delivery [--rebuild]` subcommand |

---

## Task 1: Diff engine (`delivery_diff.py`)

**Files:** Create `scripts/delivery_diff.py`, `tests/test_delivery_diff.py`.

- [ ] **Step 1: Write the failing test** — `tests/test_delivery_diff.py`:
```python
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))
from delivery_diff import snapshot, diff, format_changelog

def snap_entry(status="acknowledged", verdict="A2", total=5, open=True):
    return {"status": status, "verdict": verdict, "total": total, "open": open}

def rec(key, status="acknowledged", verdict="A2", **kw):
    base = {"key": key, "status": status, "verdict": verdict, "module": key.split('/')[0],
            "owner": "firm-field", "label": "lbl", "counts_by_round": {"8": 5}}
    base.update(kw); return base

def test_snapshot_shape():
    s = snapshot([rec("M04/a18/r", counts_by_round={"7": 3, "8": 5})])
    assert s["M04/a18/r"] == {"status": "acknowledged", "verdict": "A2", "total": 8, "open": True}

def test_diff_categories():
    prev = {
        "M04/a18/r": snap_entry(open=True),                       # still open -> persisting
        "M05/ia3/r": snap_entry(open=True),                       # gone now  -> resolved
        "M01/d5/r":  snap_entry(status="resolved", open=False),   # was closed, now open -> regressed
    }
    curr = [rec("M04/a18/r"), rec("M01/d5/r"), rec("M07/h4/r")]   # h4 = new
    d = diff(prev, curr)
    assert [x["key"] for x in d["resolved"]] == ["M05/ia3/r"]
    assert [r["key"] for r in d["new"]] == ["M07/h4/r"]
    assert [r["key"] for r in d["regressed"]] == ["M01/d5/r"]
    assert [r["key"] for r in d["persisting"]] == ["M04/a18/r"]
    assert d["resolved"][0]["now"] == "gone (flag cleared)"      # ia3 absent from curr

def test_diff_baseline_empty_prev():
    d = diff({}, [rec("M04/a18/r")])
    assert [r["key"] for r in d["new"]] == ["M04/a18/r"]          # everything new on baseline
    assert d["resolved"] == [] and d["regressed"] == []

def test_format_changelog_smoke():
    d = diff({}, [rec("M04/a18/r")])
    md = format_changelog(d, "20260628", None)
    assert "Delivery 20260628" in md and "vs prior baseline" in md
    assert "1 new" in md and "## Resolved" in md and "## Still open" in md
```

- [ ] **Step 2: Run, expect FAIL.** `cd CATI/Analysis/QC && python3 -m pytest tests/test_delivery_diff.py -q` → ModuleNotFoundError.

- [ ] **Step 3: Implement** `scripts/delivery_diff.py`:
```python
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
```

- [ ] **Step 4: Run, expect PASS (4 passed).** `cd CATI/Analysis/QC && python3 -m pytest tests/test_delivery_diff.py -q`

- [ ] **Step 5: Commit.**
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git add CATI/Analysis/QC/scripts/delivery_diff.py CATI/Analysis/QC/tests/test_delivery_diff.py
git commit -m "feat(qc): delivery diff engine (snapshot + changelog)"
```

---

## Task 2: Orchestrator (`new_delivery.py`)

**Files:** Create `scripts/new_delivery.py`.

- [ ] **Step 1: Implement** `scripts/new_delivery.py`:
```python
"""Process a firm data delivery: diff the issue state, regen tracker, write changelog."""
import os, json, glob, sys, datetime, subprocess
from delivery_diff import snapshot, diff, format_changelog
import build_firm_report

_HERE = os.path.dirname(__file__)
_CACHE = os.path.join(_HERE, "..", "cache")
_OUTPUT = os.path.join(_HERE, "..", "output")
_SNAPS = os.path.join(_CACHE, "issue_snapshots")

def _latest_snapshot():
    files = sorted(glob.glob(os.path.join(_SNAPS, "*.json")))
    if not files:
        return {}, None
    return json.load(open(files[-1])), os.path.basename(files[-1])[:8]

def run(rebuild=False, today=None):
    today = today or datetime.date.today().strftime("%Y%m%d")
    if rebuild:
        subprocess.run([sys.executable, os.path.join(_HERE, "..", "update_pipeline.py"), "--all"], check=False)
    prev, prev_date = _latest_snapshot()
    issues = json.load(open(os.path.join(_CACHE, "issues.json")))
    d = diff(prev, issues)
    os.makedirs(_SNAPS, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    json.dump(snapshot(issues), open(os.path.join(_SNAPS, f"{stamp}.json"), "w"), indent=2)
    build_firm_report.main()
    md = format_changelog(d, today, prev_date)
    os.makedirs(_OUTPUT, exist_ok=True)
    path = os.path.join(_OUTPUT, f"L2PHL_CATI_Delivery_Changelog_{today}.md")
    open(path, "w").write(md)
    print(f"Delivery {today}: {len(d['resolved'])} resolved · {len(d['new'])} new · "
          f"{len(d['regressed'])} regressed · {len(d['persisting'])} still open")
    print(f"  changelog -> {os.path.basename(path)}")
    return d

def main():
    run(rebuild="--rebuild" in sys.argv)

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Smoke-test the snapshot/diff cycle** (no `--rebuild`, against the real cache). Run it TWICE; the second run must show no change because nothing changed between them:
```bash
cd CATI/Analysis/QC
rm -rf cache/issue_snapshots                      # clean slate for the demo
python3 scripts/new_delivery.py                   # baseline: everything "new"
echo "--- second run (no data change) ---"
python3 scripts/new_delivery.py                   # should be 0 resolved / 0 new / 0 regressed
ls cache/issue_snapshots/                          # 2 snapshot files
head -4 output/L2PHL_CATI_Delivery_Changelog_*.md
```
Expected: first run prints `N new` (N = current issue count, e.g. 18) with 0 resolved/regressed; second run prints `0 resolved · 0 new · 0 regressed · <N> still open`. Two snapshot files exist; the changelog md exists.

- [ ] **Step 3: Commit.**
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git add CATI/Analysis/QC/scripts/new_delivery.py
git commit -m "feat(qc): new_delivery orchestrator (diff + snapshot + tracker + changelog)"
```

---

## Task 3: CLI hook (`qc_issue.py delivery`)

**Files:** Modify `scripts/qc_issue.py`.

- [ ] **Step 1: Add the subcommand.** In `main()` where subparsers are declared (after `sub.add_parser("firm-report")`), add:
```python
    dp = sub.add_parser("delivery"); dp.add_argument("--rebuild", action="store_true")
```
and in the dispatch chain (after the `firm-report` branch), add:
```python
    elif a.cmd == "delivery":
        import new_delivery
        new_delivery.run(rebuild=a.rebuild)
```

- [ ] **Step 2: Verify existing CLI tests still pass.** `cd CATI/Analysis/QC && python3 -m pytest tests/test_qc_issue.py -q` → expect 2 passed.

- [ ] **Step 3: Smoke-test the CLI.** `cd CATI/Analysis/QC && python3 scripts/qc_issue.py delivery`
Expected: prints `Delivery <date>: … resolved · … new · …` with no error.

- [ ] **Step 4: Commit.**
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git add CATI/Analysis/QC/scripts/qc_issue.py
git commit -m "feat(qc): qc-issue delivery subcommand"
```

---

## Self-review

**Spec coverage:** snapshot shape (T1) ✓; four diff categories via set logic (T1) ✓; baseline empty-prev (T1) ✓; changelog markdown + console (T1 format + T2 print) ✓; snapshot history in `cache/issue_snapshots/` gitignored (T2) ✓; optional `--rebuild` runs update_pipeline (T2) ✓; firm-tracker regen folded in (T2) ✓; dated changelog in output/ (T2) ✓; `qc_issue.py delivery` hook (T3) ✓; snapshots only on delivery runs (T2 — only new_delivery writes them) ✓.

**Placeholder scan:** none — full code in every step.

**Type consistency:** `snapshot` emits `{key: {status,verdict,total,open}}`; `diff` reads `prev[k]["open"]`/`["verdict"]`/`["status"]` and current records' `key/status/verdict/module/owner/label`; `format_changelog` reads `resolved` dicts (`key/verdict/now`) and record dicts (`key/verdict/owner/label/module`) — all consistent with `build_issues.py` record fields. `new_delivery.run` returns the same `d` dict shape the tests assert.

**Edge note:** `diff` tolerates `prev=None`/`{}` (baseline). `_latest_snapshot` returns `({}, None)` when no history. `total` recompute in `snapshot` mirrors the firm-report `_total` convention.
