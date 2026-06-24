# CATI Storyline Reproducibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every number in `CATI/Analysis/SL/l2p_cati_story.html` derive automatically from a single `sl_stats.json` that Stata writes directly — eliminating both the hand-typing of the JSON from the Stata log and the hand-editing of numbers into the HTML.

**Architecture:** A reusable pure-Python `sl_build/` module (formatter → resolver → injector) powers a `build_story.py` that injects `sl_stats.json` into the HTML at marked bindings and verifies agreement. The HTML is refactored once so charts read an injected `#sl-data` block and prose numbers sit in `data-stat` spans. A Stata emitter (`_stat_emit.do`) makes the master do-file write `sl_stats.json` as it runs, and an orchestrator (`scripts/build_cati_story.py`) runs Stata → build → verify in one command.

**Tech Stack:** Python 3.12 stdlib only (`json`, `re`, `html.parser`/regex, `argparse`, `subprocess`, `pathlib`); `pytest`; Stata batch (`stata-mp -b`). No third-party deps.

**Two stages with a checkpoint:**
- **Stage 1 (Tasks 1–7)** — `sl_build/`, `build_story.py`, the canonical-JSON contract, and the one-time HTML refactor. Deliverable: the HTML is fully injection-driven and verifiable from `sl_stats.json` (initially the adopted `sl_stats_v2.json`). Closes the HTML-editing pain.
- **Stage 2 (Tasks 8–11)** — the Stata `stat_put` emitter, master-do retrofit, and orchestrator. Deliverable: Stata writes `sl_stats.json`; one command runs the whole chain. Closes the Stata-transcription pain.

---

## File Structure

- `CATI/Analysis/SL/sl_build/__init__.py` — package marker.
- `CATI/Analysis/SL/sl_build/formatter.py` — the `data-fmt` vocabulary (raw value → display string). One responsibility: formatting.
- `CATI/Analysis/SL/sl_build/resolver.py` — dotted-path lookup into the JSON dict. One responsibility: key resolution.
- `CATI/Analysis/SL/sl_build/injector.py` — rewrite `#sl-data` block + `data-stat` spans in an HTML string. One responsibility: HTML mutation.
- `CATI/Analysis/SL/build_story.py` — CATI entry: load JSON + HTML, call injector (build) or compare (verify).
- `CATI/Analysis/SL/docs/sl_stats_schema.md` — the key namespace (the Stata↔HTML contract).
- `CATI/Analysis/SL/sl_stats.json` — canonical artifact (adopted from `sl_stats_v2.json` in Stage 1; Stata-written in Stage 2).
- `CATI/Analysis/SL/_stat_emit.do` — Stata emitter program.
- `CATI/Analysis/SL/l2phl_master_analysis.do` — live master (renamed from `_v2`, retrofitted with `stat_put`).
- `scripts/build_cati_story.py` — orchestrator (tracked top-level `scripts/`).
- Tests: `CATI/Analysis/SL/tests/test_*.py` (Python) and `CATI/Analysis/SL/tests/test_stat_emit.do` (Stata round-trip).

All Python tests assume `cd CATI/Analysis/SL` and run with `python3 -m pytest tests/ -q`. Test files self-insert the `SL/` dir onto `sys.path` (the pattern already used by `scripts/tests/`), so no `__init__.py` is needed in `tests/`.

---

# STAGE 1 — Build foundation + HTML

## Task 1: Formatter vocabulary

**Files:**
- Create: `CATI/Analysis/SL/sl_build/__init__.py` (empty)
- Create: `CATI/Analysis/SL/sl_build/formatter.py`
- Test: `CATI/Analysis/SL/tests/test_formatter.py`

- [ ] **Step 1: Write the failing test**

```python
# CATI/Analysis/SL/tests/test_formatter.py
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import pytest
from sl_build.formatter import fmt

def test_int():           assert fmt(2470, "int") == "2470"
def test_intcomma():      assert fmt(2470, "intcomma") == "2,470"
def test_intcomma_float(): assert fmt(108667043.0, "intcomma") == "108,667,043"
def test_pct0():          assert fmt(41.0, "pct0") == "41%"
def test_pct0_rounds():   assert fmt(40.99, "pct0") == "41%"
def test_pct1():          assert fmt(18.2, "pct1") == "18.2%"
def test_millions1():     assert fmt(108667043, "millions1") == "108.7M"
def test_peso():          assert fmt(19497, "peso") == "₱19,497"
def test_ppt():           assert fmt(22.8, "ppt") == "23"
def test_raw():           assert fmt("Sep–Oct 2025", "raw") == "Sep–Oct 2025"
def test_unknown_fmt_raises():
    with pytest.raises(ValueError, match="unknown data-fmt"):
        fmt(1, "bogus")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd CATI/Analysis/SL && python3 -m pytest tests/test_formatter.py -q`
Expected: FAIL — `ModuleNotFoundError: No module named 'sl_build'`

- [ ] **Step 3: Write minimal implementation**

```python
# CATI/Analysis/SL/sl_build/formatter.py
"""Render a raw stat value as a display string per a data-fmt token."""


def _comma(n):
    return f"{int(round(n)):,}"


def fmt(value, spec):
    if spec == "raw":
        return str(value)
    if spec == "int":
        return str(int(round(float(value))))
    if spec == "intcomma":
        return _comma(float(value))
    if spec == "pct0":
        return f"{int(round(float(value)))}%"
    if spec == "pct1":
        return f"{float(value):.1f}%"
    if spec == "millions1":
        return f"{float(value) / 1_000_000:.1f}M"
    if spec == "peso":
        return f"₱{_comma(float(value))}"
    if spec == "ppt":
        return str(int(round(float(value))))
    raise ValueError(f"unknown data-fmt: {spec!r}")
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd CATI/Analysis/SL && python3 -m pytest tests/test_formatter.py -q`
Expected: PASS (11 passed)

