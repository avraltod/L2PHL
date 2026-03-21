#!/usr/bin/env python3
"""
L2PH Data Quality Analysis — grounded in actual questionnaire routing.
Questionnaire source: Project TIPON CATI R1-R5 Excel files.
Outputs dq_data.json for the DQ dashboard.
"""
import json, warnings, os
from pathlib import Path
import numpy as np
import pandas as pd

warnings.filterwarnings('ignore')

# ── Paths ──────────────────────────────────────────────────────────────────────
_HERE  = Path(__file__).resolve().parent        # scripts/
_QC    = _HERE.parent                           # Analysis/QC/
_CACHE = _QC / 'cache'
HF_DIR = _QC.parent / 'HF'                     # Analysis/HF/ — pooled .dta files
UPLOAD = str(HF_DIR)                            # used by find_file()
CACHE  = str(_CACHE)

_CACHE.mkdir(exist_ok=True)

ROUNDS = [1, 2, 3, 4, 5]

def find_file(keyword):
    for f in sorted(os.listdir(UPLOAD)):
        if keyword.lower() in f.lower() and f.endswith('.dta'):
            return os.path.join(UPLOAD, f)

def load_dta(keyword):
    path = find_file(keyword)
    if not path: return pd.DataFrame()
    print(f'  {os.path.basename(path)}')
    df = pd.read_stata(path, convert_categoricals=False)
    df.columns = [c.lower() for c in df.columns]
    if 'round' not in df.columns:
        for c in ['wave','survey_round']:
            if c in df.columns:
                df['round'] = pd.to_numeric(df[c], errors='coerce'); break
    else:
        df['round'] = pd.to_numeric(df['round'], errors='coerce')
    return df

def n(s): return pd.to_numeric(s, errors='coerce')

# ── Load ──────────────────────────────────────────────────────────────────────
print('Loading data files...')
m00 = load_dta('m00')
m01 = load_dta('m01')
m02 = load_dta('m02')
m03 = load_dta('m03')
m04 = load_dta('m04')
m05 = load_dta('m05')
m06 = load_dta('m06')
m07 = load_dta('m07')
m08 = load_dta('m08')
m09 = load_dta('m09')

# ── Sample counts ─────────────────────────────────────────────────────────────
def cnt(df):
    return {r: int((df['round']==r).sum()) for r in ROUNDS}

sample_counts = {
    'M00':cnt(m00),'M01':cnt(m01),'M02':cnt(m02),'M03':cnt(m03),
    'M04':cnt(m04),'M05':cnt(m05),'M06':cnt(m06),'M07':cnt(m07),
    'M08':cnt(m08),'M09':cnt(m09)
}

# ── DQ rules from questionnaire ───────────────────────────────────────────────
# Each rule: {module, q_gate, gate_value (gate value that triggers SKIP = no follow-up),
#             follow_cols, label, severity, note}
# We check: rows where gate==gate_skip_val but follow-up cols have data = VIOLATION
# gate_skip_val: the value that means "go to next section" (skip follow-up)

print('\nBuilding questionnaire-grounded DQ checks...')

# ── SKIP VIOLATION CHECKER ────────────────────────────────────────────────────
def is_filled(series):
    """True if a cell is non-null AND not an empty string (handles string cols)."""
    return series.notna() & (series.astype(str).str.strip() != '') & (series.astype(str) != 'nan')

def check_skip(df, gate_col, gate_skip_vals, follow_cols, round_col='round'):
    """
    Count rows per round where gate is in gate_skip_vals but follow-up col(s) are filled.
    gate_skip_vals: list of values that mean 'skip follow-up'.
    Returns count dict and pct dict.
    Ignores empty strings (some string columns store '' for missing).
    """
    if gate_col not in df.columns:
        return {r: None for r in ROUNDS}, {r: None for r in ROUNDS}
    out_cnt, out_pct = {}, {}
    gate_num = n(df[gate_col])
    gate_mask = gate_num.isin(gate_skip_vals)
    for r in ROUNDS:
        round_mask = df['round'] == r
        sub_gate = df[round_mask & gate_mask]
        if not len(sub_gate):
            out_cnt[r] = None; out_pct[r] = None; continue
        filled = pd.Series(False, index=sub_gate.index)
        for fc in follow_cols:
            if fc in df.columns:
                filled |= is_filled(sub_gate[fc])
        c = int(filled.sum())
        out_cnt[r] = c
        out_pct[r] = round(100*c/len(sub_gate), 1)
    return out_cnt, out_pct

def check_mandatory(df, gate_col, gate_ask_vals, follow_cols, round_col='round'):
    """
    Opposite: gate is in gate_ask_vals but follow-up col(s) are EMPTY.
    Returns missing count (expected to be filled but isn't).
    """
    if gate_col not in df.columns:
        return {r: None for r in ROUNDS}, {r: None for r in ROUNDS}
    out_cnt, out_pct = {}, {}
    gate_num = n(df[gate_col])
    gate_mask = gate_num.isin(gate_ask_vals)
    for r in ROUNDS:
        round_mask = df['round'] == r
        sub_gate = df[round_mask & gate_mask]
        if not len(sub_gate):
            out_cnt[r] = None; out_pct[r] = None; continue
        # Check if ALL follow-up cols are missing (none filled)
        all_missing = pd.Series(True, index=sub_gate.index)
        for fc in follow_cols:
            if fc in df.columns:
                all_missing &= sub_gate[fc].isna()
        c = int(all_missing.sum())
        out_cnt[r] = c
        out_pct[r] = round(100*c/len(sub_gate), 1)
    return out_cnt, out_pct

