#!/usr/bin/env python3
"""
L2PHL CATI Data Quality Pipeline
==================================
Regenerates the QC dashboard and Excel cross-round report.
Run from any directory — all paths are resolved relative to this file.

Usage:
  python3 update_pipeline.py [--dta] [--questionnaire] [--dofiles] [--all]

Flags:
  --dta           Re-run DQ checks from pooled .dta files in Analysis/HF/
  --questionnaire Re-parse questionnaire Excel files from CATI/Questionnaire/
  --dofiles       Re-parse Stata do-files from CATI/Round*/do/
  --all           Run all of the above (default if no flags given)

The HTML dashboard and Excel report are always regenerated at the end.

Outputs:
  output/l2ph_dq_dashboard.html
  output/L2PHL_Questionnaire_Cross_Round_Report.xlsx

Cache (intermediate JSON):
  cache/dq_data.json
  cache/panel_data.json
  cache/all_questions.json
  cache/module_tables.json
  cache/do_modules.json
"""
import sys, os, subprocess, json, time, re, glob
from pathlib import Path
from collections import defaultdict

# ── Paths ──────────────────────────────────────────────────────────────────────
HERE     = Path(__file__).resolve().parent          # Analysis/QC/
CATI     = HERE.parent.parent                       # CATI/
SCRIPTS  = HERE / 'scripts'
CACHE    = HERE / 'cache'
OUTPUT   = HERE / 'output'
HF_DIR   = HERE.parent / 'HF'                      # Analysis/HF/ — pooled .dta files
QUEST_DIR= CATI / 'Questionnaire'                  # CATI/Questionnaire/
ROUNDS_DIR= CATI                                   # CATI/Round*/do/

CACHE.mkdir(exist_ok=True)
OUTPUT.mkdir(exist_ok=True)


# ── Helpers ────────────────────────────────────────────────────────────────────
def log(msg, level='INFO'):
    icons = {'INFO': 'ℹ️ ', 'OK': '✅', 'WARN': '⚠️ ', 'ERROR': '❌', 'STEP': '🔷'}
    print(f"  {icons.get(level, '  ')}{msg}")

def step(n, msg):
    print(f"\n{'='*60}")
    print(f"  🔷 STEP {n}: {msg}")
    print(f"{'='*60}")

def run_script(name):
    result = subprocess.run(
        [sys.executable, str(SCRIPTS / name)],
        capture_output=True, text=True, cwd=str(HERE)
    )
    if result.returncode != 0:
        log(f"{name} failed:", 'ERROR')
        for line in result.stderr.splitlines()[-15:]:
            print(f"    {line}")
        return False
    for line in result.stdout.splitlines():
        print(f"    {line}")
    return True


# ── STEP 1 — Detect available data ────────────────────────────────────────────
def detect_files():
    step(1, "Detecting available files")

    # Pooled .dta files in Analysis/HF/
    dta_files = sorted(HF_DIR.glob('l2phl_M*.dta'))
    log(f"Pooled .dta modules in Analysis/HF/: {len(dta_files)}", 'OK' if dta_files else 'WARN')
    for f in dta_files:
        log(f"  {f.name}")

    # Per-round .dta files in Analysis/HF/R*/
    round_dta = {}
    for rdir in sorted(HF_DIR.glob('R*')):
        if rdir.is_dir():
            rdtas = sorted(rdir.glob('l2phl_*_M*.dta'))
            if rdtas:
                round_dta[rdir.name] = rdtas
                log(f"  {rdir.name}/: {len(rdtas)} module files")

    # Questionnaire Excel files
    quest_files = sorted(QUEST_DIR.glob('*.xlsx'))
    quest_files = [f for f in quest_files if 'questionnaire' in f.name.lower()
                   or ('cati' in f.name.lower() and 'r' in f.name.lower())]
    log(f"Questionnaire files in CATI/Questionnaire/: {len(quest_files)}", 'OK' if quest_files else 'WARN')
    for f in quest_files:
        log(f"  {f.name}")

    # Do-files in CATI/Round*/do/
    do_files = []
    for rdir in sorted(CATI.glob('Round*/do')):
        for df in sorted(rdir.glob('L2PHL_CATI@*.do')):
            do_files.append(df)
    log(f"Do-files in CATI/Round*/do/: {len(do_files)}", 'OK' if do_files else 'WARN')
    for f in do_files:
        log(f"  {f.parent.parent.name}/{f.name}")

    return dta_files, quest_files, do_files, round_dta


