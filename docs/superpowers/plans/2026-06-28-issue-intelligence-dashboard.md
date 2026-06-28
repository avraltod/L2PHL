# Issue-Intelligence Dashboard — Implementation Plan (Plan 2: rendering)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Render the issue-intelligence layer in the QC dashboard — a per-round status strip + open-issue RAG on the module cards, and an "Issues" page with per-module issue rows expandable to 3-layer evidence, plus Review-Queue and Firm-Report filters.

**Architecture:** A pure-Python rollup (`issue_rollup.py`) aggregates `issues.json` into per-module per-round status; `build_issues.py` writes it to `cache/issue_summary.json`. `gen_dashboard.py` embeds both `issues.json` and the summary as JS consts and renders the new UI. The per-round strip is coloured by OPEN issues only — so `wontfix`/`accepted` issues stop colouring past rounds.

**Tech Stack:** Python 3.12, pytest (rollup only); the dashboard is a single self-contained HTML built by `gen_dashboard.py` (Python f-string emitting HTML+JS). All under `CATI/Analysis/QC/`.

---

## Scope & verification note

This is **Plan 2 of 2** (Plan 1 = backend, merged). Plan 2 = rendering. **Task 1 is pure Python (pytest-TDD).** Tasks 2–4 edit `gen_dashboard.py` (a ~5400-line HTML/JS generator) — JS UI is not unit-testable here, so each is verified by **regenerating the dashboard and asserting the produced HTML contains the new structures** (grep) plus a JS-syntax sanity check. **`gen_dashboard.py` is fragile** (one giant f-string with embedded JS using `${...}` and `{...}`): edits MUST be surgical and the dashboard MUST regenerate without error after each.

Prereq each run: `cd CATI/Analysis/QC && python3 scripts/build_issues.py` (writes `cache/issues.json`).

## File structure

| File | Change |
|------|--------|
| `scripts/issue_rollup.py` | NEW — `rollup(records, rounds) -> {module: {...}}` |
| `tests/test_issue_rollup.py` | NEW — pytest |
| `scripts/build_issues.py` | MODIFY — also write `cache/issue_summary.json` |
| `scripts/gen_dashboard.py` | MODIFY — embed consts + CSS (Task 2), card strip (Task 3), Issues page (Task 4) |

**Canonical rollup shape** (every task assumes this):
```python
# rollup(records, rounds=range(1,9)) -> {
#   "M04": {
#     "strip": {"1":"green","2":"red",...,"8":"yellow"},  # per-round worst-OPEN status
#     "headline": "yellow",          # = strip[last round present], else "green"
#     "open": 2, "closed": 1,        # issue counts by lifecycle group
#     "by_owner": {"firm-field": 2}  # owner -> count, OPEN issues only
#   }, ...
# }
# Per-round status: among issues with counts_by_round[r] > 0 ->
#   "red"   if any OPEN issue with verdict in {A1,A2,B}
#   "yellow"if any OPEN issue (else)
#   "closed"if only CLOSED issues have a count there
#   "green" if no issue has a count there
```

---

## Task 1: Rollup (`issue_rollup.py`)

**Files:** Create `scripts/issue_rollup.py`, `tests/test_issue_rollup.py`.

- [ ] **Step 1: Write the failing test** — `tests/test_issue_rollup.py`:
```python
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))
from issue_rollup import rollup

def rec(module, verdict, status, counts):
    return {"module":module,"verdict":verdict,"status":status,"counts_by_round":counts}

def test_open_firm_issue_reds_the_round():
    recs = [rec("M04","A2","acknowledged",{"7":80,"8":59})]
    out = rollup(recs)
    assert out["M04"]["strip"]["8"] == "red"      # open A2 with count in R8
    assert out["M04"]["strip"]["7"] == "red"
    assert out["M04"]["strip"]["1"] == "green"     # no count there
    assert out["M04"]["headline"] == "red"         # last round present = R8
    assert out["M04"]["open"] == 1 and out["M04"]["by_owner"] == {"firm-field": 1}

def test_closed_issue_is_grey_not_red():
    recs = [rec("M01","A2","wontfix",{"3":12})]
    out = rollup(recs)
    assert out["M01"]["strip"]["3"] == "closed"    # closed -> not coloured
    assert out["M01"]["open"] == 0 and out["M01"]["closed"] == 1
    assert out["M01"]["headline"] == "green"        # latest present round (R3) is closed -> green headline

def test_open_nonfirm_is_yellow():
    recs = [rec("M00","D","new",{"5":9})]
    out = rollup(recs)
    assert out["M00"]["strip"]["5"] == "yellow"    # open but verdict D (not A1/A2/B)

def test_red_beats_yellow_and_closed_same_round():
    recs = [rec("M04","A2","acknowledged",{"8":5}),
            rec("M04","D","new",{"8":3}),
            rec("M04","B","resolved",{"8":1})]
    out = rollup(recs)
    assert out["M04"]["strip"]["8"] == "red"       # worst wins
    assert out["M04"]["open"] == 2 and out["M04"]["closed"] == 1
```