def oor(df, var, lo=None, hi=None, exclude_special=(-99,-95,97,98,99)):
    """Count out-of-range values per round. Excludes special codes."""
    if var not in df.columns:
        return {r: None for r in ROUNDS}
    out = {}
    for r in ROUNDS:
        vals = n(df[df['round']==r][var]).dropna()
        vals = vals[~vals.isin(exclude_special)]
        if not len(vals):
            out[r] = None; continue
        mask = pd.Series(False, index=vals.index)
        if lo is not None: mask |= (vals < lo)
        if hi is not None: mask |= (vals > hi)
        out[r] = int(mask.sum())
    return out

def mr(df, var):
    """Missing rate by round."""
    out = {}
    for r in ROUNDS:
        sub = df[df['round']==r]
        if not len(sub) or var not in df.columns:
            out[r] = None; continue
        out[r] = round(sub[var].isna().mean()*100, 1)
    return out

def pct_eq(df, var, val):
    out = {}
    for r in ROUNDS:
        sub = n(df[df['round']==r][var]).dropna() if var in df.columns else pd.Series()
        out[r] = round((sub==val).mean()*100, 1) if len(sub) else None
    return out

def mean_by_r(df, var):
    out = {}
    for r in ROUNDS:
        sub = n(df[df['round']==r][var]).dropna() if var in df.columns else pd.Series()
        out[r] = round(float(sub.mean()),2) if len(sub) else None
    return out

def flag_shifts(by_round, thr=15):
    flags=[]
    for i in range(len(ROUNDS)-1):
        a,b = by_round.get(ROUNDS[i]), by_round.get(ROUNDS[i+1])
        if a is not None and b is not None and abs(b-a)>=thr:
            flags.append({'from':ROUNDS[i],'to':ROUNDS[i+1],'shift':round(abs(b-a),1),'dir':'up' if b>a else 'down'})
    return flags

# ─────────────────────────────────────────────────────────────────────────────
# MODULE 00: PASSPORT / INTERVIEW METADATA
# ─────────────────────────────────────────────────────────────────────────────
print('M00 Passport...')

skip_issues = []
oor_issues  = []
mandatory_issues = []

# Interview duration: valid 5-180 min (real interviews)
oor_issues.append({
    'module':'M00','variable':'dur_tot','label':'Total interview duration',
    'rule':'< 5 min (suspiciously short) or > 180 min',
    'counts': oor(m00, 'dur_tot', 5, 180, exclude_special=()),
    'severity':'high',
    'note': 'Questionnaire states interview should take ~30 min on average.'
})

# Module durations - each module should take >0 min
for col, label in [('dur_pp','Duration Passport'),('dur_rr','Duration Roster'),
                   ('dur_educ','Duration Education'),('dur_sh','Duration Shocks'),
                   ('dur_emp','Duration Employment'),('dur_inc','Duration Income'),
                   ('dur_fin','Duration Finance'),('dur_hlt','Duration Health'),
                   ('dur_f_nf','Duration Food/NonFood'),('dur_vw','Duration Views')]:
    oor_issues.append({
        'module':'M00','variable':col,'label':label,
        'rule':'= 0 (no time recorded)',
        'counts': oor(m00, col, 0.001, 999, exclude_special=()),
        'severity':'medium',
        'note':'Zero duration means module was skipped or duration not recorded.'
    })

# ─────────────────────────────────────────────────────────────────────────────
# MODULE 01: ROSTER / DEMOGRAPHICS
# ─────────────────────────────────────────────────────────────────────────────
print('M01 Roster / Demographics...')

# D5a=2 (left HH) → D25 (reason leaving) must be filled
c,p = check_mandatory(m01, 'd5a', [2], ['d25'])
mandatory_issues.append({
    'module':'M01','rule':'D5a=2 (left HH) but D25 (reason) is missing',
    'variable':'D5a → D25','counts_by_round':c,'pct_by_round':p,'severity':'high',
    'note':'When a member left the household, reason for leaving (D25) must be recorded.'
})

# D5a=2 AND D25 in (1,2) → D26 (area moved to) should be filled
if 'd25' in m01.columns:
    mask_left = (n(m01['d5a'])==2) & n(m01['d25']).isin([1,2])
    c2,p2 = check_mandatory(m01[mask_left.fillna(False)].assign(gate_='ok'), 'gate_', ['ok'], ['d26']) \
        if 'd26' in m01.columns else ({r:None for r in ROUNDS},{r:None for r in ROUNDS})
    # Simpler: direct check
    c2, p2 = {}, {}
    for r in ROUNDS:
        sub = m01[(m01['round']==r) & mask_left.fillna(False)]
        if not len(sub) or 'd26' not in m01.columns:
            c2[r]=None; p2[r]=None; continue
        missing = sub['d26'].isna().sum()
        c2[r] = int(missing)
        p2[r] = round(100*missing/len(sub),1)
    mandatory_issues.append({
        'module':'M01','rule':'D5a=2 AND D25=1/2 (moved away) but D26 (destination) is missing',
        'variable':'D25=1/2 → D26','counts_by_round':c2,'pct_by_round':p2,'severity':'medium',
        'note':'When member moved away, destination area should be recorded.'
    })

# Age valid: 0-120 (questionnaire says "Accept answers 0-120" for D32)
oor_issues.append({
    'module':'M01','variable':'age','label':'Respondent age',
    'rule':'< 0 or > 120 (questionnaire says Accept 0-120)',
    'counts': oor(m01, 'age', 0, 120),
    'severity':'high',
    'note':'Questionnaire specifies valid age range 0-120 years.'
})