# ── STEP 2 — Rebuild DQ from pooled .dta files ────────────────────────────────
def rebuild_dq(dta_files):
    step(2, "Rebuilding DQ data from pooled .dta files")
    if not dta_files:
        log("No pooled .dta files found in Analysis/HF/ — skipping", 'WARN')
        return False
    ok = run_script('build_dq.py')
    if ok:
        size = (CACHE / 'dq_data.json').stat().st_size // 1024
        log(f"cache/dq_data.json written ({size} KB)", 'OK')
    return ok


# ── STEP 2b — Rebuild panel tracking data ─────────────────────────────────────
def rebuild_panel(dta_files):
    step('2b', "Rebuilding panel tracking data")
    passport = next((f for f in dta_files if 'M00' in f.name), None)
    if not passport:
        log("l2phl_M00_passport.dta not found — skipping panel build", 'WARN')
        return False
    ok = run_script('build_panel.py')
    if ok:
        size = (CACHE / 'panel_data.json').stat().st_size // 1024
        log(f"cache/panel_data.json written ({size} KB)", 'OK')
    return ok


# ── STEP 3 — Re-parse questionnaire Excel files ───────────────────────────────
def rebuild_questionnaire(quest_files):
    step(3, "Parsing questionnaire Excel files")
    if not quest_files:
        log("No questionnaire files found in CATI/Questionnaire/ — skipping", 'WARN')
        return False

    import openpyxl

    ROUND_MAP = {
        'R1': ['phase 1', 'phase1', 'cati phase', 'cati r1'],
        'R2': ['r2 questionnaire', 'cati r2'],
        'R3': ['r3 questionnaire', 'cati r3'],
        'R4': ['r4 questionnaire', 'cati r4'],
        'R5': ['r5 questionnaire', 'cati r5'],
    }
    SHEETS = {
        'Introduction': 'M00', 'Demographics': 'M01', 'Education': 'M02',
        'Shocks': 'M03', 'Employment': 'M04', 'Income': 'M05',
        'Finance': 'M06', 'Health': 'M07', 'Food & Non-Food': 'M08',
        'Opinions & Views': 'M09',
    }

    files_map = {}
    for fpath in sorted(quest_files, reverse=True):
        fl = fpath.name.lower()
        if 'trailer' in fl:
            continue
        for rnd, patterns in ROUND_MAP.items():
            if any(p in fl for p in patterns) and rnd not in files_map:
                files_map[rnd] = fpath

    log(f"Rounds mapped: {sorted(files_map.keys())}")
    for r, f in files_map.items():
        log(f"  {r}: {f.name}")

    if len(files_map) < 2:
        log("Need at least 2 questionnaire files — skipping", 'WARN')
        return False

    def get_col(headers, *names):
        for name in names:
            for i, h in enumerate(headers):
                if name.upper() in str(h).upper():
                    return i
        return None

    def val(row, idx):
        if idx is not None and idx < len(row) and row[idx] is not None:
            v = str(row[idx]).strip()
            return v if v and v.lower() not in ('none', 'nan') else ''
        return ''

    def extract_questions(wb, sheet_name):
        if sheet_name not in wb.sheetnames:
            return []
        ws = wb[sheet_name]
        rows = list(ws.values)
        if not rows:
            return []
        header_idx = 0
        for i, row in enumerate(rows[:8]):
            rv = [str(c).upper().strip() if c else '' for c in row]
            if 'Q#' in rv or 'ENGLISH' in rv or any('QUESTION' in v for v in rv):
                header_idx = i
                break
        headers = [str(c).strip() if c else f'col_{j}' for j, c in enumerate(rows[header_idx])]
        qnum_col  = get_col(headers, 'Q#', 'Q #') or 1
        title_col = get_col(headers, 'QUESTION TITLE', 'TITLE')
        prog_col  = get_col(headers, 'PROGRAMMING')
        type_col  = get_col(headers, 'TYPE OF QUESTION', 'TYPE')
        codes_col = get_col(headers, 'CODES')
        eng_col   = get_col(headers, 'ENGLISH')
        remarks_col = next((i for i, h in enumerate(headers)
                           if 'REMARK' in h.upper() and 'PSRC' not in h.upper()
                           and 'DATA CHECK' not in h.upper()), None)
        check_col = get_col(headers, 'DATA CHECK')

        questions = []
        current_q = None
        for row in rows[header_idx + 1:]:
            if not any(c for c in row):
                continue
            qnum = val(row, qnum_col)
            if qnum and re.match(r'^[A-Za-z][A-Za-z0-9_]*$', qnum) and qnum.upper() not in ('NONE', 'COL_0', 'COL_1'):
                current_q = {
                    'qnum': qnum, 'title': val(row, title_col),
                    'type': val(row, type_col), 'english': val(row, eng_col)[:300],
                    'codes': [], 'skip_rules': [], 'remarks': val(row, remarks_col)[:300],
                    'data_check': val(row, check_col)[:200], 'prog_note': '',
                }
                questions.append(current_q)
                codes = val(row, codes_col)
                if codes:
                    current_q['codes'].append({'code': codes, 'label': val(row, eng_col)[:100]})
                prog = val(row, prog_col)
                if prog and ('go to' in prog.lower() or 'skip' in prog.lower()):
                    current_q['skip_rules'].append(prog[:150])
                elif prog:
                    current_q['prog_note'] = prog[:150]
            elif current_q:
                codes = val(row, codes_col)
                eng   = val(row, eng_col)
                prog  = val(row, prog_col)
                if codes and eng:
                    current_q['codes'].append({'code': codes, 'label': eng[:100]})
                if prog and ('go to' in prog.lower() or 'if' in prog.lower()):
                    current_q['skip_rules'].append(
                        f"Code {codes}: {prog[:120]}" if codes else prog[:120])
                if val(row, remarks_col) and not current_q['remarks']:
                    current_q['remarks'] = val(row, remarks_col)[:300]
                if val(row, check_col) and not current_q['data_check']:
                    current_q['data_check'] = val(row, check_col)[:200]
        return questions

    ROUNDS = sorted(files_map.keys())
    all_qs = {}
    for rnd, fpath in files_map.items():
        wb = openpyxl.load_workbook(str(fpath), read_only=True, data_only=True)
        all_qs[rnd] = {}
        for sheet, mod in SHEETS.items():
            all_qs[rnd][mod] = extract_questions(wb, sheet)
        wb.close()
        n = sum(len(v) for v in all_qs[rnd].values())
        log(f"  {rnd}: {n} questions extracted")

    with open(CACHE / 'all_questions.json', 'w') as f:
        json.dump(all_qs, f, indent=2)
    log(f"cache/all_questions.json written ({(CACHE/'all_questions.json').stat().st_size//1024} KB)", 'OK')

    # Build module_tables
    MODULES = ['M00', 'M01', 'M02', 'M03', 'M04', 'M05', 'M06', 'M07', 'M08', 'M09']
    module_tables = {}
    for mod in MODULES:
        seen = {}
        order = []
        for r in ROUNDS:
            for q in all_qs.get(r, {}).get(mod, []):
                v = q['qnum'].upper()
                if v not in seen:
                    seen[v] = r
                    order.append(v)
        rows_out = []
        for v in order:
            row = {'variable': v, 'first_round': seen[v]}
            titles = {}; types = {}; skips = {}; eng = {}; codes = {}; remarks = {}; checks = {}
            for r in ROUNDS:
                q = next((x for x in all_qs.get(r, {}).get(mod, []) if x['qnum'].upper() == v), None)
                row[f'in_{r}'] = '✓' if q else ''
                if q:
                    titles[r]  = q.get('title', '')
                    types[r]   = q.get('type', '')
                    skips[r]   = '; '.join(q.get('skip_rules', []))[:200]
                    eng[r]     = q.get('english', '')[:200]
                    codes[r]   = len(q.get('codes', []))
                    remarks[r] = q.get('remarks', '')
                    checks[r]  = q.get('data_check', '')
            def best(d): return next((d[r] for r in reversed(ROUNDS) if d.get(r, '')), '')
            row['question_title'] = best(titles)
            row['question_type']  = best(types)
            row['english_text']   = best(eng)
            for r in ROUNDS:
                row[f'codes_{r.lower()}']      = codes.get(r, '')
                row[f'skip_{r.lower()}']       = skips.get(r, '')
                row[f'data_check_{r.lower()}'] = checks.get(r, '')
            title_changes = []
            for i, r in enumerate(ROUNDS[1:], 1):
                pr = ROUNDS[i - 1]
                if titles.get(r) and titles.get(pr) and titles[r] != titles[pr]:
                    title_changes.append(f"{pr}→{r}: '{titles[pr]}' → '{titles[r]}'")
            row['title_changes'] = ' | '.join(title_changes)
            skip_changes = []
            for i, r in enumerate(ROUNDS[1:], 1):
                pr = ROUNDS[i - 1]
                s_r = skips.get(r, ''); s_pr = skips.get(pr, '')
                if s_r != s_pr:
                    if s_r and not s_pr:   skip_changes.append(f"Added in {r}")
                    elif s_pr and not s_r: skip_changes.append(f"Removed in {r}")
                    else:                  skip_changes.append(f"Changed {pr}→{r}")
            row['skip_changes'] = ' | '.join(skip_changes)
            present = [r for r in ROUNDS if row.get(f'in_{r}') == '✓']
            if not present:             row['status'] = 'NOT FOUND'
            elif present == ROUNDS:     row['status'] = 'All rounds'
            elif present[0] != ROUNDS[0]: row['status'] = f'New in {present[0]}'
            elif present[-1] != ROUNDS[-1]: row['status'] = f'Dropped after {present[-1]}'
            else:                       row['status'] = 'All rounds'
            row['remarks'] = best(remarks)
            rows_out.append(row)
        module_tables[mod] = rows_out

    with open(CACHE / 'module_tables.json', 'w') as f:
        json.dump(module_tables, f, indent=2)
    log(f"cache/module_tables.json written ({(CACHE/'module_tables.json').stat().st_size//1024} KB)", 'OK')
    return True


