# Dashboard Polish — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`).

**Goal:** Three surgical `gen_dashboard.py` edits: open-issue-driven card colour, a strip legend, an Issues-page verdict summary.

**Architecture:** Edits to the overview card-render map (~line 2455), the module-grid container (~line 1771), and `renderIssues()`. UI — verified by regenerating + `node --check` + grep + a `node` eval of the rag formula (no live browser).

**Tech Stack:** Python (gen_dashboard) emitting HTML/JS. Run from `CATI/Analysis/QC/`. Regenerate prereq: `python3 scripts/build_issues.py` (issues.json + issue_summary.json current).

---

## Task 1: Open-issue-driven card colour

**Files:** Modify `scripts/gen_dashboard.py` (card-render map).

- [ ] **Step 1: Replace the rag computation.** Find:
```javascript
    const rag = s.rag||'green';
    const iss = ISUM[m] || {strip:{}, headline:'green', open:0, closed:0, by_owner:{}};
```
Replace with:
```javascript
    const iss = ISUM[m] || {strip:{}, headline:'green', open:0, closed:0, by_owner:{}};
    const _miss = s.max_missing_pct || 0;
    const _missSig = _miss >= 30 ? 'red' : (_miss >= 10 ? 'yellow' : 'green');
    const _ord = {green:0, yellow:1, red:2};
    const _ih = iss.headline || 'green';
    const rag = _ord[_ih] >= _ord[_missSig] ? _ih : _missSig;   // worst of open-issue status + missing%
```

- [ ] **Step 2: Replace the "why" triggers.** Find the block:
```javascript
    // Build "why" triggers list
    const triggers = [];
    if(rag==='red'){
      if((s.n_skip_violations||0)>100) triggers.push(`skip violations (${s.n_skip_violations}) > 100`);
      if((s.n_mandatory_missing||0)>100) triggers.push(`mandatory missing (${s.n_mandatory_missing}) > 100`);
      if((s.max_missing_pct||0)>=30) triggers.push(`worst variable ${s.max_missing_pct}% ≥ 30%`);
    } else if(rag==='yellow'){
      if((s.n_skip_violations||0)>0) triggers.push(`${s.n_skip_violations} skip violation${s.n_skip_violations>1?'s':''}`);
      if((s.n_mandatory_missing||0)>0) triggers.push(`${s.n_mandatory_missing} mandatory missing`);
      if((s.n_oor_values||0)>0) triggers.push(`${s.n_oor_values} out-of-range`);
      if((s.max_missing_pct||0)>=10) triggers.push(`worst variable ${s.max_missing_pct}% ≥ 10%`);
    }
```
Replace with:
```javascript
    // Build "why" triggers list (open-issue + missing-data driven)
    const triggers = [];
    if(iss.open > 0) triggers.push(`${iss.open} open issue${iss.open>1?'s':''}`);
    if(_miss >= 10) triggers.push(`worst variable ${_miss.toFixed(0)}% missing`);
```

- [ ] **Step 3: Regenerate + verify.**
```bash
cd CATI/Analysis/QC && python3 scripts/build_issues.py >/dev/null && python3 scripts/gen_dashboard.py 2>&1 | grep -E "Generated|Error" | tail -1
# embedded script still valid:
python3 - <<'PY'
import re
h=open('output/l2ph_dq_dashboard.html').read()
b=next(x for x in re.findall(r'<script(?![^>]*src=)[^>]*>(.*?)</script>', h, re.S) if 'worst of open-issue' in x)
open('/tmp/_card.js','w').write(b)
PY
node --check /tmp/_card.js && echo "SYNTAX OK"
```
Expected: "Generated …", "SYNTAX OK".

- [ ] **Step 4: node-eval the rag precedence** (confirm worst-of logic):
```bash
node -e '
const _ord={green:0,yellow:1,red:2};
function rag(ih,miss){const ms=miss>=30?"red":(miss>=10?"yellow":"green");return _ord[ih]>=_ord[ms]?ih:ms;}
const cases=[["green",0,"green"],["green",12,"yellow"],["green",35,"red"],["yellow",0,"yellow"],["green",9,"green"],["red",0,"red"],["yellow",35,"red"]];
let ok=true; for(const[ih,m,exp]of cases){const got=rag(ih,m); if(got!==exp){ok=false;console.log("FAIL",ih,m,"->",got,"exp",exp);}}
console.log(ok?"rag precedence OK":"rag precedence WRONG");
'
```
Expected: "rag precedence OK".

- [ ] **Step 5: Commit.**
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git add CATI/Analysis/QC/scripts/gen_dashboard.py
git commit -m "feat(qc): module-card colour driven by open-issue status + missing-data"
```

---

## Task 2: Per-round strip legend

**Files:** Modify `scripts/gen_dashboard.py` (module-grid container).

- [ ] **Step 1: Insert the legend** before the module grid. Find:
```html
  <h2>Module-Level Quality Summary <span class="badge badge-blue">Click a card to view details</span></h2>
  <div id="mod-grid" class="mod-grid"></div>