# Sex valid: 1 or 2
oor_issues.append({
    'module':'M01','variable':'sex','label':'Sex/Gender',
    'rule':'Not 1 or 2 (invalid code)',
    'counts': oor(m01, 'sex', 1, 2, exclude_special=(98,99)),
    'severity':'medium',
    'note':'Valid codes: 1=Male, 2=Female only.'
})

# ─────────────────────────────────────────────────────────────────────────────
# MODULE 02: EDUCATION
# ─────────────────────────────────────────────────────────────────────────────
print('M02 Education...')

# ED15=2 (dropped out) → ED16 (reasons) must be filled  [questionnaire: "Ask if ED15=2"]
ed16_cols = [c for c in m02.columns if c.startswith('ed16')]
c,p = check_mandatory(m02, 'ed15', [2], ed16_cols if ed16_cols else ['ed16'])
mandatory_issues.append({
    'module':'M02','rule':'ED15=2 (dropped out) but ED16 (dropout reasons) is missing',
    'variable':'ED15=2 → ED16','counts_by_round':c,'pct_by_round':p,'severity':'high',
    'note':'Questionnaire: Ask ED16 if ED15=2 (not attending). Must record dropout reason.'
})

# ED15=1 (still in school) → ED16 should NOT be filled  [SKIP: "Proceed to next section"]
c,p = check_skip(m02, 'ed15', [1], ed16_cols if ed16_cols else ['ed16'])
skip_issues.append({
    'module':'M02','rule':'ED15=1 (still in school) but ED16 (dropout reason) is filled',
    'variable':'ED15=1 → ED16 should be empty','counts_by_round':c,'pct_by_round':p,
    'severity':'high',
    'note':'Questionnaire: ED15=1 → Proceed to next section (skip ED16). Dropout reasons should be blank.'
})

# ─────────────────────────────────────────────────────────────────────────────
# MODULE 03: SHOCKS
# ─────────────────────────────────────────────────────────────────────────────
print('M03 Shocks...')

# SH1=2 (no shock) → SH1b must NOT be filled  [questionnaire: "Go to S3" = go to SH3 = skip SH1b]
sh1b_cols = [c for c in m03.columns if c.startswith('sh1b') and c != 'sh1b']
if not sh1b_cols: sh1b_cols = ['sh1b_1','sh1b_2','sh1b_3','sh1b_4']
sh1b_cols_exist = [c for c in sh1b_cols if c in m03.columns]
c,p = check_skip(m03, 'sh1', [2], sh1b_cols_exist)
skip_issues.append({
    'module':'M03','rule':'SH1=2 (no shock) but SH1b (shock types) is filled',
    'variable':'SH1=2 → SH1b should be empty','counts_by_round':c,'pct_by_round':p,
    'severity':'high',
    'note':'Questionnaire: SH1=2 → Go to SH3 (skip SH1b shock types). Any filled SH1b entry is an error.'
})

# SH1=1 (shock) → SH1b must be filled  [questionnaire: "Go to SH1b"]
c,p = check_mandatory(m03, 'sh1', [1], sh1b_cols_exist)
mandatory_issues.append({
    'module':'M03','rule':'SH1=1 (shock experienced) but SH1b (shock type) is missing',
    'variable':'SH1=1 → SH1b','counts_by_round':c,'pct_by_round':p,'severity':'high',
    'note':'Questionnaire: SH1=1 → Go to SH1b. Shock type must be recorded.'
})

# SH3=2 (no water disruption) → SH4 should NOT be filled
c,p = check_skip(m03, 'sh3', [2], ['sh4'] if 'sh4' in m03.columns else [])
skip_issues.append({
    'module':'M03','rule':'SH3=2 (no water disruption) but SH4 (disruption days) is filled',
    'variable':'SH3=2 → SH4 should be empty','counts_by_round':c,'pct_by_round':p,
    'severity':'high',
    'note':'Questionnaire: SH3=2 → Go to EL5 (skip SH4). Days of water disruption should be blank.'
})

# SH3=1 → SH4 must be filled
c,p = check_mandatory(m03, 'sh3', [1], ['sh4'] if 'sh4' in m03.columns else [])
mandatory_issues.append({
    'module':'M03','rule':'SH3=1 (water disruption) but SH4 (days) is missing',
    'variable':'SH3=1 → SH4','counts_by_round':c,'pct_by_round':p,'severity':'high',
    'note':'Questionnaire: SH3=1 → Ask SH4. Days of water disruption must be recorded.'
})

# SH4 valid range: 1-30  [questionnaire R5: "Allow answers from 1-30 days"]
oor_issues.append({
    'module':'M03','variable':'sh4','label':'Days of water supply disruption',
    'rule':'< 1 or > 30',
    'counts': oor(m03, 'sh4', 1, 30),
    'severity':'high',
    'note':'Questionnaire specifies valid range 1-30 days for water disruption.'
})

# EL5 valid range: 0-168  [questionnaire: "Allow answers from 0-168 hours"]
oor_issues.append({
    'module':'M03','variable':'el5','label':'Hours electricity unavailable',
    'rule':'> 168 (exceeds max hours in a week)',
    'counts': oor(m03, 'el5', 0, 168),
    'severity':'high',
    'note':'Questionnaire specifies valid range 0-168 hours (max hours in a week).'
})

# ─────────────────────────────────────────────────────────────────────────────
# MODULE 04: EMPLOYMENT
# ─────────────────────────────────────────────────────────────────────────────
print('M04 Employment...')

# A1=2 (not working last week) AND not in job/business (A26 ≠ 1)
# → A4/A5/A6/A10/A11 should NOT be filled
# Routing: "Go to A26" for both A1=1 and A1=2. A4 is only asked if A1=1 or A24=1 or A26=1.
# So: rows where a1=2 AND a26 ≠ 1 (or a26 missing) → a10/a11 should be empty

