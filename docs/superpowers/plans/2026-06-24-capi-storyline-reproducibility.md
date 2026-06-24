# CAPI Baseline Storyline Reproducibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every prose/KPI number in `CAPI/Analysis/SL/html/l2phl_baseline_story.html` derive automatically from the existing `storyline_results_stata.md` export, eliminating the hand-editing of CAPI prose numbers.

**Architecture:** Promote the CATI-built `sl_build/` module to a shared `scripts/sl_build/`, add an `.md`-table parser and word-variant number formats, then bind the CAPI HTML's prose numbers to `data-stat="<ID>"` spans fed by parsing `storyline_results_stata.md` live. Charts are untouched (the injector's chart step becomes optional). A `build_capi_story.py` + orchestrator mirror the CATI tooling.

**Tech Stack:** Python 3.12 stdlib only; `pytest`. Reuses `sl_build/` (formatter/resolver/injector). No new Stata code — the `.md` is the source.

---

## File Structure

- Move: `CATI/Analysis/SL/sl_build/` → `scripts/sl_build/` (shared by both deliverables).
- Create: `conftest.py` (repo root) — puts `scripts/` on `sys.path` for all tests.
- Create: `scripts/sl_build/md_parser.py` — parse the `ID|Label|Value` table → `{ID: value}`.
- Modify: `scripts/sl_build/formatter.py` — add `pct0word`/`pct1word`/`millions1word`.
- Modify: `scripts/sl_build/injector.py` — make `chart_key` optional.
- Modify: `CATI/Analysis/SL/build_story.py` — import `sl_build` from `scripts/`.
- Create: `CAPI/Analysis/SL/build_capi_story.py` — CAPI entry (parse md → inject → verify).
- Create: `scripts/build_capi_story.py` — orchestrator.
- Modify: `CAPI/Analysis/SL/html/l2phl_baseline_story.html` — wrap prose numbers.
- Tests under `CAPI/Analysis/SL/tests/` and the existing `CATI/Analysis/SL/tests/` (regression).

All Python tests run from the repo root: `python3 -m pytest <path> -q`. The root `conftest.py` makes `from sl_build...` resolve everywhere.

---

## Task 1: Promote `sl_build/` to a shared location (regression-guarded)

**Files:**
- Move: `CATI/Analysis/SL/sl_build/` → `scripts/sl_build/`
- Create: `conftest.py`
- Modify: `CATI/Analysis/SL/build_story.py`

- [ ] **Step 1: Move the module**

```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git mv CATI/Analysis/SL/sl_build scripts/sl_build
```

- [ ] **Step 2: Add repo-root `conftest.py`**

```python
# conftest.py  (repo root)
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "scripts"))
```

This makes `from sl_build...` importable in every test under the repo (pytest auto-loads root `conftest.py`).

- [ ] **Step 3: Fix the CATI `build_story.py` import path**

In `CATI/Analysis/SL/build_story.py`, replace:
```python
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
```
with:
```python
_HERE = os.path.dirname(os.path.abspath(__file__))                      # CATI/Analysis/SL
_REPO = os.path.dirname(os.path.dirname(os.path.dirname(_HERE)))         # repo root
sys.path.insert(0, os.path.join(_REPO, "scripts"))
```

- [ ] **Step 4: Run the full CATI suite (regression guard)**

Run: `cd /Users/avraa/iDrive/GitHub/PHL/L2PHL && python3 -m pytest CATI/Analysis/SL/tests/ -q`
Expected: PASS (32 passed, 1 skipped) — exactly as before the move. The CATI tests' own `sys.path.insert(... SL)` is now harmless; the root `conftest.py` resolves `sl_build`.

- [ ] **Step 5: Verify the CATI story still builds**