- [ ] **Step 5: Commit**

```bash
git add CATI/Analysis/SL/sl_build/__init__.py CATI/Analysis/SL/sl_build/formatter.py CATI/Analysis/SL/tests/test_formatter.py
git commit -m "add sl_build formatter vocabulary"
```

---

## Task 2: Dotted-path resolver

**Files:**
- Create: `CATI/Analysis/SL/sl_build/resolver.py`
- Test: `CATI/Analysis/SL/tests/test_resolver.py`

- [ ] **Step 1: Write the failing test**

```python
# CATI/Analysis/SL/tests/test_resolver.py
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import pytest
from sl_build.resolver import resolve, MissingKey

DATA = {"fies": {"mod_sev_r1": 41.0, "food_trend": [41.0, 18.2]}, "sample": {"total_hh": 1917}}

def test_resolve_nested_scalar():
    assert resolve(DATA, "fies.mod_sev_r1") == 41.0

def test_resolve_top_object():
    assert resolve(DATA, "sample.total_hh") == 1917

def test_resolve_array():
    assert resolve(DATA, "fies.food_trend") == [41.0, 18.2]

def test_missing_key_raises():
    with pytest.raises(MissingKey, match="fies.nope"):
        resolve(DATA, "fies.nope")

def test_missing_intermediate_raises():
    with pytest.raises(MissingKey, match="ghost.x"):
        resolve(DATA, "ghost.x")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd CATI/Analysis/SL && python3 -m pytest tests/test_resolver.py -q`
Expected: FAIL — `ModuleNotFoundError: No module named 'sl_build.resolver'`

- [ ] **Step 3: Write minimal implementation**

```python
# CATI/Analysis/SL/sl_build/resolver.py
"""Resolve a dotted key path into a nested dict."""


class MissingKey(KeyError):
    pass


def resolve(data, dotted):
    node = data
    for part in dotted.split("."):
        if not isinstance(node, dict) or part not in node:
            raise MissingKey(dotted)
        node = node[part]
    return node
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd CATI/Analysis/SL && python3 -m pytest tests/test_resolver.py -q`
Expected: PASS (5 passed)

- [ ] **Step 5: Commit**

```bash
git add CATI/Analysis/SL/sl_build/resolver.py CATI/Analysis/SL/tests/test_resolver.py
git commit -m "add sl_build dotted-path resolver"
```

---

## Task 3: HTML injector

**Files:**
- Create: `CATI/Analysis/SL/sl_build/injector.py`
- Test: `CATI/Analysis/SL/tests/test_injector.py`

The injector mutates an HTML string in two ways: (a) replace the inner text of `<script id="sl-data" type="application/json">…</script>` with the chart-data JSON; (b) for every `<span data-stat="KEY" data-fmt="FMT">…</span>`, replace inner text with the formatted resolved value. It returns `(new_html, report)` where `report` lists keys used, so verify can detect orphans.

- [ ] **Step 1: Write the failing test**

```python
# CATI/Analysis/SL/tests/test_injector.py
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import pytest
from sl_build.injector import inject, InjectError

HTML = (
    '<script id="sl-data" type="application/json">{}</script>\n'
    'Fell from <span data-stat="fies.mod_sev_r1" data-fmt="pct0">OLD</span> '
    'to <span data-stat="fies.mod_sev_r5" data-fmt="pct1">OLD</span>.'
)
DATA = {"charts": {"food_trend": [41.0, 18.2]},
        "fies": {"mod_sev_r1": 41.0, "mod_sev_r5": 18.2}}

def test_inject_fills_spans():
    out, report = inject(HTML, DATA, chart_key="charts")
    assert '>41%<' in out
    assert '>18.2%<' in out
    assert "OLD" not in out

def test_inject_writes_sl_data_block():
    out, _ = inject(HTML, DATA, chart_key="charts")
    assert '"food_trend"' in out
    assert '[41.0, 18.2]' in out or '[41.0,18.2]' in out

def test_report_lists_used_keys():
    _, report = inject(HTML, DATA, chart_key="charts")
    assert report.used_stat_keys == {"fies.mod_sev_r1", "fies.mod_sev_r5"}

def test_missing_stat_key_raises():
    bad = HTML.replace("fies.mod_sev_r5", "fies.ghost")
    with pytest.raises(InjectError, match="fies.ghost"):
        inject(bad, DATA, chart_key="charts")

def test_idempotent():
    out1, _ = inject(HTML, DATA, chart_key="charts")
    out2, _ = inject(out1, DATA, chart_key="charts")
    assert out1 == out2
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd CATI/Analysis/SL && python3 -m pytest tests/test_injector.py -q`
Expected: FAIL — `ModuleNotFoundError: No module named 'sl_build.injector'`

- [ ] **Step 3: Write minimal implementation**