# Simpler check: a1=2 but a10 or a11 filled (most common skip error)
c,p = check_skip(m04, 'a1', [2], ['a10','a11'])
skip_issues.append({
    'module':'M04','rule':'A1=2 (not working) but A10/A11 (days/hours) are filled',
    'variable':'A1=2 → A10,A11 should be empty','counts_by_round':c,'pct_by_round':p,
    'severity':'high',
    'note':'Questionnaire: A10/A11 only asked if A1=1 (or change in employment). '
          'Note: some valid exceptions if A26=1 (has job but didn\'t work last week).'
})

# A8=2 (not gig work) → A9 should NOT be filled  [questionnaire: "Go to A10"]
c,p = check_skip(m04, 'a8', [2,99], ['a9'] if 'a9' in m04.columns else [])
skip_issues.append({
    'module':'M04','rule':'A8=2/DK (not gig work) but A9 (digital platform) is filled',
    'variable':'A8=2/99 → A9 should be empty','counts_by_round':c,'pct_by_round':p,
    'severity':'medium',
    'note':'Questionnaire: A8=2/99 → Go to A10 (skip A9 digital platform question).'
})

# A16=3/99 (no contract) → A17 should NOT be filled  [questionnaire: "Go to A18"]
c,p = check_skip(m04, 'a16', [3,99], ['a17'] if 'a17' in m04.columns else [])
skip_issues.append({
    'module':'M04','rule':'A16=3/99 (no contract/DK) but A17 (contract duration) is filled',
    'variable':'A16=3/99 → A17 should be empty','counts_by_round':c,'pct_by_round':p,
    'severity':'medium',
    'note':'Questionnaire: A16=3/99 → Go to A18 (skip A17 contract duration).'
})

# A10 valid range: 0-7  [questionnaire: "Accept 0-7 only"]
oor_issues.append({
    'module':'M04','variable':'a10','label':'Days worked per week (A10)',
    'rule':'< 0 or > 7',
    'counts': oor(m04, 'a10', 0, 7),
    'severity':'high',
    'note':'Questionnaire states: Accept 0-7 only (days per week).'
})

# A11 valid range: 0-168  [questionnaire: "Accept 0-168 only"]
oor_issues.append({
    'module':'M04','variable':'a11','label':'Hours worked per week (A11)',
    'rule':'> 168 (more than all hours in a week)',
    'counts': oor(m04, 'a11', 0, 168),
    'severity':'high',
    'note':'Questionnaire states: Accept 0-168 only (max hours in a week = 24×7).'
})

# A22 (travel time in minutes) – reasonable range 1-300 min
oor_issues.append({
    'module':'M04','variable':'a22','label':'Travel time to work (minutes)',
    'rule':'> 300 min (5 hours one way)',
    'counts': oor(m04, 'a22', 0, 300),
    'severity':'medium',
    'note':'Travel time >5 hours is highly suspicious. Questionnaire accepts numeric input.'
})

# ─────────────────────────────────────────────────────────────────────────────
# MODULE 05: INCOME
# ─────────────────────────────────────────────────────────────────────────────
print('M05 Income...')

# IA2=2 (no regular employment income) → IA3 should NOT be filled (non-null AND non-zero)
ia3_cols_exist = [col for col in m05.columns if col.startswith('ia3') and col != 'ia3']
ia6_cols_exist = [col for col in m05.columns if col.startswith('ia6') and col != 'ia6']

def check_skip_nonzero(df, gate_col, gate_skip_vals, follow_cols):
    """Skip check that counts non-null AND non-zero values (for numeric earnings cols)."""
    if gate_col not in df.columns:
        return {r: None for r in ROUNDS}, {r: None for r in ROUNDS}
    out_cnt, out_pct = {}, {}
    gate_num = n(df[gate_col])
    gate_mask = gate_num.isin(gate_skip_vals)
    for r in ROUNDS:
        sub_gate = df[(df['round']==r) & gate_mask]
        if not len(sub_gate):
            out_cnt[r]=None; out_pct[r]=None; continue
        filled = pd.Series(False, index=sub_gate.index)
        for fc in follow_cols:
            if fc in df.columns:
                v = n(sub_gate[fc])
                filled |= (v.notna() & (v != 0))
        c_val = int(filled.sum())
        out_cnt[r] = c_val; out_pct[r] = round(100*c_val/len(sub_gate),1)
    return out_cnt, out_pct

c,p = check_skip_nonzero(m05, 'ia2', [2], ia3_cols_exist)
skip_issues.append({
    'module':'M05','rule':'IA2=2 (no regular income) but IA3 earnings (>0) are filled',
    'variable':'IA2=2 → IA3 should be empty','counts_by_round':c,'pct_by_round':p,
    'severity':'high',
    'note':'Questionnaire: IA2=2 → Go to IA5 (skip IA3). Non-zero earnings suggest skip error or miscoding. Zeros excluded (may be auto-filled).'
})

# IA5=2 (no seasonal income) → IA6 should NOT be filled (non-zero)
c,p = check_skip_nonzero(m05, 'ia5', [2], ia6_cols_exist)
skip_issues.append({
    'module':'M05','rule':'IA5=2 (no seasonal income) but IA6 earnings (>0) are filled',
    'variable':'IA5=2 → IA6 should be empty','counts_by_round':c,'pct_by_round':p,
    'severity':'high',
    'note':'Questionnaire: IA5=2 → next section (skip IA6 seasonal earnings).'
})

