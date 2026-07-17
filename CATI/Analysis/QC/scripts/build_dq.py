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

ROUNDS = [1, 2, 3, 4, 5, 6, 7, 8, 9]

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
# Harmonize naming inconsistency: some rounds saved _other instead of _oth
if 'member_leftreason_other' in m01.columns and 'member_leftreason_oth' in m01.columns:
    m01['member_leftreason_oth'] = m01['member_leftreason_oth'].fillna(m01['member_leftreason_other'])
    m01.drop(columns=['member_leftreason_other'], inplace=True)
elif 'member_leftreason_other' in m01.columns:
    m01.rename(columns={'member_leftreason_other': 'member_leftreason_oth'}, inplace=True)
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
        return {r: 0 for r in ROUNDS}, {r: 0 for r in ROUNDS}
    out_cnt, out_pct = {}, {}
    gate_num = n(df[gate_col])
    gate_mask = gate_num.isin(gate_ask_vals)
    for r in ROUNDS:
        round_mask = df['round'] == r
        sub_gate = df[round_mask & gate_mask]
        if not len(sub_gate):
            out_cnt[r] = 0; out_pct[r] = 0; continue  # No eligible cases → 0 violations
        # Check if ALL follow-up cols are missing (none filled)
        # Uses is_filled() instead of .isna() to catch empty strings & 'nan' strings
        all_missing = pd.Series(True, index=sub_gate.index)
        for fc in follow_cols:
            if fc in df.columns:
                all_missing &= ~is_filled(sub_gate[fc])
        c = int(all_missing.sum())
        out_cnt[r] = c
        out_pct[r] = round(100*c/len(sub_gate), 1)
    return out_cnt, out_pct

def oor(df, var, lo=None, hi=None, exclude_special=(-99,-95,97,98,99)):
    """Count out-of-range values per round. Excludes special codes.
    Returns None only if the variable truly doesn't exist for that round
    (column missing). Returns 0 if column exists but all values are null
    (this is a data issue, not a missing-variable issue)."""
    if var not in df.columns:
        return {r: None for r in ROUNDS}
    out = {}
    for r in ROUNDS:
        sub = df[df['round']==r]
        if not len(sub):
            out[r] = None; continue
        raw = n(sub[var])
        vals = raw.dropna()
        vals = vals[~vals.isin(exclude_special)]
        if not len(vals):
            # Column exists but no clean values: 0 (not None)
            # This makes it green instead of grey — the missing-ness
            # is flagged in the mandatory panel, not here.
            out[r] = 0; continue
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

# ── Mandatory checks ──
# call_status1=1 → Z16 (correct_resp) must be filled
c, p = check_mandatory(m00, 'call_status1', [1], ['correct_resp'])
mandatory_issues.append({
    'module':'M00','rule':'call_status1=1 but Z16 (correct respondent) is missing',
    'variable':'call_status1=1 → Z16','counts_by_round':c,'pct_by_round':p,'severity':'high',
    'note':'Kobo: Z16 relevant=${call_status1}=1. Must confirm respondent identity.'
})

# call_status1=1 → Z9 (agreement) must be filled
c, p = check_mandatory(m00, 'call_status1', [1], ['agreement'])
mandatory_issues.append({
    'module':'M00','rule':'call_status1=1 but Z9 (agreement/consent) is missing',
    'variable':'call_status1=1 → Z9','counts_by_round':c,'pct_by_round':p,'severity':'high',
    'note':'Kobo: Z9 relevant=${call_status1}=1. Consent must be recorded for every call.'
})

# agreement=1 → Z19 (interview_record) must be filled
c, p = check_mandatory(m00, 'agreement', [1], ['interview_record'])
mandatory_issues.append({
    'module':'M00','rule':'Z9=1 (agreed) but Z19 (recording consent) is missing',
    'variable':'Z9=1 → Z19','counts_by_round':c,'pct_by_round':p,'severity':'medium',
    'note':'Kobo: Z19 relevant=${Z9}=1. Recording consent must be asked to all agreeing respondents.'
})

# agreement=1 → Z20 (address_unchanged) must be filled
c, p = check_mandatory(m00, 'agreement', [1], ['address_unchanged'])
mandatory_issues.append({
    'module':'M00','rule':'Z9=1 (agreed) but Z20 (address unchanged) is missing',
    'variable':'Z9=1 → Z20','counts_by_round':c,'pct_by_round':p,'severity':'medium',
    'note':'Kobo: Z20 relevant=${Z9}=1. Address verification required for all consenting respondents.'
})

# ── Skip logic checks ──
# agreement=1 (agreed) → Z18 (refusal_reason) should NOT be filled
c, p = check_skip(m00, 'agreement', [1], ['refusal_reason'])
skip_issues.append({
    'module':'M00','rule':'Z9=1 (agreed) but Z18 (refusal reason) is filled',
    'variable':'Z9=1 → Z18 should be empty','counts_by_round':c,'pct_by_round':p,'severity':'medium',
    'note':'Kobo: Z18 relevant=${Z9}=2 only. Refusal reason should be blank for agreeing respondents.'
})

# agreement=1 → Z18_oth (refusal_reason_oth) should NOT be filled
c, p = check_skip(m00, 'agreement', [1], ['refusal_reason_oth'])
skip_issues.append({
    'module':'M00','rule':'Z9=1 (agreed) but Z18_oth (other refusal reason) is filled',
    'variable':'Z9=1 → Z18_oth should be empty','counts_by_round':c,'pct_by_round':p,'severity':'medium',
    'note':'Kobo: Z18_oth relevant=${Z18}=96 AND ${Z9}=2. Should be blank for agreeing respondents.'
})

# ── OOR checks ──
# call_attemp: reasonable range 1-20
oor_issues.append({
    'module':'M00','variable':'call_attemp','label':'Z8 (call_attemp)',
    'rule':'< 1 or > 20 call attempts',
    'counts': oor(m00, 'call_attemp', 1, 20, exclude_special=()),
    'severity':'medium',
    'note':'Call attempt number should be between 1 and 20. Values outside suggest data entry error.'
})

# Interview duration: valid 5-180 min (real interviews)
oor_issues.append({
    'module':'M00','variable':'dur_tot','label':'Total interview duration',
    'rule':'< 5 min (suspiciously short) or > 180 min',
    'counts': oor(m00, 'dur_tot', 5, 180, exclude_special=()),
    'severity':'high',
    'note': 'Median ~28 min. <5 min = possible speeding (only ~1 case). >180 min (incl. some absurd, e.g. >13,000 min) are almost all CATI suspend/resume — interview spans multiple callbacks, timer keeps running. Treat long durations as paradata artifacts, not 3-hour interviews.'
})

# Module durations - each module should take >0 min
for col, label in [('dur_pp','Duration Passport'),('dur_rr','Duration Roster'),
                   ('dur_educ','Duration Education'),('dur_sh','Duration Shocks'),
                   ('dur_emp','Duration Employment'),('dur_inc','Duration Income'),
                   ('dur_fin','Duration Finance'),('dur_hlt','Duration Health'),
                   ('dur_f_nf','Duration Food/NonFood'),('dur_vw','Duration Views')]:
    oor_issues.append({
        'module':'M00','variable':col,'label':label,
        'rule':'≤0 or >999 min (implausible duration)',
        'counts': oor(m00, col, 0.001, 999, exclude_special=()),
        'severity':'medium',
        'note':'Negative/zero or huge module durations are almost always CATI suspend/resume or callback timing artifacts (the timer spans the gap between call attempts) — not response errors. Review interviewer/app timing, not the answers.'
    })

# ─────────────────────────────────────────────────────────────────────────────
# MODULE 01: ROSTER / DEMOGRAPHICS
# ─────────────────────────────────────────────────────────────────────────────
print('M01 Roster / Demographics...')

# Kobo mappings (from Question-Level Cross-Round Tracker):
# D5A = isfmid — 5 response options in Kobo:
#   1=Yes, 2=Left HH, 3=Name wrong, 4=Age wrong, 5=Sex wrong [R2+]
#   Code 6 (New member) is DERIVED in Stata from D29=1 rows — not a D5A response option.
#   D29 asks "Are there any new HH members?" → if yes, D30/D31/D32 collect name/sex/age,
#   and the do-file creates new roster rows with isfmid=6.
# D25 = member_leftreason (if isfmid=2)
# D26_1/2/3 = country_moved/prov_moved/city_moved (if member_leftreason=1/2)
# D27 = correct_name (if isfmid=3)
# D28 = correct_age (if isfmid=4)
# D33 = correct_gender (if isfmid=5, R2+ only — R1 had no Code 5)
# D29 = new_member incidence (select_one yes-none) — triggers new member block
# D30/D31/D32 = new member name/sex/age — consumed during do-file processing
# D6  = relationship (if isfmid=6, new members from D29)
# M13 = moved_in_reason (if isfmid=6, new members, R3+)
# M10_1/2/3 = country_migrated_from/province_migrated_from/city_migrated_from

# ── isfmid → member_leftreason ──
c,p = check_mandatory(m01, 'isfmid', [2], ['member_leftreason'])
mandatory_issues.append({
    'module':'M01','rule':'D5a=2 (left HH) but D25 (reason for leaving) is missing',
    'variable':'D5A=2 → D25','counts_by_round':c,'pct_by_round':p,'severity':'high',
    'note':'Kobo: D25 relevant=${D5a_}=2. When member left household, reason must be recorded.'
})

c,p = check_skip(m01, 'isfmid', [1,3,4,5], ['member_leftreason'])
skip_issues.append({
    'module':'M01','rule':'D5a≠2 but D25 (reason for leaving) is filled',
    'variable':'D5A≠2 → D25 should be empty','counts_by_round':c,'pct_by_round':p,'severity':'medium',
    'note':'Kobo: D25 only relevant when D5a=2. Should be blank for permanent/moved-in/passed/born.'
})

# ── member_leftreason=1/2 → destination (prov_moved, city_moved) ──
if 'member_leftreason' in m01.columns:
    mask_left = (n(m01['isfmid'])==2) & n(m01['member_leftreason']).isin([1,2])
    dest_cols = [c for c in ['prov_moved','city_moved'] if c in m01.columns]
    if dest_cols:
        c2, p2 = {}, {}
        for r in ROUNDS:
            sub = m01[(m01['round']==r) & mask_left.fillna(False)]
            if not len(sub):
                c2[r]=0; p2[r]=0; continue  # No eligible cases → 0 violations
            all_miss = pd.Series(True, index=sub.index)
            for dc in dest_cols:
                all_miss &= sub[dc].isna()
            # Firm QC Tracker 20260701: D26_2/3 (prov/city) are required only for DOMESTIC
            # moves (country_moved=1=Philippines). Moves abroad (e.g. Jordan/KSA/Korea) or
            # with no country recorded leave prov/city legitimately blank -> not a violation.
            if 'country_moved' in sub.columns:
                all_miss &= (n(sub['country_moved']) == 1)
            c2[r] = int(all_miss.sum())
            p2[r] = round(100*all_miss.mean(),1)
        mandatory_issues.append({
            'module':'M01','rule':'D5a=2 AND D25=1/2 (moved away) but D26 (destination) is missing',
            'variable':'D25=1/2 → D26_2, D26_3','counts_by_round':c2,'pct_by_round':p2,'severity':'medium',
            'note':'Firm QC 20260701: D26_2/3 required only when country_moved=Philippines (domestic). Abroad/unspecified -> blank valid.'
        })

# ── isfmid → moved_in_reason (D27) ──
# Kobo D5a routing changed across rounds:
#   R1-R2: D27 asked when D5a=3 ("moved in") — but pooled isfmid was recoded, and
#          moved_in_reason is filled for isfmid=1 (R2) and isfmid=5 (R1, originally "born")
#   R3-R5: D27 asked for new members — isfmid=6 ("New member joined this round")
# The pooled isfmid categories ≠ original Kobo D5a codes due to harmonisation recoding.
# Gate: isfmid=6 is the reliable gate for R3-R5; R1-R2 routing is inconsistent.
if 'moved_in_reason' in m01.columns:
    # Mandatory: new members (R3-R5) should have a reason recorded
    m01_r3plus = m01[m01['round'].isin([3,4,5])] if 'round' in m01.columns else m01
    c,p = check_mandatory(m01_r3plus, 'isfmid', [6], ['moved_in_reason'])
    mandatory_issues.append({
        'module':'M01','rule':'D29=1 (new member) but M13 (reason for moving in) is missing',
        'variable':'D29=1 → M13 (coded D5A=6 in Stata)','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'R3-R5 only: M13 relevant for new members identified via D29. R1-R2 routing differs — excluded.'
    })

    # Skip: moved_in_reason should be empty for non-new-members in R3-R5
    # R1-R2 excluded from skip check due to different routing
    c,p = check_skip(m01_r3plus, 'isfmid', [1,2,3,4,5], ['moved_in_reason'])
    skip_issues.append({
        'module':'M01','rule':'D5a≠6 but D27 (move-in reason) is filled (R3-R5)',
        'variable':'D5A≠6 → M13 should be empty','counts_by_round':c,'pct_by_round':p,'severity':'low',
        'note':'R3-R5: M13 relevant only for new members (D29=1, coded D5A=6). R1-R2 excluded (different routing).'
    })

# ── ED15/ED16 checks moved to M02 (education belongs there, not in M01 roster) ──

# ── member_leftreason=96 → member_leftreason_oth (other specify) ──
if 'member_leftreason_oth' in m01.columns:
    c,p = {}, {}
    for r in ROUNDS:
        sub = m01[(m01['round']==r) & (n(m01['member_leftreason'])==96)]
        if not len(sub):
            c[r]=0; p[r]=0; continue  # No eligible cases → 0 violations
        miss = (~is_filled(sub['member_leftreason_oth'])).sum()
        c[r] = int(miss); p[r] = round(100*miss/len(sub),1)
    mandatory_issues.append({
        'module':'M01','rule':'D25=96 (other) but D25_other (specify) is missing',
        'variable':'D25=96 → D25_oth','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'When D25=96 (other reason for leaving), specification must be recorded.'
    })

# ── Age OOR ──
oor_issues.append({
    'module':'M01','variable':'age','label':'Respondent age (D32)',
    'rule':'< 0 or > 120',
    'counts': oor(m01, 'age', 0, 120),
    'severity':'high',
    'note':'Questionnaire specifies valid age range 0-120 years.'
})

# ── Gender OOR ──
oor_issues.append({
    'module':'M01','variable':'gender','label':'Sex/Gender',
    'rule':'Not 1 or 2',
    'counts': oor(m01, 'gender', 1, 2, exclude_special=(98,99)),
    'severity':'high',
    'note':'Valid codes: 1=Male, 2=Female only.'
})

# ── isfmid (D5A) OOR ──
oor_issues.append({
    'module':'M01','variable':'isfmid','label':'D5A: Member status (isfmid)',
    'rule':'Not in 1–6',
    'counts': oor(m01, 'isfmid', 1, 6),
    'severity':'high',
    'note':'Kobo D5A has 5 options: 1=Yes, 2=Left, 3=Name wrong, 4=Age wrong, 5=Sex wrong. Code 6=New member is derived in Stata from D29=1 rows.'
})

# ── isfmid mandatory (must be filled for all roster members) ──
if 'isfmid' in m01.columns:
    c, p = {}, {}
    for r in ROUNDS:
        sub = m01[m01['round']==r]
        if not len(sub):
            c[r]=0; p[r]=0; continue  # No roster members → 0 violations
        miss = sub['isfmid'].isna().sum()
        c[r] = int(miss); p[r] = round(100*miss/len(sub),1)
    mandatory_issues.append({
        'module':'M01','rule':'D5A must be filled for all roster members',
        'variable':'D5A','counts_by_round':c,'pct_by_round':p,'severity':'high',
        'note':'D5A is the core roster verification question — must be answered for every member.'
    })

# ── correct_name (D27): isfmid=3 → correct_name mandatory ──
if 'correct_name' in m01.columns:
    c, p = {}, {}
    for r in ROUNDS:
        sub = m01[(m01['round']==r) & (n(m01['isfmid'])==3)]
        if not len(sub):
            c[r]=0; p[r]=0; continue  # No eligible cases → 0 violations
        miss = (~is_filled(sub['correct_name'])).sum()
        c[r] = int(miss); p[r] = round(100*miss/len(sub),1)
    mandatory_issues.append({
        'module':'M01','rule':'D5A=3 (name wrong) but D27 (correct name) is missing',
        'variable':'D5A=3 → D27','counts_by_round':c,'pct_by_round':p,'severity':'high',
        'note':'Kobo: D27 relevant when D5a=3 (name recorded incorrectly). Correct name must be recorded.'
    })

    # Skip: correct_name should be empty when isfmid≠3
    c, p = check_skip(m01, 'isfmid', [1,2,4,5,6], ['correct_name'])
    skip_issues.append({
        'module':'M01','rule':'D5A≠3 but D27 (correct name) is filled',
        'variable':'D5A≠3 → D27 should be empty','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'D27 only relevant when D5a=3 (name incorrect). Should be blank otherwise.'
    })

# ── correct_age (D28): isfmid=4 → correct_age mandatory ──
if 'correct_age' in m01.columns:
    c, p = check_mandatory(m01, 'isfmid', [4], ['correct_age'])
    mandatory_issues.append({
        'module':'M01','rule':'D5A=4 (age wrong) but D28 (correct age) is missing',
        'variable':'D5A=4 → D28','counts_by_round':c,'pct_by_round':p,'severity':'high',
        'note':'Kobo: D28 relevant when D5a=4 (age recorded incorrectly). Correct age must be recorded.'
    })

    # Skip: correct_age should be empty when isfmid≠4
    c, p = check_skip(m01, 'isfmid', [1,2,3,5,6], ['correct_age'])
    skip_issues.append({
        'module':'M01','rule':'D5A≠4 but D28 (correct age) is filled',
        'variable':'D5A≠4 → D28 should be empty','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'D28 only relevant when D5a=4 (age incorrect). Should be blank otherwise.'
    })

    # OOR for correct_age
    oor_issues.append({
        'module':'M01','variable':'correct_age','label':'D28: Corrected age',
        'rule':'< 0 or > 120',
        'counts': oor(m01, 'correct_age', 0, 120),
        'severity':'high',
        'note':'Same valid range as age (0–120 years).'
    })