```python
# CATI/Analysis/SL/sl_build/injector.py
"""Inject sl_stats values into the storyline HTML: the #sl-data chart block and
each data-stat span. Pure string mutation; returns (html, Report)."""
import json
import re
from dataclasses import dataclass, field

from .formatter import fmt
from .resolver import resolve, MissingKey


class InjectError(Exception):
    pass


@dataclass
class Report:
    used_stat_keys: set = field(default_factory=set)

# <span data-stat="KEY" data-fmt="FMT" ...> INNER </span>
_SPAN = re.compile(
    r'(<span\b[^>]*\bdata-stat="(?P<key>[^"]+)"[^>]*\bdata-fmt="(?P<fmt>[^"]+)"[^>]*>)'
    r'(?P<inner>.*?)(</span>)',
    re.DOTALL,
)
_SLDATA = re.compile(
    r'(<script id="sl-data" type="application/json">)(.*?)(</script>)',
    re.DOTALL,
)


def inject(html, data, chart_key):
    report = Report()

    chart_obj = data.get(chart_key, {})
    block = json.dumps(chart_obj, ensure_ascii=False)
    if not _SLDATA.search(html):
        raise InjectError('missing <script id="sl-data"> block')
    html = _SLDATA.sub(lambda m: m.group(1) + block + m.group(3), html, count=1)

    def _repl(m):
        key, spec = m.group("key"), m.group("fmt")
        try:
            value = resolve(data, key)
        except MissingKey:
            raise InjectError(f"data-stat key not in sl_stats.json: {key}")
        report.used_stat_keys.add(key)
        return m.group(1) + fmt(value, spec) + m.group(5)

    html = _SPAN.sub(_repl, html)
    return html, report
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd CATI/Analysis/SL && python3 -m pytest tests/test_injector.py -q`
Expected: PASS (5 passed)

- [ ] **Step 5: Commit**

```bash
git add CATI/Analysis/SL/sl_build/injector.py CATI/Analysis/SL/tests/test_injector.py
git commit -m "add sl_build HTML injector"
```

---

## Task 4: `build_story.py` build + verify CLI

**Files:**
- Create: `CATI/Analysis/SL/build_story.py`
- Test: `CATI/Analysis/SL/tests/test_build_story.py`

`build_story.py` wires the module to real files. `build` writes the injected HTML back; `--check` re-injects into a fresh copy and asserts it equals the on-disk HTML (agreement), and reports orphan JSON keys.

- [ ] **Step 1: Write the failing test**

```python
# CATI/Analysis/SL/tests/test_build_story.py
import sys, os, json, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
SL = os.path.dirname(HERE)

def _write(p, s): open(p, "w", encoding="utf-8").write(s)

HTML = (
    '<script id="sl-data" type="application/json">{}</script>\n'
    'Fell to <span data-stat="fies.mod_sev_r5" data-fmt="pct1">OLD</span>.'
)
DATA = {"charts": {"t": [1, 2]}, "fies": {"mod_sev_r5": 18.2}}

def _run(args, cwd):
    return subprocess.run([sys.executable, os.path.join(SL, "build_story.py")] + args,
                          capture_output=True, text=True, cwd=cwd)

def test_build_then_check(tmp_path):
    h = os.path.join(tmp_path, "story.html"); j = os.path.join(tmp_path, "s.json")
    _write(h, HTML); _write(j, json.dumps(DATA))
    r = _run(["--html", h, "--json", j, "--chart-key", "charts"], str(tmp_path))
    assert r.returncode == 0, r.stderr
    assert ">18.2%<" in open(h, encoding="utf-8").read()
    # --check on the freshly built file passes
    r2 = _run(["--html", h, "--json", j, "--chart-key", "charts", "--check"], str(tmp_path))
    assert r2.returncode == 0, r2.stderr

def test_check_fails_on_drift(tmp_path):
    h = os.path.join(tmp_path, "story.html"); j = os.path.join(tmp_path, "s.json")
    _write(h, HTML.replace("OLD", "99.9%")); _write(j, json.dumps(DATA))
    r = _run(["--html", h, "--json", j, "--chart-key", "charts", "--check"], str(tmp_path))
    assert r.returncode == 1
    assert "drift" in (r.stdout + r.stderr).lower()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd CATI/Analysis/SL && python3 -m pytest tests/test_build_story.py -q`
Expected: FAIL — build_story.py does not exist (non-zero, error in stderr)

- [ ] **Step 3: Write minimal implementation**

```python
# CATI/Analysis/SL/build_story.py
#!/usr/bin/env python3
"""Build (inject) or verify the CATI storyline HTML from sl_stats.json.

  build_story.py --html l2p_cati_story.html --json sl_stats.json --chart-key charts
  build_story.py ... --check          # verify only; non-zero on drift/orphans
"""
import argparse, json, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sl_build.injector import inject, InjectError

DEFAULT_HTML = "l2p_cati_story.html"
DEFAULT_JSON = "sl_stats.json"
DEFAULT_CHART_KEY = "charts"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--html", default=DEFAULT_HTML)
    ap.add_argument("--json", default=DEFAULT_JSON)
    ap.add_argument("--chart-key", default=DEFAULT_CHART_KEY)
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    with open(args.json, encoding="utf-8") as f:
        data = json.load(f)
    with open(args.html, encoding="utf-8") as f:
        original = f.read()

    try:
        built, report = inject(original, data, chart_key=args.chart_key)
    except InjectError as e:
        print(f"BUILD FAILED: {e}")
        return 1

    # Orphan detection: chart_key sub-keys + used stat keys must cover the JSON.
    used = set(report.used_stat_keys)
    orphans = _orphans(data, used, args.chart_key)

    if args.check:
        problems = []
        if built != original:
            problems.append("drift: HTML does not match sl_stats.json (rebuild needed)")
        for o in orphans:
            problems.append(f"orphan: sl_stats key never shown in HTML: {o}")
        if problems:
            print("CHECK FAILED:")
            for p in problems:
                print("  " + p)
            return 1
        print("CHECK OK")
        return 0

    with open(args.html, "w", encoding="utf-8") as f:
        f.write(built)
    print(f"built {args.html}: {len(report.used_stat_keys)} stat bindings"
          + (f"; WARNING {len(orphans)} orphan keys" if orphans else ""))
    return 0


def _orphans(data, used_stat_keys, chart_key):
    """Top-level leaf keys (outside chart_key and _meta) not referenced by any span.
    Uses dotted prefixes: a key is covered if any used key starts with its path."""
    out = []
    for top, val in data.items():
        if top in (chart_key, "_meta"):
            continue
        if isinstance(val, dict):
            for sub in val:
                dotted = f"{top}.{sub}"
                if not any(u == dotted or u.startswith(dotted + ".") for u in used_stat_keys):
                    out.append(dotted)
        else:
            if top not in used_stat_keys:
                out.append(top)
    return out


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd CATI/Analysis/SL && python3 -m pytest tests/test_build_story.py -q`
Expected: PASS (2 passed)