# ─────────────────────────────────────────────────────────────────────────────
# MODULE 06: FINANCE
# ─────────────────────────────────────────────────────────────────────────────
print('M06 Finance...')

# F7=2/98/99 (no loan) → F9, F10 should NOT be filled  [F8 is string - skip it]
# [questionnaire: "Go to F13" for F7=2/98/99]
c,p = check_skip(m06, 'f7', [2,98,99], ['f9','f10'])
skip_issues.append({
    'module':'M06','rule':'F7=2/98/99 (no loan) but F9/F10 (institution/approval) are filled',
    'variable':'F7=2/98/99 → F9,F10 should be empty','counts_by_round':c,'pct_by_round':p,
    'severity':'high',
    'note':'Questionnaire: F7=2/98/99 → Go to F13 (skip F9/F10 loan institution and approval). F8 is a multiple-response string field.'
})

# F7=1 (applied for loan) → F8 and F9 must be filled  [questionnaire: "Ask if F7=1"]
c,p = check_mandatory(m06, 'f7', [1], ['f8','f9'])
mandatory_issues.append({
    'module':'M06','rule':'F7=1 (applied for loan) but F8/F9 (purpose/institution) is missing',
    'variable':'F7=1 → F8,F9','counts_by_round':c,'pct_by_round':p,'severity':'high',
    'note':'Questionnaire: F8 and F9 are mandatory when F7=1 (loan applied for).'
})

# R5 specific: F17=2 (no formal bank account) → F1 should NOT be filled
# [questionnaire R5: "F17=2 → Go to F18"]
# Since F17 only exists in R5, check only round 5
if 'f17' in m06.columns:
    c,p = check_skip(m06[m06['round']==5], 'f17', [2], ['f1'])
    skip_issues.append({
        'module':'M06','rule':'[R5 only] F17=2 (no bank account) but F1 (deposits) is filled',
        'variable':'F17=2 → F1 should be empty (R5 only)','counts_by_round':{**{r:None for r in ROUNDS},5:c.get(5)},
        'pct_by_round':{**{r:None for r in ROUNDS},5:p.get(5)},
        'severity':'high',
        'note':'In R5, F1 is only asked if F17=1 (has a formal bank account). This routing was NOT present in R1-R4.'
    })

    # R5: F18=2 (no mobile money) → F2 should NOT be filled
    if 'f18' in m06.columns:
        c,p = check_skip(m06[m06['round']==5], 'f18', [2], ['f2'])
        skip_issues.append({
            'module':'M06','rule':'[R5 only] F18=2 (no mobile money) but F2 (mobile deposits) is filled',
            'variable':'F18=2 → F2 should be empty (R5 only)','counts_by_round':{**{r:None for r in ROUNDS},5:c.get(5)},
            'pct_by_round':{**{r:None for r in ROUNDS},5:p.get(5)},
            'severity':'high',
            'note':'In R5, F2 is only asked if F18=1 (has mobile money account). New routing in R5.'
        })

# ─────────────────────────────────────────────────────────────────────────────
# MODULE 07: HEALTH
# ─────────────────────────────────────────────────────────────────────────────
print('M07 Health...')

# H2=4 (health care NOT needed) AND H2A≠2 → H3 should NOT be filled
# Questionnaire: H3 asked if "code 4 in H2" OR "code 2 in H2A"
# So if H2=4 AND H2A=1 (was able to get care when needed), H3 shouldn't be filled
if 'h2' in m07.columns and 'h3' in m07.columns:
    # H2=4 AND (H2A=1 or H2A is missing) → H3 should be empty
    h2a = n(m07['h2a']) if 'h2a' in m07.columns else pd.Series(np.nan, index=m07.index)
    # Violation: H2=4 but H3 is filled AND H2A ≠ 2
    viol_mask = (n(m07['h2'])==4) & (h2a != 2) & m07['h3'].notna()
    c3,p3 = {}, {}
    for r in ROUNDS:
        sub_all = m07[(m07['round']==r) & (n(m07['h2'])==4)]
        sub_viol = m07[(m07['round']==r) & viol_mask]
        if not len(sub_all):
            c3[r]=None; p3[r]=None; continue
        c3[r]=int(len(sub_viol)); p3[r]=round(100*len(sub_viol)/len(sub_all),1)
    skip_issues.append({
        'module':'M07','rule':'H2=4 (care not needed) but H3 (reason unable) is filled',
        'variable':'H2=4, H2A≠2 → H3 should be empty','counts_by_round':c3,'pct_by_round':p3,
        'severity':'high',
        'note':'Questionnaire: H3 only asked if H2=4 (care needed but not sought) OR H2A=2 (not able to get care).'
    })

# H2=1/2/3 → H2A must be filled  [questionnaire: "Ask if H2=1/2/3"]
c,p = check_mandatory(m07, 'h2', [1,2,3], ['h2a'] if 'h2a' in m07.columns else [])
mandatory_issues.append({
    'module':'M07','rule':'H2=1/2/3 (health care needed) but H2A is missing',
    'variable':'H2=1/2/3 → H2A','counts_by_round':c,'pct_by_round':p,'severity':'high',
    'note':'Questionnaire: H2A must be filled when health care was needed (H2=1/2/3).'
})

# R5 ONLY: H2=2 or 3 (outpatient) → H4, H7, H8 should be filled (new in R5)
if 'h4' in m07.columns:
    c,p = check_mandatory(m07, 'h2', [2,3], ['h4'])
    mandatory_issues.append({
        'module':'M07','rule':'H2=2/3 (outpatient) but H4 (healthcare facility) is missing',
        'variable':'H2=2/3 → H4','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'H4 is only present in R5. Questionnaire: ask H4 if H2=2 or 3.'
    })