# ── STEP 4 — Re-parse do-files ────────────────────────────────────────────────
def rebuild_dofiles(do_files):
    step(4, "Parsing Stata do-files")
    if not do_files:
        log("No do-files found in CATI/Round*/do/ — skipping", 'WARN')
        return False

    ROUND_RE = re.compile(r'@R0?(\d)', re.I)
    SECTION_PATTERNS = [
        (r'\(M1\)|ROSTER|M01', 'M01'), (r'\(M2\)|EDUCATION|M02', 'M02'),
        (r'\(M3\)|SHOCKS?|M03', 'M03'), (r'\(M4\)|EMPLOYMENT|M04', 'M04'),
        (r'\(M5\)|INCOME|M05', 'M05'), (r'\(M6\)|FINANCE|M06', 'M06'),
        (r'\(M7\)|HEALTH|M07', 'M07'), (r'\(M8\)|FOOD|M08', 'M08'),
        (r'\(M9\)|OPINION|VIEW|M09', 'M09'),
    ]

    def parse_do(path):
        with open(path, 'r', encoding='utf-8', errors='ignore') as f:
            lines = f.readlines()
        result = {}
        current_mod = None
        for line in lines:
            raw = line.strip()
            if raw.startswith('*') or raw.startswith('//'):
                text = raw.lstrip('*').lstrip('/').strip().upper()
                for pattern, mod in SECTION_PATTERNS:
                    if re.search(pattern, text, re.I):
                        if any(kw in text for kw in ['(M', 'MODULE', 'ROUNDS']):
                            current_mod = mod
                            if mod not in result:
                                result[mod] = {'vars': set(), 'destring': [], 'tostring': [], 'generate': []}
                            break
                continue
            if current_mod is None:
                continue
            code = re.sub(r'\s*//.*$', '', raw).strip()
            if not code:
                continue
            m = re.match(r'(?:cap(?:ture)?\s+)?destring\s+([\w\s*?]+?)(?:,|$)', code, re.I)
            if m:
                for v in m.group(1).strip().split():
                    if re.match(r'^[a-zA-Z_]', v) and v.lower() not in ('replace', 'force', 'ignore', 'float', 'double'):
                        result[current_mod]['vars'].add(v.lower())
                        result[current_mod]['destring'].append(v.lower())
            m = re.match(r'tostring\s+([\w\s]+?)(?:,|$)', code, re.I)
            if m:
                for v in m.group(1).strip().split():
                    if re.match(r'^[a-zA-Z_]', v):
                        result[current_mod]['vars'].add(v.lower())
                        result[current_mod]['tostring'].append(v.lower())
            m = re.match(r'gen(?:erate)?\s+(\w+)\s*=', code, re.I)
            if m:
                var = m.group(1).lower()
                result[current_mod]['vars'].add(var)
                result[current_mod]['generate'].append({'var': var, 'expr': code[m.end():].strip()[:80]})
        for mod in result:
            result[mod]['vars'] = sorted(result[mod]['vars'])
        return result

    # Map by round number — prefer the @AP file, use most recent if multiple
    do_map = {}
    for fpath in do_files:
        m = ROUND_RE.search(fpath.name)
        if m:
            rnd = f"R{int(m.group(1))}"
            fl = fpath.name.lower()
            # Prefer @AP files (as-processed), skip @CV
            if rnd not in do_map or ('@ap' in fl and '@cv' in do_map[rnd].name.lower()):
                do_map[rnd] = fpath

    do_modules = {}
    for rnd, fpath in sorted(do_map.items()):
        mods = parse_do(fpath)
        do_modules[rnd] = mods
        n = sum(len(d['vars']) for d in mods.values())
        log(f"  {rnd} ({fpath.name}): {n} vars across {list(mods.keys())}")

    with open(CACHE / 'do_modules.json', 'w') as f:
        json.dump(do_modules, f, indent=2)
    log(f"cache/do_modules.json written ({(CACHE/'do_modules.json').stat().st_size//1024} KB)", 'OK')
    return True