- [ ] **Step 5: Commit**

```bash
git add CATI/Analysis/SL/build_story.py CATI/Analysis/SL/tests/test_build_story.py
git commit -m "add build_story build+verify CLI over sl_build"
```

---

## Task 5: Canonical JSON contract + schema doc

**Files:**
- Create: `CATI/Analysis/SL/sl_stats.json` (adopt from `sl_stats_v2.json`, restructured)
- Create: `CATI/Analysis/SL/docs/sl_stats_schema.md`
- Modify: archive `sl_stats_v2.json` / `sl_stats.json`-stale via `_attic/` (manual git mv)

This task defines the **key namespace** — the contract Stata and HTML share. There is no Python logic to test; correctness is proven when Task 6's `build_story --check` passes against this file.

- [ ] **Step 1: Define the canonical structure**

The canonical `sl_stats.json` has these top-level keys:
- `_meta` — `{ "generated": "<date>", "rounds": "R1-R5", "source": "l2phl_master_analysis.do" }` (carried from `sl_stats_v2.json`).
- `charts` — an object whose keys are **exactly** the keys the HTML chart code reads today (`food_trend`, `shock_trend`, `ls_trend`, `fies`, `severity`, `sev_macro`, `shock_types`, `coping`, `shock_macro`, `finance`, `loan_purpose`, `inc_macro`, `ph_type`, `ph_macro`, `facility`, `contract`, `class_work`, `eco_change`, `likert`, `life_sat_dist`, `fies_items_trend`, `shock_types_trend`, `finance_trend`, `eco_trend`, `perception_trend`). Values copied from the current `const DATA` literal (lines 1450–1522 of the HTML).
- Scalar groups for prose, dotted under domain keys: `sample.*`, `fies.*`, `shocks.*`, `finance.*`, `health.*`, `employment.*`, `views.*`. Seed values from the existing `sl_stats_v2.json` (e.g. `fies.mod_sev_r1 = 41.0`, `fies.mod_sev_r5 = 18.2`, `fies.change_ppt = 22.8`, `fies.severe_r5 = 3.7`, `sample.total_hh = 1917`).

- [ ] **Step 2: Create the file**

Build `CATI/Analysis/SL/sl_stats.json` by hand from the two existing sources: copy `const DATA` (HTML 1450–1522) verbatim into `charts`, and copy the scalar groups from `sl_stats_v2.json`. This is the interim source of truth until Stage 2 makes Stata write it. Validate it parses:

Run: `cd CATI/Analysis/SL && python3 -c "import json; d=json.load(open('sl_stats.json')); print(sorted(d)); print(sorted(d['charts'])[:5])"`
Expected: prints top-level keys including `charts` and the chart sub-keys.

- [ ] **Step 3: Write the schema doc**

```markdown
<!-- CATI/Analysis/SL/docs/sl_stats_schema.md -->
# sl_stats.json — key namespace (Stata ↔ HTML contract)

`sl_stats.json` is the single source of truth for the CATI storyline. Stata writes
it (`_stat_emit.do`); `build_story.py` injects it into `l2p_cati_story.html`.

## Top level
- `_meta` — generation metadata (date, rounds, source do-file).
- `charts` — chart data; keys equal the `DATA.*` names the HTML chart code reads.
- `sample`, `fies`, `shocks`, `finance`, `health`, `employment`, `views` — scalar
  groups bound to prose/KPI `data-stat` spans.

## Conventions
- Raw values only (no `%`, `₱`, or thousands separators) — formatting lives in `data-fmt`.
- A scalar key path (e.g. `fies.mod_sev_r1`) is the exact string used in
  `<span data-stat="fies.mod_sev_r1">`.
- Percentages stored as the number (41.0 = "41%"); pesos as integer pesos; counts as integers.

## Scalar keys (seed set — extend as the HTML binds more)
| Key | Meaning | Example | Typical data-fmt |
|-----|---------|---------|------------------|
| sample.total_hh | Unique panel households | 1917 | intcomma |
| fies.mod_sev_r1 | Mod-sev food insecurity, R1 (%) | 41.0 | pct0 |
| fies.mod_sev_r5 | Mod-sev food insecurity, R5 (%) | 18.2 | pct1 |
| fies.change_ppt | R1→R5 drop (ppt) | 22.8 | ppt |
| fies.severe_r5 | Severe food insecurity, R5 (%) | 3.7 | pct1 |
```

- [ ] **Step 4: Archive the superseded JSONs**

```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL/CATI/Analysis/SL
mkdir -p _attic
git mv sl_stats_v2.json _attic/sl_stats_v2.json 2>/dev/null || mv sl_stats_v2.json _attic/
# the stale plain one, if still tracked at this path from before, also goes:
[ -f sl_stats_v1.json ] && git mv sl_stats_v1.json _attic/ 2>/dev/null || true
```
(The canonical name is now `sl_stats.json`; `_attic/` is gitignored per Part A.)