Run: `cd /Users/avraa/iDrive/GitHub/PHL/L2PHL && python3 scripts/build_cati_story.py --check`
Expected: `CHECK OK` (the orchestrator subprocesses `build_story.py`, which now finds `sl_build` under `scripts/`).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "promote sl_build to shared scripts/sl_build; add root conftest; CATI green"
```

---

## Task 2: Word-variant number formats

**Files:**
- Modify: `scripts/sl_build/formatter.py`
- Test: add to existing `CATI/Analysis/SL/tests/test_formatter.py`

CAPI prose spells units out ("108.7 million", "54 percent"), which `millions1`/`pct0` (→ "108.7M"/"54%") don't match.

- [ ] **Step 1: Write the failing test**

```python
# append to CATI/Analysis/SL/tests/test_formatter.py
def test_pct0word():     assert fmt(54.0, "pct0word") == "54 percent"
def test_pct1word():     assert fmt(40.56, "pct1word") == "40.6 percent"
def test_millions1word(): assert fmt(108667043, "millions1word") == "108.7 million"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/avraa/iDrive/GitHub/PHL/L2PHL && python3 -m pytest CATI/Analysis/SL/tests/test_formatter.py -q`
Expected: FAIL — `ValueError: unknown data-fmt: 'pct0word'`

- [ ] **Step 3: Add the formats**

In `scripts/sl_build/formatter.py`, add these branches before the final `raise`:
```python
    if spec == "pct0word":
        return f"{int(round(float(value)))} percent"
    if spec == "pct1word":
        return f"{float(value):.1f} percent"
    if spec == "millions1word":
        return f"{float(value) / 1_000_000:.1f} million"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/avraa/iDrive/GitHub/PHL/L2PHL && python3 -m pytest CATI/Analysis/SL/tests/test_formatter.py -q`
Expected: PASS (14 passed)

- [ ] **Step 5: Commit**

```bash
git add scripts/sl_build/formatter.py CATI/Analysis/SL/tests/test_formatter.py
git commit -m "add word-variant formats (pct0word/pct1word/millions1word) for spelled-out prose"
```

---

## Task 3: The `.md` table parser

**Files:**
- Create: `scripts/sl_build/md_parser.py`
- Test: `CAPI/Analysis/SL/tests/test_md_parser.py`

- [ ] **Step 1: Write the failing test**

```python
# CAPI/Analysis/SL/tests/test_md_parser.py
from sl_build.md_parser import parse_md

SAMPLE = """# L2Phl Storyline Results
Generated: 1 Apr 2026

| ID | Label | Value |
|:---|:------|------:|

## §1 Roster (M01)

| R01_N | Total household members | 10496 |
| R01_POP | Weighted population | 108667043 |
| R01_UNDER20 | % under 20 | 40.56 |
| R01_MEDIAN_AGE | Median age | 25.0 |
| R07_NOTE | Some text value | n/a |
"""

def test_parses_ids_to_values():
    d = parse_md(SAMPLE)
    assert d["R01_N"] == 10496
    assert d["R01_POP"] == 108667043
    assert d["R01_UNDER20"] == 40.56
    assert d["R01_MEDIAN_AGE"] == 25          # 25.0 collapses to int
    assert d["R07_NOTE"] == "n/a"             # non-numeric stays string

def test_skips_header_separator_headings():
    d = parse_md(SAMPLE)
    assert "ID" not in d
    assert all(not k.startswith(":") for k in d)
    assert "## §1 Roster (M01)" not in d
    assert len(d) == 5

def test_pipe_in_label_keeps_id_and_value():
    # A label containing '|' must NOT drop the row (first cell=ID, last=Value).
    md = "| A03_X | broad (a1|a2) rate | 52.05 |\n"
    assert parse_md(md) == {"A03_X": 52.05}

def test_duplicate_id_raises():
    import pytest
    md = "| R01_POP | a | 1 |\n| R01_POP | b | 2 |\n"
    with pytest.raises(ValueError, match="duplicate"):
        parse_md(md)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/avraa/iDrive/GitHub/PHL/L2PHL && python3 -m pytest CAPI/Analysis/SL/tests/test_md_parser.py -q`
Expected: FAIL — `ModuleNotFoundError: No module named 'sl_build.md_parser'`

- [ ] **Step 3: Write minimal implementation**

```python
# scripts/sl_build/md_parser.py
"""Parse a `| ID | Label | Value |` markdown table into {ID: value}."""


def _num(s):
    try:
        f = float(s.replace(",", ""))
    except ValueError:
        return s
    return int(f) if f.is_integer() else f