# R5: H12=1 (hospitalized) → H13, H14, H15 must be filled
if 'h12' in m07.columns:
    c,p = check_mandatory(m07, 'h12', [1], ['h14'] if 'h14' in m07.columns else [])
    mandatory_issues.append({
        'module':'M07','rule':'H12=1 (hospitalized) but H14 (total hospital bill) is missing',
        'variable':'H12=1 → H14','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'R5 only. Questionnaire: H14 (total bill) mandatory if H12=1 (hospitalized).'
    })
    # H15 ≤ H14 (out-of-pocket ≤ total bill)
    if 'h15' in m07.columns and 'h14' in m07.columns:
        viol_cross = {r: None for r in ROUNDS}
        for r in ROUNDS:
            sub = m07[(m07['round']==r) & (n(m07['h12'])==1)]
            if not len(sub): continue
            v14 = n(sub['h14']); v15 = n(sub['h15'])
            valid = v14.notna() & v15.notna() & (v14>=0) & (v15>=0)
            if not valid.sum(): continue
            viol_cross[r] = int((v15[valid] > v14[valid]).sum())
        oor_issues.append({
            'module':'M07','variable':'h15 vs h14','label':'H15 out-of-pocket > H14 total bill',
            'rule':'H15 (out-of-pocket) > H14 (total bill) — impossible',
            'counts': viol_cross,
            'severity':'high',
            'note':'R5 only. Questionnaire note: "Answer should be less than total hospital bill (H14)".'
        })

# ─────────────────────────────────────────────────────────────────────────────
# MODULE 08: FOOD & NON-FOOD (FIES)
# ─────────────────────────────────────────────────────────────────────────────
print('M08 Food & Non-Food...')

# All FIES items asked of all – check for any blanks
fies_cols = [c for c in m08.columns if 'fies' in c.lower() or c.startswith('f08')]
actual_fies = [c for c in fies_cols if c in m08.columns]
if actual_fies:
    c,p = {}, {}
    for r in ROUNDS:
        sub = m08[m08['round']==r]
        if not len(sub): c[r]=None; p[r]=None; continue
        any_missing = sub[actual_fies].isna().any(axis=1)
        c[r] = int(any_missing.sum())
        p[r] = round(100*any_missing.mean(), 1)
    mandatory_issues.append({
        'module':'M08','rule':'Any FIES item (FIES1-FIES5/F08 A-E) is blank — asked of all HHs',
        'variable':'FIES questions','counts_by_round':c,'pct_by_round':p,'severity':'high',
        'note':'Questionnaire: "Ask all" — no valid reason for any FIES item to be missing.'
    })

# FIES valid codes: 1 or 2 only
for fv in actual_fies[:5]:
    oor_issues.append({
        'module':'M08','variable':fv,'label':f'FIES item {fv}',
        'rule':'Not 1 (Yes) or 2 (No)',
        'counts': oor(m08, fv, 1, 2, exclude_special=(98,99)),
        'severity':'medium',
        'note':'Valid codes for FIES items are 1=Yes or 2=No only.'
    })

# ─────────────────────────────────────────────────────────────────────────────
# MODULE 09: OPINIONS & VIEWS
# ─────────────────────────────────────────────────────────────────────────────
print('M09 Opinions & Views...')

# V1, V5 valid: 1-5  [questionnaire: scale 1-5]
for var, label in [('v1','Life satisfaction (V1)'), ('v5','Economic change (V5)')]:
    oor_issues.append({
        'module':'M09','variable':var,'label':label,
        'rule':'Not 1-5 (invalid Likert code)',
        'counts': oor(m09, var, 1, 5, exclude_special=(98,99)),
        'severity':'high',
        'note':'Questionnaire: 5-point scale 1-5 only. No other valid codes.'
    })

# V9 items valid: 1-5 (or 6 for item f only)
v9_cols = [c for c in m09.columns if c.startswith('v9')]
for vc in v9_cols[:8]:
    oor_issues.append({
        'module':'M09','variable':vc,'label':f'Agreement statement {vc}',
        'rule':'Not 1-5 (or 6 for V9f)',
        'counts': oor(m09, vc, 1, 6 if vc.endswith('f') or vc.endswith('_f') else 5,
                      exclude_special=(98,99)),
        'severity':'medium',
        'note':'V9 items use 1-5 scale; V9f may have code 6 (No child).'
    })

# V1 and V5 missing (both "ask all" – no blanks should exist)
for var, label in [('v1','V1 life satisfaction'), ('v5','V5 economic change')]:
    c,p = {}, {}
    for r in ROUNDS:
        sub = m09[m09['round']==r]
        if not len(sub) or var not in m09.columns:
            c[r]=None; p[r]=None; continue
        miss = sub[var].isna().sum()
        c[r]=int(miss); p[r]=round(100*miss/len(sub),1)
    if any(v for v in c.values() if v):
        mandatory_issues.append({
            'module':'M09','rule':f'{label} is blank — asked of all respondents',
            'variable':var,'counts_by_round':c,'pct_by_round':p,'severity':'high',
            'note':f'Questionnaire: "Ask all" — {var} must be filled for every respondent.'
        })

# ─────────────────────────────────────────────────────────────────────────────
# DISTRIBUTION SHIFTS
# ─────────────────────────────────────────────────────────────────────────────
print('Checking distribution shifts...')