- [ ] **Step 5: Commit**

```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git add CATI/Analysis/SL/sl_stats.json CATI/Analysis/SL/docs/sl_stats_schema.md
git add -u CATI/Analysis/SL/   # record the sl_stats_v2.json removal
git commit -m "establish canonical sl_stats.json + schema; retire _v2"
```

---

## Task 6: Refactor the HTML to bindings

**Files:**
- Modify: `CATI/Analysis/SL/l2p_cati_story.html`

Mechanical, verified by `build_story --check`. Two sub-steps: charts, then prose. There is no unit test; the gate is the verifier.

- [ ] **Step 1: Convert the chart `DATA` block to an injected block**

Replace lines 1450–1522 (the `const DATA = { … };` literal) with:
```html
<script id="sl-data" type="application/json">{}</script>
<script>const DATA = JSON.parse(document.getElementById('sl-data').textContent).charts ?? JSON.parse(document.getElementById('sl-data').textContent);</script>
```
Wait — to keep chart code (`DATA.food_trend`) unchanged, `DATA` must be the `charts` object. Use exactly:
```html
<script id="sl-data" type="application/json">{}</script>
<script>const SL = JSON.parse(document.getElementById('sl-data').textContent); const DATA = SL.charts;</script>
```
Leave all `makeTrendChart('cFoodTrend', DATA.food_trend, …)` calls untouched.

- [ ] **Step 2: Build once to populate charts**

Run: `cd CATI/Analysis/SL && python3 build_story.py --html l2p_cati_story.html --json sl_stats.json --chart-key charts`
Expected: `built l2p_cati_story.html: 0 stat bindings; WARNING N orphan keys` (0 spans yet; orphans = all scalar keys, expected at this point).
Open the HTML in a browser; confirm every chart still renders (the injected `charts` object matches the old `DATA`).

- [ ] **Step 3: Wrap prose & KPI numbers in `data-stat` spans**

For each hardcoded number in the prose/KPI markup, wrap it. Pattern:
```html
<!-- before -->  fell from <em class="terra">41% to 18%</em> in five months
<!-- after -->   fell from <em class="terra"><span data-stat="fies.mod_sev_r1" data-fmt="pct0">41%</span> to <span data-stat="fies.mod_sev_r5" data-fmt="pct1">18.2%</span></em> in five months
```
Rules:
- Each distinct displayed number → one span with the matching `sl_stats.json` key + a `data-fmt` from the vocabulary.
- The same value appearing in multiple places (e.g. `108.7M`, `2,470`) gets the same `data-stat` key in each location — they will all stay in sync.
- If a number you want to show has no key yet, add it to `sl_stats.json` and the schema doc, then bind it.
- Do NOT wrap numbers that are not statistics (round numbers like "five months", axis labels baked into chart config, CSS values).

Work section by section (hero KPIs → FIES chapter → shocks → finance → health → employment → views), running Step 4 after each section to catch mistakes early.

- [ ] **Step 4: Build + verify**

Run:
```bash
cd CATI/Analysis/SL
python3 build_story.py --html l2p_cati_story.html --json sl_stats.json --chart-key charts
python3 build_story.py --html l2p_cati_story.html --json sl_stats.json --chart-key charts --check
```
Expected: build prints the binding count; `--check` prints `CHECK OK`. If `--check` reports `orphan:` lines, either bind that stat in the HTML or remove it from `sl_stats.json`. If it reports `drift:`, you edited a span's text by hand — rebuild.

- [ ] **Step 5: Commit**

```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git add CATI/Analysis/SL/l2p_cati_story.html CATI/Analysis/SL/sl_stats.json CATI/Analysis/SL/docs/sl_stats_schema.md
git commit -m "refactor CATI storyline to data-stat bindings + injected chart block"
```

---

## Task 7: Stage 1 gate — full Python suite + verify green

**Files:** none (verification task)

- [ ] **Step 1: Run the full Python suite**

Run: `cd CATI/Analysis/SL && python3 -m pytest tests/ -q`
Expected: PASS (all formatter/resolver/injector/build_story tests green).

- [ ] **Step 2: Verify the real storyline**

Run: `cd CATI/Analysis/SL && python3 build_story.py --html l2p_cati_story.html --json sl_stats.json --chart-key charts --check`
Expected: `CHECK OK` (no drift, no orphans).

- [ ] **Step 3: Visual spot check**

Open `CATI/Analysis/SL/l2p_cati_story.html` in a browser. Confirm headline numbers (41% → 18%, 108.7M-equivalents, etc.) read correctly and all charts render.

- [ ] **Step 4: Commit checkpoint tag (optional)**

```bash
git commit --allow-empty -m "stage 1 complete: CATI storyline injection-driven + verifiable"
```

**>>> CHECKPOINT: Stage 1 closes the HTML-editing pain. Pause for review before Stage 2. <<<**

---

# STAGE 2 — Stata emitter + orchestrator

## Task 8: Stata emitter `_stat_emit.do`

**Files:**
- Create: `CATI/Analysis/SL/_stat_emit.do`
- Test: `CATI/Analysis/SL/tests/test_stat_emit.do` + `CATI/Analysis/SL/tests/test_stat_emit.py` (drives the do-file in batch and checks the JSON)

The emitter accumulates entries in Stata locals/globals and writes nested JSON. Keys are dotted; `stat_put` writes scalars, `stat_arr` arrays, `stat_obj` label→value objects.

- [ ] **Step 1: Write the failing test (Python drives Stata batch)**