- [ ] **Step 2: Run, expect FAIL.** `cd CATI/Analysis/QC && python3 -m pytest tests/test_issue_rollup.py -q` → ModuleNotFoundError.

- [ ] **Step 3: Implement** `scripts/issue_rollup.py`:
```python
"""Roll up issue records into per-module per-round dashboard status."""
from collections import Counter

OPEN_STATES   = {"new", "acknowledged", "fix-pending", "reopened"}
FIRM_VERDICTS = {"A1", "A2", "B"}

def rollup(records, rounds=range(1, 9)):
    out = {}
    by_mod = {}
    for r in records:
        by_mod.setdefault(r["module"], []).append(r)
    for mod, recs in by_mod.items():
        strip = {}
        for rd in rounds:
            k = str(rd)
            here = [r for r in recs if r.get("counts_by_round", {}).get(k)]
            open_here = [r for r in here if r.get("status") in OPEN_STATES]
            if any(r.get("verdict") in FIRM_VERDICTS for r in open_here):
                strip[k] = "red"
            elif open_here:
                strip[k] = "yellow"
            elif here:
                strip[k] = "closed"
            else:
                strip[k] = "green"
        present = [str(rd) for rd in rounds
                   if any(r.get("counts_by_round", {}).get(str(rd)) for r in recs)]
        headline = strip[present[-1]] if present else "green"
        if headline == "closed":
            headline = "green"
        open_issues = [r for r in recs if r.get("status") in OPEN_STATES]
        out[mod] = {
            "strip": strip,
            "headline": headline,
            "open": len(open_issues),
            "closed": len(recs) - len(open_issues),
            "by_owner": dict(Counter(r.get("owner") for r in open_issues if r.get("owner"))),
        }
    return out
```

- [ ] **Step 4: Run, expect PASS (4 passed).** `cd CATI/Analysis/QC && python3 -m pytest tests/test_issue_rollup.py -q`

- [ ] **Step 5: Commit.**
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git add CATI/Analysis/QC/scripts/issue_rollup.py CATI/Analysis/QC/tests/test_issue_rollup.py
git commit -m "feat(qc): per-module per-round issue rollup"
```

---

## Task 2: build_issues writes issue_summary.json + embed consts/CSS in dashboard

**Files:** MODIFY `scripts/build_issues.py`, `scripts/gen_dashboard.py`.

- [ ] **Step 1: build_issues writes the summary.** In `scripts/build_issues.py`:
  - Add `from issue_rollup import rollup` to the imports.
  - In `main()`, right after the line that writes `issues.json` (`json.dump(out["issues"], open(...issues.json..."w"), indent=2)`), add:
```python
    summ = rollup(out["issues"])
    json.dump(summ, open(os.path.join(_CACHE, "issue_summary.json"), "w"), indent=2)
