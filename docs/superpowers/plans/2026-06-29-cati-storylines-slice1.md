# CATI Panel Storylines — Slice 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Two project-specific skills are REQUIRED at the tagged tasks** (the user asked for this explicitly):
> - **`/avraa-stata`** — invoke before authoring/editing ANY `.do` file (Tasks 2, 3, 4). It writes Stata in the author's style; it does NOT run Stata.
> - **`/avraa-voice`** — invoke before writing ANY storyline prose (Task 8). It drafts in the author's writing voice (use the **broad-science register**: short, modular, declarative — right for a WB+government storyline).

**Goal:** Build a vertical slice of the CATI panel storyline system — the data pipeline, the shared scrollytelling engine, one flagship topic page ("Recovery is measurable"), and a hub shell — proving the full Stata→JSON→build→self-contained-HTML stack end to end.

**Architecture:** Extend the existing `CATI/Analysis/SL/` spine. Stata computes R1–R8 series × breakdowns and emits `sl_series.json` (reusing the `_stat_emit.do` primitives via a new `_series_emit.do` helper). A new `build_storyline.py` assembles each topic by inlining a shared `storyline.css`/`storyline.js` engine + Chart.js CDN + the topic's series JSON into a self-contained HTML, injecting data-bound numbers via the existing `build_story.inject`. A `--check` drift gate and the existing QC grounding/badges are reused.

**Each topic page adopts the proven baseline-story chapter template** — `CAPI/Analysis/SL/html/l2phl_baseline_story.html` (`#ch-roster`). That file's `<style>` block (lines **13–278**) is a self-contained editorial design system we **extract and adapt** into `storyline.css`: serif/editorial type (**Playfair Display** display, **Source Serif 4** body, **IBM Plex Mono** labels), cream paper (`--paper:#f5f0e8`), navy `--ink:#002244`, the WB/PH palette, and the chapter classes `.chap` · `.eyebrow` · `.hed` · `.two-col` · `.body-copy` · `.sgrid/.scell/.scell-n/.scell-l` · `.cbox` · `.rev/.rev.vis/.rev.d1-3`. The baseline already uses the **same `data-stat`/`data-fmt` injector** and lazy `IntersectionObserver` chart init — we reuse both. Slice 1 ADDS one thing the baseline lacks: an **interactive R1–R8 breakdown chart** (toggle chips + round scrubber + hover) mounted inside a `.cbox`. Motion stays the baseline's `.rev` scroll-reveal; sections tagged with `data-indicator` also drive the interactive chart as they reveal.

**Tech Stack:** Stata (MP, batch + Stata MCP) · Python 3 (stdlib + pytest) · vanilla JS + Chart.js 4.4.1 (CDN) · node (for JS unit tests + `--check`). Type: Playfair Display / Source Serif 4 / IBM Plex Mono (Google Fonts).

**Reference:** Design doc `docs/superpowers/specs/2026-06-29-cati-panel-storylines-design.md`. **Template source:** `CAPI/Analysis/SL/html/l2phl_baseline_story.html` (`<style>` lines 13–278; chapter markup at `#ch-roster`; reveal/chart JS near lines 2834–2890).

**Branch:** `feat/cati-storylines-slice1` (do NOT work on `main`).

---

## Scope (Slice 1 only)

IN: data pipeline for **Topic 1 indicators only** (`mod_sev` food insecurity, `any_shock`) with breakdowns (income quintile, region, urban/rural); shared engine; `build_storyline.py`; Topic 1 page; hub shell (9 cards, only Topic 1 linked live); tests; `--check`.

OUT (Slice 2): the other 8 topics, sex/age breakdown wiring, full hub links.

## File structure

| File | New/Mod | Responsibility |
|------|---------|----------------|
| `CATI/Analysis/SL/series.py` | new | Pure Python: load + validate `sl_series.json` shape. |
| `CATI/Analysis/SL/_series_emit.do` | new (`/avraa-stata`) | Stata helper `series_emit`: one indicator → R1–R8 series overall + by each breakdown, emitted via `_stat_emit.do` primitives under `series.<name>.*`. |
| `CATI/Analysis/SL/_breakdowns.do` | new (`/avraa-stata`) | Build breakdown vars on the loaded dataset: `inc_q` (baseline imputed-income quintile), `reg4` (region group), `urbrur`. |
| `CATI/Analysis/SL/l2phl_storyline_series.do` | new (`/avraa-stata`) | Orchestrator: load food + shocks data, build breakdowns, call `series_emit`, write `sl_series.json`. |
| `CATI/Analysis/SL/sl_series.json` | generated | Series data (chart source). |
| `CATI/Analysis/SL/storyline.css` | new | **Extracted + adapted from the baseline story `<style>` (lines 13–278)** — editorial serif design system + chapter classes; plus the interactive-chart additions (`.chips-bd/.chip/.scrub`). |
| `CATI/Analysis/SL/storyline.js` | new | Shared engine: pure data helpers (tested) + DOM wiring that mounts the interactive chart in a `.cbox` and reuses the baseline `.rev`→`.vis` reveal + lazy chart init. |
| `CATI/Analysis/SL/topics/recovery.html` | new (`/avraa-voice` prose) | Topic 1 content fragment: hero + beats + prose `data-stat` spans + beat markup. |
| `CATI/Analysis/SL/hub.template.html` | new | Hub content fragment: hero + 9 theme cards. |
| `CATI/Analysis/SL/build_storyline.py` | new | Assemble topic(s) + hub into self-contained HTML; reuse `build_story.inject`; `--check`. |
| `CATI/Analysis/SL/topics_registry.py` | new | The 9-theme registry (slug, title, modules, headline, sparkline series key, accent color). |
| `CATI/Analysis/SL/tests/test_series.py` | new | Tests for `series.py`. |
| `CATI/Analysis/SL/tests/test_series_emit.py` | new | Stata roundtrip test for `_series_emit.do` (skip-guarded). |
| `CATI/Analysis/SL/tests/test_breakdowns.py` | new | Stata test for `_breakdowns.do` on a synthetic dataset (skip-guarded). |
| `CATI/Analysis/SL/tests/test_storyline_engine.mjs` | new | node tests for `storyline.js` pure helpers. |
| `CATI/Analysis/SL/tests/test_build_storyline.py` | new | Tests for `build_storyline.py`. |
| `CATI/Analysis/SL/html/l2p_cati_recovery.html` | generated | Topic 1 page. |
| `CATI/Analysis/SL/html/l2p_cati_hub.html` | generated | Hub shell. |