dist_shifts = []
checks = [
    (m09,'M09','v1','Mean life satisfaction (1-5)',mean_by_r,0.5,None),
    (m09,'M09','v5','Economic situation worsened R1→R5 (%)',pct_eq,15,1),
    (m08,'M08','fies1','Worried about food (%)',pct_eq,15,1),
    (m08,'M08','fies5','No food for whole day (%)',pct_eq,15,1),
    (m03,'M03','sh1','Experienced any shock (%)',pct_eq,15,1),
    (m04,'M04','a1','Working last 7 days (%)',pct_eq,15,1),
    (m06,'M06','f1','Has formal deposits (%)',pct_eq,15,1),
    (m06,'M06','f3','Saved money for future (%)',pct_eq,15,1),
    (m06,'M06','f7','Applied for loan (%)',pct_eq,15,1),
    (m03,'M03','sh3','Water supply disrupted (%)',pct_eq,15,1),
    (m07,'M07','h2','Health care needed (%)',pct_eq,15,1),
]
for item in checks:
    df, mod, var, label, fn, thr, extra = item
    if var not in df.columns: continue
    by_r = fn(df, var, extra) if extra is not None else fn(df, var)
    flags = flag_shifts(by_r, thr)
    if flags:
        dist_shifts.append({'module':mod,'variable':var,'label':label,
                            'values_by_round':by_r,'flags':flags})

# ─────────────────────────────────────────────────────────────────────────────
# HEATMAP (missing rates per variable per round)
# ─────────────────────────────────────────────────────────────────────────────
print('Building heatmaps...')

EXCL = {'hhid','pid','round','wave','strata','psu','weight','fweight',
        'stratum','popw','hhw','region','province','city','barangay',
        'locale','survey_lang','int_id','start_date','end_date','subm_date',
        'date_str','start_time','end_time','subm_time','time_str',
        'date_of_interview','time_of_interview','fmid','survey_round'}

def heatmap(df, keep=25):
    cols = [c for c in df.columns if c not in EXCL
            and not c.startswith(('wt','w_','_')) and c != 'round'][:keep]
    rows = []
    for var in cols:
        row = {'var': var}
        for r in ROUNDS:
            sub = df[df['round']==r]
            row[str(r)] = round(sub[var].isna().mean()*100, 1) if len(sub) else None
        vals = [row[str(r)] for r in ROUNDS if row[str(r)] is not None]
        mx = max(vals) if vals else 0
        row['rag'] = 'red' if mx>=15 else ('yellow' if mx>=5 else 'green')
        rows.append(row)
    return rows

heatmap_data = {
    'M00':heatmap(m00),'M01':heatmap(m01),'M02':heatmap(m02),
    'M03':heatmap(m03),'M04':heatmap(m04),'M05':heatmap(m05),
    'M06':heatmap(m06),'M07':heatmap(m07),'M08':heatmap(m08),'M09':heatmap(m09),
}

# ─────────────────────────────────────────────────────────────────────────────
# INTERVIEW METADATA
# ─────────────────────────────────────────────────────────────────────────────
print('Interview metadata...')
interview_meta = {}

dur_stats = {}
for r in ROUNDS:
    sub = n(m00[m00['round']==r]['dur_tot']).dropna()
    sub_valid = sub[(sub>0) & (sub<300)]
    sub_all   = sub[sub>0]
    if not len(sub_valid):
        dur_stats[r] = None; continue
    dur_stats[r] = {
        'n':int(len(sub_valid)),
        'p10':round(float(sub_valid.quantile(.10)),1),
        'p25':round(float(sub_valid.quantile(.25)),1),
        'p50':round(float(sub_valid.quantile(.50)),1),
        'p75':round(float(sub_valid.quantile(.75)),1),
        'p90':round(float(sub_valid.quantile(.90)),1),
        'p95':round(float(sub_valid.quantile(.95)),1),
        'very_short': int((sub_all<10).sum()),
        'short':      int(((sub_all>=10)&(sub_all<20)).sum()),
        'normal':     int(((sub_all>=20)&(sub_all<=60)).sum()),
        'long':       int(((sub_all>60)&(sub_all<=120)).sum()),
        'very_long':  int((sub_all>120).sum()),
        'outliers':   int((sub_all>300).sum()),
    }
interview_meta['duration'] = {'by_round': dur_stats}

mod_dur_data = {}
for label, col in [('Passport','dur_pp'),('Roster','dur_rr'),('Education','dur_educ'),
                   ('Shocks','dur_sh'),('Employment','dur_emp'),('Income','dur_inc'),
                   ('Finance','dur_fin'),('Health','dur_hlt'),('Food','dur_f_nf'),('Views','dur_vw')]:
    if col not in m00.columns: continue
    by_r = {}
    for r in ROUNDS:
        sub = n(m00[m00['round']==r][col]).dropna()
        by_r[r] = round(float(sub.median()),2) if len(sub) else None
    mod_dur_data[label] = by_r
interview_meta['module_durations'] = mod_dur_data

partial = {}
for r in ROUNDS:
    sub = m00[m00['round']==r]
    partial[r] = int((sub['interview_record']==2).sum()) if 'interview_record' in m00.columns else None
interview_meta['partial_interviews'] = {'by_round': partial}

excess = {}
for r in ROUNDS:
    sub = m00[m00['round']==r]
    excess[r] = int((n(sub['excess_int'])==1).sum()) if 'excess_int' in m00.columns else None
interview_meta['excess_interviews'] = {'by_round': excess}

call_att = {}
call_att_3p = {}
for r in ROUNDS:
    sub = n(m00[m00['round']==r]['call_attemp']).dropna() if 'call_attemp' in m00.columns else pd.Series()
    call_att[r] = round(float(sub.mean()),2) if len(sub) else None
    call_att_3p[r] = int((sub>=3).sum()) if len(sub) else None
interview_meta['call_attempts'] = {'mean_by_round': call_att, 'three_plus_by_round': call_att_3p}