# ── correct_gender (D33): isfmid=5 → correct_gender mandatory (R2+ only) ──
# D5A Code 5 ("sex wrong") added from R2 onwards (R1 title was "NAME & AGE" only, no sex)
if 'correct_gender' in m01.columns:
    m01_r2plus = m01[m01['round'].isin([2,3,4,5])] if 'round' in m01.columns else m01
    c, p = check_mandatory(m01_r2plus, 'isfmid', [5], ['correct_gender'])
    mandatory_issues.append({
        'module':'M01','rule':'D5A=5 (sex wrong) but D33 (correct sex) is missing (R2+)',
        'variable':'D5A=5 → D33','counts_by_round':c,'pct_by_round':p,'severity':'high',
        'note':'Kobo R2-R5: D33 relevant when D5a=5 (sex recorded incorrectly). R1 excluded (Code 5 not in R1 questionnaire).'
    })

    # Skip: correct_gender should be empty when isfmid≠5
    c, p = check_skip(m01_r2plus, 'isfmid', [1,2,3,4,6], ['correct_gender'])
    skip_issues.append({
        'module':'M01','rule':'D5A≠5 but D33 (correct sex) is filled (R2+)',
        'variable':'D5A≠5 → D33 should be empty','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'D33 only relevant when D5a=5 (sex incorrect). R1 excluded (Code 5 not in R1 questionnaire).'
    })

    # OOR for correct_gender
    oor_issues.append({
        'module':'M01','variable':'correct_gender','label':'D33: Corrected sex',
        'rule':'Not 1 or 2',
        'counts': oor(m01, 'correct_gender', 1, 2, exclude_special=(98,99)),
        'severity':'high',
        'note':'Valid codes: 1=Male, 2=Female only.'
    })

# ── relationship (D6): isfmid=6 → relationship mandatory ──
if 'relationship' in m01.columns:
    c, p = check_mandatory(m01, 'isfmid', [6], ['relationship'])
    mandatory_issues.append({
        'module':'M01','rule':'D29=1 (new member) but D6 (relationship) is missing',
        'variable':'D29=1 → D6 (coded D5A=6 in Stata)','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'D6 asked for new HH members identified via D29. Relationship to HH head must be recorded.'
    })

    # Skip: relationship should be empty for non-new members
    c, p = check_skip(m01, 'isfmid', [1,2,3,4,5], ['relationship'])
    skip_issues.append({
        'module':'M01','rule':'D5A≠6 but D6 (relationship) is filled',
        'variable':'D5A≠6 → D6 should be empty','counts_by_round':c,'pct_by_round':p,'severity':'low',
        'note':'D6 only relevant for new members (D29=1, coded D5A=6). Should be blank for existing/left members.'
    })

    oor_issues.append({
        'module':'M01','variable':'relationship','label':'D6: Relationship to HH head',
        'rule':'Not in 1–13',
        'counts': oor(m01, 'relationship', 1, 13, exclude_special=(96,98,99)),
        'severity':'medium',
        'note':'Valid codes: 1=Head, 2=Spouse, 3–13=Other relationships, 96=Other specify.'
    })

# ── moved_in_reason_oth (M13_oth): moved_in_reason=96 → other specify ──
if 'moved_in_reason_oth' in m01.columns and 'moved_in_reason' in m01.columns:
    c, p = {}, {}
    for r in ROUNDS:
        sub = m01[(m01['round']==r) & (n(m01['moved_in_reason'])==96)]
        if not len(sub):
            c[r]=0; p[r]=0; continue  # No eligible cases → 0 violations
        miss = (~is_filled(sub['moved_in_reason_oth'])).sum()
        c[r] = int(miss); p[r] = round(100*miss/len(sub),1)
    mandatory_issues.append({
        'module':'M01','rule':'M13=96 (other) but M13_oth (specify) is missing',
        'variable':'M13=96 → M13_oth','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'When M13=96 (other reason for moving in), specification must be recorded.'
    })

# ── country_migrated_from (M10_1): isfmid=6 → origin mandatory ──
if 'country_migrated_from' in m01.columns:
    c, p = check_mandatory(m01, 'isfmid', [6], ['country_migrated_from'])
    mandatory_issues.append({
        'module':'M01','rule':'D29=1 (new member) but M10_1 (origin country) is missing',
        'variable':'D29=1 → M10_1 (coded D5A=6 in Stata)','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'M10 asked for new HH members identified via D29. Origin location must be recorded.'
    })

# ── hhsize OOR ──
oor_issues.append({
    'module':'M01','variable':'hhsize','label':'Household size (derived)',
    'rule':'< 1 or > 30',
    'counts': oor(m01, 'hhsize', 1, 30),
    'severity':'medium',
    'note':'Derived from roster count. Flag unusually large households.'
})

# ─────────────────────────────────────────────────────────────────────────────
# MODULE 02: EDUCATION
# ─────────────────────────────────────────────────────────────────────────────
print('M02 Education...')

# Kobo: ED16_1_ relevant=${ED15_1}=2
ed16_cols = [c for c in m02.columns if c.startswith('ed16')]
if not ed16_cols:
    ed16_cols = ['ed16']

# Gate to R1-R3 only — ED16 not collected in R4-R5
m02_r1r3 = m02[m02['round'].isin([1,2,3])] if 'round' in m02.columns else m02
c,p = check_mandatory(m02_r1r3, 'ed15', [2], ed16_cols)
mandatory_issues.append({
    'module':'M02','rule':'ED15=2 (dropped out) but ED16 (dropout reason) is missing',
    'variable':'ED15=2 → ED16','counts_by_round':c,'pct_by_round':p,'severity':'medium',
    'note':'Kobo: ED16_1_ relevant=${ED15_1}=2. R4-R5 excluded — ED16 not collected in those rounds.'
})

c,p = check_skip(m02_r1r3, 'ed15', [1], ed16_cols)
skip_issues.append({
    'module':'M02','rule':'ED15=1 (still in school) but ED16 (dropout reason) is filled',
    'variable':'ED15=1 → ED16 should be empty','counts_by_round':c,'pct_by_round':p,'severity':'medium',
    'note':'Kobo: ED16_1_ relevant=${ED15_1}=2. R4-R5 excluded — ED16 not collected in those rounds.'
})

# ─────────────────────────────────────────────────────────────────────────────
# MODULE 03: SHOCKS
# ─────────────────────────────────────────────────────────────────────────────
print('M03 Shocks...')

# Kobo: SH1b_ relevant=${SH1}=1
sh1b_cols = [c for c in m03.columns if c.startswith('sh1b') and c != 'sh1b']
if not sh1b_cols: sh1b_cols = ['sh1b_1','sh1b_2','sh1b_3','sh1b_4']
sh1b_cols_exist = [c for c in sh1b_cols if c in m03.columns]

c,p = check_mandatory(m03, 'sh1', [1], sh1b_cols_exist)
mandatory_issues.append({
    'module':'M03','rule':'SH1=1 (shock experienced) but SH1b (shock type) is missing',
    'variable':'SH1=1 → SH1b','counts_by_round':c,'pct_by_round':p,'severity':'high',
    'note':'Kobo: SH1b_ relevant=${SH1}=1. Shock type must be recorded.'
})

c,p = check_skip(m03, 'sh1', [2], sh1b_cols_exist)
skip_issues.append({
    'module':'M03','rule':'SH1=2 (no shock) but SH1b (shock types) is filled',
    'variable':'SH1=2 → SH1b should be empty','counts_by_round':c,'pct_by_round':p,'severity':'high',
    'note':'Kobo: SH1b_ relevant=${SH1}=1. Should be blank when no shock reported.'
})

# ── SH2 (coping strategy) gated on SH1=1 ──
# Kobo: sh2_ relevant=${SH1}=1
sh2_cols_exist = [c for c in m03.columns if c.startswith('sh2')]
if sh2_cols_exist:
    c,p = check_mandatory(m03, 'sh1', [1], sh2_cols_exist)
    mandatory_issues.append({
        'module':'M03','rule':'SH1=1 (shock) but SH2 (coping strategy) is missing',
        'variable':'SH1=1 → SH2','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'Kobo: sh2_ relevant=${SH1}=1. Coping strategy must be recorded.'
    })

    c,p = check_skip(m03, 'sh1', [2], sh2_cols_exist)
    skip_issues.append({
        'module':'M03','rule':'SH1=2 (no shock) but SH2 (coping strategy) is filled',
        'variable':'SH1=2 → SH2 should be empty','counts_by_round':c,'pct_by_round':p,'severity':'high',
        'note':'Kobo: sh2_ relevant=${SH1}=1. Should be blank when no shock.'
    })

# ── SH3 (water disruption) → SH4 (days) ──
# Kobo: SH4 relevant=${SH3}=1
sh4_col = 'sh4' if 'sh4' in m03.columns else None
if sh4_col:
    c,p = check_mandatory(m03, 'sh3', [1], [sh4_col])
    mandatory_issues.append({
        'module':'M03','rule':'SH3=1 (water disruption) but SH4 (days) is missing',
        'variable':'SH3=1 → SH4','counts_by_round':c,'pct_by_round':p,'severity':'high',
        'note':'Kobo: SH4 relevant=${SH3}=1. Days of disruption must be recorded.'
    })

    c,p = check_skip(m03, 'sh3', [2], [sh4_col])
    skip_issues.append({
        'module':'M03','rule':'SH3=2 (no water disruption) but SH4 (disruption days) is filled',
        'variable':'SH3=2 → SH4 should be empty','counts_by_round':c,'pct_by_round':p,'severity':'high',
        'note':'Kobo: SH4 relevant=${SH3}=1. Should be blank when no water disruption.'
    })

# ── SH4 OOR ──
oor_issues.append({
    'module':'M03','variable':'sh4','label':'Days of water supply disruption',
    'rule':'< 1 or > 30',
    'counts': oor(m03, 'sh4', 1, 30),
    'severity':'high',
    'note':'Questionnaire specifies valid range 1-30 days.'
})

# ── EL5 OOR (electricity hours unavailable) ──
oor_issues.append({
    'module':'M03','variable':'el5','label':'Hours electricity unavailable',
    'rule':'< 0 or > 168',
    'counts': oor(m03, 'el5', 0, 168),
    'severity':'high',
    'note':'Questionnaire specifies valid range 0-168 hours (max hours in a week).'
})

# ─────────────────────────────────────────────────────────────────────────────
# MODULE 04: EMPLOYMENT
# ─────────────────────────────────────────────────────────────────────────────
print('M04 Employment...')

# CRITICAL NOTE: A24, A25, A26, A27 are routing variables NOT in the pooled .dta.
# Many checks depend on these. Severity='medium' for affected checks with notes about approximation.

# ── A3, A4, A5 "other specify" (96 = other) ──
if 'a3_oth' in m04.columns:
    c,p = {}, {}
    for r in ROUNDS:
        sub = m04[(m04['round']==r) & (n(m04['a3'])==96)]
        if not len(sub):
            c[r]=0; p[r]=0; continue  # No eligible cases → 0 violations
        miss = (~is_filled(sub['a3_oth'])).sum()
        c[r] = int(miss); p[r] = round(100*miss/len(sub),1)
    mandatory_issues.append({
        'module':'M04','rule':'A3=96 (other occupation) but A3_other (specify) is missing',
        'variable':'a3=96 → a3_oth','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'When A3=96, occupation specification must be recorded.'
    })

if 'a4_oth' in m04.columns:
    c,p = {}, {}
    for r in ROUNDS:
        sub = m04[(m04['round']==r) & (n(m04['a4'])==9996)]
        if not len(sub):
            c[r]=0; p[r]=0; continue  # No eligible cases → 0 violations
        miss = (~is_filled(sub['a4_oth'])).sum()
        c[r] = int(miss); p[r] = round(100*miss/len(sub),1)
    mandatory_issues.append({
        'module':'M04','rule':'A4=9996 (other sector) but A4_other (specify) is missing',
        'variable':'a4=9996 → a4_oth','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'When A4=9996 (other sector), specification must be recorded.'
    })

if 'a5_oth' in m04.columns:
    c,p = {}, {}
    for r in ROUNDS:
        sub = m04[(m04['round']==r) & (n(m04['a5'])==96)]
        if not len(sub):
            c[r]=0; p[r]=0; continue  # No eligible cases → 0 violations
        miss = (~is_filled(sub['a5_oth'])).sum()
        c[r] = int(miss); p[r] = round(100*miss/len(sub),1)
    mandatory_issues.append({
        'module':'M04','rule':'A5=96 (other main product) but A5_other (specify) is missing',
        'variable':'a5=96 → a5_oth','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'When A5=96 (agriculture other), specification must be recorded.'
    })

# ── A8 (gig/platform work) → A9 (digital platform) ──
# Kobo: A9 relevant=${A8}=1
if 'a9' in m04.columns and 'a8' in m04.columns:
    c,p = check_mandatory(m04, 'a8', [1], ['a9'])
    mandatory_issues.append({
        'module':'M04','rule':'A8=1 (gig work) but A9 (digital platform) is missing',
        'variable':'A8=1 → A9','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'Kobo: A9 relevant=${A8}=1. Digital platform use must be recorded for gig workers.'
    })

    c,p = check_skip(m04, 'a8', [2,99], ['a9'])
    skip_issues.append({
        'module':'M04','rule':'A8=2/99 (not gig work) but A9 (digital platform) is filled',
        'variable':'A8≠1 → A9 should be empty','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'Kobo: A9 relevant=${A8}=1. Should be blank for non-gig workers.'
    })

# ── A16 (contract status) → A17 (contract duration) ──
# Kobo: A17 relevant=${A16}=1 or ${A16}=2
if 'a17' in m04.columns and 'a16' in m04.columns:
    c,p = check_mandatory(m04, 'a16', [1,2], ['a17'])
    mandatory_issues.append({
        'module':'M04','rule':'A16=1/2 (has contract) but A17 (contract duration) is missing',
        'variable':'A16=1/2 → A17','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'Kobo: A17 relevant=${A16}=1 or ${A16}=2. Duration must be recorded if contract exists.'
    })

    c,p = check_skip(m04, 'a16', [3,99], ['a17'])
    skip_issues.append({
        'module':'M04','rule':'A16=3/99 (no contract/DK) but A17 (contract duration) is filled',
        'variable':'A16≠1,2 → A17 should be empty','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'Kobo: A17 relevant=${A16}=1 or ${A16}=2. Should be blank when no contract.'
    })

# ── A6=4 (gig/platform) → A20 (gig earnings) ──
# Kobo: A20 relevant=${A6}=4
if 'a20' in m04.columns and 'a6' in m04.columns:
    c,p = check_mandatory(m04, 'a6', [4], ['a20'])
    mandatory_issues.append({
        'module':'M04','rule':'A6=4 (gig/platform work) but A20 (gig earnings) is missing',
        'variable':'A6=4 → A20','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'Kobo: A20 relevant=${A6}=4. Gig earnings must be recorded for platform workers.'
    })

# ── A5=1 (agriculture) AND A6 in (5,6,7) → A7 (farm type) ──
# Kobo: A7 relevant=${A5}=1 and (${A6}=5 or ${A6}=6 or ${A6}=7)
if 'a7' in m04.columns and 'a5' in m04.columns and 'a6' in m04.columns:
    c7, p7 = {}, {}
    for r in ROUNDS:
        sub = m04[(m04['round']==r) & (n(m04['a5'])==1) & n(m04['a6']).isin([5,6,7])]
        if not len(sub):
            c7[r]=0; p7[r]=0; continue
        miss = sub['a7'].isna().sum()
        c7[r] = int(miss); p7[r] = round(100*miss/len(sub),1)
    mandatory_issues.append({
        'module':'M04','rule':'A5=1 (agriculture) AND A6=5/6/7 (farm activity) but A7 (farm type) is missing',
        'variable':'A5=1,A6=5/6/7 → A7','counts_by_round':c7,'pct_by_round':p7,'severity':'medium',
        'note':'Kobo: A7 relevant=${A5}=1 and (${A6}=5 or ${A6}=6 or ${A6}=7). Farm type must be recorded.'
    })

# ── A1=2 (not working) → A10/A11 should be empty ──
# Firm-confirmed routing (per the A18/A19 clarification, Firm QC Tracker 20260701):
# A10/A11 are reached via the employment BLOCK (A1=1 OR A24=1 OR A26=1 OR A27=1), not A1
# alone. Someone with A1=2 who still worked in the reference period (A24/A26/A27=1)
# legitimately has days/hours. Flag only A1=2 with NO work path (the genuine residual).
c, p = {}, {}
_work_paths = [w for w in ['a24','a26','a27'] if w in m04.columns]
for r in ROUNDS:
    sub = m04[m04['round']==r]
    if not len(sub):
        c[r]=0; p[r]=0; continue
    a1_v = n(sub['a1'])
    reached = (a1_v==1)
    for wp in _work_paths:
        reached = reached | (n(sub[wp])==1)
    not_working = (a1_v==2) & ~reached
    filled = pd.Series(False, index=sub.index)
    for dc in ['a10','a11']:
        if dc in sub.columns: filled |= n(sub[dc]).notna()
    viol = not_working & filled
    gate = int(not_working.sum())
    c[r] = int(viol.sum()); p[r] = round(100*int(viol.sum())/gate,1) if gate else 0
