#!/usr/bin/env python3
"""
clean_modules.py — Clean HF module .dta files to questionnaire variables only.

For each module:
  - Keeps: hhid, round, fmid (if individual-level), isfmid (M04 only)
  - Keeps: all variables in the UNION of questionnaire outlines for that module
  - Includes suffix expansions (_oth, _1, _2, ... _N) for matched questionnaire vars
  - Orders: id vars first, then questionnaire order
  - Saves to: HF/clean/l2phl_M*.dta
  - Writes: HF/clean/cleaning_log.csv  (what was kept / dropped from each module)
"""
import os, re, csv, sys
import pandas as pd
import numpy as np
try:
    import pyreadstat
    HAS_PYREADSTAT = True
except ImportError:
    HAS_PYREADSTAT = False

_HERE   = os.path.dirname(os.path.abspath(__file__))
_QC     = os.path.dirname(_HERE)
_HF     = os.path.join(os.path.dirname(_QC), 'HF')
_CLEAN  = os.path.join(_HF, 'clean')
_QUEST  = os.path.join(os.path.dirname(os.path.dirname(_QC)), 'Questionnaire')

os.makedirs(_CLEAN, exist_ok=True)

# ── Questionnaire files (all rounds) ──────────────────────────────────────────
QUEST_FILES = [
    'L2PHL (Project TIPON) - CATI Phase 1 Questionnaire 10Nov2025.xlsx',
    'L2PHL- CATI R1 Trailer Questionnaire 09Dec2025.xlsx',
    'L2PHL (Project TIPON) - CATI R2 Questionnaire 26Nov25.xlsx',
    'L2PHL (Project TIPON) - CATI R3 Questionnaire v5 12Jan2026.xlsx',
    'L2PHL (Project TIPON) - CATI R4 Questionnaire v2 27Jan2026.xlsx',
    'L2PHL (Project TIPON) - CATI R5 Questionnaire v2 20Feb2026.xlsx',
]

# ── Section → module mapping ───────────────────────────────────────────────────
# Each module maps to one or more L2PHL Outline section names
MODULE_SECTIONS = {
    'M00': ['INTRODUCTION'],
    'M01': ['DEMOGRAPHICS'],
    'M02': ['EDUCATION'],
    'M03': ['NATURAL HAZARDS'],        # SH* vars handled separately via Shocks sheet
    'M04': ['EMPLOYMENT'],
    'M05': ['INCOME'],
    'M06': ['FINANCE'],
    'M07': ['HEALTH'],
    'M08': ['FOOD & NON-FOOD'],
    'M09': ['OPINIONS & VIEWS'],
}

# ── ID variables per module (always kept, in this order, before questionnaire vars) ──
MODULE_ID_VARS = {
    'M00': ['hhid', 'round'],
    'M01': ['hhid', 'round', 'fmid'],
    'M02': ['hhid', 'round', 'fmid'],
    'M03': ['hhid', 'round'],
    'M04': ['hhid', 'round', 'fmid', 'isfmid'],
    'M05': ['hhid', 'round', 'fmid'],
    'M06': ['hhid', 'round'],
    'M07': ['hhid', 'round'],
    'M08': ['hhid', 'round'],
    'M09': ['hhid', 'round'],
}

# ── Explicit variable ordering for renamed modules (M00, M01) ─────────────────
# Variable names as they appear in the HF .dta files, in the order they
# correspond to the questionnaire (Introduction / Demographics sections).
M00_ORDERED_VARS = [
    # Call record / contact attempt
    'call_attemp', 'call_status1', 'correct_resp', 'agreement',
    'refusal_reason', 'refusal_reason_oth', 'interview_record',
    # Address / location (Z1-Z5, Z15 from questionnaire)
    'address_unchanged', 'new_address_str',
    'region', 'province', 'city', 'barangay', 'locale',
    # HH size (D4)
    'hhsize',
    # Survey meta (D3, Z6, Z7)
    'survey_lang', 'date_of_interview', 'time_of_interview',
    'start_date', 'end_date', 'start_time', 'end_time',
    # Call result
    'call_result',
    # Respondent info (D2, D22 — FMID comes from id vars)
    'fmid', 'sample',
]

M01_ORDERED_VARS = [
    # Member identity
    'fmid', 'fmidpermanent',
    # Household size
    'hhsize',
    # Core demographics (D8, D9, D6, D24, D14)
    'age', 'gender', 'relationship',
    # Membership changes (D7, D5b)
    'member_leftreason', 'member_leftreason_oth', 'member_leftreason_other',
    'moved_in_reason', 'moved_in_reason_oth',
    # Migration origin/destination
    'country_moved', 'prov_moved', 'city_moved',
    'country_migrated_from', 'province_migrated_from', 'city_migrated_from',
]