def parse_md(text):
    out = {}
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if len(cells) < 3:
            continue                                # not a data row
        # First cell = ID, last = Value. The label (middle) may itself contain a
        # '|' (e.g. "broad (a1|a2) rate"); values are numeric, so first/last is robust.
        key, val = cells[0], cells[-1]
        if key == "ID" or set(key) <= set(":-"):    # header row or |:---| separator
            continue
        if key in out:
            raise ValueError(f"md_parser: duplicate ID {key!r}")
        out[key] = _num(val)
    return out
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/avraa/iDrive/GitHub/PHL/L2PHL && python3 -m pytest CAPI/Analysis/SL/tests/test_md_parser.py -q`
Expected: PASS (4 passed)

- [ ] **Step 5: Commit**

```bash
git add scripts/sl_build/md_parser.py CAPI/Analysis/SL/tests/test_md_parser.py
git commit -m "add storyline_results_stata.md table parser"
```

---

## Task 4: Make injector chart injection optional

**Files:**
- Modify: `scripts/sl_build/injector.py`
- Test: `CATI/Analysis/SL/tests/test_injector.py`

- [ ] **Step 1: Write the failing test**

```python
# append to CATI/Analysis/SL/tests/test_injector.py
def test_inject_no_chart_key_prose_only():
    # No #sl-data block at all; chart_key=None must still bind spans and not error.
    h = 'pop <span data-stat="R01_POP" data-fmt="millions1word">x</span> people'
    out, rep = inject(h, {"R01_POP": 108667043}, chart_key=None)
    assert ">108.7 million<" in out
    assert rep.used_stat_keys == {"R01_POP"}

def test_inject_no_chart_key_still_sweeps_unbound():
    h = 'a <span data-stat="MISSING" data-fmt="int">x</span>'
    import pytest
    with pytest.raises(InjectError):
        inject(h, {}, chart_key=None)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/avraa/iDrive/GitHub/PHL/L2PHL && python3 -m pytest CATI/Analysis/SL/tests/test_injector.py -q`
Expected: FAIL — `inject()` raises `InjectError('missing <script id="sl-data"> block')` (chart step is not yet optional)

- [ ] **Step 3: Make the chart step conditional**

In `scripts/sl_build/injector.py`, change the signature and guard the chart block:
```python
def inject(html, data, chart_key=None):
    report = Report()

    if chart_key is not None:
        if chart_key not in data:
            raise InjectError(f"chart-key not in sl_stats.json: {chart_key}")
        if not _SLDATA.search(html):
            raise InjectError('missing <script id="sl-data"> block')
        block = json.dumps(data[chart_key], ensure_ascii=False).replace("</", "<\\/")
        html = _SLDATA.sub(lambda m: m.group(1) + block + m.group(3), html, count=1)

    matched = [0]
    # ... (the rest of the span-binding + sweep is unchanged) ...
```
(Leave the `_repl` closure and the unbound-span sweep exactly as they are.)

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/avraa/iDrive/GitHub/PHL/L2PHL && python3 -m pytest CATI/Analysis/SL/tests/test_injector.py -q`
Expected: PASS (13 passed — the 11 existing + 2 new)

- [ ] **Step 5: Commit**

```bash
git add scripts/sl_build/injector.py CATI/Analysis/SL/tests/test_injector.py
git commit -m "make injector chart injection optional (chart_key=None for prose-only)"
```

---

## Task 5: `build_capi_story.py` (CAPI entry)

**Files:**
- Create: `CAPI/Analysis/SL/build_capi_story.py`
- Test: `CAPI/Analysis/SL/tests/test_build_capi_story.py`

`--check` fails on drift; orphan md IDs (the `.md` is intentionally a 164-row superset) are reported as a COUNT only, not per-line warnings.

- [ ] **Step 1: Write the failing test**

```python
# CAPI/Analysis/SL/tests/test_build_capi_story.py
import sys, os, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
SL = os.path.dirname(HERE)

def _w(p, s): open(p, "w", encoding="utf-8").write(s)

HTML = 'pop <span data-stat="R01_POP" data-fmt="millions1word">OLD</span> people'
MD = ("| ID | Label | Value |\n|:---|:------|------:|\n"
      "| R01_POP | Weighted population | 108667043 |\n"
      "| R01_EXTRA | unused | 5 |\n")

def _run(args, cwd):
    return subprocess.run([sys.executable, os.path.join(SL, "build_capi_story.py")] + args,
                          capture_output=True, text=True, cwd=cwd)

def test_build_then_check(tmp_path):
    h = os.path.join(tmp_path, "s.html"); m = os.path.join(tmp_path, "s.md")
    _w(h, HTML); _w(m, MD)
    r = _run(["--html", h, "--md", m], str(tmp_path))
    assert r.returncode == 0, r.stderr
    assert ">108.7 million<" in open(h, encoding="utf-8").read()
    r2 = _run(["--html", h, "--md", m, "--check"], str(tmp_path))
    assert r2.returncode == 0, r2.stderr
    assert "CHECK OK" in r2.stdout

def test_check_fails_on_drift(tmp_path):
    h = os.path.join(tmp_path, "s.html"); m = os.path.join(tmp_path, "s.md")
    _w(h, HTML.replace("OLD", "999")); _w(m, MD)
    r = _run(["--html", h, "--md", m, "--check"], str(tmp_path))
    assert r.returncode == 1
    assert "drift" in (r.stdout + r.stderr).lower()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/avraa/iDrive/GitHub/PHL/L2PHL && python3 -m pytest CAPI/Analysis/SL/tests/test_build_capi_story.py -q`