skip_issues.append({
    'module':'M04','rule':'A1=2 (not working) but A10/A11 (days/hours) are filled',
    'variable':'A1=2 → A10,A11 should be empty','counts_by_round':c,'pct_by_round':p,'severity':'medium',
    'note':'Firm QC 20260701 routing: A10/A11 reached via A1=1 OR A24/A26/A27=1. Residual flags = A1=2 with NO work path but days/hours filled (genuine, for the firm).'
})

# ── A24-A27 routing chain (all rounds, panel routing) ──
# Kobo skip logic: A24 if fmidA1=1|fmidA2=1 (R1–R3) or fmid_employment=1 (R5)
#                  A27 if fmidA2=2 (R1–R2) / complex panel routing (R3+)
#                  A25 if A24=4 (status unchanged — confirmation note)
#                  A26 if A1=1|A1=2|A24=2|A27=1|A27=2
# fmid* vars are panel pre-fills not in pooled data — can't gate A24/A27 precisely.
# But we can check: A24=4 → A25 must be filled (mandatory), A24≠4 → A25 should be empty (skip).

# A25 is type=note in Kobo (display-only, no data entry) — no mandatory/skip checks needed.
# Relevant condition ${A24}=4 controls when the note is SHOWN, but notes don't store values.

# A26: relevant if A1=1|A1=2|A24=2|A27=1|A27=2
# Complex multi-gate: check that A26 is empty when none of the routing conditions are met.
# Approximate: if A1 is not 1 or 2, AND a24 is not 2, AND a27 is not 1 or 2 → A26 should be empty.
# A26: relevant if A1=1|A1=2|A24=2|A27=1|A27=2
# Full check requires a24 and a27 in the data — if missing for a round, skip that round
# (would produce false positives because the A24/A27 gate conditions can't be evaluated).
if 'a26' in m04.columns:
    c26, p26 = {}, {}
    for r in ROUNDS:
        sub = m04[m04['round']==r]
        if not len(sub):
            c26[r]=0; p26[r]=0; continue
        # If a24/a27 not in data for this round, skip check (would be all false positives)
        has_a24 = 'a24' in sub.columns and sub['a24'].notna().any()
        has_a27 = 'a27' in sub.columns and sub['a27'].notna().any()
        if not (has_a24 and has_a27):
            c26[r]=None; p26[r]=None; continue
        # Build mask: none of the routing conditions met
        a1_ok = n(sub['a1']).isin([1,2]) if 'a1' in sub.columns else pd.Series(False, index=sub.index)
        a24_ok = (n(sub['a24'])==2)
        a27_ok = n(sub['a27']).isin([1,2])
        should_skip = ~(a1_ok | a24_ok | a27_ok)
        sub_skip = sub[should_skip]
        if not len(sub_skip):
            c26[r]=0; p26[r]=0; continue
        filled = is_filled(sub_skip['a26']).sum()
        c26[r] = int(filled); p26[r] = round(100*filled/len(sub_skip),1)
    skip_issues.append({
        'module':'M04','rule':'A26 filled but none of A1=1/2, A24=2, A27=1/2 are met',
        'variable':'routing → A26 should be empty','counts_by_round':c26,'pct_by_round':p26,'severity':'medium',
        'note':'Kobo: A26 relevant=${A1}=1 or ${A1}=2 or ${A24}=2 or ${A27}=1 or ${A27}=2. '
              'Rounds without a24/a27 in data are skipped (shown as N/A).'
    })

# A19_oth: relevant if A1=1 AND A19 contains 96
if 'a19_oth' in m04.columns and 'a19' in m04.columns:
    c,p = {}, {}
    for r in ROUNDS:
        sub = m04[(m04['round']==r) & (n(m04['a1'])==1)]
        if not len(sub):
            c[r]=0; p[r]=0; continue
        # a19 is select_multiple — check if 96 is among values
        # In pooled data, a19 might be numeric (first code) or have split dummies a19_5
        has_96 = pd.Series(False, index=sub.index)
        if 'a19_5' in sub.columns:
            has_96 = n(sub['a19_5']) == 1  # a19_5 is the "other" dummy (code 96 → position 5)
        elif 'a19' in sub.columns:
            has_96 = n(sub['a19']) == 96
        sub_96 = sub[has_96]
        if not len(sub_96):
            c[r]=0; p[r]=0; continue
        miss = (~is_filled(sub_96['a19_oth'])).sum()
        c[r] = int(miss); p[r] = round(100*miss/len(sub_96),1)
    mandatory_issues.append({
        'module':'M04','rule':'A19=96 (other benefit) but A19_oth (specify) is missing',
        'variable':'A1=1,A19=96 → A19_oth','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'Kobo: A19_oth relevant=${A1}=1 and selected(${A19},96). Specify text for "other" benefit.'
    })

# A21_oth: relevant if A1=1 AND A21 contains 96
if 'a21_oth' in m04.columns and 'a21' in m04.columns:
    c,p = {}, {}
    for r in ROUNDS:
        sub = m04[(m04['round']==r) & (n(m04['a1'])==1)]
        if not len(sub):
            c[r]=0; p[r]=0; continue
        has_96 = pd.Series(False, index=sub.index)
        if 'a21_3' in sub.columns:
            has_96 = n(sub['a21_3']) == 1  # a21_3 is the "other" dummy (code 96 → position 3)
        elif 'a21' in sub.columns:
            has_96 = n(sub['a21']) == 96
        sub_96 = sub[has_96]
        if not len(sub_96):
            c[r]=0; p[r]=0; continue
        miss = (~is_filled(sub_96['a21_oth'])).sum()
        c[r] = int(miss); p[r] = round(100*miss/len(sub_96),1)
    mandatory_issues.append({
        'module':'M04','rule':'A21=96 (other transport) but A21_oth (specify) is missing',
        'variable':'A1=1,A21=96 → A21_oth','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'Kobo: A21_oth relevant=${A1}=1 and selected(${A21},96). Specify text for "other" transport.'
    })

# ── A18 skip (R2+): pension contributions only for wage/salary workers ──
# Kobo: A18 relevant=${A1}=1 and ${A6}=1|2|3 (R2+ questionnaires add class-of-worker filter).
# Skip violation: A1=1 AND A6∉{1,2,3} but A18 is filled.
if 'a18' in m04.columns and 'a6' in m04.columns:
    c18, p18 = {}, {}
    for r in ROUNDS:
        sub = m04[m04['round']==r]
        if not len(sub):
            c18[r]=0; p18[r]=0; continue
        if r == 1:
            # R1 may not have the A6 restriction — skip check for R1
            c18[r]=None; p18[r]=None; continue
        a1_v = n(sub['a1']); a6_v = n(sub['a6']); a18_v = n(sub['a18'])
        employed = a1_v == 1
        # Firm QC Tracker 20260701: A18 is NOT gated on A6 alone. R2-R3 route through
        # the employment block with NO class-of-worker filter (so any employed reply is
        # valid); R4+ add A16=3|99 and A8=2|99. Our old R4+-only A16 path still
        # false-flagged the R2 cases (all A1=1, A16=3). Widened to the firm's routing.
        if r in (2, 3):
            eligible = employed
        else:
            eligible = a6_v.isin([1,2,3])
            if 'a16' in sub.columns: eligible = eligible | n(sub['a16']).isin([3,99])
            if 'a8'  in sub.columns: eligible = eligible | n(sub['a8']).isin([2,99])
        filled_18 = a18_v.notna()
        violations = employed & ~eligible & filled_18
        total_gate = int((employed & ~eligible).sum())
        viol_n = int(violations.sum())
        c18[r] = viol_n; p18[r] = round(100*viol_n/total_gate,1) if total_gate else 0
    skip_issues.append({
        'module':'M04','rule':'A1=1, not eligible for A18 (A6∉{1,2,3}; R4+ also A16∉{3,99}) but A18 (pension) is filled',
        'variable':'A18 should be empty when not asked','counts_by_round':c18,'pct_by_round':p18,'severity':'medium',
        'note':'Corrected per Firm QC Tracker 20260701: R2-R3 employment-block route (no class gate); R4+ add A16=3|99, A8=2|99. R1 skipped.'
    })

# ── A19 skip (R2+): benefits only for wage/salary workers ──
# Kobo: A19 relevant=${A1}=1 and ${A6}=1|2|3 (same class-of-worker filter as A18).
# Skip violation: A1=1 AND A6∉{1,2,3} but A19 is filled.
if 'a6' in m04.columns:
    c19, p19 = {}, {}
    # A19 may be split into a19_1..a19_5 dummies (select_multiple) — check any filled
    a19_cols = [c for c in m04.columns if c.startswith('a19_') and c != 'a19_oth']
    has_a19_base = 'a19' in m04.columns
    if has_a19_base or a19_cols:
        for r in ROUNDS:
            sub = m04[m04['round']==r]
            if not len(sub):
                c19[r]=0; p19[r]=0; continue
            if r == 1:
                c19[r]=None; p19[r]=None; continue
            a1_v = n(sub['a1']); a6_v = n(sub['a6'])
            employed = a1_v == 1
            # Firm QC Tracker 20260701: same fuller routing as A18 (R2-R3 no class-of-worker
            # gate; R4+ add A16=3|99 and A8=2|99). Widened so legitimate replies aren't flagged.
            if r in (2, 3):
                not_wage = pd.Series(False, index=sub.index)
            else:
                elig19 = a6_v.isin([1,2,3])
                if 'a16' in sub.columns: elig19 = elig19 | n(sub['a16']).isin([3,99])
                if 'a8'  in sub.columns: elig19 = elig19 | n(sub['a8']).isin([2,99])
                not_wage = ~elig19
            # Check if any a19 value is filled
            filled_19 = pd.Series(False, index=sub.index)
            if has_a19_base:
                filled_19 |= n(sub['a19']).notna()
            for ac in a19_cols:
                if ac in sub.columns:
                    filled_19 |= n(sub[ac]).notna()
            violations = employed & not_wage & filled_19
            total_gate = (employed & not_wage).sum()
            viol_n = int(violations.sum())
            c19[r] = viol_n; p19[r] = round(100*viol_n/total_gate,1) if total_gate else 0
        skip_issues.append({
            'module':'M04','rule':'A1=1, A6≠1|2|3 (not wage worker) but A19 (benefits) is filled',
            'variable':'A6∉{1,2,3} → A19 should be empty','counts_by_round':c19,'pct_by_round':p19,'severity':'medium',
            'note':'Corrected per Firm QC Tracker 20260701: R2-R3 employment-block route (no class gate); R4+ add A16=3|99, A8=2|99. R1 skipped.'
        })

# ── A10 OOR (days worked per week) ──
oor_issues.append({
    'module':'M04','variable':'a10','label':'Days worked per week',
    'rule':'< 0 or > 7',
    'counts': oor(m04, 'a10', 0, 7),
    'severity':'high',
    'note':'Valid range: 0-7 days per week.'
})

# ── A11 OOR (hours worked per week) ──
oor_issues.append({
    'module':'M04','variable':'a11','label':'Hours worked per week',
    'rule':'< 0 or > 168',
    'counts': oor(m04, 'a11', 0, 168),
    'severity':'high',
    'note':'Valid range: 0-168 hours per week (24 hours × 7 days).'
})

# ── A22 OOR (travel time to work) ──
oor_issues.append({
    'module':'M04','variable':'a22','label':'Travel time to work (minutes)',
    'rule':'< 0 or > 300',
    'counts': oor(m04, 'a22', 0, 300),
    'severity':'medium',
    'note':'Reasonable range: 0-300 minutes (5 hours one way).'
})

# ─────────────────────────────────────────────────────────────────────────────
# MODULE 05: INCOME
# ─────────────────────────────────────────────────────────────────────────────
print('M05 Income...')

# ── M05 Kobo evolution (7 differences across R1–R5) ──────────────────────────
#
# DIFF 1 — Recall period wording:
#   R1: "During the period September-October 2025" (2-month fixed window)
#   R2: "During the period November-December 2025" (2-month fixed window)
#   R3–R5: "In the past month" (1-month rolling window)
#   → Substantive: R1–R2 cover 2-month window, R3–R5 cover 1-month window.
#
# DIFF 2 — IA2 pre-fill routing (who gets ASKED IA2):
#   R1–R2: income_fmidA1=2 only (prior-round A1 = not working)
#   R3–R4: income_fmidA1=2 OR income_fmidA24=2 OR income_fmidA27=2
#   R5:    income_fmid_employment=2 (consolidated variable)
#   → More people bypass IA2 in R3+ (A24/A27 added); R5 consolidates to single var.
#   → income_fmid* vars are Kobo calculates, NOT in pooled .dta.
#   → IA2 missing ≈ pre-fill routed past (employed last round), NOT a data gap.
#
# DIFF 3 — IA3_A–F skip logic (who gets AMOUNTS):
#   R1–R2: IA2=1 only
#   R3–R4: IA2=1 OR income_fmidA1=1 OR income_fmidA24=1 OR income_fmidA24=4
#           OR income_fmidA27=1
#   R5:    IA2=1 OR income_fmid_employment=1
#   → CRITICAL: In R3–R5, IA3 can be filled even when IA2=2 (pre-fill bypass).
#   → The simple "IA2=2 → IA3 empty" skip rule is ONLY valid for R1–R2.
#   → R3–R5 violations are likely legitimate data via pre-fill path.
#
# DIFF 4 — IA5 pre-fill gating:
#   R1–R2: income_fmidA1=2 (same gate as IA2 — only non-employed get asked)
#   R3–R5: NO relevance (asked unconditionally to all repeat members)
#   → Explains IA5 missing ~27–31% in R1–R2 (identical to IA2) vs 0% in R4–R5.
#
# DIFF 5 — Pre-fill variables added over time:
#   R1–R2: income_fmidA1 only
#   R3–R4: + income_fmidage, income_fmidA24, income_fmidA27, income_round_lastint
#   R5:    + income_fmidfieldemploy, income_fmid_employment (consolidated)
#
# DIFF 6 — Hints added R3+:
#   IA3_C: in-kind earnings hint moved from IA3_A (R1–R2) to IA3_C (R3+)
#   IA6_C–F: in-kind earnings hint added from R3 (absent R1–R2)
#
# DIFF 7 — IA7 skip logic CONSISTENT all rounds:
#   indexed-repeat(${A9}, ${employ_}, ${income_old_fmid}) = 1
#   Cross-module reference to M04 A9 (gig work). Not in pooled .dta.
#   ~92–100% missing expected (only gig workers).
#
# No age restriction on the income_ repeat: it loops over ALL roster members
# (fmid_max = hhsize). Children get IA2=2 (no income) via the enumerator.
# The ~27–35% "missing" on IA2 = adults routed past by pre-fill, not children.

ia3_cols_exist = [col for col in m05.columns if col.startswith('ia3') and col != 'ia3']
ia6_cols_exist = [col for col in m05.columns if col.startswith('ia6') and col != 'ia6']

def check_skip_nonzero(df, gate_col, gate_skip_vals, follow_cols, rounds_only=None):
    """Skip check counting non-null AND non-zero values (for numeric earnings cols).
    rounds_only: if set, only check these rounds; others get None."""
    if gate_col not in df.columns:
        return {r: None for r in ROUNDS}, {r: None for r in ROUNDS}
    out_cnt, out_pct = {}, {}
    gate_num = n(df[gate_col])
    gate_mask = gate_num.isin(gate_skip_vals)
    for r in ROUNDS:
        if rounds_only and r not in rounds_only:
            out_cnt[r] = None; out_pct[r] = None; continue
        sub_gate = df[(df['round']==r) & gate_mask]
        if not len(sub_gate):
            out_cnt[r]=0; out_pct[r]=0; continue
        filled = pd.Series(False, index=sub_gate.index)
        for fc in follow_cols:
            if fc in df.columns:
                v = n(sub_gate[fc])
                filled |= (v.notna() & (v != 0))
        c_val = int(filled.sum())
        out_cnt[r] = c_val; out_pct[r] = round(100*c_val/len(sub_gate),1)
    return out_cnt, out_pct

# ── IA2=2 → IA3 should be empty (R1–R2 ONLY) ──
# In R1–R2, IA3 relevance is strictly IA2=1. Pre-fill bypass does NOT exist.
# In R3–R5, IA3 can be filled via pre-fill path even when IA2=2 — NOT a violation.
if ia3_cols_exist:
    c,p = check_skip_nonzero(m05, 'ia2', [2], ia3_cols_exist, rounds_only=[1,2])
    skip_issues.append({
        'module':'M05','rule':'IA2=2 (no regular income) but IA3 earnings (>0) are filled [R1–R2 only]',
        'variable':'IA2=2 → IA3 should be empty','counts_by_round':c,'pct_by_round':p,'severity':'high',
        'note':'R1–R2 Kobo: IA3 relevant=${IA2}=1 only. Simple skip rule applies. '
              'R3–R5: IA3 also relevant if income_fmidA1=1 / income_fmid_employment=1 '
              '(pre-fill bypass, not in .dta) — IA2=2 with IA3 filled is EXPECTED, not checked.'
    })

    # Also flag R3–R5 as informational (not severity=high) so the dashboard explains it
    c2,p2 = check_skip_nonzero(m05, 'ia2', [2], ia3_cols_exist, rounds_only=[3,4,5])
    skip_issues.append({
        'module':'M05','rule':'IA2=2 but IA3 filled [R3–R5, expected via pre-fill bypass]',
        'variable':'IA2=2 → IA3 pre-fill bypass (R3–R5)','counts_by_round':c2,'pct_by_round':p2,'severity':'info',
        'note':'R3–R5 Kobo: IA3 relevant=${IA2}=1 OR ${income_fmidA1}=1 OR ... (pre-fill). '
              'Members with prior-round employment skip IA2 but still get IA3 via pre-fill path. '
              'These are NOT skip violations — income_fmid* not in .dta so we cannot verify gate.'
    })

    c,p = check_mandatory(m05, 'ia2', [1], ia3_cols_exist)
    mandatory_issues.append({
        'module':'M05','rule':'IA2=1 (has regular income) but IA3 (income amounts) are missing',
        'variable':'IA2=1 → IA3','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'Kobo: IA3 relevant=${IA2}=1 (all rounds). When regular employment income '
              'confirmed via IA2, amounts must be recorded.'
    })

