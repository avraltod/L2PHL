# Inline Storyline QC Badges — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`).

**Goal:** Reader-facing QC caveat badges in `l2p_cati_story.html`, inserted after caveat `data-stat` spans (drift-safe), idempotent + reversible.

**Architecture:** Pure `storyline_badges.apply_badges(html, caveats)` (TDD) + `build_storyline_badges.py` (grounding → in-place apply) + a `qc_issue.py storyline-badges` hook.

**Tech Stack:** Python 3.12, pytest. `CATI/Analysis/QC/`. Reads `../SL/{sl_stats.json,l2p_cati_story.html}`.

---

## Task 1: Badge engine (`storyline_badges.py`)

**Files:** Create `scripts/storyline_badges.py`, `tests/test_storyline_badges.py`.

- [ ] **Step 1: Write the failing test** — `tests/test_storyline_badges.py`:
```python
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))
from storyline_badges import apply_badges

SPAN = '<span data-stat="employment.no_contract_a16eq2" data-fmt="pct1">71.7%</span>'

def test_marks_caveat_span():
    html = f'<style>body{{}}</style><p>x {SPAN} y</p>'
    out = apply_badges(html, {"employment.no_contract_a16eq2": "rests on M04/a18"})
    assert '</span><sup class="qc-caveat"' in out      # badge right after the span
    assert '.qc-caveat{' in out                         # CSS injected once
    assert 'title="rests on M04/a18"' in out

def test_skips_non_caveat_span():
    html = '<style></style>' + '<span data-stat="fies.mod_sev_r5" data-fmt="pct1">18%</span>'
    out = apply_badges(html, {"employment.x": "tip"})    # fies not a caveat
    assert 'qc-caveat' not in out                        # no badge, no CSS

def test_idempotent():
    html = '<style></style><span data-stat="a.b" data-fmt="x">1</span>'
    once = apply_badges(html, {"a.b": "tip"})
    twice = apply_badges(once, {"a.b": "tip"})
    assert once == twice
    assert once.count('class="qc-caveat"') == 1

def test_clear_removes_badges():
    html = '<style></style><span data-stat="a.b" data-fmt="x">1</span>'
    badged = apply_badges(html, {"a.b": "tip"})
    cleared = apply_badges(badged, {})                   # no caveats
    assert '<sup class="qc-caveat"' not in cleared
```

- [ ] **Step 2: Run, expect FAIL.** `cd CATI/Analysis/QC && python3 -m pytest tests/test_storyline_badges.py -q` (ModuleNotFoundError).

- [ ] **Step 3: Implement** `scripts/storyline_badges.py`:
```python
"""Insert/refresh QC data-quality badges in the storyline HTML (idempotent, drift-safe)."""
import re

_BADGE_RE = re.compile(r'<sup class="qc-caveat"[^>]*>.*?</sup>', re.DOTALL)
_SPAN_RE  = re.compile(r'<span\b[^>]*\bdata-stat="(?P<key>[^"]+)"[^>]*>.*?</span>', re.DOTALL)
_CSS = ('.qc-caveat{color:#c77d00;font-size:.7em;font-weight:700;cursor:help;'
        'margin-left:1px;text-decoration:none}')

def _esc(s):
    return (str(s) if s is not None else "").replace("&", "&amp;").replace('"', "&quot;") \
        .replace("<", "&lt;").replace(">", "&gt;")

def _strip_badges(html):
    return _BADGE_RE.sub("", html)

def apply_badges(html, caveats):
    """caveats: {stat_key: tooltip}. Idempotently (re)place a badge after each
    data-stat span whose key is a caveat. Returns the new html."""
    html = _strip_badges(html)
    added = [0]
    def add(m):
        span = m.group(0)
        tip = caveats.get(m.group("key"))
        if not tip:
            return span
        added[0] += 1
        return span + f'<sup class="qc-caveat" title="{_esc(tip)}">&#9888;</sup>'
    html = _SPAN_RE.sub(add, html)
    if added[0] and "qc-caveat{" not in html:
        html = html.replace("</style>", _CSS + "</style>", 1)
    return html
```

- [ ] **Step 4: Run, expect PASS (4 passed).** `cd CATI/Analysis/QC && python3 -m pytest tests/test_storyline_badges.py -q`

- [ ] **Step 5: Commit.**
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git add CATI/Analysis/QC/scripts/storyline_badges.py CATI/Analysis/QC/tests/test_storyline_badges.py
git commit -m "feat(qc): storyline QC badge engine (idempotent, drift-safe)"
```

---

## Task 2: Apply to the storyline (`build_storyline_badges.py`)

**Files:** Create `scripts/build_storyline_badges.py`.

- [ ] **Step 1: Implement** `scripts/build_storyline_badges.py`:
```python
"""Apply QC grounding badges to the CATI storyline (in place, idempotent)."""
import os, json, sys
from grounding import ground
from build_grounding import _stat_keys
from storyline_badges import apply_badges