```
Replace with (legend between the heading and grid):
```html
  <h2>Module-Level Quality Summary <span class="badge badge-blue">Click a card to view details</span></h2>
  <div style="margin:2px 0 10px;font-size:11px;color:#555">
    Per-round strip:
    <span class="idot red" style="display:inline-block;vertical-align:middle">!</span> open firm issue
    &nbsp;<span class="idot yellow" style="display:inline-block;vertical-align:middle"></span> open
    &nbsp;<span class="idot closed" style="display:inline-block;vertical-align:middle">·</span> closed
    &nbsp;<span class="idot green" style="display:inline-block;vertical-align:middle;border:1px solid #cfe8d6"></span> clean
  </div>
  <div id="mod-grid" class="mod-grid"></div>
```

- [ ] **Step 2: Regenerate + verify.**
```bash
cd CATI/Analysis/QC && python3 scripts/gen_dashboard.py 2>&1 | grep -E "Generated|Error" | tail -1
grep -c "Per-round strip:" output/l2ph_dq_dashboard.html   # expect 1
```
Expected: "Generated …", `1`.

- [ ] **Step 3: Commit.**
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git add CATI/Analysis/QC/scripts/gen_dashboard.py
git commit -m "feat(qc): per-round strip legend on overview"
```

---

## Task 3: Issues-page verdict summary

**Files:** Modify `scripts/gen_dashboard.py` (`renderIssues()`).

- [ ] **Step 1: Add a verdict breakdown line.** In `renderIssues()`, find:
```javascript
  let html = `<div class="mstat">Showing ${rows.length} issue(s) · ${counts.open} open / ${counts.closed} closed total</div>`;
```
Replace with:
```javascript
  const vc = {}; ISSUES.forEach(r=>{ vc[r.verdict] = (vc[r.verdict]||0)+1; });
  const vcLine = Object.keys(vc).sort().map(v=>`${v}:${vc[v]}`).join(' · ');
  let html = `<div class="mstat">Showing ${rows.length} issue(s) · ${counts.open} open / ${counts.closed} closed total</div>`
           + `<div class="mstat">By verdict: ${vcLine}</div>`;
```

- [ ] **Step 2: Regenerate + verify the script still runs.**
```bash
cd CATI/Analysis/QC && python3 scripts/gen_dashboard.py 2>&1 | grep -E "Generated|Error" | tail -1
grep -c "By verdict:" output/l2ph_dq_dashboard.html   # expect 1
# runtime: renderIssues still produces rows (DOM-stubbed)
python3 - <<'PY'
import re
h=open('output/l2ph_dq_dashboard.html').read()
js=next(x for x in re.findall(r'<script(?![^>]*src=)[^>]*>(.*?)</script>', h, re.S) if 'function renderIssues' in x)
i=js.index('function renderIssues(){'); d=0; st=False; e=i
for j in range(i,len(js)):
    c=js[j]
    if c=='{': d+=1; st=True
    elif c=='}':
        d-=1
        if st and d==0: e=j+1; break
open('/tmp/_ri.js','w').write(js[i:e])
PY
node -e '
const fs=require("fs");const ISSUES=JSON.parse(fs.readFileSync("cache/issues.json"));
const ISUM=JSON.parse(fs.readFileSync("cache/issue_summary.json"));const MOD_NAMES=new Proxy({},{get:()=>""});
let cap="";const cb={"iss-firm-only":{checked:false},"iss-review-only":{checked:false},"issues-body":{set innerHTML(v){cap=v;}}};
global.document={getElementById:id=>cb[id]||null};
eval(fs.readFileSync("/tmp/_ri.js","utf8"));renderIssues();
console.log("By verdict line present:", cap.includes("By verdict:"), "| rows:", (cap.match(/vbadge /g)||[]).length);
'
```
Expected: "Generated …", `1`, "By verdict line present: true | rows: 18".

- [ ] **Step 3: Commit.**
```bash
cd /Users/avraa/iDrive/GitHub/PHL/L2PHL
git add CATI/Analysis/QC/scripts/gen_dashboard.py
git commit -m "feat(qc): verdict breakdown on Issues page"
```

---

## Self-review

**Spec coverage:** item 1 card colour worst(ISUM.headline, missing%) + rewritten triggers (T1) ✓; item 2 strip legend (T2) ✓; item 3 verdict summary (T3) ✓. Verification by regenerate + node --check + node-eval + grep (T1–T3) ✓.

**Placeholder scan:** none.

**Consistency:** `rag` (T1) feeds the existing `mod-card ${rag}`, `ragChipBg[rag]`, `ragLabel[rag]`, `triggerHtml` — all unchanged downstream, `rag` is still one of green/yellow/red. `iss`/`_miss` defined before first use. The legend reuses the existing `.idot` CSS (from Plan 2). `renderIssues` change only prepends a line; the existing body loop is untouched.