# ─────────────────────────────────────────────────────────────────────────────
# MODULE SUMMARY
# ─────────────────────────────────────────────────────────────────────────────
print('Module summary...')

def mod_rag(mod_name):
    rows = heatmap_data.get(mod_name,[])
    vals = [row.get(str(r)) for row in rows for r in ROUNDS if row.get(str(r)) is not None]
    max_miss = max(vals) if vals else 0
    avg_miss = round(sum(vals)/len(vals),1) if vals else 0
    skip_t  = sum(v for s in skip_issues if s['module']==mod_name for v in s['counts_by_round'].values() if v)
    mand_t  = sum(v for m in mandatory_issues if m['module']==mod_name for v in m['counts_by_round'].values() if v)
    oor_t   = sum(v for o in oor_issues if o['module']==mod_name for v in o['counts'].values() if v)
    n_shifts= sum(1 for d in dist_shifts if d['module']==mod_name)
    rag = ('red' if skip_t>100 or mand_t>100 or max_miss>=30
           else 'yellow' if skip_t>0 or mand_t>0 or oor_t>0 or max_miss>=10
           else 'green')
    return {'avg_missing_pct':avg_miss,'max_missing_pct':round(max_miss,1),
            'n_skip_violations':int(skip_t),'n_mandatory_missing':int(mand_t),
            'n_oor_values':int(oor_t),'n_dist_shifts':int(n_shifts),'rag':rag}

module_summary = {m: mod_rag(m) for m in
    ['M00','M01','M02','M03','M04','M05','M06','M07','M08','M09']}

# ─────────────────────────────────────────────────────────────────────────────
# KEY MISSING RATES SPOTLIGHT
# ─────────────────────────────────────────────────────────────────────────────
key_missing = {}
key_missing['M03'] = {
    'sh1':{'label':'SH1 – Experienced shock (Ask all)','rates':mr(m03,'sh1')},
    'sh3':{'label':'SH3 – Water disruption (Ask all)','rates':mr(m03,'sh3')},
    'sh4':{'label':'SH4 – Days disruption (Ask if SH3=1)','rates':mr(m03,'sh4')},
    'el5':{'label':'EL5 – Hours no electricity (Ask all)','rates':mr(m03,'el5')},
}
key_missing['M04'] = {
    'a1': {'label':'A1 – Worked last week (conditional)','rates':mr(m04,'a1')},
    'a10':{'label':'A10 – Days worked (Ask if working)','rates':mr(m04,'a10')},
    'a11':{'label':'A11 – Hours worked (Ask if working)','rates':mr(m04,'a11')},
    'a3': {'label':'A3 – Reason not working (if A1=2)','rates':mr(m04,'a3')},
}
key_missing['M06'] = {
    'f1': {'label':'F1 – Formal deposits (R5: if F17=1)','rates':mr(m06,'f1')},
    'f3': {'label':'F3 – Saved money (Ask all)','rates':mr(m06,'f3')},
    'f7': {'label':'F7 – Applied for loan (Ask all)','rates':mr(m06,'f7')},
    'f9': {'label':'F9 – Loan institution (if F7=1)','rates':mr(m06,'f9')},
}
key_missing['M08'] = {
    'fies1':{'label':'FIES1 – Worried about food (Ask all)','rates':mr(m08,'fies1')},
    'fies5':{'label':'FIES5 – No food whole day (Ask all)','rates':mr(m08,'fies5')},
}
key_missing['M09'] = {
    'v1': {'label':'V1 – Life satisfaction (Ask all)','rates':mr(m09,'v1')},
    'v5': {'label':'V5 – Economic change (Ask all)','rates':mr(m09,'v5')},
}
key_missing['M07'] = {
    'h2': {'label':'H2 – Health care needed (Ask all)','rates':mr(m07,'h2')},
    'h2a':{'label':'H2A – Able to get care (if H2=1/2/3)','rates':mr(m07,'h2a') if 'h2a' in m07.columns else {r:None for r in ROUNDS}},
}

# ─────────────────────────────────────────────────────────────────────────────
# SERIALIZE
# ─────────────────────────────────────────────────────────────────────────────
def safe(obj):
    if isinstance(obj, dict):   return {k: safe(v) for k, v in obj.items()}
    if isinstance(obj, list):   return [safe(v) for v in obj]
    if isinstance(obj, (np.integer,)):  return int(obj)
    if isinstance(obj, (np.floating,)): return None if np.isnan(obj) else float(obj)
    if isinstance(obj, float) and (np.isnan(obj) or np.isinf(obj)): return None
    return obj

output = safe({
    'rounds': ROUNDS,
    'sample_counts': sample_counts,
    'heatmap_data': heatmap_data,
    'skip_issues': skip_issues,
    'mandatory_issues': mandatory_issues,
    'oor_issues': oor_issues,
    'dist_shifts': dist_shifts,
    'interview_meta': interview_meta,
    'module_summary': module_summary,
    'key_missing': key_missing,
})

path = str(_CACHE / 'dq_data.json')
with open(path, 'w') as f:
    json.dump(output, f, separators=(',',':'))

kb = os.path.getsize(path)/1024
print(f'\nSaved → {path} ({kb:.1f} KB)')
print(f'Skip rules: {len(skip_issues)}  Mandatory: {len(mandatory_issues)}  OOR: {len(oor_issues)}  Shifts: {len(dist_shifts)}')
print('\nModule summary:')
for m,s in module_summary.items():
    print(f"  {m}: skip={s['n_skip_violations']} mand_miss={s['n_mandatory_missing']} "
          f"oor={s['n_oor_values']} rag={s['rag']}")