```python
# CATI/Analysis/SL/tests/test_stat_emit.py
import os, json, subprocess, shutil, sys, pytest
HERE = os.path.dirname(os.path.abspath(__file__))
SL = os.path.dirname(HERE)
STATA = "/Applications/Stata/StataMP.app/Contents/MacOS/stata-mp"

@pytest.mark.skipif(not os.path.exists(STATA), reason="Stata not installed")
def test_emitter_roundtrip(tmp_path):
    do = os.path.join(tmp_path, "rt.do")
    out = os.path.join(tmp_path, "out.json")
    with open(do, "w") as f:
        f.write(f'''
include "{SL}/_stat_emit.do"
stat_open "{out}"
stat_put "fies.mod_sev_r1" = 41.0
stat_arr "charts.food_trend" 41 31 26.8 21.5 18.2
stat_obj "charts.sev_macro" NCR 66.3 Luzon 60.0
stat_close
''')
    r = subprocess.run([STATA, "-b", "do", do], cwd=str(tmp_path),
                       capture_output=True, text=True)
    assert os.path.exists(out), r.stdout
    d = json.load(open(out))
    assert d["fies"]["mod_sev_r1"] == 41.0
    assert d["charts"]["food_trend"] == [41, 31, 26.8, 21.5, 18.2]
    assert d["charts"]["sev_macro"] == {"NCR": 66.3, "Luzon": 60.0}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd CATI/Analysis/SL && python3 -m pytest tests/test_stat_emit.py -q`
Expected: FAIL — `_stat_emit.do` does not exist (Stata batch errors; `out.json` missing)

- [ ] **Step 3: Write minimal implementation**

```stata
* CATI/Analysis/SL/_stat_emit.do
* Accumulate stats and write nested JSON. Keys are dotted paths.
* Usage: stat_open "path.json" ; stat_put "a.b" = expr ; stat_arr "k" v1 v2 ;
*        stat_obj "k" lab1 v1 lab2 v2 ; stat_close
cap program drop stat_open
program define stat_open
    global _SE_PATH `"`1'"'
    global _SE_BODY ""
    global _SE_KEYS ""
end

cap program drop _se_guard
program define _se_guard          /* fail on duplicate key */
    args key
    if strpos(" $_SE_KEYS ", " `key' ") {
        di as error "stat_emit: duplicate key `key'"
        exit 459
    }
    global _SE_KEYS "$_SE_KEYS `key'"
end

cap program drop _se_append
program define _se_append
    args frag
    if "$_SE_BODY" == "" global _SE_BODY `"`frag'"'
    else global _SE_BODY `"$_SE_BODY,`frag'"'
end

cap program drop stat_put
program define stat_put
    * syntax: stat_put "key" = expr
    gettoken key 0 : 0
    gettoken eq  0 : 0           /* the '=' */
    local val = `0'
    if "`val'" == "." {
        di as error "stat_emit: missing value for `key'"
        exit 459
    }
    _se_guard "`key'"
    _se_append `"\"`key'\":`val'"'
end

cap program drop stat_arr
program define stat_arr
    gettoken key 0 : 0
    local arr ""
    foreach v of local 0 {
        if "`arr'" == "" local arr "`v'"
        else local arr "`arr',`v'"
    }
    _se_guard "`key'"
    _se_append `"\"`key'\":[`arr']"'
end

cap program drop stat_obj
program define stat_obj
    gettoken key 0 : 0
    local obj ""
    while "`0'" != "" {
        gettoken lab 0 : 0
        gettoken val 0 : 0
        local pair `"\"`lab'\":`val'"'
        if "`obj'" == "" local obj `"`pair'"'
        else local obj `"`obj',`pair'"'
    }
    _se_guard "`key'"
    _se_append `"\"`key'\":{`obj'}"'
end

* Nesting dotted keys purely in Stata is verbose, so write a FLAT JSON object
* keyed by the dotted strings; build_story.py un-flattens on load (Task 9).
cap program drop stat_close
program define stat_close
    tempname fh
    file open `fh' using "$_SE_PATH", write replace text
    file write `fh' "{$_SE_BODY}" _n
    file close `fh'
    di as result "stat_emit: wrote $_SE_PATH"
end
```

This writes e.g. `{"fies.mod_sev_r1":41.0,"charts.food_trend":[41,...],"charts.sev_macro":{"NCR":66.3,...}}`. Un-flattening to nested form happens in Task 9's loader.

- [ ] **Step 4: Adjust the test for flat output + nest in loader**

Update `test_stat_emit.py` assertions to read the flat keys, then confirm the Task 9 `unflatten` produces the nested form:
```python
    raw = json.load(open(out))
    assert raw["fies.mod_sev_r1"] == 41.0
    assert raw["charts.food_trend"] == [41, 31, 26.8, 21.5, 18.2]
    assert raw["charts.sev_macro"] == {"NCR": 66.3, "Luzon": 60.0}
```

Run: `cd CATI/Analysis/SL && python3 -m pytest tests/test_stat_emit.py -q`
Expected: PASS (1 passed; or skipped if Stata absent — then run manually once).

- [ ] **Step 5: Commit**

```bash
git add CATI/Analysis/SL/_stat_emit.do CATI/Analysis/SL/tests/test_stat_emit.py
git commit -m "add Stata stat_put/arr/obj emitter (flat dotted JSON)"
```

---

## Task 9: Un-flatten loader + wire into build_story

**Files:**
- Create: `CATI/Analysis/SL/sl_build/loader.py`
- Modify: `CATI/Analysis/SL/build_story.py` (load via loader)
- Test: `CATI/Analysis/SL/tests/test_loader.py`

- [ ] **Step 1: Write the failing test**