# ── IA5=2 → IA6 should be empty (all rounds — IA6 gating is consistent) ──
# IA6 relevance is IA5=1 across all 5 rounds (no pre-fill bypass for seasonal).
if ia6_cols_exist:
    c,p = check_skip_nonzero(m05, 'ia5', [2], ia6_cols_exist)
    skip_issues.append({
        'module':'M05','rule':'IA5=2 (no seasonal income) but IA6 earnings (>0) are filled',
        'variable':'IA5=2 → IA6 should be empty','counts_by_round':c,'pct_by_round':p,'severity':'high',
        'note':'Kobo: IA6 relevant=${IA5}=1 (all rounds, no pre-fill bypass for seasonal block). '
              'Non-zero earnings when IA5=2 is a true skip violation.'
    })

    c,p = check_mandatory(m05, 'ia5', [1], ia6_cols_exist)
    mandatory_issues.append({
        'module':'M05','rule':'IA5=1 (has seasonal income) but IA6 (income amounts) are missing',
        'variable':'IA5=1 → IA6','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'Kobo: IA6 relevant=${IA5}=1 (all rounds). Seasonal income amounts must be recorded.'
    })

# ─────────────────────────────────────────────────────────────────────────────
# MODULE 06: FINANCE
# ─────────────────────────────────────────────────────────────────────────────
print('M06 Finance...')

# Kobo:
# F7 = applied for loan (1=yes, 2=no/98/99)
# F8 = loan purpose (if F7=1)
# F9 = loan institution (if F7=1)
# F10 = approval status (if F7=1)
# F9_oth, F8_oth = other specify fields
# R5 NEW: F17 = has formal bank account, F18 = has mobile money (gates F1, F2)

# ── F7 (loan application) → F8, F9, F10 ──
# Kobo: F8_ relevant=${F7}=1, F9 relevant=${F7}=1, F10 relevant=${F7}=1
f7_follow = [c for c in ['f8','f9','f10'] if c in m06.columns]
if f7_follow:
    c,p = check_mandatory(m06, 'f7', [1], f7_follow)
    mandatory_issues.append({
        'module':'M06','rule':'F7=1 (applied for loan) but F8/F9/F10 (purpose/institution/approval) is missing',
        'variable':'F7=1 → F8,F9,F10','counts_by_round':c,'pct_by_round':p,'severity':'high',
        'note':'Kobo: F8_, F9, F10 all relevant=${F7}=1. All details mandatory when loan applied for.'
    })

    c,p = check_skip(m06, 'f7', [2,98,99], f7_follow)
    skip_issues.append({
        'module':'M06','rule':'F7=2/98/99 (no loan) but F8/F9/F10 (purpose/institution/approval) are filled',
        'variable':'F7≠1 → F8,F9,F10 should be empty','counts_by_round':c,'pct_by_round':p,'severity':'high',
        'note':'Kobo: F8_, F9, F10 all relevant=${F7}=1. Should be blank when no loan applied for.'
    })

# ── F9=96 → F9_oth (other institution specify) ──
if 'f9_oth' in m06.columns:
    c,p = {}, {}
    for r in ROUNDS:
        sub = m06[(m06['round']==r) & (n(m06['f9'])==96)]
        if not len(sub):
            c[r]=0; p[r]=0; continue  # No eligible cases → 0 violations
        miss = (~is_filled(sub['f9_oth'])).sum()
        c[r] = int(miss); p[r] = round(100*miss/len(sub),1)
    mandatory_issues.append({
        'module':'M06','rule':'F9=96 (other institution) but F9_other (specify) is missing',
        'variable':'F9=96 → F9_oth','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'When F9=96 (other loan institution), specification must be recorded.'
    })

# ── F8=96 → F8_oth (other purpose specify) ──
if 'f8_oth' in m06.columns:
    c,p = {}, {}
    for r in ROUNDS:
        sub = m06[(m06['round']==r) & (n(m06['f8'])==96)]
        if not len(sub):
            c[r]=0; p[r]=0; continue  # No eligible cases → 0 violations
        miss = (~is_filled(sub['f8_oth'])).sum()
        c[r] = int(miss); p[r] = round(100*miss/len(sub),1)
    mandatory_issues.append({
        'module':'M06','rule':'F8=96 (other purpose) but F8_other (specify) is missing',
        'variable':'F8=96 → F8_oth','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'When F8=96 (other loan purpose), specification must be recorded.'
    })

# ── R5 ONLY: F17=2 (no bank account) → F1 should be empty ──
# Kobo R5: F1 relevant=${F17}=1 (NEW in R5, not in R1-R4)
if 'f17' in m06.columns:
    c,p = check_skip(m06[m06['round']==5], 'f17', [2], ['f1'])
    skip_issues.append({
        'module':'M06','rule':'[R5 only] F17=2 (no bank account) but F1 (deposits) is filled',
        'variable':'F17=2 → F1 should be empty (R5 only)','counts_by_round':{**{r:None for r in ROUNDS},5:c.get(5)},
        'pct_by_round':{**{r:None for r in ROUNDS},5:p.get(5)},'severity':'high',
        'note':'Kobo R5: F1 relevant=${F17}=1. This routing NEW in R5 (not in R1-R4).'
    })

    c,p = check_mandatory(m06[m06['round']==5], 'f17', [1], ['f1'])
    mandatory_issues.append({
        'module':'M06','rule':'[R5 only] F17=1 (has bank account) but F1 (deposits) is missing',
        'variable':'F17=1 → F1 (R5 only)','counts_by_round':{**{r:None for r in ROUNDS},5:c.get(5)},
        'pct_by_round':{**{r:None for r in ROUNDS},5:p.get(5)},'severity':'medium',
        'note':'Kobo R5: F1 relevant=${F17}=1. Should be asked if has formal bank account.'
    })

# ── R5 ONLY: F18=2 (no mobile money) → F2 should be empty ──
# Kobo R5: F2 relevant=${F18}=1 (NEW in R5)
if 'f18' in m06.columns:
    c,p = check_skip(m06[m06['round']==5], 'f18', [2], ['f2'])
    skip_issues.append({
        'module':'M06','rule':'[R5 only] F18=2 (no mobile money) but F2 (mobile deposits) is filled',
        'variable':'F18=2 → F2 should be empty (R5 only)','counts_by_round':{**{r:None for r in ROUNDS},5:c.get(5)},
        'pct_by_round':{**{r:None for r in ROUNDS},5:p.get(5)},'severity':'high',
        'note':'Kobo R5: F2 relevant=${F18}=1. This routing NEW in R5 (not in R1-R4).'
    })

    c,p = check_mandatory(m06[m06['round']==5], 'f18', [1], ['f2'])
    mandatory_issues.append({
        'module':'M06','rule':'[R5 only] F18=1 (has mobile money) but F2 (mobile deposits) is missing',
        'variable':'F18=1 → F2 (R5 only)','counts_by_round':{**{r:None for r in ROUNDS},5:c.get(5)},
        'pct_by_round':{**{r:None for r in ROUNDS},5:p.get(5)},'severity':'medium',
        'note':'Kobo R5: F2 relevant=${F18}=1. Should be asked if has mobile money account.'
    })

# ─────────────────────────────────────────────────────────────────────────────
# MODULE 07: HEALTH
# ─────────────────────────────────────────────────────────────────────────────
print('M07 Health...')

# NOTE: M07 only collected in R5 (health module expansion). All H* checks are R5-only.
# Kobo R5 routing is complex; simplified where SH1b cross-references not checkable in pooled data.

# ── H2 (health care needed) → H2A (able to get care) ──
# Kobo R5: H2A relevant=${H2}<4 OR (${H2}=4 AND (health shock))
# Simplified: H2 in (1,2,3) → H2A must be filled
c,p = check_mandatory(m07, 'h2', [1,2,3], ['h2a'] if 'h2a' in m07.columns else [])
mandatory_issues.append({
    'module':'M07','rule':'H2=1/2/3 (health care sought) but H2A (able to get care) is missing',
    'variable':'H2=1/2/3 → H2A','counts_by_round':c,'pct_by_round':p,'severity':'high',
    'note':'Kobo R5: H2A relevant=${H2}<4 (also if H2=4 + health shock). Whether able to get needed care.'
})

# ── H2A≠2 → H3 should be empty (skip check) ──
# Kobo R5: H3 relevant=${H2A}=2 (only asked if could NOT get care)
if 'h2a' in m07.columns and 'h3' in m07.columns:
    h3_cols = [c for c in m07.columns if c.startswith('h3')]
    c3,p3 = {}, {}
    for r in ROUNDS:
        sub = m07[(m07['round']==r) & (n(m07['h2a'])!=2) & m07['h2a'].notna()]
        if not len(sub):
            c3[r]=0; p3[r]=0; continue
        filled = pd.Series(False, index=sub.index)
        for hc in h3_cols:
            filled |= is_filled(sub[hc])
        c3[r]=int(filled.sum()); p3[r]=round(100*filled.mean(),1)
    skip_issues.append({
        'module':'M07','rule':'H2A≠2 (could get care) but H3 (reason unable) is filled',
        'variable':'H2A≠2 → H3 should be empty','counts_by_round':c3,'pct_by_round':p3,'severity':'high',
        'note':'Kobo R5: H3 relevant=${H2A}=2. Should be blank if respondent could get care.'
    })

    # H2A=2 → H3 must be filled
    c,p = check_mandatory(m07, 'h2a', [2], h3_cols)
    mandatory_issues.append({
        'module':'M07','rule':'H2A=2 (could NOT get care) but H3 (reason unable) is missing',
        'variable':'H2A=2 → H3','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'Kobo R5: H3 relevant=${H2A}=2. Reason unable to get care must be recorded.'
    })

    # H3=96 → H3_oth (other reason specify)
    if 'h3_oth' in m07.columns:
        c,p = {}, {}
        for r in ROUNDS:
            sub = m07[(m07['round']==r) & (n(m07['h3'])==96)]
            if not len(sub):
                c[r]=0; p[r]=0; continue  # No eligible cases → 0 violations
            miss = (~is_filled(sub['h3_oth'])).sum()
            c[r] = int(miss); p[r] = round(100*miss/len(sub),1)
        mandatory_issues.append({
            'module':'M07','rule':'H3=96 (other reason) but H3_other (specify) is missing',
            'variable':'H3=96 → H3_oth','counts_by_round':c,'pct_by_round':p,'severity':'medium',
            'note':'When H3=96 (other reason for not getting care), specification must be recorded.'
        })

# ── H2=2/3 (outpatient) → H4, H7, H8 ──
# Kobo R5: H4, H7, H8 all relevant=${H2}=2 or ${H2}=3
outpat_cols = [c for c in ['h4','h7','h8'] if c in m07.columns]
if outpat_cols:
    c,p = check_mandatory(m07, 'h2', [2,3], outpat_cols)
    mandatory_issues.append({
        'module':'M07','rule':'H2=2/3 (outpatient) but H4/H7/H8 (facility/PhilHealth/OOP) are missing',
        'variable':'H2=2/3 → H4,H7,H8','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'Kobo R5: H4, H7, H8 all relevant=${H2}=2 or ${H2}=3. Outpatient details required.'
    })

    c,p = check_skip(m07, 'h2', [1,4], outpat_cols)
    skip_issues.append({
        'module':'M07','rule':'H2=1/4 (not outpatient) but H4/H7/H8 are filled',
        'variable':'H2≠2,3 → H4,H7,H8 should be empty','counts_by_round':c,'pct_by_round':p,'severity':'high',
        'note':'Kobo R5: H4/H7/H8 relevant=${H2}=2 or ${H2}=3. Should be blank for H2=1 or H2=4.'
    })

# ── H4=96 → H4_oth (other healthcare facility specify) ──
if 'h4_oth' in m07.columns and 'h4' in m07.columns:
    c,p = {}, {}
    for r in ROUNDS:
        sub = m07[(m07['round']==r) & (n(m07['h4'])==96)]
        if not len(sub):
            c[r]=0; p[r]=0; continue  # No eligible cases → 0 violations
        miss = (~is_filled(sub['h4_oth'])).sum()
        c[r] = int(miss); p[r] = round(100*miss/len(sub),1)
    mandatory_issues.append({
        'module':'M07','rule':'H4=96 (other facility) but H4_other (specify) is missing',
        'variable':'H4=96 → H4_oth','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'When H4=96 (other healthcare facility), specification must be recorded.'
    })

# ── H8 (out-of-pocket payment) → H8_amt (OOP amount) ──
# Kobo R5: H8_amt relevant=${H8}=1 or ${H8}=2 (paid OOP)
if 'h8_amt' in m07.columns and 'h8' in m07.columns:
    c,p = check_mandatory(m07, 'h8', [1,2], ['h8_amt'])
    mandatory_issues.append({
        'module':'M07','rule':'H8=1/2 (paid OOP) but H8_amt (amount) is missing',
        'variable':'H8=1/2 → H8_amt','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'Kobo R5: H8_amt relevant=${H8}=1 or ${H8}=2. OOP amount required when payment made.'
    })

    c,p = check_skip(m07, 'h8', [3], ['h8_amt'])
    skip_issues.append({
        'module':'M07','rule':'H8=3 (no OOP) but H8_amt (amount) is filled',
        'variable':'H8=3 → H8_amt should be empty','counts_by_round':c,'pct_by_round':p,'severity':'medium',
        'note':'Kobo R5: H8_amt relevant=${H8}=1 or ${H8}=2. Should be blank when H8=3 (no payment).'
    })

# ── H10_1 (PhilHealth coverage) → H11a, H11b (PhilHealth type) ──
# Kobo R5: H11a relevant=${H10}=1, H11b_ relevant=${H10}=1
# Note: H10 is h10_1/h10_2/h10_3 in .dta (per-member). Check h10_1.
h10_cols = [c for c in m07.columns if c.startswith('h10')]
if h10_cols:
    h10_col = h10_cols[0]  # Use first H10 variable (usually h10_1)
    h11a_cols = [c for c in m07.columns if c.startswith('h11a')]
    if h11a_cols:
        c,p = check_mandatory(m07, h10_col, [1], h11a_cols[:1])
        mandatory_issues.append({
            'module':'M07','rule':f'H10=1 (has PhilHealth) but H11a (type) is missing',
            'variable':f'{h10_col}=1 → H11a','counts_by_round':c,'pct_by_round':p,'severity':'medium',
            'note':'Kobo R5: H11a relevant=${H10}=1. PhilHealth type must be recorded.'
        })

# ── H12 (hospitalization) → H13, H14 (facility, total bill) ──
# Kobo R5: H13, H14 both relevant=${H12}=1
if 'h12' in m07.columns:
    h12_follow = [c for c in ['h13','h14'] if c in m07.columns]
    if h12_follow:
        c,p = check_mandatory(m07, 'h12', [1], h12_follow)
        mandatory_issues.append({
            'module':'M07','rule':'H12=1 (hospitalized) but H13/H14 (facility/bill) is missing',
            'variable':'H12=1 → H13,H14','counts_by_round':c,'pct_by_round':p,'severity':'high',
            'note':'Kobo R5: H13, H14 both relevant=${H12}=1. Hospital details mandatory if hospitalized.'
        })

    h12_skip = [c for c in ['h13','h14','h15','h16'] if c in m07.columns]
    if h12_skip:
        c,p = check_skip(m07, 'h12', [2], h12_skip)
        skip_issues.append({
            'module':'M07','rule':'H12=2 (not hospitalized) but H13-H16 (hosp details) are filled',
            'variable':'H12=2 → H13-H16 should be empty','counts_by_round':c,'pct_by_round':p,'severity':'high',
            'note':'Kobo R5: H13-H16 all gated on H12=1. Should be blank when not hospitalized.'
        })

    # H13=96 → H13_oth (other facility specify)
    if 'h13_oth' in m07.columns and 'h13' in m07.columns:
        c,p = {}, {}
        for r in ROUNDS:
            sub = m07[(m07['round']==r) & (n(m07['h13'])==96)]
            if not len(sub):
                c[r]=0; p[r]=0; continue  # No eligible cases → 0 violations
            miss = (~is_filled(sub['h13_oth'])).sum()
            c[r] = int(miss); p[r] = round(100*miss/len(sub),1)
        mandatory_issues.append({
            'module':'M07','rule':'H13=96 (other hospital facility) but H13_other (specify) is missing',
            'variable':'H13=96 → H13_oth','counts_by_round':c,'pct_by_round':p,'severity':'medium',
            'note':'When H13=96 (other hospital type), specification must be recorded.'
        })