**`sl_series.json` schema** (flat dotted keys, consumed via `unflatten()` → nested):
```json
{
  "_meta": {"generated": "...", "rounds": "R1-R8", "source": "l2phl_storyline_series.do"},
  "series.food_insecurity.label": "Moderate-to-severe food insecurity",
  "series.food_insecurity.unit": "pct",
  "series.food_insecurity.rounds": [1,2,3,4,5,6,7,8],
  "series.food_insecurity.overall": [41.0, 31.0, 26.8, 21.5, 18.2, 17.0, 16.4, 18.0],
  "series.food_insecurity.by_quintile": {"Poorest":[...8...],"Q2":[...],"Q3":[...],"Q4":[...],"Richest":[...]},
  "series.food_insecurity.by_region":   {"NCR":[...],"Luzon":[...],"Visayas":[...],"Mindanao":[...]},
  "series.food_insecurity.by_urbrur":   {"Urban":[...],"Rural":[...]},
  "series.any_shock.label": "Households reporting any shock",
  "series.any_shock.unit": "pct",
  "series.any_shock.rounds": [1,2,3,4,5,6,7,8],
  "series.any_shock.overall": [...],
  "series.any_shock.by_quintile": {...}, "series.any_shock.by_region": {...}, "series.any_shock.by_urbrur": {...}
}
```
Every `overall` / breakdown array has length == `rounds` length. Breakdown groups that an indicator does not support are simply absent.

---

## Task 1: Series loader + validator (`series.py`)

**Files:**
- Create: `CATI/Analysis/SL/series.py`
- Test: `CATI/Analysis/SL/tests/test_series.py`

- [ ] **Step 1: Write the failing test**

```python
# CATI/Analysis/SL/tests/test_series.py
import json, os, pytest
import sys; sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from series import load_series, validate_series, indicator_keys, SeriesError

GOOD = {
    "_meta": {"rounds": "R1-R8"},
    "series.food_insecurity.label": "Mod-sev food insecurity",
    "series.food_insecurity.unit": "pct",
    "series.food_insecurity.rounds": [1,2,3,4,5,6,7,8],
    "series.food_insecurity.overall": [41,31,26.8,21.5,18.2,17,16.4,18],
    "series.food_insecurity.by_quintile": {"Poorest":[60,55,50,46,44,43,42,45],
                                           "Richest":[20,15,12,10,9,8,8,9]},
}

def _write(tmp, obj):
    p = os.path.join(tmp, "sl_series.json"); open(p,"w").write(json.dumps(obj)); return p

def test_load_and_indicator_keys(tmp_path):
    d = load_series(_write(tmp_path, GOOD))
    assert indicator_keys(d) == ["food_insecurity"]
    assert d["series"]["food_insecurity"]["overall"][0] == 41

def test_validate_ok(tmp_path):
    validate_series(load_series(_write(tmp_path, GOOD)))  # no raise

def test_length_mismatch_raises(tmp_path):
    bad = json.loads(json.dumps(GOOD))
    bad["series.food_insecurity.overall"] = [1,2,3]  # wrong length
    with pytest.raises(SeriesError, match="length"):
        validate_series(load_series(_write(tmp_path, bad)))

def test_breakdown_length_mismatch_raises(tmp_path):
    bad = json.loads(json.dumps(GOOD))
    bad["series.food_insecurity.by_quintile"]["Poorest"] = [1,2]
    with pytest.raises(SeriesError, match="Poorest"):
        validate_series(load_series(_write(tmp_path, bad)))
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd CATI/Analysis/SL && python3 -m pytest tests/test_series.py -q`
Expected: FAIL (ModuleNotFoundError: series).

- [ ] **Step 3: Implement `series.py`**

```python
# CATI/Analysis/SL/series.py
"""Load + validate sl_series.json (flat dotted keys -> nested 'series' tree)."""
import json

class SeriesError(Exception):
    pass

def _unflatten(flat):
    out = {}
    for k, v in flat.items():
        parts = k.split(".")
        cur = out
        for p in parts[:-1]:
            cur = cur.setdefault(p, {})
        cur[parts[-1]] = v
    return out

def load_series(path):
    with open(path, encoding="utf-8") as f:
        return _unflatten(json.load(f))

def indicator_keys(data):
    return sorted(data.get("series", {}).keys())

def validate_series(data):
    series = data.get("series", {})
    if not series:
        raise SeriesError("no series found")
    for name, entry in series.items():
        rounds = entry.get("rounds")
        if not isinstance(rounds, list) or not rounds:
            raise SeriesError(f"{name}: missing/empty rounds")
        n = len(rounds)
        ov = entry.get("overall")
        if not isinstance(ov, list) or len(ov) != n:
            raise SeriesError(f"{name}.overall: length {len(ov) if isinstance(ov,list) else '?'} != {n}")
        for bd_key in [k for k in entry if k.startswith("by_")]:
            for sub, arr in entry[bd_key].items():
                if not isinstance(arr, list) or len(arr) != n:
                    raise SeriesError(f"{name}.{bd_key}.{sub}: length != {n}")
    return data
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd CATI/Analysis/SL && python3 -m pytest tests/test_series.py -q`
Expected: PASS (4 passed).

- [ ] **Step 5: Commit**

```bash
git add CATI/Analysis/SL/series.py CATI/Analysis/SL/tests/test_series.py
git commit -m "feat(sl): series.py loader+validator for sl_series.json"
```

---

## Task 2: Stata series emitter `_series_emit.do` (`/avraa-stata`)

**INVOKE `/avraa-stata` before writing the do-file.** It authors the Stata; the contract + test below define correctness.

**Files:**
- Create: `CATI/Analysis/SL/_series_emit.do`
- Test: `CATI/Analysis/SL/tests/test_series_emit.py`

**Contract.** `_series_emit.do` includes `_stat_emit.do` and defines a program `series_emit` with this behaviour:

```
series_emit <name> <indicator_var>, label("<text>") unit("pct"|"raw") ///
            round(<rvar>) [quintile(<qvar>) region(<rgvar>) urbrur(<uvar>)] [scale(100)]
```
- Runs `svy: mean <indicator_var>, over(<rvar>)` and emits `series.<name>.overall` as a `stat_arr` of the per-round means × `scale` (default 100), in round order.
- Emits `series.<name>.rounds` as the sorted integer round list, `series.<name>.label` (`stat_put` string) and `series.<name>.unit`.
- For each supplied breakdown option, runs `svy: mean <indicator_var>, over(<rvar> <bdvar>)` and emits `series.<name>.by_quintile|by_region|by_urbrur` as a `stat_objarr` (one row per breakdown level → array over rounds × scale). Missing cells emit `.` → JSON `null`-safe: emit the level only if all rounds present; otherwise emit the available rounds padded with the group's last-observed value is NOT allowed — instead emit the cell as the round mean if estimable, else `stat_objarr` row is still length-`nrounds` using `.` written as the literal token the JSON consumer treats as gap (use `-1` sentinel is NOT allowed). **Decision: pad missing round cells with the JSON value `null` by writing the token `null` (the emitter must support a null token).**