Expected: FAIL — `build_capi_story.py` does not exist

- [ ] **Step 3: Write minimal implementation**

```python
# CAPI/Analysis/SL/build_capi_story.py
#!/usr/bin/env python3
"""Build (inject) or verify the CAPI baseline storyline HTML from the
storyline_results_stata.md ID|Value export. Prose-only (charts untouched).

  build_capi_story.py --html l2phl_baseline_story.html --md storyline_results_stata.md
  build_capi_story.py ... --check          # verify only; non-zero on drift
"""
import argparse, os, sys

_HERE = os.path.dirname(os.path.abspath(__file__))                  # CAPI/Analysis/SL
_REPO = os.path.dirname(os.path.dirname(os.path.dirname(_HERE)))    # repo root
sys.path.insert(0, os.path.join(_REPO, "scripts"))
from sl_build.injector import inject, InjectError
from sl_build.md_parser import parse_md

DEFAULT_HTML = os.path.join(_HERE, "html", "l2phl_baseline_story.html")
DEFAULT_MD = os.path.join(_HERE, "results", "storyline_results_stata.md")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--html", default=DEFAULT_HTML)
    ap.add_argument("--md", default=DEFAULT_MD)
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    with open(args.md, encoding="utf-8") as f:
        data = parse_md(f.read())
    with open(args.html, encoding="utf-8") as f:
        original = f.read()

    try:
        built, report = inject(original, data, chart_key=None)
    except InjectError as e:
        print(f"BUILD FAILED: {e}")
        return 1

    unused = len(set(data) - report.used_stat_keys)

    if args.check:
        if unused:
            print(f"CHECK INFO: {unused} md IDs not shown in prose (the .md is a superset)")
        if built != original:
            print("CHECK FAILED:\n  drift: HTML does not match storyline_results_stata.md (rebuild needed)")
            return 1
        print("CHECK OK")
        return 0

    with open(args.html, "w", encoding="utf-8") as f:
        f.write(built)
    print(f"built {os.path.basename(args.html)}: {len(report.used_stat_keys)} bindings; {unused} md IDs unused")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/avraa/iDrive/GitHub/PHL/L2PHL && python3 -m pytest CAPI/Analysis/SL/tests/test_build_capi_story.py -q`
Expected: PASS (2 passed)

- [ ] **Step 5: Commit**

```bash
git add CAPI/Analysis/SL/build_capi_story.py CAPI/Analysis/SL/tests/test_build_capi_story.py
git commit -m "add build_capi_story: parse storyline_results_stata.md, inject prose, verify"
```

---

## Task 6: Orchestrator `scripts/build_capi_story.py`

**Files:**
- Create: `scripts/build_capi_story.py`
- Test: `scripts/tests/test_build_capi_story_orch.py`

- [ ] **Step 1: Write the failing test**

```python
# scripts/tests/test_build_capi_story_orch.py
import sys, os, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.dirname(HERE)
REPO = os.path.dirname(SCRIPTS)

def test_check_runs(tmp_path):
    # After the HTML refactor (Task 7) the real story is in sync, so --check returns 0.
    r = subprocess.run([sys.executable, os.path.join(SCRIPTS, "build_capi_story.py"), "--check"],
                       capture_output=True, text=True, cwd=REPO)
    assert r.returncode == 0, r.stdout + r.stderr
    assert "CHECK OK" in r.stdout
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/avraa/iDrive/GitHub/PHL/L2PHL && python3 -m pytest scripts/tests/test_build_capi_story_orch.py -q`
Expected: FAIL — `build_capi_story.py` (orchestrator) does not exist (and/or story not yet refactored). This test goes green at the end of Task 7.

- [ ] **Step 3: Write minimal implementation**