# ── STEP 5 — Regenerate HTML dashboard ───────────────────────────────────────
def rebuild_dashboard():
    step(5, "Regenerating HTML dashboard")
    ok = run_script('gen_dashboard.py')
    if ok:
        size = (OUTPUT / 'l2ph_dq_dashboard.html').stat().st_size // 1024
        log(f"output/l2ph_dq_dashboard.html ({size} KB)", 'OK')
    return ok


# ── STEP 6 — Regenerate Excel report ─────────────────────────────────────────
def rebuild_excel():
    step(6, "Regenerating Excel cross-round report")
    ok = run_script('build_report.py')
    if ok:
        size = (OUTPUT / 'L2PHL_Questionnaire_Cross_Round_Report.xlsx').stat().st_size // 1024
        log(f"output/L2PHL_Questionnaire_Cross_Round_Report.xlsx ({size} KB)", 'OK')
    return ok


# ── MAIN ──────────────────────────────────────────────────────────────────────
if __name__ == '__main__':
    args = sys.argv[1:] or ['--all']
    do_dta = '--all' in args or '--dta' in args
    do_q   = '--all' in args or '--questionnaire' in args
    do_do  = '--all' in args or '--dofiles' in args

    print()
    print("╔══════════════════════════════════════════════╗")
    print("║  L2PHL CATI Data Quality Pipeline           ║")
    print("╚══════════════════════════════════════════════╝")
    print(f"  Root  : {CATI}")
    print(f"  HF    : {HF_DIR}")
    print(f"  QC    : {HERE}")

    dta_files, quest_files, do_files, round_dta = detect_files()

    errors = []
    t0 = time.time()

    if do_dta:
        if not rebuild_dq(dta_files):    errors.append('DQ rebuild failed')
        if not rebuild_panel(dta_files): errors.append('Panel rebuild failed')

    if do_q:
        if not rebuild_questionnaire(quest_files): errors.append('Questionnaire parse failed')

    if do_do:
        if not rebuild_dofiles(do_files): errors.append('Do-file parse failed')

    if not rebuild_dashboard(): errors.append('Dashboard generation failed')
    if not rebuild_excel():     errors.append('Excel report generation failed')

    elapsed = time.time() - t0
    print()
    print("╔══════════════════════════════════════════════╗")
    if errors:
        print(f"║  ⚠️  Finished with {len(errors)} error(s) in {elapsed:.1f}s")
        for e in errors: print(f"║  ❌ {e}")
    else:
        print(f"║  ✅ All outputs updated in {elapsed:.1f}s")
        print("║")
        print("║  📊 output/l2ph_dq_dashboard.html")
        print("║  📋 output/L2PHL_Questionnaire_Cross_Round_Report.xlsx")
    print("╚══════════════════════════════════════════════╝")
    print()