# ── H14 (total hospital bill) → H15 (out-of-pocket amount) ──
# Kobo R5: H15 relevant=${H14}>0 or ${H14}=-99
if 'h14' in m07.columns and 'h15' in m07.columns:
    # H14>0 → H15 must be filled
    c,p = check_mandatory(m07, 'h14', list(range(1,100000)), ['h15'])  # Any positive value
    # But we need custom logic for this — count where H14>0 but H15 missing
    c_h15, p_h15 = {}, {}
    for r in ROUNDS:
        sub = m07[(m07['round']==r) & (n(m07['h14'])>0)]
        if not len(sub):
            c_h15[r]=0; p_h15[r]=0; continue
        miss = sub['h15'].isna().sum()
        c_h15[r] = int(miss); p_h15[r] = round(100*miss/len(sub),1)
    if any(c_h15.values()):
        mandatory_issues.append({
            'module':'M07','rule':'H14>0 (has bill) but H15 (OOP amount) is missing',
            'variable':'H14>0 → H15','counts_by_round':c_h15,'pct_by_round':p_h15,'severity':'medium',
            'note':'Kobo R5: H15 relevant=${H14}>0 or ${H14}=-99. OOP amount must be recorded when bill exists.'
        })

    # H14=0 → H15 should be empty (no bill, no OOP payment)
    c_s, p_s = {}, {}
    for r in ROUNDS:
        sub = m07[(m07['round']==r) & (n(m07['h14'])==0)]
        if not len(sub):
            c_s[r]=0; p_s[r]=0; continue
        filled = is_filled(sub['h15']).sum()
        c_s[r]=int(filled); p_s[r]=round(100*filled/len(sub),1)
    if any(c_s.values()):
        skip_issues.append({
            'module':'M07','rule':'H14=0 (no bill) but H15 (OOP amount) is filled',
            'variable':'H14=0 → H15 should be empty','counts_by_round':c_s,'pct_by_round':p_s,'severity':'medium',
            'note':'Kobo R5: H15 relevant=${H14}>0 or ${H14}=-99. Should be blank when total bill is zero.'
        })

    # Cross-check: H15 ≤ H14 (OOP cannot exceed total bill)
    viol_cross = {r: None for r in ROUNDS}
    for r in ROUNDS:
        sub = m07[(m07['round']==r) & (n(m07['h12'])==1)]
        if not len(sub): continue
        v14 = n(sub['h14']); v15 = n(sub['h15'])
        valid = v14.notna() & v15.notna() & (v14>=0) & (v15>=0)
        if not valid.sum(): continue
        viol_cross[r] = int((v15[valid] > v14[valid]).sum())
    oor_issues.append({
        'module':'M07','variable':'h15_vs_h14','label':'H15 out-of-pocket > H14 total bill',
        'rule':'H15 (OOP) > H14 (total bill) — logically impossible',
        'counts': viol_cross,
        'severity':'high',
        'note':'Kobo R5 note: "Answer should be less than or equal to total hospital bill (H14)".'
    })

# ── H16 (payment source for gap) ──
# Kobo R5: H16_ relevant=${H14}>0 and ${H14}!=${H15}
# (gap exists: difference between bill and OOP must come from somewhere)
if 'h16' in m07.columns and 'h14' in m07.columns and 'h15' in m07.columns:
    h16_cols = [c for c in m07.columns if c.startswith('h16') and c != 'h16_oth']
    c16, p16 = {}, {}
    for r in ROUNDS:
        v14 = n(m07[m07['round']==r]['h14']); v15 = n(m07[m07['round']==r]['h15'])
        mask = (v14>0) & (v14!=v15)
        sub = m07[(m07['round']==r)][mask.fillna(False)]
        if not len(sub):
            c16[r]=0; p16[r]=0; continue
        all_miss = pd.Series(True, index=sub.index)
        for hc in h16_cols:
            if hc in sub.columns: all_miss &= sub[hc].isna()
        c16[r]=int(all_miss.sum()); p16[r]=round(100*all_miss.mean(),1)
    if any(c16.values()):
        mandatory_issues.append({
            'module':'M07','rule':'H14>0 AND H14≠H15 (gap exists) but H16 (payment source) is missing',
            'variable':'H14>0,H14≠H15 → H16','counts_by_round':c16,'pct_by_round':p16,'severity':'medium',
            'note':'Kobo R5: H16_ relevant=${H14}>0 and ${H14}!=${H15}. Payment source required when gap between bill and OOP.'
        })

    # H16=96 → H16_oth (other payment source specify)
    if 'h16_oth' in m07.columns:
        c,p = {}, {}
        for r in ROUNDS:
            sub = m07[(m07['round']==r) & (n(m07['h16'])==96)]
            if not len(sub):
                c[r]=0; p[r]=0; continue  # No eligible cases → 0 violations
            miss = (~is_filled(sub['h16_oth'])).sum()
            c[r] = int(miss); p[r] = round(100*miss/len(sub),1)
        mandatory_issues.append({
            'module':'M07','rule':'H16=96 (other payment source) but H16_other (specify) is missing',
            'variable':'H16=96 → H16_oth','counts_by_round':c,'pct_by_round':p,'severity':'medium',
            'note':'When H16=96 (other payment source), specification must be recorded.'
        })

# ─────────────────────────────────────────────────────────────────────────────
# MODULE 08: FOOD & NON-FOOD (FIES)
# ─────────────────────────────────────────────────────────────────────────────
print('M08 Food & Non-Food...')

# Core FIES1–FIES5 = f08_a..f08_e (unconditional, asked of all HHs every round).
# f08_f/g/h are EXTENDED food items added R6+ — excluded from this FIES1–5 check
# so R1–R5 aren't falsely flagged for items that did not exist yet (this was
# inflating M08 to ~6,033 false "missing"). f/g/h missingness still shows in the heatmap.
_FIES_CORE = ['f08_a', 'f08_b', 'f08_c', 'f08_d', 'f08_e']
fies_cols = [c for c in _FIES_CORE if c in m08.columns]
if not fies_cols:  # fallback for 'fies'-named schemas
    fies_cols = [c for c in m08.columns if 'fies' in c.lower()]
actual_fies = fies_cols

if actual_fies:
    # ── Any FIES item missing ──
    c,p = {}, {}
    for r in ROUNDS:
        sub = m08[m08['round']==r]
        if not len(sub): c[r]=0; p[r]=0; continue  # No eligible cases → 0 violations
        any_missing = sub[actual_fies].isna().any(axis=1)
        c[r] = int(any_missing.sum())
        p[r] = round(100*any_missing.mean(), 1)
    mandatory_issues.append({
        'module':'M08','rule':'Any FIES item (FIES1–FIES5) is blank — asked of all HHs',
        'variable':'FIES items','counts_by_round':c,'pct_by_round':p,'severity':'high',
        'note':'Questionnaire: unconditional. All FIES items must be answered for every household.'
    })

    # ── FIES OOR: valid codes are 1 (Yes) or 2 (No) only ──
    for fv in actual_fies[:5]:
        oor_issues.append({
            'module':'M08','variable':fv,'label':f'FIES item {fv}',
            'rule':'Not 1 (Yes) or 2 (No)',
            'counts': oor(m08, fv, 1, 2, exclude_special=(98,99)),
            'severity':'medium',
            'note':'Valid codes for FIES items: 1=Yes, 2=No only.'
        })

# ─────────────────────────────────────────────────────────────────────────────
# MODULE 09: OPINIONS & VIEWS
# ─────────────────────────────────────────────────────────────────────────────
print('M09 Opinions & Views...')

# M09 contains unconditional questions (V1, V5 asked of all) and randomized (V9).
# Kobo: V1, V5 = mandatory for all; V9 = randomized (not all respondents)

# ── V1 (life satisfaction) and V5 (economic change) — mandatory for all ──
for var, label in [('v1','V1 life satisfaction'), ('v5','V5 economic change')]:
    if var in m09.columns:
        # Mandatory check
        c,p = {}, {}
        for r in ROUNDS:
            sub = m09[m09['round']==r]
            if not len(sub):
                c[r]=0; p[r]=0; continue  # No eligible cases → 0 violations
            miss = sub[var].isna().sum()
            c[r]=int(miss); p[r]=round(100*miss/len(sub),1)
        if any(v for v in c.values() if v):
            mandatory_issues.append({
                'module':'M09','rule':f'{label} is blank — asked of all respondents',
                'variable':var,'counts_by_round':c,'pct_by_round':p,'severity':'high',
                'note':f'Questionnaire: unconditional. {var} must be answered by every respondent.'
            })

# ── V1, V5 OOR: valid range 1-5 (Likert scale) ──
for var, label in [('v1','Life satisfaction'), ('v5','Economic change')]:
    if var in m09.columns:
        oor_issues.append({
            'module':'M09','variable':var,'label':label,
            'rule':'Not 1-5 (invalid Likert code)',
            'counts': oor(m09, var, 1, 5, exclude_special=(98,99)),
            'severity':'high',
            'note':'Valid codes: 1-5 point Likert scale.'
        })

