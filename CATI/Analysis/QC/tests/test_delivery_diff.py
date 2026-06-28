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