> Implementation note for `/avraa-stata`: add a `stat_objarr_row_n` variant (or extend `stat_objarr_row`) that accepts `.`/missing and writes `null`. Keep the author's preamble/style. The program must be idempotent across calls (append rows to the same `sl_series.json` via `stat_open`/`stat_close` managed by the orchestrator, Task 4).

- [ ] **Step 1: Write the failing test** (skip-guarded, mirrors `tests/test_stat_emit.py`)

```python
# CATI/Analysis/SL/tests/test_series_emit.py
import os, json, subprocess, functools, shutil, pytest
SL = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
STATA = shutil.which("stata-mp") or shutil.which("stata-se") or shutil.which("stata")

@functools.lru_cache(maxsize=1)
def _stata_ok():
    return STATA is not None

@pytest.mark.skipif(not _stata_ok(), reason="batch Stata not available")
def test_series_emit_roundtrip(tmp_path):
    do = os.path.join(tmp_path, "rt.do")
    out = os.path.join(tmp_path, "sl_series.json")
    with open(do, "w") as f:
        f.write(f'''
clear
set obs 16
gen round = mod(_n-1,8)+1
gen q = cond(_n<=8,1,5)
gen y = 0.4 - 0.02*round        // declining indicator
svyset, clear
gen one = 1
svyset one
include "{SL}/_series_emit.do"
stat_open "{out}"
series_emit foodins y, label("Mod-sev food insecurity") unit("pct") round(round) quintile(q)
stat_close
''')
        # NOTE: real orchestrator uses true svyset; this probe uses a trivial design.
    r = subprocess.run([STATA, "-b", "do", do], cwd=tmp_path, capture_output=True, text=True)
    assert os.path.exists(out), r.stdout
    raw = json.load(open(out))
    assert raw["series.foodins.label"] == "Mod-sev food insecurity"
    assert raw["series.foodins.rounds"] == [1,2,3,4,5,6,7,8]
    assert len(raw["series.foodins.overall"]) == 8
    assert set(raw["series.foodins.by_quintile"].keys()) == {"1","5"}
    assert len(raw["series.foodins.by_quintile"]["1"]) == 8
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd CATI/Analysis/SL && python3 -m pytest tests/test_series_emit.py -q`
Expected: FAIL if Stata present (program undefined), or SKIP if not. If SKIP, note it and proceed — Task 4 exercises it on real data.