```python
# CATI/Analysis/SL/tests/test_loader.py
import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from sl_build.loader import unflatten

def test_unflatten_dotted():
    flat = {"fies.mod_sev_r1": 41.0, "charts.food_trend": [1, 2], "sample.total_hh": 1917}
    out = unflatten(flat)
    assert out == {"fies": {"mod_sev_r1": 41.0},
                   "charts": {"food_trend": [1, 2]},
                   "sample": {"total_hh": 1917}}

def test_unflatten_passthrough_nested():
    # already-nested JSON (Stage 1 hand-built) is returned unchanged
    nested = {"fies": {"mod_sev_r1": 41.0}}
    assert unflatten(nested) == nested
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd CATI/Analysis/SL && python3 -m pytest tests/test_loader.py -q`
Expected: FAIL — `ModuleNotFoundError: No module named 'sl_build.loader'`

- [ ] **Step 3: Write minimal implementation**

```python
# CATI/Analysis/SL/sl_build/loader.py
"""Accept either nested JSON or Stata's flat dotted-key JSON; return nested."""


def unflatten(data):
    if not any("." in k for k in data):
        return data
    out = {}
    for key, val in data.items():
        parts = key.split(".")
        node = out
        for p in parts[:-1]:
            node = node.setdefault(p, {})
        node[parts[-1]] = val
    return out
```

- [ ] **Step 4: Wire into build_story.py**

In `CATI/Analysis/SL/build_story.py`, change the JSON load:
```python
from sl_build.injector import inject, InjectError
from sl_build.loader import unflatten
...
    with open(args.json, encoding="utf-8") as f:
        data = unflatten(json.load(f))
```

Run: `cd CATI/Analysis/SL && python3 -m pytest tests/test_loader.py tests/test_build_story.py -q`
Expected: PASS (4 passed).

- [ ] **Step 5: Commit**

```bash
git add CATI/Analysis/SL/sl_build/loader.py CATI/Analysis/SL/build_story.py CATI/Analysis/SL/tests/test_loader.py
git commit -m "accept Stata flat-dotted JSON via unflatten loader"
```

---

## Task 10: Retrofit the master do-file

**Files:**
- Rename: `CATI/Analysis/SL/l2phl_master_analysis_v2.do` → `CATI/Analysis/SL/l2phl_master_analysis.do`
- Modify: the renamed file (add emitter calls)

Mechanical; verified by re-running build against the Stata-written JSON. No unit test — the gate is `build_story --check` against fresh Stata output.

- [ ] **Step 1: Rename the live master (archive the stale one)**

```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL/CATI/Analysis/SL
mkdir -p _attic
[ -f l2phl_master_analysis.do ] && git mv l2phl_master_analysis.do _attic/l2phl_master_analysis_OLD.do 2>/dev/null || true
git mv l2phl_master_analysis_v2.do l2phl_master_analysis.do
```

- [ ] **Step 2: Include the emitter and open the collection**

Near the top of `l2phl_master_analysis.do`, after the globals block, add:
```stata
include "`c(pwd)'/_stat_emit.do"     // or absolute path to CATI/Analysis/SL/_stat_emit.do
stat_open "CATI/Analysis/SL/sl_stats.json"
```
At the very end of the file add:
```stata
stat_close
```

- [ ] **Step 3: Emit each headline stat at its source**

For every number the storyline shows, add a `stat_put`/`stat_arr`/`stat_obj` next to where it is computed, using the exact key from `sl_stats_schema.md`. Pattern:
```stata
* FIES moderate-to-severe, Round 1
svy: mean fies_modsev if round==1
stat_put "fies.mod_sev_r1" = r(table)[1,1]*100

* trend array
stat_arr "charts.food_trend" `=v1' `=v2' `=v3' `=v4' `=v5'
```
Work module by module (sample → FIES → shocks → finance → health → employment → views), mirroring the keys the HTML now binds. Every key in `sl_stats.json` must get exactly one emitter call (Task 8's duplicate guard enforces uniqueness).

- [ ] **Step 4: Run Stata and rebuild**

```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
/Applications/Stata/StataMP.app/Contents/MacOS/stata-mp -b do CATI/Analysis/SL/l2phl_master_analysis.do
cd CATI/Analysis/SL
python3 build_story.py --html l2p_cati_story.html --json sl_stats.json --chart-key charts
python3 build_story.py --html l2p_cati_story.html --json sl_stats.json --chart-key charts --check
```
Expected: Stata writes `sl_stats.json`; build succeeds; `--check` prints `CHECK OK`. Any `orphan:` means a key in the HTML/JSON has no emitter or vice-versa — reconcile. Cross-check a few values against the Stata log.

- [ ] **Step 5: Commit**

```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git add CATI/Analysis/SL/l2phl_master_analysis.do CATI/Analysis/SL/sl_stats.json CATI/Analysis/SL/l2p_cati_story.html
git commit -m "retrofit CATI master do-file with stat_put emitter; Stata now writes sl_stats.json"
```

---

## Task 11: Orchestrator `scripts/build_cati_story.py`

**Files:**
- Create: `scripts/build_cati_story.py`
- Test: `scripts/tests/test_build_cati_story.py`

- [ ] **Step 1: Write the failing test**

```python
# scripts/tests/test_build_cati_story.py
import sys, os, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.dirname(HERE)