# ── V9 items (agreement statements) — randomized, 1-5 scale (V9f may have 6=No child) ──
v9_cols = [c for c in m09.columns if c.startswith('v9')]
for vc in v9_cols[:8]:
    # V9f (child enrollment statement) may have code 6 = "No child" (not applicable)
    hi_val = 6 if vc.endswith('f') or vc.endswith('_f') else 5
    oor_issues.append({
        'module':'M09','variable':vc,'label':f'Agreement statement {vc}',
        'rule':f'Not 1-5 (or 6 for V9f)',
        'counts': oor(m09, vc, 1, hi_val, exclude_special=(98,99)),
        'severity':'medium',
        'note':f'V9 items: 1-5 Likert scale. V9f may also have 6=No child.'
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

# Admin / merge / derived columns to exclude from heatmaps.
# These are not substantive survey questions — they are merge keys, weights,
# demographics carried from other modules, or processing artifacts.
EXCL = {
    # Identifiers & merge keys
    'hhid','pid','round','wave','strata','psu','weight','fweight',
    'stratum','popw','hhw','indw','region','province','city','barangay',
    'locale','survey_lang','int_id','fmid','survey_round','macro_region',
    # Date/time processing vars
    'start_date','end_date','subm_date','date_str',
    'start_time','end_time','subm_time','time_str',
    'date_of_interview','time_of_interview',
    # Demographics carried into non-roster modules (merge artifacts)
    'urban','age','age_grp','gender','isfmid','hhsize','relationship',
    # Other processing artifacts
    'trailer_tag','sample','excess_int','round_lastint',
    # Duration and derived non-question vars (not survey questions — exclude from all modules)
    'dur_f_nf',             # interview duration for Food/NonFood block
    'pcinc_imp_mean',       # imputed per-capita income (derived/merged, not a Kobo question)
    # M00 derived/PII vars
    'call_result',          # Always 1 in clean data (only completed interviews)
    'new_address_str',      # PII — contains actual respondent addresses
    # Trailer intermediate vars (R1 only, not real questions)
    'age_old','hhsize_update','name_old','gender_old','permanent',
}

# Demographics that ARE main questions in M01 Roster but are merge artifacts elsewhere
ROSTER_QUESTIONS = {'age','age_grp','gender','isfmid','hhsize','relationship','isfmid'}

# Education variables carried in M01 roster dataset — belong in M02, exclude from M01 heatmap
M01_EDUCATION_VARS = {'ed15','ed16'}

# Duplicate variable from naming inconsistency (now harmonized to _oth) — exclude residual
M01_DUPLICATE_VARS = {'member_leftreason_other'}

# M00 Passport variables that ARE primary survey questions in M00 but appear in EXCL
# because they are metadata/merge keys in other modules.
M00_PASSPORT_VARS = {
    'hhid', 'int_id',
    'survey_lang',                              # D3: survey language
    'date_of_interview', 'time_of_interview',   # Z6, Z7
    'region', 'province', 'city', 'barangay', 'locale',  # Z1–Z5: address (current/updated)
    # new_address_str excluded (PII) · call_result excluded (constant=1 in clean data)
    # fmid excluded — not in authoritative M00 variable list
}
# Duration and admin vars to exclude from M00 heatmap (not in authoritative variable list)
M00_HEATMAP_EXCL = {
    'fmid',
    'dur_pp', 'dur_rr', 'dur_educ', 'dur_sh', 'dur_emp', 'dur_inc',
    'dur_fin', 'dur_hlt', 'dur_f_nf', 'dur_vw', 'dur_tot',
    # X22 "irritating modules" — interviewer feedback, not a survey question.
    # ~99.7% blank = "no module flagged", a valid none-selected, not missing data.
    'x22', 'x22_1', 'x22_2', 'x22_3', 'x22_4', 'x22_5', 'x22_6', 'x22_7',
}

# M02 Education: authoritative vars that are in EXCL/ROSTER_QUESTIONS but ARE primary M02 questions
# R8-only ed17/ed2/ed19_* added 2026-06-28 after firm delivered real R08 Kobo form.
M02_EDUCATION_KEEP = {
    'hhid', 'fmid', 'age', 'gender',
    'ed15', 'ed16',   # ed16_oth dropped: sparse other-specify (gate selected(ed16,'96')), not completeness-monitorable at R4+
    # R8-only education-expenditure block (firm's R08 Kobo form delivered 2026-06-27)
    'ed17', 'ed2',
    'ed19_a', 'ed19_b', 'ed19_c', 'ed19_d', 'ed19_e',
    'ed19_f', 'ed19_g', 'ed19_h', 'ed19_i',
}

# M05 Income: derived/calculated totals (not Kobo questions). Their "missing" means
# "no income of that type" (e.g. 98% of HHs have no seasonal income), not a
# collection failure — so they are excluded from the heatmap.
M05_DERIVED = {
    'regular_cash_income', 'regular_inkind_income', 'total_regular_income',
    'season_cash_income', 'season_inkind_income', 'total_season_income',
    'total_income', 'regular_cash_earnings',
}

# Preload-gated variables: their Kobo skip-gate references prior-round preload vars
# (fmidA1, fmidA24, fmidA27, round_lastint, fmid_employment) or a cross-module var
# (A9) that are NOT in the pooled .dta. The heatmap therefore cannot apply the gate,
# so their high "missing" is an artifact of un-applied skip logic, not a collection
# failure. Marked conditional (kept out of module max-missing) + tagged in the heatmap.
PRELOAD_GATED = {
    ('M04', 'a1'), ('M04', 'a24'), ('M04', 'a26'), ('M04', 'a27'),
    ('M04', 'a25_olda10'), ('M04', 'a25_olda11'),
    ('M04', 'a25_olda6'), ('M04', 'a25_olda8a9'),
    ('M05', 'ia2'), ('M05', 'ia5'), ('M05', 'ia7'),
}

# ── Conditional skip logic gates for heatmap ──────────────────────────────────
# Maps (module, variable_prefix) → (gate_col, eligible_values)
# Missing rate is computed ONLY among rows where gate_col is in eligible_values.
# Prefix matching: ('M05','ia3') matches ia3_a, ia3_b, ia3_c, etc.
# Grounded in Kobo XLSForm `relevant` column.
#
# Special gate types:
#   ('col', [vals])         — standard: filter to rows where col in vals
#   ('__age__', [lo, hi])   — age gate: filter to rows where age between lo and hi
#   ('__round__', [r1,..])  — round gate: variable only exists in these rounds (N/A otherwise)
#   ('__a1_roster__', None) — M04 special: age>=15 in R1-R3, a1 notna in R4-R5
#   ('__compound__', [g1, g2]) — apply gates sequentially; if any is N/A, the round is N/A

CONDITIONAL_GATES = {
    # ── M00 Passport ──
    # Pooled HF data contains only completed interviews (call_status1=1, agreement=1).
    # Refusal vars are always N/A in clean data; address cascade gated on Z20=2 (address changed).
    # Values are Stata numeric codes (convert_categoricals=False):
    #   call_status1: 1=Yes · agreement: 1=I agree, 2=Refused
    #   address_unchanged: 1=Yes, 2=No · interview_record: 1=I agree, 2=No
    ('M00','correct_resp'):         ('call_status1', [1]),           # Z16: relevant=${call_status1}=1
    ('M00','agreement'):            ('call_status1', [1]),           # Z9: relevant=${call_status1}=1
    ('M00','refusal_reason'):       ('agreement', [2]),              # Z18: relevant=${Z9}=2 (never in clean data)
    ('M00','refusal_reason_oth'):   ('__compound__', [('agreement', [2]), ('refusal_reason', [96])]),
    ('M00','interview_record'):     ('agreement', [1]),              # Z19: relevant=${Z9}=1
    ('M00','address_unchanged'):    ('agreement', [1]),              # Z20: relevant=${Z9}=1
    ('M00','region'):               ('address_unchanged', [2]),      # Z1: relevant=${Z20}=2
    ('M00','province'):             ('address_unchanged', [2]),      # Z2: relevant=${Z20}=2
    ('M00','city'):                 ('address_unchanged', [2]),      # Z3: relevant=${Z20}=2
    ('M00','barangay'):             ('address_unchanged', [2]),      # Z4: relevant=${Z20}=2
    ('M00','locale'):               ('address_unchanged', [2]),      # Z5: relevant=${Z20}=2

    # ── M01 Roster ──
    # D5a (isfmid) is asked in ALL rounds (R1-R5), confirmed in Kobo XLSForms — no gate needed
    # ed15/ed16 excluded from M01 heatmap — they belong in M02 (see M01_EDUCATION_VARS)
    ('M01','member_leftreason'):       ('isfmid', [2]),         # D25 relevant=${D5a}=2
    ('M01','member_leftreason_oth'):   ('__compound__', [('isfmid', [2]), ('member_leftreason', [96])]),   # D5A=2 & D25=96
    ('M01','moved_in_reason'):         ('isfmid', [6]),         # M13: new member reason (isfmid=6). R1-R2 routing differs
    ('M01','moved_in_reason_oth'):     ('__compound__', [('isfmid', [6]), ('moved_in_reason', [96])]),  # D29=1 & M13=96
    ('M01','country_moved'):           ('__compound__', [('isfmid', [2]), ('member_leftreason', [1,2])]),   # D5A=2 & D25=1|2
    ('M01','prov_moved'):              ('__compound__', [('isfmid', [2]), ('member_leftreason', [1,2])]),   # D5A=2 & D25=1|2
    ('M01','city_moved'):              ('__compound__', [('isfmid', [2]), ('member_leftreason', [1,2])]),   # D5A=2 & D25=1|2
    ('M01','correct_name'):            ('isfmid', [3]),         # D27: correct name when isfmid=3 (name wrong)
    ('M01','correct_age'):             ('isfmid', [4]),         # D28: correct age when isfmid=4 (age wrong)
    ('M01','correct_gender'):          ('__compound__', [('__round__', [2,3,4,5]), ('isfmid', [5])]),  # D33: R2+ only, isfmid=5
    ('M01','relationship'):            ('isfmid', [6]),         # D6: relationship to HH head — new members only
    ('M01','country_migrated_from'):   ('isfmid', [6]),         # M10: origin of new member (isfmid=6)
    ('M01','province_migrated_from'):  ('isfmid', [6]),
    ('M01','city_migrated_from'):      ('isfmid', [6]),

    # ── M02 Education ──
    ('M02','ed15'):   ('__age__', [5, 17]),                            # school-age children
    # ed16 ("what is member doing now") asked of anyone no longer attending (ED15=2),
    # regardless of age. Its data splits by round: aggregate ed16 filled R1–R3, but
    # R4–R8 the answer lives in the dummies ed16_1/ed16_2 (aggregate empty). The
    # heatmap "filled" check for ed16 therefore looks at aggregate OR dummies (see
    # the ED16 derived-indicator path in heatmap()), so missing ≈ 0% among ED15=2.
    ('M02','ed16'):   ('ed15', [2]),                                                 # ED15=2 (no longer attending)
    ('M02','ed16_1'): ('__compound__', [('__age__', [5, 17]), ('ed15', [2])]),       # age 5-17 & ED15=2
    ('M02','ed16_2'): ('__compound__', [('__age__', [5, 17]), ('ed15', [2])]),       # age 5-17 & ED15=2
    # R8-only education-expenditure block (firm's R08 Kobo form delivered 2026-06-27)
    # ed17 = enrollment filter (roster member gate); ed2 = school type; ed19_* = cost items
    ('M02','ed17'):   ('__round__', [8]),                               # ED17 enrollment filter — R8 only
    ('M02','ed2'):    ('__compound__', [('__round__', [8]), ('ed17', [1, 2])]),      # ED2 school type — R8, among enrolled
    ('M02','ed19_'):  ('__compound__', [('__round__', [8]), ('ed17', [1, 2])]),      # ED19a-i — R8, enrolled students only

    # ── M03 Shocks & Natural Hazards ──
    ('M03','sh1b'):  ('sh1', [1]),
    ('M03','sh2'):   ('sh1', [1]),
    ('M03','sh4'):   ('sh3', [1]),                                     # SH4 relevant=${SH3}=1
    ('M03','n5'):    ('__round__', [1, 2, 3, 4, 5]),                    # N5 asked in all rounds (gated on baseline internet)
    ('M03','n1'):    ('__round__', [3]),                               # N1 internet connection type — R3 only
    ('M03','n3'):    ('__round__', [3]),                               # N3 internet subscription — R3 only
    # Natural hazards: nh2 is SATA of hazard types; nh3/nh7/nh10 nested per hazard
    # nh3_X_Y = Yth impact of Xth hazard → gate on nh2_X being notna
    # Use __nh_nested__ special gate type — resolved dynamically based on var name
    ('M03','nh2'):   ('sh1', [1]),                                      # NH section gated on sh1=1 (experienced shocks)
    ('M03','nh3'):   ('__nh_nested__', None),
    ('M03','nh7'):   ('__nh_nested__', None),
    ('M03','nh10'):  ('__nh_nested__', None),

    # ── M04 Employment ──
    # a24-a27: Panel routing vars — exist in Kobo for ALL rounds (R1–R5).
    # Skip logic: a24 if fmidA1=1|fmidA2=1 (R1–R3) or fmid_employment=1 (R5);
    # a27 if fmidA2=2; a25 note if a24=4; a26 if a1=1|a1=2|a24=2|a27=1|a27=2.
    # Role shifts R4–R5 (become primary routing gates replacing a19/a21).
    # a24-a27: Panel routing vars — exist in Kobo for ALL rounds (R1–R5).
    # Skip logic: a24 if fmidA1=1|fmidA2=1 (R1–R3) or fmid_employment=1 (R5);
    # a27 if fmidA2=2; a25 note if a24=4; a26 conditional on employment status.
    # Role shifts R4–R5 (become primary routing gates replacing a19/a21).
    # NOT gated — M04 dataset already contains selected roster members.
    # (Using __roster_filter__ would suppress the row via is_na=True → skipped.)
    # a1: first employment question, asked to all roster members in M04.
    # Also ungated — module dataset is already the right denominator.
    ('M04','a3'):    ('a1', [2]),                                      # A3 (reason not working) relevant=${A1}=2
    ('M04','a3_oth'):('__compound__', [('a1', [2]), ('a3', [96])]),      # A1=2 & A3=96
    ('M04','a4'):    ('a1', [1]),                                      # A4–A21 block: employed
    ('M04','a4_oth'):('__compound__', [('a1', [1]), ('a4', [9996])]),  # A1=1 & A4=9996
    ('M04','a5'):    ('a1', [1]),
    ('M04','a5_oth'):('__compound__', [('a1', [1]), ('a5', [96])]),    # A1=1 & A5=96
    ('M04','a6'):    ('a1', [1]),
    ('M04','a7'):    ('__compound__', [('a1', [1]), ('a5', [1])]),     # A1=1 & A5=1
    ('M04','a8'):    ('a1', [1]),
    ('M04','a9'):    ('__compound__', [('a1', [1]), ('a8', [1])]),     # A1=1 & A8=1
    ('M04','a10'):   ('a1', [1]),
    ('M04','a11'):   ('a1', [1]),
    ('M04','a16'):   ('a1', [1]),
    ('M04','a17'):   ('__compound__', [('a1', [1]), ('a16', [1,2])]),  # A1=1 & A16=1|2
    ('M04','a18'):   ('a1', [1]),
    ('M04','a19'):   ('a1', [1]),
    ('M04','a19_oth'):('__compound__', [('a1', [1]), ('a19', [96])]),  # A1=1 & A19 contains 96
    ('M04','a20'):   ('__compound__', [('a1', [1]), ('a6', [4])]),     # A1=1 & A6=4
    ('M04','a21'):   ('a1', [1]),
    ('M04','a21_oth'):('__compound__', [('a1', [1]), ('a21', [96])]),  # A1=1 & A21 contains 96
    ('M04','a21_own'):('a1', [1]),                                     # A1=1 (derived: owns vehicle)
    ('M04','a22'):   ('__compound__', [('a1', [1]), ('a21_1', 'notna')]),  # A1=1 & A21_1≠missing
    ('M04','a23'):   ('a1', [1]),                                      # A1=1 (transport cost)

    # ── M05 Income ──
    # ia2: Kobo relevant depends on panel pre-fill (income_fmid_employment/income_fmidA1).
    #   Pre-fill not in pooled data — show ungated. ~27-35% missing = panel-routed past IA2.
    # ia5: R1-R2 gated on fmidA1=2 (same as IA2), R3+ unconditional. Show ungated.
    #   R1-R2 missing ~27-31% (pre-fill gate) vs R4-R5 0% (unconditional).
    # ia7: Kobo relevant=indexed-repeat(${A9}, ${employ_}, ${income_old_fmid})=1
    #   A9 is cross-module (M04 gig work), not in M05 data. ~92-100% missing expected.
    #   Consistent across all 5 rounds.
    # ia3: R1-R2 IA2=1 only; R3-R5 IA2=1 OR income_fmid*=1 (pre-fill bypass, not in data).
    #   Gate on ia2=1 for heatmap — R3-R5 will show some "missing" that are actually
    #   filled via pre-fill bypass (income_fmid_employment=1 → skip IA2, go to IA3).
    ('M05','ia3'):   ('ia2', [1]),                                     # IA3_a–f: R1-R2 strict IA2=1; R3+ also pre-fill bypass
    ('M05','ia6'):   ('ia5', [1]),                                     # IA6_a–f: IA5=1 all rounds (no pre-fill bypass)

    # ── M06 Finance ──
    ('M06','f17'):   ('__round__', [5]),                               # F17 (bank account) R5-only question
    ('M06','f18'):   ('__round__', [5]),                               # F18 (mobile money) R5-only question
    ('M06','f1'):    ('__round__', [1, 2, 3, 4]),                     # R5: f1 gated on f17=1 (not in pooled data)
    ('M06','f2'):    ('__round__', [1, 2, 3, 4]),                     # R5: f2 gated on f18=1 (not in pooled data)
    ('M06','f8'):    ('f7', [1]),
    ('M06','f8_oth'):('__compound__', [('f7', [1]), ('f8', [96])]),   # F7=1 & F8=96 (other purpose)
    ('M06','f9'):    ('f7', [1]),
    ('M06','f9_oth'):('__compound__', [('f7', [1]), ('f9', [96])]),   # F7=1 & F9=96 (other institution)
    ('M06','f10'):   ('f7', [1]),

    # ── M07 Health (R5 only) ──
    ('M07','h2a'):   ('h2', [1,2,3]),
    ('M07','h3'):    ('__compound__', [('h2', [1,2,3]), ('h2a', [2])]),              # H2=1|2|3 & H2A=2
    ('M07','h3_oth'):('__compound__', [('h2', [1,2,3]), ('h2a', [2]), ('h3', [96])]),# H2=1|2|3 & H2A=2 & H3=96
    ('M07','h4'):    ('h2', [2,3]),                                    # H4 outpatient block
    ('M07','h4_oth'):('__compound__', [('h2', [2,3]), ('h4', [96])]),  # H2=2|3 & H4=96
    ('M07','h7'):    ('h2', [2,3]),
    ('M07','h8'):    ('h2', [2,3]),
    ('M07','h8_amt'):('__compound__', [('h2', [2,3]), ('h8', [1,2])]),              # H2=2|3 & H8=1|2
    ('M07','h9'):    ('__compound__', [('h2', [2,3]), ('h8', [1,2])]),              # H2=2|3 & H8=1|2
    ('M07','h9a'):   ('__compound__', [('h2', [2,3]), ('h8', [1,2])]),
    ('M07','h9b'):   ('__compound__', [('h2', [2,3]), ('h8', [1,2])]),
    ('M07','h9c'):   ('__compound__', [('h2', [2,3]), ('h8', [1,2])]),
    ('M07','h10'):   ('h2', [2,3]),                                    # H10 treatments: outpatient block
    ('M07','h11a'):  ('__compound__', [('h2', [2,3]), ('h10_1', [1])]),             # H2=2|3 & H10_1=1
    ('M07','h11b_1_'):('__compound__', [('h2', [2,3]), ('h10_1', [1])]),            # H2=2|3 & H10_1=1
    ('M07','h11b_2_'):('__compound__', [('h2', [2,3]), ('h10_2', 'notna')]),        # H2=2|3 & H10_2≠missing
    ('M07','h11b_3_'):('__compound__', [('h2', [2,3]), ('h10_3', 'notna')]),        # H2=2|3 & H10_3≠missing
    ('M07','h12'):   None,                                              # Unconditional in R5
    ('M07','h13'):   ('h12', [1]),
    ('M07','h14'):   ('h12', [1]),
    ('M07','h15'):   ('h12', [1]),
    ('M07','h16'):   ('h12', [1]),
}

# ── Kobo questionnaire variable ordering ──────────────────────────────────────
# Variables appear in heatmaps in the order they are asked in the Kobo XLSForm.
# Derived from R5 XLSForm (supplemented by R3 for natural hazard vars).
# Names are .dta column names (lowercase), matching what appears in heatmap rows.
# SATA families use base name; "(multi)" suffix is handled by sort key function.
KOBO_VAR_ORDER = {
    'M00': [
        # Ordered to match authoritative M00 variable list (data-available subset).
        # Only questionnaire vars — duration vars and fmid excluded for panel consistency.
        # Vars not in pooled data: Z0_first, Z0_last, member_called, Z17,
        #   member_talkedto, n_Z17, backgound_audio (appear in Tracker/Kobo only)
        'int_id',                       # int_id
        'hhid',                         # hhid
        'survey_lang',                  # D3: survey language
        'date_of_interview',            # Z6: date of interview
        'time_of_interview',            # Z7: time of interview
        'call_attemp',                  # Z8: call attempt number
        'call_status1',                 # call_status1: call outcome
        'correct_resp',                 # Z16: correct respondent
        'agreement',                    # Z9: consent/agreement
        'refusal_reason',               # Z18: refusal reason (if Z9≠agree)
        'refusal_reason_oth',           # Z18_oth: other refusal reason
        'interview_record',             # Z19: recording consent
        'address_unchanged',            # Z20: address still the same?
        'region',                       # Z1: region
        'province',                     # Z2: province
        'city',                         # Z3: city/municipality
        'barangay',                     # Z4: barangay
        'locale',                       # Z5: locale/urban-rural
    ],
    'M01': [
        # Ordered to match Question-Level Cross-Round Tracker & user's full variable list
        'isfmid',                       # D5A: Name, age & sex of HH members
        'age',                          # (part of D5A roster)
        'gender',                       # (part of D5A roster)
        'hhsize',                       # (derived from roster)
        'member_leftreason',            # D25: Reason for leaving
        'member_leftreason_oth',        # D25_oth: Other specify
        'country_moved',                # D26_1: Country where moved
        'prov_moved',                   # D26_2: Province where moved
        'city_moved',                   # D26_3: City where moved
        'correct_name',                 # D27: Correct name
        'correct_age',                  # D28: Correct age
        'correct_gender',               # D33: Correct sex (R2+)
        # D29/D30/D31/D32 not in pooled data — consumed during cleaning to create new roster rows
        'relationship',                 # D6: Relationship to HH head (new members)
        'moved_in_reason',              # M13: Reason for moving in
        'moved_in_reason_oth',          # M13_oth: Other specify
        'country_migrated_from',        # M10_1: Country where came from
        'province_migrated_from',       # M10_2: Province where came from
        'city_migrated_from',           # M10_3: City where came from
    ],
    'M02': [
        # Ordered to match authoritative M02 variable list (data-available subset)
        'hhid', 'fmid', 'age', 'gender',
        'ed15', 'ed16', 'ed16_oth',
    ],
    'M03': [
        # Authoritative M03 variable list (15 vars) — updated 2026-04-03
        # Matches HF pooled dataset; removed sh1b_oth, sh2_oth (dropped in shock
        # splitting), nh14-nh17 (dropped as processing artefacts in HF do-file)
        # Core shocks (R1-R5)
        'sh1', 'sh1b', 'sh2', 'sh3', 'sh4',
        'el5', 'n5',
        # Natural hazard block (R3+ only): nh2 → nh7 → nh10 → nh3
        'nh2',
        'nh7', 'nh7_oth',
        'nh10', 'nh10_oth',
        'nh3',
        # Internet block (R3 only)
        'n1', 'n3',
    ],
    'M04': [
        # Kobo order: A24 → A27 → A25 (confirmation) → A1 → A26 → core block
        'a24', 'a27', 'a25',
        'a1', 'a26',
        'a3', 'a3_oth',
        'a4', 'a4_oth', 'a5', 'a5_oth', 'a6', 'a7', 'a8', 'a9',
        'a10', 'a11', 'a16', 'a17', 'a18',
        'a19', 'a19_oth', 'a20', 'a21', 'a21_oth', 'a21_own', 'a22', 'a23',
    ],
    'M05': [
        'ia2', 'ia3_a', 'ia3_b', 'ia3_c', 'ia3_d', 'ia3_e', 'ia3_f',
        'ia5', 'ia6_a', 'ia6_b', 'ia6_c', 'ia6_d', 'ia6_e', 'ia6_f', 'ia7',
    ],
    'M06': [
        'f17', 'f1', 'f18', 'f2', 'f3', 'f6', 'f7',
        'f8', 'f8_oth', 'f9', 'f9_oth', 'f10',
        'f13_a', 'f13_b', 'f14', 'f15', 'f16',
    ],
    'M07': [
        'h2', 'h2a', 'h3', 'h3_oth',
        'h4', 'h4_oth', 'h7', 'h8', 'h8_amt',
        'h9', 'h9a', 'h9b', 'h9c',
        'h10', 'h11a', 'h11b_1_', 'h11b_1__oth', 'h11b_2_', 'h11b_2__oth',
        'h11b_3_', 'h11b_3__oth',
        'h12', 'h13', 'h13_oth', 'h14', 'h15', 'h16', 'h16_oth', 'h17',
    ],
    'M08': [
        'f08_a', 'f08_b', 'f08_c', 'f08_d', 'f08_e',
        'f08_f', 'f08_g', 'f08_h',   # R6+ FIES items
    ],
    'M09': [
        'v1', 'v5',
        'v9_a', 'v9_b', 'v9_c', 'v9_e', 'v9_f', 'v9_g',
        'v9_i', 'v9_j', 'v9_k', 'v9_l', 'v9_m',
        'v11', 'v12',
    ],
}

# ── Display names: data column → label with questionnaire code ────────────────
# Only M01 for now; add other modules as needed.
DISPLAY_NAMES = {
    'M00': {
        'int_id':               'int_id',
        'hhid':                 'hhid',
        'survey_lang':          'D3 (survey_lang)',
        'date_of_interview':    'Z6 (date_of_interview)',
        'time_of_interview':    'Z7 (time_of_interview)',
        'call_attemp':          'Z8 (call_attemp)',
        'call_status1':         'call_status1',
        'correct_resp':         'Z16 (correct_resp)',
        'agreement':            'Z9 (agreement)',
        'refusal_reason':       'Z18 (refusal_reason)',
        'refusal_reason_oth':   'Z18_oth (refusal_reason_oth)',
        'interview_record':     'Z19 (interview_record)',
        'address_unchanged':    'Z20 (address_unchanged)',
        'region':               'Z1 (region)',
        'province':             'Z2 (province)',
        'city':                 'Z3 (city)',
        'barangay':             'Z4 (barangay)',
        'locale':               'Z5 (locale)',
        'dur_pp':               'dur_pp',
        'dur_rr':               'dur_rr',
        'dur_educ':             'dur_educ',
        'dur_sh':               'dur_sh',
        'dur_emp':              'dur_emp',
        'dur_inc':              'dur_inc',
        'dur_fin':              'dur_fin',
        'dur_hlt':              'dur_hlt',
        'dur_f_nf':             'dur_f_nf',
        'dur_vw':               'dur_vw',
        'dur_tot':              'dur_tot',
    },
    'M01': {
        'isfmid':                   'D5A (isfmid)',
        'age':                      'D5A (age)',
        'age_grp':                  'age_grp (derived)',
        'gender':                   'D5A (gender)',
        'hhsize':                   'hhsize (derived)',
        'member_leftreason':        'D25 (member_leftreason)',
        'member_leftreason_oth':    'D25_oth (member_leftreason_oth)',
        'country_moved':            'D26_1 (country_moved)',
        'prov_moved':               'D26_2 (prov_moved)',
        'city_moved':               'D26_3 (city_moved)',
        'correct_name':             'D27 (correct_name)',
        'correct_age':              'D28 (correct_age)',
        'correct_gender':           'D33 (correct_gender)',
        'relationship':             'D6 (relationship)',
        'moved_in_reason':          'M13 (moved_in_reason)',
        'moved_in_reason_oth':      'M13_oth (moved_in_reason_oth)',
        'country_migrated_from':    'M10_1 (country_migrated_from)',
        'province_migrated_from':   'M10_2 (province_migrated_from)',
        'city_migrated_from':       'M10_3 (city_migrated_from)',
    },
    'M02': {
        'hhid':       'hhid',
        'fmid':       'fmid',
        'age':        'age',
        'gender':     'gender',
        'ed15':       'ED15 (ed15)',
        'ed16':       'ED16 (ed16)',
        'ed16_oth':   'ED16_oth (ed16_oth)',
    },
    'M03': {
        'sh1':        'SH1 (sh1)',
        'sh1b':       'SH1b (sh1b)',
        'sh2':        'SH2 (sh2)',
        'sh3':        'SH3 (sh3)',
        'sh4':        'SH4 (sh4)',
        'el5':        'EL5 (el5)',
        'n5':         'N5 (n5)',
        'nh2':        'NH2 (nh2)',
        'nh7':        'NH7 (nh7)',
        'nh7_oth':    'NH7_oth (nh7_oth)',
        'nh10':       'NH10 (nh10)',
        'nh10_oth':   'NH10_oth (nh10_oth)',
        'nh3':        'NH3 (nh3)',
        'n1':         'N1 (n1)',
        'n3':         'N3 (n3)',
    },
    'M04': {
        'a24':        'A24 (a24)',
        'a27':        'A27 (a27)',
        'a1':         'A1 (a1)',
        'a26':        'A26 (a26)',
        'a25':        'A25 (a25)',
        'a3':         'A3 (a3)',
        'a3_oth':     'A3_oth (a3_oth)',
        'a4':         'A4 (a4)',
        'a4_oth':     'A4_oth (a4_oth)',
        'a5':         'A5 (a5)',
        'a5_oth':     'A5_oth (a5_oth)',
        'a6':         'A6 (a6)',
        'a7':         'A7 (a7)',
        'a8':         'A8 (a8)',
        'a9':         'A9 (a9)',
        'a10':        'A10 (a10)',
        'a11':        'A11 (a11)',
        'a16':        'A16 (a16)',
        'a17':        'A17 (a17)',
        'a18':        'A18 (a18)',
        'a19':        'A19 (a19)',
        'a19_oth':    'A19_oth (a19_oth)',
        'a20':        'A20 (a20)',
        'a21':        'A21 (a21)',
        'a21_oth':    'A21_oth (a21_oth)',
        'a21_own':    'A21_own (a21_own)',
        'a22':        'A22 (a22)',
        'a23':        'A23 (a23)',
    },
    'M05': {
        'ia2':        'IA2 (ia2)',
        'ia3_a':      'IA3_A (ia3_a)',
        'ia3_b':      'IA3_B (ia3_b)',
        'ia3_c':      'IA3_C (ia3_c)',
        'ia3_d':      'IA3_D (ia3_d)',
        'ia3_e':      'IA3_E (ia3_e)',
        'ia3_f':      'IA3_F (ia3_f)',
        'ia5':        'IA5 (ia5)',
        'ia6_a':      'IA6_A (ia6_a)',
        'ia6_b':      'IA6_B (ia6_b)',
        'ia6_c':      'IA6_C (ia6_c)',
        'ia6_d':      'IA6_D (ia6_d)',
        'ia6_e':      'IA6_E (ia6_e)',
        'ia6_f':      'IA6_F (ia6_f)',
        'ia7':        'IA7 (ia7)',
    },
    'M06': {
        'f17':        'F17 (f17)',
        'f1':         'F1 (f1)',
        'f18':        'F18 (f18)',
        'f2':         'F2 (f2)',
        'f3':         'F3 (f3)',
        'f6':         'F6 (f6)',
        'f7':         'F7 (f7)',
        'f8':         'F8 (f8)',
        'f8_oth':     'F8_oth (f8_oth)',
        'f9':         'F9 (f9)',
        'f9_oth':     'F9_oth (f9_oth)',
        'f10':        'F10 (f10)',
        'f13_a':      'F13_A (f13_a)',
        'f13_b':      'F13_B (f13_b)',
        'f14':        'F14 (f14)',
        'f15':        'F15 (f15)',
        'f16':        'F16 (f16)',
    },
    'M07': {
        'h2':         'H2 (h2)',
        'h2a':        'H2A (h2a)',
        'h3':         'H3 (h3)',
        'h3_oth':     'H3_oth (h3_oth)',
        'h4':         'H4 (h4)',
        'h4_oth':     'H4_oth (h4_oth)',
        'h7':         'H7 (h7)',
        'h8':         'H8 (h8)',
        'h8_amt':     'H8_amt (h8_amt)',
        'h9a':        'H9A (h9a)',
        'h9b':        'H9B (h9b)',
        'h9c':        'H9C (h9c)',
        'h10':        'H10 (h10)',
        'h11a':       'H11a (h11a)',
        'h11b_1_':    'H11b (h11b_1_)',
        'h11b_1__oth':'H11b_oth (h11b_1__oth)',
        'h11b_2_':    'H11b (h11b_2_)',
        'h11b_2__oth':'H11b_oth (h11b_2__oth)',
        'h11b_3_':    'H11b (h11b_3_)',
        'h11b_3__oth':'H11b_oth (h11b_3__oth)',
        'h12':        'H12 (h12)',
        'h13':        'H13 (h13)',
        'h13_oth':    'H13_oth (h13_oth)',
        'h14':        'H14 (h14)',
        'h15':        'H15 (h15)',
        'h16':        'H16 (h16)',
        'h16_oth':    'H16_oth (h16_oth)',
        'h17':        'H17 (h17)',
    },
    'M08': {
        'f08_a':      'F08_A (f08_a)',
        'f08_b':      'F08_B (f08_b)',
        'f08_c':      'F08_C (f08_c)',
        'f08_d':      'F08_D (f08_d)',
        'f08_e':      'F08_E (f08_e)',
        'f08_f':      'F08_F (f08_f)',   # R6+
        'f08_g':      'F08_G (f08_g)',   # R6+
        'f08_h':      'F08_H (f08_h)',   # R6+
    },
    'M09': {
        'v1':         'V1 (v1)',
        'v5':         'V5 (v5)',
        'v9_a':       'V9_A (v9_a)',
        'v9_b':       'V9_B (v9_b)',
        'v9_c':       'V9_C (v9_c)',
        'v9_e':       'V9_E (v9_e)',
        'v9_f':       'V9_F (v9_f)',
        'v9_g':       'V9_G (v9_g)',
        'v9_i':       'V9_I (v9_i)',
        'v9_j':       'V9_J (v9_j)',
        'v9_k':       'V9_K (v9_k)',
        'v9_l':       'V9_L (v9_l)',
        'v9_m':       'V9_M (v9_m)',
        'v11':        'V11 (v11)',
        'v12':        'V12 (v12)',
    },
}

def _kobo_sort_key(var_name, module):
    """Return a sort key for a heatmap variable based on Kobo questionnaire order.
    Handles SATA '(multi)' suffix and prefix matching for nested vars like nh3_2_1."""
    order = KOBO_VAR_ORDER.get(module, [])
    # Strip " (multi)" for lookup
    base = var_name.replace(' (multi)', '')
    # Exact match
    for i, v in enumerate(order):
        if base == v:
            # Put "(multi)" right after its base variable
            return (i, 1 if '(multi)' in var_name else 0)
    # Prefix match: nh3_2_1 matches 'nh3', sh1b_1 matches 'sh1b', sh2_1 matches 'sh2'
    for i, v in enumerate(order):
        if base.startswith(v) and base != v:
            # Sub-sort by the full name to keep nested vars together
            return (i, 0, base)
    # Not found in Kobo order — put at end, sorted alphabetically
    return (9999, 0, base)


def _find_gate(module, var):
    """Find the conditional gate for a variable using prefix matching."""
    # Exact match first
    key = (module, var)
    if key in CONDITIONAL_GATES:
        return CONDITIONAL_GATES[key]
    # Prefix match: e.g. ('M05','ia3') matches 'ia3_a'
    for (mod, prefix), gate in CONDITIONAL_GATES.items():
        if mod == module and var.startswith(prefix) and var != prefix:
            return gate
    return None  # Unconditional


# ── Gate label display mapping ────────────────────────────────────────────────
# Maps Stata column names to questionnaire variable names for gate labels.
# Keeps heatmap condition tags consistent with questionnaire naming convention.
GATE_LABEL_MAP = {
    # M00 Passport
    'call_status1':         'call_status1',
    'agreement':            'Z9',
    'address_unchanged':    'Z20',
    'refusal_reason':       'Z18',
    # M01 Roster
    'isfmid':               'D5A',
    'member_leftreason':    'D25',
    'moved_in_reason':      'M13',
    # M02 Education
    'ed15':                 'ED15',
    'ed17':                 'ED17',
    # M03 Shocks
    'sh1':                  'SH1',
    'sh3':                  'SH3',
    # M04 Employment
    'a1':                   'A1',
    'a3':                   'A3',
    'a4':                   'A4',
    'a5':                   'A5',
    'a6':                   'A6',
    'a8':                   'A8',
    'a16':                  'A16',
    'a21_1':                'A21_1',
    # M05 Income
    'ia2':                  'IA2',
    'ia5':                  'IA5',
    # M06 Finance
    'f7':                   'F7',
    # M07 Health
    'h2':                   'H2',
    'h2a':                  'H2A',
    'h3':                   'H3',
    'h4':                   'H4',
    'h8':                   'H8',
    'h10_1':                'H10_1',
    'h10_2':                'H10_2',
    'h10_3':                'H10_3',
    'h12':                  'H12',
}

# Special overrides: when a gate column + value combination needs a completely
# different display label (e.g. isfmid=6 is derived from D29=1 in Stata).
GATE_LABEL_OVERRIDES = {
    ('isfmid', (6,)):  'D29=1',   # isfmid=6 = new member, derived from D29=1
}

def _apply_gate(sub, gate, r, var):
    """Apply a gate to filter a DataFrame subset. Returns (filtered_df, gate_label, is_na).
    is_na=True means this round should show N/A (not applicable)."""
    if gate is None:
        return sub, None, False

    gate_col, gate_vals = gate

    # Special: compound gate — apply multiple gates sequentially
    if gate_col == '__compound__':
        combined_label_parts = []
        for sub_gate in gate_vals:
            sub, lbl, is_na = _apply_gate(sub, sub_gate, r, var)
            if lbl:
                combined_label_parts.append(lbl)
            if is_na or not len(sub):
                return sub, ' & '.join(combined_label_parts) if combined_label_parts else None, True
        return sub, ' & '.join(combined_label_parts) if combined_label_parts else None, False

    # Special: round gate — variable only exists in specific rounds
    if gate_col == '__round__':
        if r not in gate_vals:
            return sub, f"R{','.join(str(v) for v in gate_vals)} only", True
        return sub, f"R{','.join(str(v) for v in gate_vals)} only", False

    # Special: age gate
    if gate_col == '__age__':
        lo, hi = gate_vals
        if 'age' in sub.columns:
            sub = sub[(sub['age'] >= lo) & (sub['age'] <= hi)]
        return sub, f"age {lo}-{hi}", False

    # Special: nested natural hazard SATA — nh3_X_Y → gate on nh2_X notna
    if gate_col == '__nh_nested__':
        import re
        # Extract hazard number from variable name: nh3_2_1 → hazard 2, nh7_1_1 → hazard 1
        m = re.match(r'nh\d+_(\d+)', var)
        if m:
            haz_num = m.group(1)
            gate_var = f'nh2_{haz_num}'
            if gate_var not in sub.columns:
                return sub, f"nh2_{haz_num} (not in data)", True  # N/A
            sub = sub[sub[gate_var].notna()]
            if len(sub) < 5:  # tiny sample, not meaningful
                return sub, f"nh2_{haz_num}≠missing (n<5)", True
            return sub, f"nh2_{haz_num}≠missing", False
        # For the SATA family itself (e.g., nh3_1 collapsed) — gate on nh2_1
        if 'nh2_1' in sub.columns:
            sub = sub[sub['nh2_1'].notna()]
        return sub, "nh2 respondents", False

    # Special: roster-filtered module — asked to selected HH members only
    # Denominator is unknowable from pooled data; exclude from missing rate
    if gate_col == '__roster_filter__':
        return sub, "roster filter", True

    # Special: 'notna' gate — filter to rows where gate_col is not NaN
    if gate_vals == 'notna':
        if gate_col in sub.columns:
            sub = sub[sub[gate_col].notna()]
        disp = GATE_LABEL_MAP.get(gate_col, gate_col)
        return sub, f"{disp}≠missing", False

    # Standard: filter to rows where gate_col in gate_vals
    if gate_col in sub.columns:
        if any(isinstance(v, str) for v in gate_vals):
            # String gate values (e.g. categoricals with labels) — match directly
            sub = sub[sub[gate_col].isin(gate_vals)]
        else:
            sub = sub[n(sub[gate_col]).isin(gate_vals)]
    # Check for a full override first (e.g. isfmid=6 → D29=1)
    override_key = (gate_col, tuple(gate_vals))
    if override_key in GATE_LABEL_OVERRIDES:
        return sub, GATE_LABEL_OVERRIDES[override_key], False
    disp = GATE_LABEL_MAP.get(gate_col, gate_col)
    return sub, f"{disp}={'|'.join(str(v) for v in gate_vals)}", False

def _detect_sata_families(cols):
    """Detect select-all-that-apply families: base_1, base_2, ... (2+ numbered suffixes).
    If the base variable also exists as its own column (e.g. ed16 + ed16_1 + ed16_2),
    the base is kept as a regular variable and the _N items are collapsed separately.
    Nested SATA families (where the base is itself a member of an outer family)
    are suppressed — their sub-items are excluded from the heatmap entirely.
    Returns dict {display_name: [col1, col2, ...]} and set of all member columns."""
    import re
    pat = re.compile(r'^(.+?)_(\d+)$')
    bases = {}
    for c in cols:
        m = pat.match(c)
        if m:
            base = m.group(1)
            bases.setdefault(base, []).append(c)
    # Only keep families with 2+ numbered items (true SATA)
    families = {}
    for b, vs in bases.items():
        if len(vs) >= 2:
            families[b] = sorted(vs)
    # Suppress nested SATA: if a family's base is itself a member of another family,
    # it's a sub-question within a repeat group (e.g. sh2_1 is member of sh2 family
    # AND base of sh2_1 family with sub-items sh2_1_1...sh2_1_9).
    # These inner families create misleading missing rates.
    outer_members = {c for vs in families.values() for c in vs}
    nested_bases = {b for b in families if b in outer_members}
    nested_sub_items = set()
    for b in nested_bases:
        nested_sub_items |= set(families[b])
        del families[b]
    # Exclude ALL deeper sub-items of SATA families: base_N_anything
    # e.g. sh2 family → exclude sh2_1_oth, sh2_4_1, sh2_2_3, etc.
    # This catches both nested family sub-items AND orphan sub-items
    col_set = set(cols)
    sub_pat = re.compile(r'_\d+_.+$')
    for outer_base, outer_mems in families.items():
        prefix = outer_base + '_'
        for c in col_set:
            if c.startswith(prefix) and c not in outer_mems and sub_pat.search(c[len(outer_base):]):
                nested_sub_items.add(c)
    members = {c for vs in families.values() for c in vs} | nested_sub_items
    return families, members


def heatmap(df, keep=25, module=None):
    # For M01, don't exclude roster question vars; for all others, exclude them
    excl = EXCL.copy()
    if module == 'M00':
        excl -= M00_PASSPORT_VARS   # address, language, IDs are actual M00 questions
        excl |= M00_HEATMAP_EXCL    # duration vars & fmid not in authoritative list
    elif module == 'M01':
        excl -= ROSTER_QUESTIONS    # age, gender, isfmid, etc. ARE actual M01 questions
        excl |= M01_EDUCATION_VARS  # ed15/ed16 belong in M02, not M01
        excl |= M01_DUPLICATE_VARS  # member_leftreason_other (now harmonized to _oth)
    elif module == 'M02':
        # M02 authoritative list: hhid, fmid, age, gender, ed15, ed16, ed16_oth (7 vars).
        # Restrict heatmap to exactly these — exclude everything else (ed17, ed18, ed19_*,
        # ed20, ed2, dur_educ, dur_emp, pcinc_imp_mean, etc.) by adding all other df
        # columns to excl.
        excl -= M02_EDUCATION_KEEP          # un-exclude the 7 authoritative vars
        excl |= {c for c in df.columns if c not in M02_EDUCATION_KEEP}  # exclude all others
    elif module == 'M05':
        excl |= ROSTER_QUESTIONS | M05_DERIVED   # drop derived income totals (not Kobo questions)
    else:
        excl |= ROSTER_QUESTIONS
    # Other-specify (_oth) fields are ~100% missing by design (only filled when
    # "other" is picked) — never a meaningful DQ signal, so exclude from the heatmap.
    cols = [c for c in df.columns if c not in excl
            and not c.startswith(('wt','w_','_'))
            and not c.endswith('_oth') and c != 'round']

    # Detect select-all-that-apply families (base_1, base_2, ...)
    sata_families, sata_members = _detect_sata_families(cols)

    # Build list: non-SATA individual vars + one entry per SATA family
    # If the base variable also exists as its own column, keep it as regular +
    # add the SATA group with a distinct display name (base + " (multi)")
    items = []  # (display_name, is_sata, sata_cols_or_None)
    seen_families = set()
    for c in cols:
        if c in sata_members:
            # Find which family this belongs to
            for base, members in sata_families.items():
                if c in members:
                    if base not in seen_families:
                        seen_families.add(base)
                        # If base also exists as a column, use distinct name
                        disp = f"{base} (multi)" if base in cols and base not in sata_members else base
                        items.append((disp, True, members))
                    break
        else:
            items.append((c, False, None))

    # Sort by Kobo questionnaire order before truncating
    if module and module in KOBO_VAR_ORDER:
        items.sort(key=lambda x: _kobo_sort_key(x[0], module))

    items = items[:keep]
    rows = []
    for var_name, is_sata, sata_cols in items:
        # For gate lookup, use base name (strip " (multi)" suffix)
        lookup_name = var_name.replace(' (multi)', '') if is_sata else var_name
        gate = _find_gate(module, lookup_name) if module else None
        # Apply display name with questionnaire code if available
        display = var_name
        if module and module in DISPLAY_NAMES:
            dname = DISPLAY_NAMES[module].get(lookup_name)
            if dname:
                display = dname + (' (multi)' if is_sata else '')
        row = {'var': display}
        if is_sata:
            row['sata'] = True
        is_conditional = gate is not None
        gate_label = None
        for r in ROUNDS:
            sub = df[df['round']==r]
            if not len(sub):
                row[str(r)] = None
                continue
            # Apply gate (handles age, round, roster, standard gates)
            if gate:
                sub, lbl, is_na = _apply_gate(sub, gate, r, lookup_name)
                if not is_na and lbl:
                    gate_label = lbl  # keep label from a round that had valid data
                if is_na or not len(sub):
                    row[str(r)] = None
                    continue
            if is_sata:
                # SATA: "missing" = ALL sub-items are NaN (whole question skipped)
                present = [c for c in sata_cols if c in sub.columns]
                if not present:
                    row[str(r)] = None
                    continue
                any_answered = sub[present].notna().any(axis=1)
                if any_answered.sum() == 0:
                    row[str(r)] = None  # question not in this round
                else:
                    # % of respondents who didn't answer ANY sub-item
                    row[str(r)] = round((~any_answered).mean()*100, 1)
            else:
                filled = is_filled(sub[var_name])
                # ED16 derived indicator: the select_multiple "what is the member
                # doing now" splits across columns by round. The aggregate ed16
                # column holds data R1–R3, but R4–R8 the answer lives in the split
                # dummies ed16_1/ed16_2 (aggregate empty). A respondent has answered
                # if the aggregate OR any dummy is filled — otherwise the bare ed16
                # column shows a spurious 100% missing R4+. (Dummies are excluded
                # from the M02 keep-set so they're not in `cols`, but the gated
                # `sub` frame still carries them.)
                if module == 'M02' and lookup_name == 'ed16':
                    for _d in ('ed16_1', 'ed16_2'):
                        if _d in sub.columns:
                            filled = filled | sub[_d].notna()
                n_filled = filled.sum()
                if n_filled == 0:
                    # All values are missing/empty this round.
                    # Structural case: if this scalar also has a select-multiple
                    # dummy family (e.g. R1 stores sh1b as sh1b_1..22, leaving the
                    # scalar column empty) and that family HAS data this round, the
                    # scalar is just a placeholder → suppress instead of reporting
                    # a misleading 100% missing.
                    _fam = sata_families.get(var_name)
                    _fam_has_data = False
                    if _fam:
                        _fp = [c for c in _fam if c in sub.columns]
                        _fam_has_data = bool(_fp) and int(sub[_fp].notna().any(axis=1).sum()) > 0
                    if _fam_has_data:
                        row[str(r)] = None
                    # If a gate was applied (conditional var) and rows matched,
                    # this means the question SHOULD have been answered → 100%.
                    # If ungated and all NaN → variable not in this round → None.
                    elif gate and len(sub) > 0:
                        row[str(r)] = 100.0
                    else:
                        row[str(r)] = None
                else:
                    row[str(r)] = round((~filled).mean()*100, 1)
        vals = [row[str(r)] for r in ROUNDS if row[str(r)] is not None]
        if not vals:
            continue
        mx = max(vals)
        row['rag'] = 'red' if mx>=15 else ('yellow' if mx>=5 else 'green')
        # Mark conditional variables so the dashboard can show the gate info
        if is_conditional and gate_label:
            row['conditional'] = True
            row['gate'] = gate_label
        # Preload-gated routing/income vars: gate references prior-round preload or
        # cross-module variables absent from the pooled .dta → heatmap can't apply
        # it and the high "missing" is an artifact. Mark conditional (kept out of
        # module max-missing) + tag so reviewers know it isn't a collection failure.
        if module and (module, lookup_name) in PRELOAD_GATED:
            row['conditional'] = True
            row.setdefault('gate', 'preload gate (prior-round) — not in pooled data')
        # Note: ed17/ed2/ed19_* are now gated via CONDITIONAL_GATES (see M02 section).
        # The __round__=8 gate suppresses R1-R7 (None) and marks them conditional.
        rows.append(row)
    return rows

heatmap_data = {
    'M00':heatmap(m00, keep=35, module='M00'),'M01':heatmap(m01, module='M01'),
    'M02':heatmap(m02, module='M02'),'M03':heatmap(m03, module='M03'),
    'M04':heatmap(m04, keep=35, module='M04'),'M05':heatmap(m05, module='M05'),
    'M06':heatmap(m06, module='M06'),'M07':heatmap(m07, module='M07'),
    'M08':heatmap(m08, module='M08'),'M09':heatmap(m09, module='M09'),
}

# ── Inject D29–D32 into M01 heatmap ──────────────────────────────────────────
# These variables are consumed during Stata cleaning (D29=1 → new roster rows
# with isfmid=6) and don't exist in the pooled data. Insert as all-None rows
# so the tracker is complete. Position: after correct_gender (D33), before
# relationship (D6), matching questionnaire order.
# D29–D32: consumed in Stata cleaning. D29 is asked to all D5A=1 members (all rounds).
# D30–D32 are conditional on D29=1 (new member reported). No new members in R1–R2
# (isfmid=6 count: R1=0, R2=0, R3=23, R4=26, R5=27), so D30–D32 show N/A for R1–R2.
_D29_D32_ROWS = [
    {'var': 'D29 (new_member)',      'conditional': True, 'gate': 'if D5A=1',
     '1': 0, '2': 0, '3': 0, '4': 0, '5': 0, 'rag': 'green',
     'note': 'Collected in all rounds. Consumed in Stata to create new roster rows (isfmid=6).'},
    {'var': 'D30 (new_member_name)', 'conditional': True, 'gate': 'if D29=1',
     '1': None, '2': None, '3': 0, '4': 0, '5': 0, 'rag': 'green',
     'note': 'Conditional on D29=1. No new members in R1–R2. Consumed in Stata.'},
    {'var': 'D31 (new_member_sex)',  'conditional': True, 'gate': 'if D29=1',
     '1': None, '2': None, '3': 0, '4': 0, '5': 0, 'rag': 'green',
     'note': 'Conditional on D29=1. No new members in R1–R2. Consumed in Stata.'},
    {'var': 'D32 (new_member_age)',  'conditional': True, 'gate': 'if D29=1',
     '1': None, '2': None, '3': 0, '4': 0, '5': 0, 'rag': 'green',
     'note': 'Conditional on D29=1. No new members in R1–R2. Consumed in Stata.'},
]
# Find insertion point: after correct_gender (D33), before relationship (D6)
_m01_rows = heatmap_data.get('M01', [])
_insert_idx = len(_m01_rows)  # default: append at end
for _i, _r in enumerate(_m01_rows):
    v = _r.get('var', '')
    if ('D6' in v and 'relationship' in v) or v.startswith('D6 '):
        _insert_idx = _i
        break
for _j, _new_row in enumerate(_D29_D32_ROWS):
    _m01_rows.insert(_insert_idx + _j, _new_row)
heatmap_data['M01'] = _m01_rows

# ── Cross-reference skip violations → heatmap rows ─────────────────────────
# For each skip issue, tag affected heatmap rows with per-round violation counts.
# This lets the dashboard render skip-violation badges on heatmap cells so the
# viewer sees both "missing when should be filled" and "filled when should be empty".
#
# Map: (module, substring in 'variable' field) → list of target var prefixes (lowercase)
# Prefix matching: 'ia3' matches ia3_a, ia3_b, …, ia3_f
_SKIP_HEATMAP_MAP = {
    # M00
    ('M00', 'Z18 should be empty'):       ['refusal_reason'],
    ('M00', 'Z18_oth should be empty'):   ['refusal_reason_oth'],
    # M01
    ('M01', 'D25 should be empty'):       ['d25'],
    ('M01', 'M13 should be empty'):       ['m13'],
    ('M01', 'D27 should be empty'):       ['d27'],
    ('M01', 'D28 should be empty'):       ['d28'],
    ('M01', 'D33 should be empty'):       ['d33'],
    ('M01', 'D6 should be empty'):        ['d6'],
    # M02
    ('M02', 'ED16 should be empty'):      ['ed16'],
    # M03
    ('M03', 'SH1b should be empty'):      ['sh1b'],
    ('M03', 'SH2 should be empty'):       ['sh2'],
    ('M03', 'SH4 should be empty'):       ['sh4'],
    # M04
    ('M04', 'A9 should be empty'):        ['a9'],
    ('M04', 'A17 should be empty'):       ['a17'],
    ('M04', 'A10,A11 should be empty'):   ['a10', 'a11'],
    ('M04', 'A26 should be empty'):       ['a26'],
    ('M04', 'A18 should be empty'):       ['a18'],
    ('M04', 'A19 should be empty'):       ['a19'],
    # M05 — IA3 skip badge only for R1–R2 rule (R3–R5 "pre-fill bypass" is severity=info, no badge)
    ('M05', 'IA3 should be empty'):       ['ia3'],       # R1–R2 only (strict IA2=1 gate)
    ('M05', 'IA6 should be empty'):       ['ia6'],       # All rounds (IA5=1, no pre-fill bypass)
    # M06
    ('M06', 'F8,F9,F10 should be empty'): ['f8', 'f9', 'f10'],
    # M07
    ('M07', 'H3 should be empty'):        ['h3'],
    ('M07', 'H4,H7,H8 should be empty'):  ['h4', 'h7', 'h8'],
    ('M07', 'H8_amt should be empty'):    ['h8_amt'],
    ('M07', 'H13-H16 should be empty'):   ['h13', 'h14', 'h15', 'h16'],
}

import re as _re_skip
for skip in skip_issues:
    # Skip severity=info issues — these are informational (e.g. pre-fill bypass), not violations
    if skip.get('severity') == 'info':
        continue
    mod = skip['module']
    var_field = skip['variable']
    # Find matching target prefixes
    targets = None
    for (m, substr), prefixes in _SKIP_HEATMAP_MAP.items():
        if m == mod and substr in var_field:
            targets = prefixes
            break
    if not targets:
        continue
    # Find matching heatmap rows
    hm_rows = heatmap_data.get(mod, [])
    for row in hm_rows:
        # Extract stata var name from display: e.g. "IA3_A (ia3_a)" → "ia3_a"
        m_var = _re_skip.search(r'\(([^)]+)\)', row.get('var', ''))
        stata_name = (m_var.group(1) if m_var else row.get('var', '')).lower()
        # Check if this row matches any target prefix
        matched = any(stata_name == t or stata_name.startswith(t + '_') for t in targets)
        if not matched:
            continue
        # Attach per-round violation counts
        if 'skip_viol' not in row:
            row['skip_viol'] = {}
        for rnd in ROUNDS:
            cnt = skip['counts_by_round'].get(rnd)
            if cnt and cnt > 0:
                row['skip_viol'][str(rnd)] = row['skip_viol'].get(str(rnd), 0) + cnt

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

# ── Per-interviewer module duration stats ────────────────────────────────────
# For each module, compute median duration per interviewer across all rounds,
# plus per-round medians, total interviews, and a flag for speed outliers.
_dur_map = {
    'M00':'dur_pp','M01':'dur_rr','M02':'dur_educ','M03':'dur_sh','M04':'dur_emp',
    'M05':'dur_inc','M06':'dur_fin','M07':'dur_hlt','M08':'dur_f_nf','M09':'dur_vw'
}
interviewer_quality = {}
if 'int_id' in m00.columns:
    for mod, dur_col in _dur_map.items():
        if dur_col not in m00.columns:
            continue
        df_valid = m00[['int_id','round',dur_col]].copy()
        df_valid[dur_col] = n(df_valid[dur_col])
        df_valid = df_valid.dropna(subset=[dur_col])
        if len(df_valid) == 0:
            continue
        # Global stats for this module duration
        global_median = round(float(df_valid[dur_col].median()), 2)
        global_p25 = round(float(df_valid[dur_col].quantile(0.25)), 2)
        global_p75 = round(float(df_valid[dur_col].quantile(0.75)), 2)
        # Per-interviewer stats
        int_rows = []
        for iid, grp in df_valid.groupby('int_id'):
            row = {
                'int_id': str(int(iid)) if pd.notna(iid) else str(iid),
                'n': int(len(grp)),
                'median': round(float(grp[dur_col].median()), 2),
                'p25': round(float(grp[dur_col].quantile(0.25)), 2),
                'p75': round(float(grp[dur_col].quantile(0.75)), 2),
                'min': round(float(grp[dur_col].min()), 2),
                'max': round(float(grp[dur_col].max()), 2),
            }
            # Per-round medians
            by_r = {}
            for r in ROUNDS:
                rsub = grp[grp['round']==r][dur_col]
                by_r[str(r)] = {'median': round(float(rsub.median()),2), 'n': int(len(rsub))} if len(rsub) else None
            row['by_round'] = by_r
            # Flag: interviewer median below global P25 (fast) or above P75 (slow)
            if row['median'] < global_p25:
                row['flag'] = 'fast'
            elif row['median'] > global_p75:
                row['flag'] = 'slow'
            else:
                row['flag'] = 'normal'
            int_rows.append(row)
        # Sort by median (fastest first)
        int_rows.sort(key=lambda x: x['median'])
        interviewer_quality[mod] = {
            'dur_col': dur_col,
            'global_median': global_median,
            'global_p25': global_p25,
            'global_p75': global_p75,
            'interviewers': int_rows,
        }
interview_meta['interviewer_quality'] = interviewer_quality

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
    # For module-level RAG, use all vars for avg but only unconditional vars for max_miss
    # Conditional vars (nested sub-items with tiny denominators) shouldn't drive module red
    all_vals = [row.get(str(r)) for row in rows for r in ROUNDS if row.get(str(r)) is not None]
    uncond_vals = [row.get(str(r)) for row in rows if not row.get('conditional')
                   for r in ROUNDS if row.get(str(r)) is not None]
    max_miss = max(uncond_vals) if uncond_vals else (max(all_vals) if all_vals else 0)
    avg_miss = round(sum(all_vals)/len(all_vals),1) if all_vals else 0
    skip_t  = sum(v for s in skip_issues if s['module']==mod_name and s.get('severity')!='info' for v in s['counts_by_round'].values() if v)
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
    'h2a':{'label':'H2A – Able to get care (if H2<4)','rates':mr(m07,'h2a') if 'h2a' in m07.columns else {r:None for r in ROUNDS}},
    'h4': {'label':'H4 – Healthcare facility (if H2=2/3)','rates':mr(m07,'h4') if 'h4' in m07.columns else {r:None for r in ROUNDS}},
    'h7': {'label':'H7 – PhilHealth used (if H2=2/3)','rates':mr(m07,'h7') if 'h7' in m07.columns else {r:None for r in ROUNDS}},
    'h8': {'label':'H8 – OOP payment (if H2=2/3)','rates':mr(m07,'h8') if 'h8' in m07.columns else {r:None for r in ROUNDS}},
    'h12':{'label':'H12 – Hospitalized (Ask all R5)','rates':mr(m07,'h12') if 'h12' in m07.columns else {r:None for r in ROUNDS}},
    'h14':{'label':'H14 – Total hospital bill (if H12=1)','rates':mr(m07,'h14') if 'h14' in m07.columns else {r:None for r in ROUNDS}},
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