```python
# scripts/build_capi_story.py
#!/usr/bin/env python3
"""Orchestrate the CAPI baseline storyline: [run replication.do] -> build -> verify.

  build_capi_story.py            # build + verify from existing storyline_results_stata.md
  build_capi_story.py --stata    # run 11_..._replication.do (batch) first
  build_capi_story.py --check     # verify only
"""
import argparse, os, re, subprocess, sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SL = os.path.join(REPO, "CAPI", "Analysis", "SL")
STATA = "/Applications/Stata/StataMP.app/Contents/MacOS/stata-mp"
REPL = os.path.join(SL, "do", "11_L2PHL_CAPI_R00_replication.do")
ENTRY = os.path.join(SL, "build_capi_story.py")


def run_stata():
    if not os.path.exists(STATA):
        print(f"Stata not found at {STATA}; run 11_..._replication.do in your Stata, then re-run without --stata.")
        return 1
    subprocess.run([STATA, "-b", "do", REPL], cwd=os.path.join(SL, "do"), check=False)
    log = os.path.join(SL, "do", "11_L2PHL_CAPI_R00_replication.log")
    if not os.path.exists(log) or os.path.getsize(log) == 0:
        print("Batch Stata did not run (binary may be unlicensed/headless). "
              "Run CAPI/Analysis/SL/do/11_L2PHL_CAPI_R00_replication.do in your licensed Stata, "
              "then re-run this without --stata.")
        return 1
    text = open(log, encoding="utf-8", errors="replace").read()
    m = re.search(r"\nr\((\d+)\);", text)
    if m:
        print(f"STATA ERROR r({m.group(1)}). Log tail:")
        print("\n".join(text.splitlines()[-20:]))
        return 1
    return 0


def build(check):
    args = [sys.executable, ENTRY]
    if check:
        args.append("--check")
    return subprocess.run(args, cwd=SL).returncode


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--stata", action="store_true")
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    if args.stata and run_stata() != 0:
        return 1
    if args.check:
        return build(check=True)
    if build(check=False) != 0:
        return 1
    return build(check=True)


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: (deferred) Run after Task 7**

The orchestrator test passes once the real HTML is refactored and in sync (Task 7 Step 4). Do not expect green yet.

- [ ] **Step 5: Update `scripts/README.md` and commit**

Add to `scripts/README.md`:
```markdown
## build_capi_story.py — regenerate the CAPI baseline storyline (prose)

```bash
python3 scripts/build_capi_story.py           # rebuild prose from storyline_results_stata.md + verify
python3 scripts/build_capi_story.py --check    # verify only
```
Prose numbers come from `CAPI/Analysis/SL/results/storyline_results_stata.md` (produced by `11_..._replication.do`). Charts are still hand-edited. Batch Stata is unlicensed here — run the replication do-file in your GUI/MCP Stata.
```

```bash
git add scripts/build_capi_story.py scripts/tests/test_build_capi_story_orch.py scripts/README.md
git commit -m "add CAPI storyline orchestrator (replication.do -> build -> verify)"
```

---

## Task 7: Refactor the CAPI HTML prose to bindings

**Files:**
- Modify: `CAPI/Analysis/SL/html/l2phl_baseline_story.html`

Mechanical, verified by `build_capi_story --check`. Charts (`new Chart(...)` literals) are NOT touched.

- [ ] **Step 1: Establish the binding worklist**

Build the canonical data once and list the IDs available:
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
python3 -c "import sys; sys.path.insert(0,'scripts'); from sl_build.md_parser import parse_md; d=parse_md(open('CAPI/Analysis/SL/results/storyline_results_stata.md').read()); print(len(d),'IDs'); [print(k,'=',v) for k,v in sorted(d.items())]"
```
Use this ID→value list to choose the right `data-stat` ID for each prose number.

- [ ] **Step 2: Wrap prose & KPI numbers**