# M02: HF file uses ed15/ed16 (renamed from questionnaire ed1-ed14)
M02_ORDERED_VARS = [
    'ed15', 'ed16', 'ed16_oth', 'ed16_1', 'ed16_2',
]

# M08: HF file uses f08_a–f08_e (restructured from fo1-fo7, nf1-nf3, ssb1-ssb3)
M08_ORDERED_VARS = [
    'f08_a', 'f08_b', 'f08_c', 'f08_d', 'f08_e',
]


# ── Parse questionnaire outlines ───────────────────────────────────────────────
def parse_outline(path):
    """
    Extract ordered variable list per section from L2PHL Outline sheet.
    Returns {section_name_upper: [q_number_lower, ...]}
    """
    try:
        df = pd.ExcelFile(path).parse('L2PHL Outline', header=None)
    except Exception as e:
        print(f"  [warn] Could not parse {os.path.basename(path)}: {e}")
        return {}
    sections = {}
    cur_section = None
    for _, row in df.iterrows():
        c1 = str(row.iloc[1]).strip() if pd.notna(row.iloc[1]) else ''
        c2 = str(row.iloc[2]).strip() if pd.notna(row.iloc[2]) else ''
        # Section header: col1 has text, col2 is empty
        if c1 and c1 not in ('nan', '') and c2 in ('nan', ''):
            cur_section = c1.upper()
            if cur_section not in sections:
                sections[cur_section] = []
        # Variable row: col2 has a question number
        elif cur_section and c2 and c2 not in ('nan', ''):
            # Valid question number: starts with letter, ≤10 chars, no spaces, not all alpha-only single letter
            if (re.match(r'^[A-Za-z][A-Za-z0-9_]{0,9}$', c2)
                    and not (len(c2) == 1 and c2.isalpha())):  # skip single letters
                q = c2.lower()
                if q not in sections[cur_section]:
                    sections[cur_section].append(q)
    return sections


def parse_shocks_sheet(path):
    """
    Extract SH* variable names from the 'Shocks' questionnaire sheet.
    Returns ordered list of lowercase q-numbers.
    """
    try:
        xl = pd.ExcelFile(path)
        if 'Shocks' not in xl.sheet_names:
            return []
        df = xl.parse('Shocks', header=None)
    except Exception:
        return []
    vars_ = []
    for _, row in df.iterrows():
        for val in row:
            s = str(val).strip() if pd.notna(val) else ''
            if (re.match(r'^(sh|SH)[A-Z0-9_]{1,8}$', s)
                    or re.match(r'^(sh|SH)\d', s)):
                q = s.lower()
                if q not in vars_:
                    vars_.append(q)
    return vars_


def build_union(module_code):
    """
    Build union of questionnaire variables for a module across all rounds.
    Returns ordered list of lowercase question numbers.
    """
    sections_needed = MODULE_SECTIONS.get(module_code, [])
    union = []

    for fn in QUEST_FILES:
        path = os.path.join(_QUEST, fn)
        if not os.path.exists(path):
            continue
        outline = parse_outline(path)
        for sec in sections_needed:
            for v in outline.get(sec, []):
                if v not in union:
                    union.append(v)
        # M03: also parse Shocks sheet for SH* vars
        if module_code == 'M03':
            for v in parse_shocks_sheet(path):
                if v not in union:
                    union.append(v)

    return union


# ── Match .dta columns to questionnaire vars ──────────────────────────────────
def match_columns(dta_cols, quest_vars, id_vars):
    """
    Given .dta column list and ordered questionnaire variable list:
    - Returns (keep_ordered, dropped) where keep_ordered = id_vars + questionnaire vars
      in questionnaire order, with suffix-expansion vars inserted after parent.
    - A column matches if:
        exact match: lowercase(col) == quest_var
        suffix match: lowercase(col) starts with quest_var + '_'
    """
    dta_lower = {c.lower(): c for c in dta_cols}  # lowercase → original name
    already_id = set(v.lower() for v in id_vars)

    # Build ordered keep list
    keep_ordered = []
    matched_lower = set()

    # 1. ID variables first
    for v in id_vars:
        orig = dta_lower.get(v.lower())
        if orig and orig not in keep_ordered:
            keep_ordered.append(orig)
            matched_lower.add(v.lower())

    # 2. Questionnaire variables in order (with suffix expansions)
    for qv in quest_vars:
        if qv in already_id:
            continue
        # Exact match
        if qv in dta_lower:
            orig = dta_lower[qv]
            if orig not in keep_ordered:
                keep_ordered.append(orig)
                matched_lower.add(qv)
        # Suffix expansions: find all cols that start with qv + '_'
        # Also catch letter-appended variants like h9a, h9b, h9c (no underscore)
        prefix = qv + '_'
        expansions = sorted(
            [c for c_low, c in dta_lower.items()
             if c_low not in matched_lower and (
                 c_low.startswith(prefix)
                 or (c_low.startswith(qv) and len(c_low) > len(qv)
                     and c_low[len(qv)].isalpha()
                     and not c_low[len(qv)].isdigit())
             )],
            key=lambda c: c.lower()
        )
        for exp in expansions:
            if exp not in keep_ordered:
                keep_ordered.append(exp)
                matched_lower.add(exp.lower())

    # What was dropped
    dropped = [c for c in dta_cols if c not in keep_ordered]
    return keep_ordered, dropped