```
  - Run `cd CATI/Analysis/QC && python3 scripts/build_issues.py` and confirm `cache/issue_summary.json` is written with per-module keys (`python3 -c "import json; d=json.load(open('cache/issue_summary.json')); print(list(d)[:3], d.get('M04'))"`).

- [ ] **Step 2: Load issues + summary in gen_dashboard.** In `scripts/gen_dashboard.py`, find the kobo-load block (ends `kobo_raw = {}` around line 223). Immediately AFTER it, add:
```python
_issues_path = _os.path.join(_CACHE, 'issues.json')
issues_raw = json.load(open(_issues_path)) if _os.path.exists(_issues_path) else []
_isum_path = _os.path.join(_CACHE, 'issue_summary.json')
isum_raw = json.load(open(_isum_path)) if _os.path.exists(_isum_path) else {}
```

- [ ] **Step 3: Dump to JS strings.** Find the dumps block (`KOBO = json.dumps(kobo_raw, ...)`, ~line 1421). Immediately after it add:
```python
ISSUES = json.dumps(issues_raw, separators=(',',':'))
ISUM   = json.dumps(isum_raw,   separators=(',',':'))
```

- [ ] **Step 4: Embed as JS consts.** Find `const KOBO = """ + KOBO + """;` (~line 2044). Immediately after it add:
```python
const ISSUES = """ + ISSUES + """;
const ISUM   = """ + ISUM + """;
```

- [ ] **Step 5: Add CSS** for the strip/verdict/status. Find the `.rag-chip{` CSS rule (~line 1530) and add these rules right after it (still inside the same `<style>` block / Python string):
```python
.istrip{display:flex;gap:3px;margin:4px 0}
.idot{width:13px;height:13px;border-radius:3px;font-size:8px;text-align:center;line-height:13px;color:#fff}
.idot.red{background:#e74c3c}.idot.yellow{background:#f1c40f;color:#5b4a00}.idot.green{background:#cfe8d6;color:#cfe8d6}.idot.closed{background:#d6d6d6;color:#888}
.vbadge{display:inline-block;font-size:9px;font-weight:700;border-radius:3px;padding:1px 5px;color:#fff}
.vbadge.A1,.vbadge.A2{background:#c0392b}.vbadge.B{background:#e67e22}.vbadge.C{background:#8e44ad}.vbadge.D{background:#95a5a6}.vbadge.REVIEW{background:#34495e}
.schip{display:inline-block;font-size:9px;border-radius:8px;padding:1px 6px;background:#ecf0f1;color:#34495e;margin-left:4px}
.evbox{background:#f7f9fb;border-left:3px solid #4db8ff;padding:8px 11px;margin-top:5px;font-size:11px;font-family:monospace;line-height:1.5;white-space:pre-wrap}
```

- [ ] **Step 6: Verify generation + embedding.**
```bash
cd CATI/Analysis/QC && python3 scripts/gen_dashboard.py 2>&1 | tail -1
grep -c "const ISSUES" output/l2ph_dq_dashboard.html      # expect 1
grep -c "const ISUM" output/l2ph_dq_dashboard.html        # expect 1
grep -c "class=\"istrip\"\|idot\|vbadge\|evbox" output/l2ph_dq_dashboard.html  # CSS present (>=4)
python3 -c "import json,re,sys; h=open('output/l2ph_dq_dashboard.html').read(); print('html bytes', len(h))"
```
Expected: dashboard regenerates ("Generated: …"), `const ISSUES`/`const ISUM` present once each, CSS classes present.

- [ ] **Step 7: Commit.**
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git add CATI/Analysis/QC/scripts/build_issues.py CATI/Analysis/QC/scripts/gen_dashboard.py
git commit -m "feat(qc): emit issue_summary.json; embed issues + CSS in dashboard"
```

---

## Task 3: Per-round strip + open-issue summary on overview module cards

**Files:** MODIFY `scripts/gen_dashboard.py` (the `mod-grid` card template, ~lines 2384–2422).

- [ ] **Step 1: Compute the issue rollup + strip inside the card map.** In the `MODULES.map(m=>{ ... })` block, find `const s = DQ.module_summary[m]||{};` (~line 2384) and add right after it:
```javascript
    const iss = ISUM[m] || {strip:{}, headline:'green', open:0, closed:0, by_owner:{}};
    const istrip = [1,2,3,4,5,6,7,8].map(r=>{
      const st = iss.strip[String(r)] || 'green';
      const ch = st==='closed' ? '·' : (st==='red'?'!':(st==='yellow'?'·':''));
      return `<span class="idot ${st}" title="R${r}: ${st}">${ch}</span>`;
    }).join('');
    const ownerBits = Object.entries(iss.by_owner||{}).map(([o,n])=>`${n} ${o.replace('firm-','')}`).join(' · ');
```

- [ ] **Step 2: Insert the strip + open/closed line into the card body.** Find the card `return \`<div class="mod-card ...` template and add the strip and an issue line. Specifically, immediately AFTER the `<div class="mname">...` line (`<div class="mname">${m} – ${MOD_NAMES[m]}</div>`), insert:
```javascript
      <div class="istrip" title="Per-round status (open issues only)">${istrip}</div>
      <div class="mstat">Issues: ${iss.open} open${ownerBits?` (${ownerBits})`:''} · ${iss.closed} closed</div>
```
(Leave the existing skip/mandatory/max-missing mstat lines as-is — they stay for continuity.)

- [ ] **Step 3: Verify.**
```bash
cd CATI/Analysis/QC && python3 scripts/gen_dashboard.py 2>&1 | tail -1
grep -c "class=\"istrip\"" output/l2ph_dq_dashboard.html          # >=1 (rendered in card template)
grep -o "Issues: \${iss.open} open" output/l2ph_dq_dashboard.html | head -1   # template line present
```
Expected: regenerates cleanly; the card template now contains the `istrip` and the `Issues:` line. (Open the dashboard in a browser to eyeball the strip on the M04 card if possible.)

- [ ] **Step 4: Commit.**
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git add CATI/Analysis/QC/scripts/gen_dashboard.py
git commit -m "feat(qc): per-round issue strip + open-issue summary on module cards"
```

---

## Task 4: "Issues" page — issue list + 3-layer evidence drill-in + Review/Firm filters

**Files:** MODIFY `scripts/gen_dashboard.py` (sidebar nav, a new page div, and a render function).

- [ ] **Step 1: Add the sidebar nav entry.** Find the closing of the nav (`</nav>` ~line 1689, preceded by the "Questionnaire Changes" section). Immediately BEFORE `</nav>`, insert:
```python
  <div class="nav-section">Issue Intelligence</div>
  <a href="#" onclick="return showPage('issues')" id="nav-issues">
    <span class="dot" style="background:#e74c3c"></span>Issues &amp; Root Cause
  </a>
```

- [ ] **Step 2: Add the page container.** Find `<div id="page-overview" class="page active">` (~line 1693). Immediately BEFORE it, insert a new page div:
```python
<div id="page-issues" class="page">
<h1>Issue Intelligence</h1>
<p class="subtitle">Every flag root-caused to a layer · A1 questionnaire · A2 field · B firm do-file · C our check · D structural</p>
<div style="margin:8px 0"><label><input type="checkbox" id="iss-firm-only" onchange="renderIssues()"> Firm report only (A1/A2/B, open)</label>
&nbsp;&nbsp;<label><input type="checkbox" id="iss-review-only" onchange="renderIssues()"> Review queue only</label></div>
<div id="issues-body"></div>
</div>
```

- [ ] **Step 3: Add the render function + call it in showPage.** Find `function showPage(id){` (~line 2301). Immediately BEFORE it, insert the renderer:
```python
function renderIssues(){
  const firmOnly = document.getElementById('iss-firm-only') && document.getElementById('iss-firm-only').checked;
  const revOnly  = document.getElementById('iss-review-only') && document.getElementById('iss-review-only').checked;
  const OWN = {A1:'firm-questionnaire',A2:'firm-field',B:'firm-dofile',C:'us',D:'expected',REVIEW:'unassigned'};
  let rows = ISSUES.slice();
  if(firmOnly) rows = rows.filter(r=>['A1','A2','B'].includes(r.verdict) && ['new','acknowledged','fix-pending','reopened'].includes(r.status));
  if(revOnly)  rows = rows.filter(r=>r.review);
  const byMod = {};
  rows.forEach(r=>{ (byMod[r.module]=byMod[r.module]||[]).push(r); });
  const counts = Object.values(ISUM||{}).reduce((a,s)=>{a.open+=s.open||0;a.closed+=s.closed||0;return a;},{open:0,closed:0});
  let html = `<div class="mstat">Showing ${rows.length} issue(s) · ${counts.open} open / ${counts.closed} closed total</div>`;
  Object.keys(byMod).sort().forEach(m=>{
    html += `<h2 style="margin-top:16px">${m} – ${MOD_NAMES[m]||''}</h2>`;
    byMod[m].forEach((r,i)=>{
      const ev = r.evidence||{}; const k=ev.kobo||{}; const d=ev.dofile||{}; const da=ev.data||{};
      const rel = Object.entries(k.relevant_by_round||{}).slice(-1).map(([rd,x])=>`R${rd}: ${x||'(none)'}`).join('');
      const cnts = Object.entries(r.counts_by_round||{}).map(([rd,n])=>`R${rd}:${n}`).join('  ');
      const did = `iss-${m}-${i}`;
      html += `<div style="border:1px solid #e3e3e3;border-radius:5px;padding:7px 10px;margin:5px 0">
        <div style="cursor:pointer" onclick="var e=document.getElementById('${did}');e.style.display=e.style.display==='none'?'block':'none'">
          <span class="vbadge ${r.verdict}">${r.verdict}</span>
          <span class="schip">${r.status}</span>
          <span class="schip">${OWN[r.verdict]||''}</span>
          <strong style="font-size:12px">&nbsp;${r.variable}</strong>
          <span style="font-size:11px;color:#666">&nbsp;${(r.label||'').slice(0,70)}</span>
          <span style="float:right;font-size:10.5px;color:#888">${cnts}</span>
        </div>
        <div id="${did}" style="display:none"><div class="evbox">Data   · ${da.total||0} total · kind ${da.kind||''}
Kobo   · ${rel||'(var not in Kobo)'}${(k.gate_refs_missing||[]).length?'\\n         gate refs absent from data: '+k.gate_refs_missing.join(', '):''}
Do-file· ${d.ever_touched?'touched by a round do-file':'not touched by any do-file'}
Verdict· ${r.verdict} via ${r.rule_fired} (confidence ${r.confidence})${r.notes?'\\nNote   · '+r.notes:''}</div></div>
      </div>`;
    });
  });
  document.getElementById('issues-body').innerHTML = html || '<p>No issues.</p>';
}
```
Then, INSIDE `function showPage(id){ ... }`, after the existing per-page dispatch logic that calls the other render functions (look for where it calls e.g. `renderOverview()` / `renderPanel()` based on id), add a branch so the issues page renders on show:
```javascript
  if(id==='issues') renderIssues();
```
(Match the existing dispatch style in showPage — if it uses an if/else chain on `id`, add an `else if(id==='issues') renderIssues();`.)

- [ ] **Step 4: Verify.**
```bash
cd CATI/Analysis/QC && python3 scripts/gen_dashboard.py 2>&1 | tail -1
grep -c "id=\"page-issues\"\|function renderIssues\|nav-issues\|Issues &amp; Root Cause" output/l2ph_dq_dashboard.html  # >=4
python3 -c "h=open('output/l2ph_dq_dashboard.html').read(); assert 'renderIssues' in h and 'page-issues' in h; print('issues page present')"
```
Expected: regenerates cleanly; the Issues nav, page, and render function are present. Open in a browser: the "Issues & Root Cause" sidebar item shows the per-module issue list; each row expands to the 3-layer evidence; the two checkboxes filter to firm-report / review-queue.

- [ ] **Step 5: Commit.**
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git add CATI/Analysis/QC/scripts/gen_dashboard.py
git commit -m "feat(qc): Issues page with 3-layer evidence drill-in + review/firm filters"
```

---

## Self-review

**Spec coverage (Section 4 of the design):** per-round strip on module cards (Task 3) ✓; open-issue RAG headline (rollup `headline`, Task 1; surfaced on the card via the strip + open count — note: the card's existing `rag-chip` still uses `DQ.module_summary` and is intentionally LEFT for continuity; the open-issue status is shown via the strip + "Issues: N open" line rather than recolouring the chip — a deliberate, smaller-footprint choice to avoid destabilising the existing RAG. If full chip-recolour is wanted, that's a follow-up) ✓-with-note; verdict=owner colour palette (CSS `.vbadge`, Task 2) ✓; status chip (`.schip`) ✓; 3-layer evidence drill-in (Task 4 evbox) ✓; Review-Queue + Firm-Report filtered views (Task 4 checkboxes) ✓.

**Placeholder scan:** none — every step has concrete code/commands.

**Known limitation (carried):** the card `rag-chip` keeps the legacy `DQ.module_summary` colour; the open-issue status is shown alongside it (strip + counts), not by recolouring the chip. Recolouring the headline chip from `ISUM[m].headline` is a one-line follow-up if desired (`const rag = (ISUM[m]&&ISUM[m].headline)||s.rag||'green';`) but is intentionally deferred so this plan doesn't change the existing module-RAG semantics in the same pass.

**Fragility guard:** Tasks 2–4 each end by regenerating the dashboard and asserting the new HTML markers exist; if `gen_dashboard.py` fails to run after an edit, STOP and fix the f-string/brace before committing.