For each hardcoded number in the prose/KPI markup, wrap the numeric token (leave spelled-out units as text, or use a `*word` format). Examples (real lines):
```html
<!-- KPI tile, line ~340 -->
<div class="hkpi-n"><span data-stat="R01_POP" data-fmt="millions1">108.7</span><span>M</span></div>
<!-- line ~341 -->
<div class="hkpi-n"><span data-stat="R01_N_HH" data-fmt="intcomma">2,470</span></div>
<!-- prose, line ~2598 -->
<p>The <span data-stat="R01_N_HH" data-fmt="intcomma">2,470</span> sampled households collectively represent approximately <span data-stat="R01_POP" data-fmt="millions1word">108.7 million</span> Filipinos. Urban areas account for <span data-stat="R01_URBAN" data-fmt="pct0word">54 percent</span> of the weighted population. The median age of the population is <span data-stat="R01_MEDIAN_AGE" data-fmt="int">25</span> years, and <span data-stat="R01_UNDER20" data-fmt="pct1word">40.6 percent</span> are under 20 years old.</p>
```
Rules:
- Pick the ID whose value, formatted by the chosen `data-fmt`, **equals the number originally shown**. Use compact formats (`millions1`, `pct1`) inside KPI tiles, `*word` formats in spelled-out prose.
- The same value in multiple places gets the same ID everywhere.
- **Guardrail:** if no ID+format reproduces the displayed number, do NOT wrap it — record it in a MISMATCHES list (real discrepancy or missing ID) and leave it hardcoded.
- Do NOT wrap chart data, axis labels, round/section numbers, CSS, or non-statistics.
- Work chapter by chapter (hero → roster → education → … → views), running Step 3 after each chapter.

- [ ] **Step 3: Build + verify (after each chapter and at the end)**

```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
python3 CAPI/Analysis/SL/build_capi_story.py
python3 CAPI/Analysis/SL/build_capi_story.py --check
```
Expected at the end: build prints the binding count; `--check` prints `CHECK OK` (drift-free). `CHECK INFO: N md IDs not shown` is expected and fine.

- [ ] **Step 4: Confirm the orchestrator test is green**

Run: `cd /Users/avraa/iDrive/GitHub/PHL/L2PHL && python3 -m pytest scripts/tests/test_build_capi_story_orch.py -q`
Expected: PASS (1 passed).

- [ ] **Step 5: Commit**

```bash
git add CAPI/Analysis/SL/html/l2phl_baseline_story.html
git commit -m "refactor CAPI baseline storyline prose to data-stat bindings from .md export"
```

---

## Task 8: Final gate

**Files:** none.

- [ ] **Step 1: Full Python suite (both deliverables)**

Run: `cd /Users/avraa/iDrive/GitHub/PHL/L2PHL && python3 -m pytest CATI/Analysis/SL/tests/ CAPI/Analysis/SL/tests/ scripts/tests/ -q`
Expected: PASS (all green; the one Stata batch test skips).

- [ ] **Step 2: Both stories verify**

Run:
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
python3 scripts/build_cati_story.py --check     # regression: CATI still OK
python3 scripts/build_capi_story.py --check     # new: CAPI OK
```
Expected: both `CHECK OK`.

- [ ] **Step 3: Visual spot check**

Open `CAPI/Analysis/SL/html/l2phl_baseline_story.html` — confirm headline prose numbers read correctly and all charts still render (charts were untouched).

---

## Self-Review

**Spec coverage:**
- Reuse existing `.md` as source → Task 3 (parser) + Task 5 (`build_capi_story` reads it live).
- Prose-only, charts untouched → Task 4 (optional chart_key) + Task 7 (charts not wrapped).
- Reuse `sl_build/`, promoted to shared → Task 1.
- Injector chart_key optional → Task 4.
- Same verification gate (drift fail, orphans informational) → Task 5 (`--check`).
- Orchestrator with `--stata`/`--check` + unlicensed-batch message → Task 6.
- Word-variant formats for spelled-out prose → Task 2 (spec implied by "format vocabulary"; added because CAPI prose spells units out).
- CATI regression green → Task 1 Step 4-5, Task 8 Step 2.

**Placeholder scan:** none — every code step is complete; Task 7 (mechanical) gives the exact pattern + real example lines + the verifier as the acceptance gate.

**Type consistency:** `parse_md(text) -> dict` defined Task 3, used Task 5. `inject(html, data, chart_key=None)` extended Task 4, called with `chart_key=None` in Task 5. `fmt(value, spec)` extended Task 2, used in Task 7 bindings. `report.used_stat_keys` (set) consumed in Task 5. Orchestrator (Task 6) subprocesses `build_capi_story.py` (Task 5) with the same `--html/--md/--check` flags.

**Note:** Task 6's orchestrator test is intentionally red until Task 7 puts the real story in sync — flagged in Task 6 Step 4 and asserted green in Task 7 Step 4.