- [ ] **Step 3: Author `_series_emit.do`** — invoke `/avraa-stata`, implement the contract above. The skill writes the ruled header, preamble-free include (it's a library include, no `cd`), and the `series_emit` program + the null-aware `stat_objarr` row helper.

- [ ] **Step 4: Run to verify it passes** (or skips cleanly)

Run: `cd CATI/Analysis/SL && python3 -m pytest tests/test_series_emit.py -q`
Expected: PASS (Stata present) or SKIP.

- [ ] **Step 5: Commit**

```bash
git add CATI/Analysis/SL/_series_emit.do CATI/Analysis/SL/tests/test_series_emit.py
git commit -m "feat(sl): _series_emit.do — indicator x round x breakdown -> sl_series.json"
```

---

## Task 3: Breakdown variables `_breakdowns.do` (`/avraa-stata`)

**INVOKE `/avraa-stata` before writing the do-file.**

**Files:**
- Create: `CATI/Analysis/SL/_breakdowns.do`
- Test: `CATI/Analysis/SL/tests/test_breakdowns.py`

**Contract.** `_breakdowns.do`, run on a dataset already in memory that has `hhid` and a region code var, creates:
- `inc_q` (1–5): quintile of **baseline imputed per-capita income**. It merges `pcinc_imp_mean` from a baseline income crosswalk (`$dta/l2phl_baseline_income_xwalk.dta`, keyed by `hhid`) and computes quintiles with `xtile inc_q = pcinc_imp_mean, nq(5)`. **If the crosswalk file does not exist, set `inc_q = .` for all rows and set global `$HAS_INCQ = 0`; else `$HAS_INCQ = 1`.** (Graceful degradation so the pipeline never hard-fails on a missing baseline link.)
- `reg4` (1–4 labelled NCR/Luzon/Visayas/Mindanao): mapped from the PSGC region code (use the standard region→island-group mapping; NCR = region 13).
- `urbrur` (1–2 labelled Urban/Rural): from the existing urban/rural indicator on the file (`urb` or `urban`; the do-file probes both).

- [ ] **Step 1: Write the failing test** (skip-guarded; uses a synthetic dataset + a synthetic crosswalk so no real data needed)

```python
# CATI/Analysis/SL/tests/test_breakdowns.py
import os, json, subprocess, functools, shutil, pytest
SL = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
STATA = shutil.which("stata-mp") or shutil.which("stata-se") or shutil.which("stata")

@functools.lru_cache(maxsize=1)
def _stata_ok():
    return STATA is not None

@pytest.mark.skipif(not _stata_ok(), reason="batch Stata not available")
def test_breakdowns_build(tmp_path):
    out = os.path.join(tmp_path, "chk.json")
    xwalk = os.path.join(tmp_path, "l2phl_baseline_income_xwalk.dta")
    do = os.path.join(tmp_path, "bd.do")
    with open(do, "w") as f:
        f.write(f'''
clear
set obs 100
gen hhid = _n
gen pcinc_imp_mean = _n*100
save "{xwalk}", replace
clear
set obs 100
gen hhid = _n
gen region = cond(_n<=25,13, cond(_n<=50,1, cond(_n<=75,6,10)))
gen urban  = mod(_n,2)
global dta "{tmp_path}"
include "{SL}/_breakdowns.do"
include "{SL}/_stat_emit.do"
qui count if !missing(inc_q)
stat_open "{out}"
stat_put "n_incq"  = r(N)
stat_put "has_incq" = $HAS_INCQ
qui levelsof reg4, local(L)
stat_put "n_reg4"  = `: word count `L''
stat_close
''')
    r = subprocess.run([STATA, "-b", "do", do], cwd=tmp_path, capture_output=True, text=True)
    assert os.path.exists(out), r.stdout
    raw = json.load(open(out))
    assert raw["has_incq"] == 1
    assert raw["n_incq"] == 100
    assert raw["n_reg4"] == 4
```

- [ ] **Step 2: Run to verify it fails** — `python3 -m pytest tests/test_breakdowns.py -q` → FAIL (no `_breakdowns.do`) or SKIP.

- [ ] **Step 3: Author `_breakdowns.do`** — invoke `/avraa-stata`, implement the contract. Use `capture confirm file` for the crosswalk existence check; `merge m:1 hhid using "$dta/l2phl_baseline_income_xwalk.dta", keep(master match) nogen`.

- [ ] **Step 4: Run to verify it passes** (or skips) — `python3 -m pytest tests/test_breakdowns.py -q`.

- [ ] **Step 5: Commit**

```bash
git add CATI/Analysis/SL/_breakdowns.do CATI/Analysis/SL/tests/test_breakdowns.py
git commit -m "feat(sl): _breakdowns.do — baseline income quintile + region4 + urban/rural"
```

---

## Task 4: Orchestrator `l2phl_storyline_series.do` + real run (`/avraa-stata` + Stata MCP)

**INVOKE `/avraa-stata`** to author the do-file; then RUN it via the **Stata MCP** (`mcp__stata__run_do_file`) on the real HF masters.

**Files:**
- Create: `CATI/Analysis/SL/l2phl_storyline_series.do`
- Generated: `CATI/Analysis/SL/sl_series.json`

**Contract.** The do-file (author register = survey pipeline; full portable preamble per `/avraa-stata`):
1. Preamble + path globals (mirror `l2phl_master_analysis.do`; `$dta` points at the HF masters dir).
2. **Food insecurity** — load `l2phl_M08_food_nonfood.dta` (the M08 master holding the FIES items; confirm item vars with `codebook`), recode FIES, `gen mod_sev = (fies_score>=3)`, `svyset psu [pweight=hhw], strata(stratum)`, `include _breakdowns.do`. `stat_open "$wd/sl_series.json"`. `series_emit food_insecurity mod_sev, label("Moderate-to-severe food insecurity") unit("pct") round(round) quintile(inc_q) region(reg4) urbrur(urbrur)`.
3. **Any shock** — load `l2phl_M03_shock.dta`, `gen any_shock = (sh1==1)` (sh1 = M03 "experienced any shock" gate per the grounding map; confirm with `codebook sh1` on the master and adjust the coding if needed), `svyset psu [pweight=hhw], strata(stratum)`, `include _breakdowns.do`, `series_emit any_shock any_shock, label("Households reporting any shock") unit("pct") round(round) quintile(inc_q) region(reg4) urbrur(urbrur)`.
4. `stat_close`.

- [ ] **Step 1: Author the do-file** — invoke `/avraa-stata`. (No unit test; validated by the run + Task 1's `validate_series` in Step 3.)

- [ ] **Step 2: Run on real data via Stata MCP**

Use `mcp__stata__run_do_file` with `CATI/Analysis/SL/l2phl_storyline_series.do`. Read the log for errors.
Expected: `sl_series.json` written.

- [ ] **Step 3: Validate the output shape**

Run:
```bash
cd CATI/Analysis/SL && python3 -c "from series import load_series, validate_series, indicator_keys; d=load_series('sl_series.json'); validate_series(d); print('OK', indicator_keys(d))"
```
Expected: `OK ['any_shock', 'food_insecurity']`. If `$HAS_INCQ==0` (baseline crosswalk missing), the `by_quintile` blocks will be absent — note this and continue (region + urban/rural still present); flag the crosswalk path to the user as a prerequisite to resolve before Slice 2.

- [ ] **Step 4: Commit**

```bash
git add CATI/Analysis/SL/l2phl_storyline_series.do CATI/Analysis/SL/sl_series.json
git commit -m "feat(sl): storyline series orchestrator + sl_series.json (Topic 1 indicators)"
```

---

## Task 5: Shared theme `storyline.css` (extract + adapt the baseline)

**Files:** Create `CATI/Analysis/SL/storyline.css`

No unit test (visual; verified in Task 8 build + browser). **Do NOT invent a theme — extract the proven baseline design system and adapt it.**

- [ ] **Step 1: Extract the baseline `<style>` block into `storyline.css`**

The baseline story's CSS lives between `<style>` (line 13) and `</style>` (line 278). Pull the inner CSS (lines 14–277) verbatim as the base:

```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
sed -n '14,277p' CAPI/Analysis/SL/html/l2phl_baseline_story.html > CATI/Analysis/SL/storyline.css
```

This brings the editorial design system: the `:root` palette + font vars (`--serif` Playfair Display, `--body` Source Serif 4, `--mono` IBM Plex Mono, `--ink` `--paper` `--cream` `--rule` + WB/PH colors), and the chapter classes `.chap` · `.eyebrow` · `.hed` · `.two-col` · `.body-copy` · `.sgrid/.scell/.scell-n/.scell-l` · `.cbox` · `.rev/.rev.vis/.rev.d1-3`.

- [ ] **Step 2: Append the interactive-chart additions** (these are the only things the baseline lacks — chips, scrubber, chart-wrap — styled with the baseline's own vars so they match)

Append to `CATI/Analysis/SL/storyline.css`:

```css
/* --- CATI additions: interactive R1–R8 breakdown chart (mounted inside a .cbox) --- */
.chips-bd{display:flex;gap:6px;flex-wrap:wrap;margin-bottom:14px;}
.chip{font-family:var(--mono);font-size:11px;letter-spacing:.04em;background:var(--cream);
  color:var(--ink);padding:5px 12px;border:1px solid var(--rule);border-radius:2px;cursor:pointer;}
.chip.on{background:var(--ink);color:#fff;border-color:var(--ink);}
.chip[disabled]{opacity:.4;cursor:not-allowed;}
.scrub{display:flex;align-items:center;gap:10px;font-family:var(--mono);font-size:11px;
  color:var(--muted);margin-top:14px;}
.scrub input{flex:1;}
.chart-wrap{position:relative;height:260px;}
.cbox h3{font-family:var(--mono);font-size:12px;letter-spacing:.06em;text-transform:uppercase;
  color:var(--ink);margin:0 0 12px;}
/* hub cards reuse .cbox; minimal grid */
.hubgrid{display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:14px;margin:30px 0;}
.tcard{display:block;background:#fff;border:1px solid var(--rule);border-top:3px solid var(--ink);
  border-radius:3px;padding:16px;box-shadow:0 2px 12px rgba(0,0,0,.05);}
.tcard .t{font-family:var(--serif);font-size:1.15rem;font-weight:900;color:var(--ink);}
.tcard .m{font-family:var(--mono);font-size:10px;letter-spacing:.06em;margin:4px 0 8px;}
.tcard .h{font-family:var(--serif);font-size:1.05rem;font-weight:700;color:var(--ink);}
.tcard.soon{opacity:.55;pointer-events:none;}
.tcard.soon::after{content:"Slice 2";font-family:var(--mono);font-size:9px;background:var(--cream);
  color:var(--muted);padding:2px 7px;border-radius:9px;float:right;}
/* page container + landing hero (baseline-styled) */
.storywrap{max-width:1080px;margin:0 auto;padding:0 28px;}
.hero{background:#002244;color:#fff;padding:46px 40px;margin-bottom:8px;}
.hero .kicker{font-family:var(--mono);font-size:12px;letter-spacing:.18em;text-transform:uppercase;color:var(--wb-sky);font-weight:600;}
.hero h1{font-family:var(--serif);font-size:clamp(2rem,3.6vw,2.9rem);font-weight:900;line-height:1.08;margin:10px 0 8px;}
.hero p{font-family:var(--body);font-size:1rem;color:#cfe3f2;max-width:680px;margin:0;}
.hero .chips{margin-top:16px;display:flex;gap:8px;flex-wrap:wrap;font-family:var(--mono);font-size:11px;}
.hero .chips span{background:rgba(255,255,255,.15);padding:4px 11px;border-radius:2px;}
```

- [ ] **Step 3: Sanity-check the extraction**

Run:
```bash
cd CATI/Analysis/SL && grep -c -E '\.(chap|eyebrow|hed|two-col|body-copy|sgrid|cbox|rev)\b' storyline.css
```
Expected: a count ≥ 8 (the chapter classes came across). If 0, the line range shifted — re-locate `<style>`/`</style>` with `grep -n` and re-extract.

- [ ] **Step 4: Commit**

```bash
git add CATI/Analysis/SL/storyline.css
git commit -m "feat(sl): storyline.css — adapt baseline editorial theme + interactive-chart styles"
```

---

## Task 6: Shared engine `storyline.js` + node tests

**Files:**
- Create: `CATI/Analysis/SL/storyline.js`
- Test: `CATI/Analysis/SL/tests/test_storyline_engine.mjs`

The engine exposes **pure helpers** (unit-tested in node) plus DOM wiring (guarded so it's a no-op under node). Beats carry `data-indicator`, `data-breakdown`, `data-round` (max round to reveal); the engine swaps the sticky chart on scroll, and the breakdown chips / round scrubber re-render it.

- [ ] **Step 1: Write the failing node test**

```js
// CATI/Analysis/SL/tests/test_storyline_engine.mjs
import assert from "node:assert";
import { availableBreakdowns, seriesFor, clampRound, sliceTo, PALETTE } from "../storyline.js";

const entry = {
  rounds:[1,2,3,4,5,6,7,8], overall:[41,31,26.8,21.5,18.2,17,16.4,18],
  by_quintile:{Poorest:[60,55,50,46,44,43,42,45], Richest:[20,15,12,10,9,8,8,9]},
  by_region:{NCR:[30,25,20,18,16,15,15,16]}
};

assert.deepStrictEqual(availableBreakdowns(entry), ["overall","quintile","region"]);
assert.deepStrictEqual(seriesFor(entry,"overall"), {Overall:[41,31,26.8,21.5,18.2,17,16.4,18]});
assert.deepStrictEqual(Object.keys(seriesFor(entry,"quintile")), ["Poorest","Richest"]);
assert.strictEqual(clampRound(99,8),8);
assert.strictEqual(clampRound(0,8),1);
assert.deepStrictEqual(sliceTo([1,2,3,4,5,6,7,8],4),[1,2,3,4]);
assert.ok(Array.isArray(PALETTE) && PALETTE.length>=5);
console.log("storyline engine: OK");
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd CATI/Analysis/SL && node tests/test_storyline_engine.mjs`
Expected: FAIL (cannot find module ../storyline.js / undefined exports).

- [ ] **Step 3: Implement `storyline.js`**

```js
// CATI/Analysis/SL/storyline.js — shared scrollytelling + interactive-chart engine.
// Pure helpers are ESM-exported for tests; DOM wiring runs only in a browser.
export const PALETTE = ["#002244","#009FDA","#00A651","#CE1126","#FCD116","#40B4E5","#7E57C2"];
const BD_LABEL = {quintile:"Income quintile", region:"Region", urbrur:"Urban/rural", sexage:"Sex/age"};

export function availableBreakdowns(entry){
  const out=["overall"];
  for(const k of Object.keys(entry)) if(k.startsWith("by_")) out.push(k.slice(3));
  return out;
}
export function seriesFor(entry, breakdown){
  if(breakdown==="overall") return {Overall: entry.overall};
  return entry["by_"+breakdown] || {Overall: entry.overall};
}
export function clampRound(r,n){ return Math.max(1, Math.min(r,n)); }
export function sliceTo(arr,maxRound){ return arr.slice(0, maxRound); }

// ---- DOM wiring (browser only) ----
function isBrowser(){ return typeof document!=="undefined" && typeof window!=="undefined"; }
function buildDatasets(entry, breakdown, maxRound){
  const groups = seriesFor(entry, breakdown);
  return Object.entries(groups).map(([name,arr],i)=>({
    label:name, data:sliceTo(arr,maxRound), borderColor:PALETTE[i%PALETTE.length],
    backgroundColor:"transparent", borderWidth:2.5, tension:.25, pointRadius:2
  }));
}
function initStoryline(){
  if(!isBrowser()) return;
  const seriesEl=document.getElementById("sl-series");
  if(!seriesEl) return;
  const flat=JSON.parse(seriesEl.textContent);
  const SERIES={}; for(const k in flat){ if(k.startsWith("series.")){ const [, name, leaf]=k.split("."); (SERIES[name]=SERIES[name]||{})[leaf]=flat[k]; } }
  const card=document.getElementById("sl-chart"); if(!card) return;
  const ctx=card.querySelector("canvas"); const title=card.querySelector("h3");
  const chips=card.querySelector(".chips-bd"); const scrub=card.querySelector('input[type=range]');
  let state={indicator:null, breakdown:"overall", maxRound:8};
  let chart=null;
  function render(){
    const e=SERIES[state.indicator]; if(!e) return;
    title.textContent=e.label||state.indicator;
    state.maxRound=clampRound(state.maxRound, e.rounds.length);
    const labels=sliceTo(e.rounds.map(r=>"R"+r), state.maxRound);
    const datasets=buildDatasets(e, state.breakdown, state.maxRound);
    if(chart) chart.destroy();
    chart=new Chart(ctx,{type:"line",data:{labels,datasets},
      options:{responsive:true,maintainAspectRatio:false,
        scales:{x:{grid:{display:false}},y:{beginAtZero:true,ticks:{callback:v=>v+"%"}}},
        plugins:{legend:{display:datasets.length>1,position:"bottom",labels:{boxWidth:10,font:{size:10}}},
                 tooltip:{callbacks:{label:c=>`${c.dataset.label} · R${c.dataIndex+1}: ${c.parsed.y}%`}}}}});
    // sync chips
    if(chips){ const avail=availableBreakdowns(e);
      chips.querySelectorAll(".chip").forEach(ch=>{
        const bd=ch.dataset.bd; ch.disabled=!avail.includes(bd); ch.classList.toggle("on",bd===state.breakdown);});
    }
  }
  if(chips) chips.addEventListener("click",ev=>{ const ch=ev.target.closest(".chip"); if(!ch||ch.disabled) return;
    state.breakdown=ch.dataset.bd; render(); });
  if(scrub) scrub.addEventListener("input",()=>{ state.maxRound=+scrub.value; render(); });
  // scroll: each .beat updates state to its indicator/breakdown/round
  const io=new IntersectionObserver(es=>es.forEach(e=>{ if(e.isIntersecting){
    const b=e.target.dataset; if(b.indicator) state.indicator=b.indicator;
    if(b.breakdown) state.breakdown=b.breakdown; if(b.round) state.maxRound=+b.round; render(); }}),{threshold:.55});
  document.querySelectorAll(".beat").forEach(b=>io.observe(b));
  // initial
  const first=document.querySelector(".beat"); if(first){ const b=first.dataset;
    state.indicator=b.indicator; state.breakdown=b.breakdown||"overall"; state.maxRound=+(b.round||8); render(); }
}
if(isBrowser()) window.addEventListener("DOMContentLoaded", initStoryline);
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd CATI/Analysis/SL && node tests/test_storyline_engine.mjs`
Expected: prints `storyline engine: OK` (exit 0).

- [ ] **Step 5: Commit**

```bash
git add CATI/Analysis/SL/storyline.js CATI/Analysis/SL/tests/test_storyline_engine.mjs
git commit -m "feat(sl): storyline.js — shared scrollytelling engine + node tests"
```

---

## Task 7: Builder `build_storyline.py` + theme registry + tests

**Files:**
- Create: `CATI/Analysis/SL/topics_registry.py`, `CATI/Analysis/SL/build_storyline.py`
- Test: `CATI/Analysis/SL/tests/test_build_storyline.py`

The builder assembles a **self-contained** topic page: read the topic content fragment, wrap it with the hero scaffold, **inline** `storyline.css` (in `<style>`), the Chart.js CDN `<script src>`, the topic's `sl_series.json` slice (in `<script id="sl-series" type="application/json">`), `storyline.js` (in a `<script type="module">` with the `export`/`import` lines stripped so it runs inline), and the point-stats block; then run the existing `build_story.inject` to bind `data-stat` spans. It also builds the hub from `topics_registry.TOPICS`.

- [ ] **Step 1: Write the theme registry**

```python
# CATI/Analysis/SL/topics_registry.py
"""The 9 storyline themes. Slice 1 builds only those with live=True."""
TOPICS = [
  {"slug":"recovery","title":"Recovery is measurable","modules":"Food · Shocks",
   "headline":"Food stress 41% → 18%","accent":"#00A651","spark":"food_insecurity","live":True},
  {"slug":"vulnerability","title":"Vulnerability hasn't moved","modules":"Finance · Employment · Shocks",
   "headline":"~2% can cover an emergency","accent":"#CE1126","spark":None,"live":False},
  {"slug":"digital","title":"The digital shift","modules":"Finance",
   "headline":"Mobile money → 50%","accent":"#009FDA","spark":None,"live":False},
  {"slug":"work","title":"Work without security","modules":"Employment · Income",
   "headline":"72% have no contract","accent":"#002244","spark":None,"live":False},
  {"slug":"lifelines","title":"Lifelines","modules":"Migration · Finance",
   "headline":"24% got a Dec remittance","accent":"#FCD116","spark":None,"live":False},
  {"slug":"mideast","title":"The Middle East crisis","modules":"Views · Migration · Finance",
   "headline":"Exposure & remittance risk","accent":"#CE1126","spark":None,"live":False},
  {"slug":"uneven","title":"Uneven recovery","modules":"ALL · by income & region",
   "headline":"The equity lens","accent":"#009FDA","spark":None,"live":False},
  {"slug":"health","title":"Health under pressure","modules":"Health · Shocks",
   "headline":"Coverage & out-of-pocket","accent":"#002244","spark":None,"live":False},
  {"slug":"mood","title":"The national mood","modules":"Views",
   "headline":"Satisfaction 2.85/5 · AI worry","accent":"#FCD116","spark":None,"live":False},
]
```

- [ ] **Step 2: Write the failing test**

```python
# CATI/Analysis/SL/tests/test_build_storyline.py
import os, json, subprocess, sys, pytest
SL = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

def _run(args):
    return subprocess.run([sys.executable, os.path.join(SL,"build_storyline.py"), *args],
                          cwd=SL, capture_output=True, text=True)

def test_build_topic_selfcontained_and_bound(tmp_path):
    r = _run(["--topic","recovery","--outdir",str(tmp_path)])
    assert r.returncode==0, r.stderr
    html = open(os.path.join(tmp_path,"l2p_cati_recovery.html"),encoding="utf-8").read()
    # self-contained: engine + baseline theme + fonts + chart lib + series all inlined
    assert "scrollytelling engine" in html          # storyline.js banner
    assert "--ink:#002244" in html                   # baseline editorial theme inlined
    assert "Playfair+Display" in html                # baseline display font
    assert "chart.umd.js" in html                    # Chart.js CDN
    assert 'id="sl-series"' in html                  # series JSON embedded
    # no bare module syntax left (stripped so it runs inline)
    assert "export function availableBreakdowns" not in html
    assert "import assert" not in html
    # data-stat bound (no leftover placeholder)
    assert ">OLD<" not in html

def test_build_hub_has_nine_cards(tmp_path):
    r = _run(["--hub","--outdir",str(tmp_path)])
    assert r.returncode==0, r.stderr
    html = open(os.path.join(tmp_path,"l2p_cati_hub.html"),encoding="utf-8").read()
    assert html.count('class="tcard') == 9
    assert 'href="l2p_cati_recovery.html"' in html   # live topic linked
    assert html.count("soon") >= 8                    # 8 not-yet-live

def test_check_passes_after_build(tmp_path):
    _run(["--topic","recovery","--outdir",str(tmp_path)])
    r = _run(["--topic","recovery","--outdir",str(tmp_path),"--check"])
    assert r.returncode==0, r.stderr
    assert "CHECK OK" in r.stdout
```

- [ ] **Step 3: Run to verify it fails** — `python3 -m pytest tests/test_build_storyline.py -q` → FAIL (no build_storyline.py).

- [ ] **Step 4: Implement `build_storyline.py`**

```python
# CATI/Analysis/SL/build_storyline.py
"""Assemble self-contained CATI storyline pages (topics + hub) from templates + JSON."""
import argparse, json, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from build_story import inject            # reuse the data-stat injector
from series import load_series, validate_series
from topics_registry import TOPICS

CHARTJS = '<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.js"></script>'
FONT = ('<link rel="preconnect" href="https://fonts.googleapis.com">'
        '<link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;700;900'
        '&family=Source+Serif+4:opsz,wght@8..60,300;8..60,400;8..60,600'
        '&family=IBM+Plex+Mono:wght@400;500&display=swap" rel="stylesheet">')

def _read(p):
    with open(p, encoding="utf-8") as f: return f.read()

def _engine_inline():
    """storyline.js minus ESM import/export so it runs as a plain inline script."""
    js = _read(os.path.join(HERE,"storyline.js"))
    js = re.sub(r'^export\s+', '', js, flags=re.M)          # drop 'export'
    js = re.sub(r'^import\s+.*$', '', js, flags=re.M)        # drop any imports
    return "/* scrollytelling engine */\n" + js

def _series_for_topic(slug):
    """Embed only the series this topic uses (Slice 1: recovery uses both)."""
    path = os.path.join(HERE,"sl_series.json")
    flat = json.load(open(path, encoding="utf-8"))
    return {k:v for k,v in flat.items() if k.startswith("series.") or k=="_meta"}

# Slice-1 prose binds to numbers DERIVED from the series (single source of truth):
# food.* / shock.* groups built from each indicator's overall[] endpoints.
_DERIVE_MAP = {"food_insecurity": "food", "any_shock": "shock"}
def _derive_pointstats(series_path):
    nested = load_series(series_path)                 # {'series': {...}, '_meta': ...}
    out = {}
    for ind, grp in _DERIVE_MAP.items():
        e = nested.get("series", {}).get(ind)
        if e and e.get("overall"):
            ov = e["overall"]
            out[grp] = {"r1": round(ov[0], 1), "r8": round(ov[-1], 1),
                        "drop": round(ov[0] - ov[-1], 1)}
    return out

def build_topic(slug, outdir, check=False):
    frag = _read(os.path.join(HERE,"topics",f"{slug}.html"))
    css  = _read(os.path.join(HERE,"storyline.css"))
    series = _series_for_topic(slug)
    bind = _derive_pointstats(os.path.join(HERE,"sl_series.json"))
    if os.path.exists(os.path.join(HERE,"sl_stats.json")):
        bind.update(json.load(open(os.path.join(HERE,"sl_stats.json"), encoding="utf-8")))
    doc = f"""<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>L2Phl CATI Panel — {slug}</title>{FONT}{CHARTJS}
<style>{css}</style></head><body>
<main class="storywrap">{frag}</main>
<script id="sl-series" type="application/json">{json.dumps(series).replace('</','<\\/')}</script>
<script id="sl-data" type="application/json">{json.dumps(bind).replace('</','<\\/')}</script>
<script>{_engine_inline()}</script>
</body></html>"""
    built, _report = inject(doc, bind, "charts")
    out = os.path.join(outdir, f"l2p_cati_{slug}.html")
    if check:
        prev = _read(out) if os.path.exists(out) else ""
        if prev != built:
            print("CHECK FAILED: drift: rebuild needed"); return 1
        print("CHECK OK"); return 0
    os.makedirs(outdir, exist_ok=True)
    with open(out,"w",encoding="utf-8") as f: f.write(built)
    print(f"Built {out}"); return 0

def build_hub(outdir, check=False):
    css = _read(os.path.join(HERE,"storyline.css"))
    cards=[]
    for t in TOPICS:
        cls = "tcard" if t["live"] else "tcard soon"
        inner = (f'<div class="t">{t["title"]}</div>'
                 f'<div class="m" style="color:{t["accent"]}">{t["modules"]}</div>'
                 f'<div class="h">{t["headline"]}</div>')
        cards.append(f'<a class="{cls}" style="border-top-color:{t["accent"]}" '
                     f'href="l2p_cati_{t["slug"]}.html">{inner}</a>' if t["live"]
                     else f'<div class="{cls}" style="border-top-color:{t["accent"]}">{inner}</div>')
    doc = f"""<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>L2Phl CATI Panel — Storylines</title>{FONT}<style>{css}</style></head><body>
<div class="hero"><div class="kicker">Listening to the Philippines · CATI Panel · Rounds 1–8</div>
<h1>Recovery is measurable. Vulnerability is not gone.</h1>
<p>Eight monthly rounds: food stress halved and shocks collapsed — yet savings, secure work, and confidence barely moved.</p>
<div class="chips"><span>2,470 households</span><span>Nov 2025 → Jun 2026</span><span>18 regions</span></div></div>
<div class="storywrap"><div class="hubgrid">{''.join(cards)}</div></div></body></html>"""
    out = os.path.join(outdir,"l2p_cati_hub.html")
    if check:
        prev = _read(out) if os.path.exists(out) else ""
        print("CHECK OK" if prev==doc else "CHECK FAILED: drift: rebuild needed")
        return 0 if prev==doc else 1
    os.makedirs(outdir, exist_ok=True)
    with open(out,"w",encoding="utf-8") as f: f.write(doc)
    print(f"Built {out}"); return 0

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--topic"); ap.add_argument("--hub", action="store_true")
    ap.add_argument("--outdir", default=os.path.join(HERE,"html"))
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    rc = 0
    if a.topic: rc |= build_topic(a.topic, a.outdir, a.check)
    if a.hub:   rc |= build_hub(a.outdir, a.check)
    if not a.topic and not a.hub:
        for t in TOPICS:
            if t["live"]: rc |= build_topic(t["slug"], a.outdir, a.check)
        rc |= build_hub(a.outdir, a.check)
    sys.exit(rc)

if __name__ == "__main__":
    main()
```

- [ ] **Step 5: Run to verify it passes**

Run: `cd CATI/Analysis/SL && python3 -m pytest tests/test_build_storyline.py -q`
Expected: the topic test needs `topics/recovery.html` (Task 8). To unblock Task 7 in isolation, create a minimal stub `topics/recovery.html` with one beat (replaced for real in Task 8), then run. Expected after stub: PASS (3 passed).

- [ ] **Step 6: Commit**

```bash
git add CATI/Analysis/SL/build_storyline.py CATI/Analysis/SL/topics_registry.py CATI/Analysis/SL/tests/test_build_storyline.py
git commit -m "feat(sl): build_storyline.py — self-contained topic+hub assembler"
```

---

## Task 8: Topic 1 content + hub + build + browser review (`/avraa-voice`)

**INVOKE `/avraa-voice` before writing the prose** (broad-science register: short, declarative).

**Files:**
- Create/replace: `CATI/Analysis/SL/topics/recovery.html`
- Generated: `CATI/Analysis/SL/html/l2p_cati_recovery.html`, `html/l2p_cati_hub.html`

**`topics/recovery.html` structure** — a content fragment built on the **baseline chapter template** (mirror `#ch-roster`: `.chap` header band, `.sec`, `.two-col`, `.eyebrow`, `.hed`, `.body-copy`, `.sgrid/.scell`, `.cbox`, `.rev` reveals). The interactive chart is a `.cbox` with `id="sl-chart"`. Reveal-tagged `.body-copy` blocks carry `data-indicator/-breakdown/-round` so the chart advances as the reader scrolls (baseline `.rev` motion + our engine). **Headline numbers are `data-stat` spans bound to the series-derived `food.*` / `shock.*` keys** (`_derive_pointstats`, Task 7) — no separate point-stats run needed.

```html
<!-- chapter header band (baseline .chap) -->
<header class="chap">
  <div class="chap-n">01</div>
  <div>
    <span class="eyebrow">Theme 1 · Food · Shocks</span>
    <h2 class="hed" style="color:#fff;margin:0">Recovery is measurable</h2>
  </div>
</header>

<section class="sec">
  <div class="two-col">
    <!-- LEFT: editorial prose with bound stats + a stat grid -->
    <div>
      <p class="body-copy rev" data-indicator="food_insecurity" data-breakdown="overall" data-round="8">
        <!-- /avraa-voice (broad-science register): opening on the halving. Reference only bound numbers:
             ~<span data-stat="food.r1" data-fmt="pct0">OLD</span> of households were cutting meals when the
             panel began; by Round 8 that had fallen to <span data-stat="food.r8" data-fmt="pct1">OLD</span>. -->
      </p>

      <div class="sgrid sgrid-3 rev d1">
        <div class="scell"><div class="scell-n" data-stat="food.r1" data-fmt="pct0">OLD</div><div class="scell-l">food insecure · R1</div></div>
        <div class="scell"><div class="scell-n" data-stat="food.r8" data-fmt="pct1">OLD</div><div class="scell-l">food insecure · R8</div></div>
        <div class="scell"><div class="scell-n" data-stat="food.drop" data-fmt="ppt">OLD</div><div class="scell-l">point drop</div></div>
      </div>

      <p class="body-copy rev" data-indicator="food_insecurity" data-breakdown="quintile" data-round="8">
        <!-- /avraa-voice: the equity beat — switch the chart to income quintile; the poorest fifth stayed high. -->
      </p>
      <blockquote class="rev">The gains were real — but they did not reach everyone equally.</blockquote>

      <p class="body-copy rev" data-indicator="any_shock" data-breakdown="overall" data-round="8">
        <!-- /avraa-voice: shocks collapsed from <span data-stat="shock.r1" data-fmt="pct0">OLD</span> to
             <span data-stat="shock.r8" data-fmt="pct1">OLD</span>; tie the two recoveries together. -->
      </p>
    </div>

    <!-- RIGHT: interactive chart in a sticky .cbox -->
    <div style="position:sticky;top:24px">
      <div class="cbox" id="sl-chart">
        <h3>Moderate-to-severe food insecurity</h3>
        <div class="chips-bd">
          <button class="chip on" data-bd="overall">Overall</button>
          <button class="chip" data-bd="quintile">Income quintile</button>
          <button class="chip" data-bd="region">Region</button>
          <button class="chip" data-bd="urbrur">Urban/rural</button>
        </div>
        <div class="chart-wrap"><canvas></canvas></div>
        <div class="scrub">R1<input type="range" min="1" max="8" value="8">R8</div>
      </div>
    </div>
  </div>
</section>
```

> If the baseline `.chap`/`.sec` markup differs in detail from the snippet above, open `#ch-roster` in the baseline file and match its exact nesting — the goal is for a CATI topic to read as a sibling chapter of the baseline story.

- [ ] **Step 1: Author the prose** — invoke `/avraa-voice`, fill the three `<p>` beats (broad-science register; concrete, mechanism-minded; no invented numbers — reference only the bound stats and the trends).

- [ ] **Step 2: Build the topic + hub**

Run: `cd CATI/Analysis/SL && python3 build_storyline.py --topic recovery --hub`
Expected: `Built .../html/l2p_cati_recovery.html` and `.../l2p_cati_hub.html`.

- [ ] **Step 3: Drift-check + full test suite**

Run:
```bash
cd CATI/Analysis/SL && python3 build_storyline.py --topic recovery --check && \
python3 build_storyline.py --hub --check && \
node tests/test_storyline_engine.mjs && \
python3 -m pytest tests/ -q
```
Expected: `CHECK OK` (×2), `storyline engine: OK`, all pytest pass (Stata tests may SKIP).

- [ ] **Step 4: Browser review (visual companion)**

Open `CATI/Analysis/SL/html/l2p_cati_recovery.html` and `l2p_cati_hub.html` in a browser. Verify: hero renders; the sticky chart updates as beats scroll; breakdown chips switch series (quintile shows multiple lines; disabled chips for absent breakdowns); the scrubber limits rounds; the hub shows 9 cards with only "Recovery is measurable" linked. Fix CSS/JS issues and rebuild.

- [ ] **Step 5: Commit**

```bash
git add CATI/Analysis/SL/topics/recovery.html CATI/Analysis/SL/html/l2p_cati_recovery.html CATI/Analysis/SL/html/l2p_cati_hub.html
git commit -m "feat(sl): Topic 1 'Recovery is measurable' + hub shell (Slice 1 complete)"
```

---

## Done criteria (Slice 1)

- `python3 -m pytest CATI/Analysis/SL/tests/ -q` passes (Stata tests pass or skip).
- `node CATI/Analysis/SL/tests/test_storyline_engine.mjs` prints OK.
- `build_storyline.py --topic recovery --hub` produces two **self-contained** HTML files; `--check` returns `CHECK OK`.
- Browser review confirms scroll-driven chart, working breakdown toggles + scrubber, and the 9-card hub with Topic 1 live.
- `sl_series.json` validates via `series.validate_series`.

## Notes carried to Slice 2

- Resolve the **baseline income crosswalk** path (`$dta/l2phl_baseline_income_xwalk.dta`) so `inc_q` populates (else quintile breakdowns are absent).
- Wire **sex/age** breakdown for individual-level indicators.
- Author the other 8 topic fragments + extend `l2phl_storyline_series.do` to all indicators; flip `live=True` in `topics_registry.py`.
- Add the grounding/badges pass (`storyline_badges.py`) over the new pages.
```