def test_check_mode_runs_build_story_check(tmp_path, monkeypatch):
    # Smoke test: --check on the real repo returns 0 (story is in sync).
    repo = os.path.dirname(SCRIPTS)
    r = subprocess.run([sys.executable, os.path.join(SCRIPTS, "build_cati_story.py"), "--check"],
                       capture_output=True, text=True, cwd=repo)
    assert r.returncode == 0, r.stdout + r.stderr
    assert "CHECK OK" in r.stdout
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/avraa/iDrive/GitHub/PHL/L2PHL && python3 -m pytest scripts/tests/test_build_cati_story.py -q`
Expected: FAIL — `build_cati_story.py` does not exist

- [ ] **Step 3: Write minimal implementation**

```python
# scripts/build_cati_story.py
#!/usr/bin/env python3
"""Orchestrate the CATI storyline: [run Stata] -> build -> verify.

  build_cati_story.py            # build + verify from existing sl_stats.json
  build_cati_story.py --stata    # run the Stata master (batch) first
  build_cati_story.py --check     # verify only (no write)
"""
import argparse, os, re, subprocess, sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SL = os.path.join(REPO, "CATI", "Analysis", "SL")
STATA = "/Applications/Stata/StataMP.app/Contents/MacOS/stata-mp"
MASTER = os.path.join(SL, "l2phl_master_analysis.do")
HTML = os.path.join(SL, "l2p_cati_story.html")
JSON = os.path.join(SL, "sl_stats.json")


def run_stata():
    if not os.path.exists(STATA):
        print(f"Stata not found at {STATA}")
        return 1
    subprocess.run([STATA, "-b", "do", MASTER], cwd=SL, check=False)
    # Stata batch returns 0 even on error; scan the log for an error code.
    log = os.path.join(SL, "l2phl_master_analysis.log")
    if os.path.exists(log):
        text = open(log, encoding="utf-8", errors="replace").read()
        m = re.search(r"\nr\((\d+)\);", text)
        if m:
            print(f"STATA ERROR r({m.group(1)}). Log tail:")
            print("\n".join(text.splitlines()[-20:]))
            return 1
    return 0


def build_story(check):
    args = [sys.executable, os.path.join(SL, "build_story.py"),
            "--html", HTML, "--json", JSON, "--chart-key", "charts"]
    if check:
        args.append("--check")
    return subprocess.run(args, cwd=SL).returncode


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--stata", action="store_true")
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    if args.stata:
        if run_stata() != 0:
            return 1
    if args.check:
        return build_story(check=True)
    # build, then always verify
    if build_story(check=False) != 0:
        return 1
    return build_story(check=True)


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/avraa/iDrive/GitHub/PHL/L2PHL && python3 -m pytest scripts/tests/test_build_cati_story.py -q`
Expected: PASS (1 passed). (Requires Task 10's in-sync story; if Stata is unavailable, the `--check` path still works against the committed `sl_stats.json`.)

- [ ] **Step 5: Update `scripts/README.md` and commit**

Add a section to `scripts/README.md`:
```markdown
## build_cati_story.py — regenerate the CATI storyline

```bash
python3 scripts/build_cati_story.py --stata   # .dta -> sl_stats.json -> HTML -> verify
python3 scripts/build_cati_story.py           # rebuild HTML from existing sl_stats.json
python3 scripts/build_cati_story.py --check    # verify only (CI gate)
```
Numbers live only in `sl_stats.json` (Stata writes it via `_stat_emit.do`); never hand-edit numbers in the HTML.
```

```bash
git add scripts/build_cati_story.py scripts/tests/test_build_cati_story.py scripts/README.md
git commit -m "add CATI storyline orchestrator (Stata -> build -> verify)"
```

---

## Self-Review

**Spec coverage:**
- Single source of truth `sl_stats.json` → Task 5 (establish) + Task 10 (Stata writes it).
- Stata `stat_put` emitter → Task 8; retrofit → Task 10.
- Build-time injection into self-contained HTML → Tasks 3–4 (injector/CLI) + Task 6 (bindings).
- Format vocabulary → Task 1.
- Verification gate (completeness/orphans/agreement) → Task 4 (`--check`) + Task 6/7 (applied).
- R cross-check optional → noted as out-of-core; `--cross-check` deferred (see note below).
- Orchestrator one command incl. Stata batch + error detection → Task 11.
- Reusable `sl_build/` deliverable-agnostic → Tasks 1–3, 9 (formatter/resolver/injector/loader carry no CATI specifics; CATI keys live in `sl_stats.json` + the HTML).
- Naming cleanup `_v2`/`_v2_R` retired, master renamed → Tasks 5, 10.

**Gap fixed inline:** the spec lists `verify --cross-check` against the R JSON. It is **not** implemented in these tasks (the R JSON isn't currently generated, and it's explicitly "optional, not a build dependency" in the spec). Deferred to a follow-up; the core verify (drift/orphans) fully covers the reproducibility gate. This is a conscious scope trim, not an omission.

**Placeholder scan:** none — every code step shows complete code; mechanical tasks (6, 10) give exact patterns + the verifier as the acceptance gate rather than enumerating every literal substitution (there are dozens; enumerating them is not feasible and the verifier is the correctness oracle).

**Type/contract consistency:** `inject(html, data, chart_key) -> (html, Report)` defined Task 3, called identically in Task 4. `Report.used_stat_keys` (set) defined Task 3, consumed Task 4 `_orphans`. `fmt(value, spec)` Task 1 used in Task 3. `resolve`/`MissingKey` Task 2 used in Task 3. `unflatten` Task 9 used in Task 4's loader wiring. `--chart-key charts` consistent across Tasks 4, 6, 10, 11. Stata keys (`fies.mod_sev_r1`, `charts.food_trend`) consistent across Tasks 5, 6, 8, 10.

**Stage independence:** Stage 1 (Tasks 1–7) delivers a verifiable injection-driven HTML from a hand-built `sl_stats.json` — working software. Stage 2 (Tasks 8–11) swaps the hand-built JSON for Stata-written and adds the button. Each stage ends green.