_HERE = os.path.dirname(__file__)
_QC = os.path.dirname(_HERE)
_CACHE = os.path.join(_QC, "cache")
_STORY = os.path.join(_QC, "..", "SL", "l2p_cati_story.html")
_SL_STATS = os.path.join(_QC, "..", "SL", "sl_stats.json")

def _caveats():
    sl = json.load(open(_SL_STATS))
    isum = json.load(open(os.path.join(_CACHE, "issue_summary.json")))
    issues = json.load(open(os.path.join(_CACHE, "issues.json")))
    out = {}
    for r in ground(_stat_keys(sl), isum, issues):
        if r.get("module") and not r["grounded"]:
            out[r["key"]] = "Rests on open firm issue(s): " + ", ".join(r["open_firm_issues"])
    return out

def run(clear=False):
    html = open(_STORY, encoding="utf-8").read()
    caveats = {} if clear else _caveats()
    open(_STORY, "w", encoding="utf-8").write(apply_badges(html, caveats))
    print(f"Storyline badges: {'cleared' if clear else str(len(caveats)) + ' caveat key(s) marked'} -> {os.path.basename(_STORY)}")

def main():
    run(clear="--clear" in sys.argv)

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Apply + verify drift-safety.**
```bash
cd CATI/Analysis/QC && python3 scripts/build_issues.py >/dev/null
python3 scripts/build_storyline_badges.py
echo "--- badge count in storyline ---"
grep -c 'class="qc-caveat"' ../SL/l2p_cati_story.html
echo "--- build_story --check still OK (badges are drift-transparent) ---"
cd ../SL && python3 build_story.py --check 2>&1 | tail -1
```
Expected: prints `7 caveat key(s) marked`; badge count > 0 (one per caveated occurrence); `build_story.py --check` → `CHECK OK`.

- [ ] **Step 3: Verify idempotency + clear.**
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL/CATI/Analysis/QC
python3 scripts/build_storyline_badges.py    # re-run
N1=$(grep -c 'class="qc-caveat"' ../SL/l2p_cati_story.html)
python3 scripts/build_storyline_badges.py
N2=$(grep -c 'class="qc-caveat"' ../SL/l2p_cati_story.html)
echo "idempotent: $N1 == $N2"
python3 scripts/build_storyline_badges.py --clear
echo "after --clear: $(grep -c 'class=\"qc-caveat\"' ../SL/l2p_cati_story.html) badges"
python3 scripts/build_storyline_badges.py    # re-apply for the commit
```
Expected: N1 == N2 (idempotent); after `--clear` → 0; re-applied at the end.

- [ ] **Step 4: Commit** (the script AND the badged storyline).
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git add CATI/Analysis/QC/scripts/build_storyline_badges.py CATI/Analysis/SL/l2p_cati_story.html
git commit -m "feat(qc): apply QC grounding badges to CATI storyline"
```

---

## Task 3: CLI hook (`qc_issue.py storyline-badges`)

**Files:** Modify `scripts/qc_issue.py`.

- [ ] **Step 1: Add the subcommand.** In `main()` after `gp = sub.add_parser("grounding"); …`, add:
```python
    bp = sub.add_parser("storyline-badges"); bp.add_argument("--clear", action="store_true")
```
and in the dispatch chain after the `grounding` branch:
```python
    elif a.cmd == "storyline-badges":
        import build_storyline_badges
        build_storyline_badges.run(clear=a.clear)
```

- [ ] **Step 2: Verify existing CLI tests still pass.** `cd CATI/Analysis/QC && python3 -m pytest tests/test_qc_issue.py -q` → 2 passed.

- [ ] **Step 3: Smoke-test the CLI.** `cd CATI/Analysis/QC && python3 scripts/qc_issue.py storyline-badges`
Expected: prints `Storyline badges: 7 caveat key(s) marked -> l2p_cati_story.html`.

- [ ] **Step 4: Commit.**
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git add CATI/Analysis/QC/scripts/qc_issue.py CATI/Analysis/SL/l2p_cati_story.html
git commit -m "feat(qc): qc-issue storyline-badges subcommand"
```

---

## Self-review

**Spec coverage:** badge after caveat spans (T1) ✓; non-caveat untouched (T1) ✓; idempotent + clear (T1) ✓; CSS once (T1) ✓; grounding-driven caveats (T2) ✓; in-place + drift-safe `build_story --check` OK (T2) ✓; CLI hook (T3) ✓.

**Placeholder scan:** none.

**Consistency:** `apply_badges(html, caveats)` — `caveats` is `{key: tooltip}`; `build_storyline_badges._caveats()` produces exactly that; `_SPAN_RE`/`_BADGE_RE` target `data-stat` spans and `qc-caveat` sups respectively; the badge is inserted OUTSIDE `</span>` so `build_story.py`'s injector (rewrites span inners) and drift-check are unaffected.