def match_explicit(dta_cols, ordered_vars, id_vars):
    """
    For M00/M01: use explicit ordered variable list.
    Keep: id_vars + any ordered_vars that exist in dta_cols.
    """
    dta_set = set(dta_cols)
    keep_ordered = []
    for v in id_vars:
        if v in dta_set and v not in keep_ordered:
            keep_ordered.append(v)
    for v in ordered_vars:
        if v in dta_set and v not in keep_ordered:
            keep_ordered.append(v)
    dropped = [c for c in dta_cols if c not in keep_ordered]
    return keep_ordered, dropped


# ── Write cleaned .dta ────────────────────────────────────────────────────────
def write_dta(df, out_path, meta=None):
    """Write .dta preserving variable labels if pyreadstat is available."""
    if HAS_PYREADSTAT and meta is not None:
        col_labels = {c: meta.column_names_to_labels.get(c, '')
                      for c in df.columns}
        try:
            pyreadstat.write_dta(df, out_path, column_labels=list(col_labels.values()))
            return
        except Exception as e:
            print(f"  [warn] pyreadstat write failed: {e} — falling back to pandas")
    df.to_stata(out_path, write_index=False, version=117)


# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    log_rows = []

    modules = [
        ('M00', 'l2phl_M00_passport.dta'),
        ('M01', 'l2phl_M01_roster.dta'),
        ('M02', 'l2phl_M02_education.dta'),
        ('M03', 'l2phl_M03_shock.dta'),
        ('M04', 'l2phl_M04_employment.dta'),
        ('M05', 'l2phl_M05_income.dta'),
        ('M06', 'l2phl_M06_finance.dta'),
        ('M07', 'l2phl_M07_health.dta'),
        ('M08', 'l2phl_M08_food_nonfood.dta'),
        ('M09', 'l2phl_M09_views.dta'),
    ]

    for mod_code, fn in modules:
        src = os.path.join(_HF, fn)
        if not os.path.exists(src):
            print(f"  [SKIP] {fn} — not found")
            continue

        print(f"\n  [{mod_code}] Processing {fn} ...")

        # Read with pyreadstat for labels, fallback to pandas
        meta = None
        if HAS_PYREADSTAT:
            try:
                df, meta = pyreadstat.read_dta(src)
            except Exception:
                df = pd.read_stata(src, convert_categoricals=False)
        else:
            df = pd.read_stata(src, convert_categoricals=False)

        id_vars    = MODULE_ID_VARS.get(mod_code, ['hhid', 'round'])
        orig_cols  = list(df.columns)

        if mod_code == 'M00':
            keep, dropped = match_explicit(orig_cols, M00_ORDERED_VARS, id_vars)
        elif mod_code == 'M01':
            keep, dropped = match_explicit(orig_cols, M01_ORDERED_VARS, id_vars)
        elif mod_code == 'M02':
            keep, dropped = match_explicit(orig_cols, M02_ORDERED_VARS, id_vars)
        elif mod_code == 'M08':
            keep, dropped = match_explicit(orig_cols, M08_ORDERED_VARS, id_vars)
        else:
            quest_vars = build_union(mod_code)
            keep, dropped = match_columns(orig_cols, quest_vars, id_vars)

        df_clean = df[keep].copy()
        out_path = os.path.join(_CLEAN, fn)
        write_dta(df_clean, out_path, meta)

        print(f"    kept {len(keep)} vars  |  dropped {len(dropped)} vars")
        if dropped:
            print(f"    dropped: {dropped}")
        print(f"    order:   {keep}")

        # Log
        for c in orig_cols:
            log_rows.append({
                'module':   mod_code,
                'file':     fn,
                'variable': c,
                'action':   'keep' if c in keep else 'drop',
                'position': keep.index(c) + 1 if c in keep else '',
            })

        size_kb = os.path.getsize(out_path) // 1024
        print(f"    written → {out_path} ({size_kb} KB)")

    # Write log
    log_path = os.path.join(_CLEAN, 'cleaning_log.csv')
    with open(log_path, 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=['module','file','variable','action','position'])
        w.writeheader()
        w.writerows(log_rows)
    print(f"\n  [done] Log written → {log_path}")


if __name__ == '__main__':
    if not HAS_PYREADSTAT:
        print("  [info] pyreadstat not available — using pandas for .dta I/O (labels not preserved)")
    main()
