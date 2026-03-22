#!/usr/bin/env python3
"""
build_interviewer.py — Operator performance analysis for L2PHL CATI panel.

Reads:   Analysis/HF/l2phl_M*.dta
Writes:  cache/interviewer_data.json

Metrics per interviewer (int_id):
  1.  Volume          – n_interviews total and per round
  2.  Duration        – mean / median / p10 / p90 / CV;
                        fast (<5 min), very fast (<10 min), slow (>90 min)
  3.  Module durations– z-score vs fleet average per module
  4.  Call attempts   – mean, % needing 3+ calls
  5.  Replacements    – % interview_record == 2
  6.  Skip violations – re-run key checks per HH, join to int_id
  7.  Short-circuit   – % selecting skip-heavy gate values vs fleet average
                        (M03: sh1=2 / M04: a1=2 / M06: f1=2)
  8.  Missing rate    – per module, % missing on key tracking vars
  9.  Attrition       – HHs they interviewed in R_prev that dropped in R_curr
  10. Time flags      – interviews outside 8am–9pm; impossible durations
"""
import os, json, warnings
import pandas as pd
import numpy as np

warnings.filterwarnings('ignore')

_SCRIPTS = os.path.dirname(os.path.abspath(__file__))
_QC      = os.path.dirname(_SCRIPTS)
_HF      = os.path.join(os.path.dirname(_QC), 'HF')
_CACHE   = os.path.join(_QC, 'cache')

ROUNDS = [1, 2, 3, 4, 5]
DUR_FAST   = 5      # minutes — suspiciously short
DUR_VFAST  = 10     # minutes — very fast (flag)
DUR_SLOW   = 90     # minutes — suspiciously long

MODULE_DUR = {
    'dur_pp':   'Passport',
    'dur_rr':   'Roster',
    'dur_educ': 'Education',
    'dur_sh':   'Shocks',
    'dur_emp':  'Employment',
    'dur_inc':  'Income',
    'dur_fin':  'Finance',
    'dur_hlt':  'Health',
    'dur_f_nf': 'FIES',
    'dur_vw':   'Views',
}

# ── Helpers ────────────────────────────────────────────────────────────────────
def load(fname):
    path = os.path.join(_HF, fname)
    if not os.path.exists(path):
        return pd.DataFrame()
    try:
        return pd.read_stata(path, convert_categoricals=False)
    except Exception as e:
        print(f'  [interviewer] Warning: could not load {fname}: {e}')
        return pd.DataFrame()

def pct(n, d):
    return round(n / d * 100, 1) if d > 0 else 0.0

def safe_round(v, n=1):
    try:
        return round(float(v), n) if pd.notna(v) else None
    except Exception:
        return None

def is_filled(series):
    """True where the column has a genuine non-empty value (handles empty strings)."""
    if series.dtype == object:
        return series.notna() & (series.str.strip() != '')
    else:
        return series.notna()

def numeric_cols_only(df, cols):
    """Return only columns from cols that are numeric (int/float), not string."""
    return [c for c in cols if c in df.columns and df[c].dtype not in (object,)]


# ── 1. Load M00 passport ──────────────────────────────────────────────────────
def load_passport():
    m00 = load('l2phl_M00_passport.dta')
    if m00.empty:
        raise RuntimeError('l2phl_M00_passport.dta not found')

    # Only rows with a valid int_id (R2+)
    m00 = m00[m00['int_id'].notna()].copy()
    m00['int_id'] = m00['int_id'].astype(int)

    # Interview hour (local time from start_time)
    if 'start_time' in m00.columns:
        m00['hour'] = pd.to_datetime(m00['start_time'], errors='coerce').dt.hour
    else:
        m00['hour'] = np.nan

    # Total duration in minutes (fallback to computed if dur_tot missing)
    if 'dur_tot' not in m00.columns:
        if 'start_time' in m00.columns and 'end_time' in m00.columns:
            s = pd.to_datetime(m00['start_time'], errors='coerce')
            e = pd.to_datetime(m00['end_time'],   errors='coerce')
            m00['dur_tot'] = (e - s).dt.total_seconds() / 60
        else:
            m00['dur_tot'] = np.nan

    return m00


# ── 2. Duration metrics ────────────────────────────────────────────────────────
def duration_metrics(grp, overall_median):
    d = grp['dur_tot'].dropna()
    n = len(d)
    if n == 0:
        return {'mean': None, 'median': None, 'p10': None, 'p90': None,
                'cv': None, 'n_fast': 0, 'n_vfast': 0, 'n_slow': 0,
                'pct_fast': 0.0, 'pct_vfast': 0.0, 'pct_slow': 0.0,
                'ratio_to_median': None}
    n_fast  = int((d < DUR_FAST).sum())
    n_vfast = int((d < DUR_VFAST).sum())
    n_slow  = int((d > DUR_SLOW).sum())
    mn      = float(d.mean())
    md      = float(d.median())
    return {
        'mean':            safe_round(mn),
        'median':          safe_round(md),
        'p10':             safe_round(d.quantile(0.10)),
        'p90':             safe_round(d.quantile(0.90)),
        'cv':              safe_round(d.std() / mn if mn > 0 else None),
        'n_fast':          n_fast,
        'n_vfast':         n_vfast,
        'n_slow':          n_slow,
        'pct_fast':        pct(n_fast,  n),
        'pct_vfast':       pct(n_vfast, n),
        'pct_slow':        pct(n_slow,  n),
        'ratio_to_median': safe_round(md / overall_median if overall_median else None, 2),
    }


# ── 3. Module duration z-scores ────────────────────────────────────────────────
def module_duration_zscores(grp, fleet_stats):
    """Return {module_key: {mean, z_score}} — z > 2 or < -2 is suspicious."""
    result = {}
    for col, label in MODULE_DUR.items():
        if col not in grp.columns:
            continue
        vals = grp[col].dropna()
        if len(vals) < 3:
            continue
        m = float(vals.mean())
        fleet_m = fleet_stats.get(col, {}).get('mean')
        fleet_s = fleet_stats.get(col, {}).get('std')
        z = None
        if fleet_m is not None and fleet_s and fleet_s > 0:
            z = safe_round((m - fleet_m) / fleet_s, 2)
        result[col] = {'label': label, 'mean': safe_round(m), 'z': z}
    return result


# ── 4. Skip violations per HH ─────────────────────────────────────────────────
def compute_skip_violations(m00):
    """
    Re-run key skip checks per (hhid, round) and join back to int_id.
    Returns a dict: {int_id: {module: count, '_total': count}}
    """
    violations_by_op = {}   # int_id → {module: count}

    id_map = m00.set_index(['hhid','round'])['int_id'].to_dict()

    def add_viols(df, mask_expr, module, label):
        """mask_expr: boolean Series over df rows identifying violations."""
        viol_rows = df[mask_expr][['hhid','round']].drop_duplicates()
        for _, row in viol_rows.iterrows():
            iid = id_map.get((row['hhid'], row['round']))
            if iid is None:
                continue
            iid = int(iid)
            if iid not in violations_by_op:
                violations_by_op[iid] = {}
            violations_by_op[iid][module] = violations_by_op[iid].get(module, 0) + 1

    # ── M02 Education: ED15=1 (still in school) but ED16 filled ──────────────
    try:
        m02 = load('l2phl_M02_education.dta')
        if not m02.empty and 'ed15' in m02.columns:
            # Only check numeric ed16 column (not ed16_oth/_1/_2 which can be empty str)
            ed16_num = numeric_cols_only(m02, ['ed16'])
            if ed16_num:
                mask = (pd.to_numeric(m02['ed15'], errors='coerce') == 1) & \
                       m02[ed16_num].notna().any(axis=1)
                add_viols(m02, mask, 'M02', 'ED15=1 but ED16 filled')
    except Exception as e:
        print(f'  [interviewer] M02 skip check failed: {e}')

    # ── M03 Shocks: SH1=2 (no shock) but SH1b filled ─────────────────────────
    try:
        m03 = load('l2phl_M03_shock.dta')
        if not m03.empty and 'sh1' in m03.columns:
            sh1b_cols = numeric_cols_only(m03,
                [c for c in m03.columns if c.startswith('sh1b') or c.startswith('sh1_')])
            if sh1b_cols:
                mask = (pd.to_numeric(m03['sh1'], errors='coerce') == 2) & \
                       m03[sh1b_cols].notna().any(axis=1)
                add_viols(m03, mask, 'M03', 'SH1=2 but SH1b filled')
    except Exception as e:
        print(f'  [interviewer] M03 skip check failed: {e}')

    # ── M03 Shocks: SH3=2 (no water disruption) but SH4 filled ───────────────
    try:
        if not m03.empty and 'sh3' in m03.columns and 'sh4' in m03.columns:
            mask = (pd.to_numeric(m03['sh3'], errors='coerce') == 2) & m03['sh4'].notna()
            add_viols(m03, mask, 'M03', 'SH3=2 but SH4 filled')
    except Exception:
        pass

    # ── M04 Employment: A1=2 (not working) but A10/A11 filled ────────────────
    try:
        m04 = load('l2phl_M04_employment.dta')
        if not m04.empty and 'a1' in m04.columns:
            check_cols = numeric_cols_only(m04, ['a10', 'a11'])
            if check_cols:
                mask = (pd.to_numeric(m04['a1'], errors='coerce') == 2) & \
                       m04[check_cols].notna().any(axis=1)
                add_viols(m04, mask, 'M04', 'A1=2 but A10/A11 filled')
    except Exception as e:
        print(f'  [interviewer] M04 skip check failed: {e}')

    # ── M04: A8=2/99 but A9 filled ───────────────────────────────────────────
    try:
        if not m04.empty and 'a8' in m04.columns and 'a9' in m04.columns:
            a8n = pd.to_numeric(m04['a8'], errors='coerce')
            mask = a8n.isin([2, 99]) & m04['a9'].notna()
            add_viols(m04, mask, 'M04', 'A8=2/99 but A9 filled')
    except Exception:
        pass

    # ── M04: A16=3/99 but A17 filled ─────────────────────────────────────────
    try:
        if not m04.empty and 'a16' in m04.columns and 'a17' in m04.columns:
            a16n = pd.to_numeric(m04['a16'], errors='coerce')
            mask = a16n.isin([3, 99]) & m04['a17'].notna()
            add_viols(m04, mask, 'M04', 'A16=3/99 but A17 filled')
    except Exception:
        pass

    # ── M06 Finance: F7=2 (no savings) but F8 filled ─────────────────────────
    try:
        m06 = load('l2phl_M06_finance.dta')
        if not m06.empty and 'f7' in m06.columns and 'f8' in m06.columns:
            f8_num = numeric_cols_only(m06, ['f8'])
            if f8_num:
                mask = (pd.to_numeric(m06['f7'], errors='coerce') == 2) & \
                       m06[f8_num].notna().any(axis=1)
                add_viols(m06, mask, 'M06', 'F7=2 but F8 filled')
    except Exception as e:
        print(f'  [interviewer] M06 skip check failed: {e}')

    # ── M06 Finance: F9=2 (no loan) but F10 filled ───────────────────────────
    try:
        if not m06.empty and 'f9' in m06.columns and 'f10' in m06.columns:
            f10_num = numeric_cols_only(m06, ['f10'])
            if f10_num:
                mask = (pd.to_numeric(m06['f9'], errors='coerce') == 2) & \
                       m06[f10_num].notna().any(axis=1)
                add_viols(m06, mask, 'M06', 'F9=2 but F10 filled')
    except Exception:
        pass

    # Add totals
    for iid in violations_by_op:
        violations_by_op[iid]['_total'] = sum(
            v for k, v in violations_by_op[iid].items() if not k.startswith('_'))

    return violations_by_op


# ── 5. Short-circuit gate rates ────────────────────────────────────────────────
def compute_shortcircuit(m00):
    """
    For each skip-heavy gate, compute the % of a given operator's interviews
    where the 'skip' option was selected, vs. the fleet average.
    High rates → possible shortcutting.
    Gates: M03.sh1=2, M04.a1=2, M06.f1=2
    Returns: {int_id: {'sh1_skip_pct': x, 'a1_skip_pct': y, 'f1_skip_pct': z}}
    and fleet: {'sh1_skip_pct': x, 'a1_skip_pct': y, 'f1_skip_pct': z}
    """
    id_map = m00.set_index(['hhid','round'])['int_id'].to_dict()
    results = {}   # int_id → {gate_key: {n_skip, n_total, pct}}

    def tabulate_gate(df, gate_col, skip_vals, key):
        if df.empty or gate_col not in df.columns:
            return
        # Aggregate to HH level (take mode or first)
        agg = df.groupby(['hhid','round'])[gate_col].first().reset_index()
        for _, row in agg.iterrows():
            iid = id_map.get((row['hhid'], row['round']))
            if iid is None:
                continue
            iid = int(iid)
            if iid not in results:
                results[iid] = {}
            if key not in results[iid]:
                results[iid][key] = {'n_skip': 0, 'n_total': 0}
            val = row[gate_col]
            if pd.notna(val):
                results[iid][key]['n_total'] += 1
                if float(val) in [float(v) for v in skip_vals]:
                    results[iid][key]['n_skip'] += 1

    try:
        m03 = load('l2phl_M03_shock.dta')
        tabulate_gate(m03, 'sh1', [2], 'sh1_skip')
    except Exception:
        pass
    try:
        m04 = load('l2phl_M04_employment.dta')
        # a1 is individual-level; aggregate: did the HH have ANY employed member?
        # For shortcutting we look at the operator's fraction where a1=2 for ALL members
        tabulate_gate(m04, 'a1', [2], 'a1_skip')
    except Exception:
        pass
    try:
        m06 = load('l2phl_M06_finance.dta')
        tabulate_gate(m06, 'f1', [2], 'f1_skip')
    except Exception:
        pass

    # Add pct and compute fleet totals
    fleet = {}
    fleet_n = {}
    for iid, gates in results.items():
        for key, d in gates.items():
            d['pct'] = pct(d['n_skip'], d['n_total'])
            if key not in fleet:
                fleet[key] = 0; fleet_n[key] = 0
            fleet[key] += d['n_skip']
            fleet_n[key] += d['n_total']

    fleet_pct = {k: pct(fleet[k], fleet_n[k]) for k in fleet}
    return results, fleet_pct


# ── 6. Missing rate per operator ──────────────────────────────────────────────
def compute_missing(m00):
    """
    For each module's key tracking variables, compute missing rate per operator.
    Returns {int_id: {module: pct_missing}}
    """
    id_map = m00.set_index(['hhid','round'])['int_id'].to_dict()
    missing_by_op = {}   # int_id → {module: [n_miss, n_total]}

    KEY_VARS = {
        # Only check vars that MUST be filled for every eligible row.
        # M04.a1 omitted — legitimately missing for children (age<15, not asked)
        # M01.relationship omitted — only filled for non-head roster members
        'M01': ['gender', 'age'],
        'M03': ['sh1'],
        'M06': ['f1'],
    }
    MODULE_FILES = {
        'M01': 'l2phl_M01_roster.dta',
        'M03': 'l2phl_M03_shock.dta',
        'M06': 'l2phl_M06_finance.dta',
    }

    for mod, fname in MODULE_FILES.items():
        try:
            df = load(fname)
            if df.empty:
                continue
            vars_ = [v for v in KEY_VARS.get(mod, []) if v in df.columns]
            if not vars_:
                continue

            # Build "truly missing" mask: NaN or empty string
            def truly_missing(series):
                if series.dtype == object:
                    return series.isna() | (series.str.strip() == '')
                return series.isna()

            # HH-level aggregation: count any missing key var per (hhid, round)
            miss_mask = df[vars_].apply(truly_missing)
            df = df.copy()
            df['_any_miss'] = miss_mask.any(axis=1)
            agg = df.groupby(['hhid','round'])['_any_miss'].sum().reset_index()
            agg.columns = ['hhid','round','n_miss']
            agg['n_rows'] = df.groupby(['hhid','round']).size().values
            for _, row in agg.iterrows():
                iid = id_map.get((row['hhid'], row['round']))
                if iid is None:
                    continue
                iid = int(iid)
                if iid not in missing_by_op:
                    missing_by_op[iid] = {}
                if mod not in missing_by_op[iid]:
                    missing_by_op[iid][mod] = [0, 0]
                missing_by_op[iid][mod][0] += int(row['n_miss'])
                missing_by_op[iid][mod][1] += int(row['n_rows'])
        except Exception as e:
            print(f'  [interviewer] Missing check {mod} failed: {e}')

    # Convert to pct
    result = {}
    for iid, mods in missing_by_op.items():
        result[iid] = {}
        total_miss = 0; total_rows = 0
        for mod, (n_miss, n_rows) in mods.items():
            result[iid][mod] = pct(n_miss, n_rows)
            total_miss += n_miss; total_rows += n_rows
        result[iid]['_overall'] = pct(total_miss, total_rows)
    return result


# ── 7. Attrition attributable to operator ─────────────────────────────────────
def compute_attrition(m00):
    """
    For each (R_prev → R_curr) transition, find HHs that dropped.
    Attribute to the operator who interviewed them in R_prev.
    Returns {int_id: {transition: {n_dropped, n_total, pct}}}
    """
    hh_rounds = m00.groupby(['hhid'])['round'].apply(set).to_dict()
    int_by_hhround = m00.set_index(['hhid','round'])['int_id'].to_dict()

    result = {}   # int_id → {'overall': [n_drop, n_total], per transition...}

    for i, r_prev in enumerate(ROUNDS[:-1]):
        r_curr = ROUNDS[i + 1]
        key = f'R{r_prev}→R{r_curr}'
        # HHs present in R_prev
        prev_hhs = m00[m00['round'] == r_prev]['hhid'].unique()
        curr_hhs = set(m00[m00['round'] == r_curr]['hhid'].unique())
        for hh in prev_hhs:
            iid = int_by_hhround.get((hh, r_prev))
            if iid is None:
                continue
            iid = int(iid)
            if iid not in result:
                result[iid] = {'_overall': [0, 0]}
            if key not in result[iid]:
                result[iid][key] = [0, 0]
            result[iid][key][1] += 1
            result[iid]['_overall'][1] += 1
            if hh not in curr_hhs:
                result[iid][key][0] += 1
                result[iid]['_overall'][0] += 1

    # Convert to pct
    out = {}
    for iid, data in result.items():
        out[iid] = {}
        for key, (n_drop, n_total) in data.items():
            out[iid][key] = {'n_dropped': n_drop, 'n_total': n_total,
                             'pct': pct(n_drop, n_total)}
    return out


# ── 8. Time flags ──────────────────────────────────────────────────────────────
def compute_time_flags(grp):
    """Return count of interviews outside 8am–9pm and near-zero duration."""
    flags = {}
    if 'hour' in grp.columns:
        h = grp['hour'].dropna()
        flags['n_late_night']  = int(((h >= 22) | (h < 6)).sum())   # 10pm–6am
        flags['n_evening']     = int(((h >= 19) & (h < 22)).sum())  # 7pm–10pm (OK but note)
        flags['n_early_morn']  = int(((h >= 6)  & (h < 8)).sum())   # 6am–8am
    else:
        flags['n_late_night'] = 0; flags['n_evening'] = 0; flags['n_early_morn'] = 0
    return flags


# ── 9. RAG scoring ────────────────────────────────────────────────────────────
def rag_score(op, fleet_median_dur, fleet_shortcircuit, fleet_missing_median=0):
    """
    Return 'red', 'amber', or 'green' + list of flag strings.
    """
    flags = []
    score = 0   # higher = worse

    dur = op.get('duration', {})
    # Duration flags
    ratio = dur.get('ratio_to_median')
    if ratio is not None:
        if ratio < 0.60:
            flags.append(f'Very short surveys (median {ratio:.0%} of fleet median)')
            score += 3
        elif ratio < 0.75:
            flags.append(f'Short surveys (median {ratio:.0%} of fleet median)')
            score += 1
    pct_fast = dur.get('pct_fast', 0)
    if pct_fast > 10:
        flags.append(f'{pct_fast:.1f}% interviews < {DUR_FAST} min (speeders)')
        score += 3
    elif pct_fast > 5:
        flags.append(f'{pct_fast:.1f}% interviews < {DUR_FAST} min')
        score += 1

    # Skip violations
    skip_tot = (op.get('skip_violations') or {}).get('_total', 0)
    if skip_tot > 10:
        flags.append(f'{skip_tot} skip violations')
        score += 3
    elif skip_tot > 3:
        flags.append(f'{skip_tot} skip violations')
        score += 1

    # Replacements
    rep = op.get('replacements', {})
    pct_rep = rep.get('pct', 0)
    if pct_rep > 10:
        flags.append(f'{pct_rep:.1f}% replacement interviews')
        score += 2
    elif pct_rep > 5:
        flags.append(f'{pct_rep:.1f}% replacement interviews')
        score += 1

    # Short-circuit rates
    sc = op.get('shortcircuit', {})
    for gate_key, label in [('sh1_skip','M03 no-shock rate'),
                             ('a1_skip', 'M04 not-employed rate'),
                             ('f1_skip', 'M06 no-account rate')]:
        op_pct  = (sc.get(gate_key) or {}).get('pct')
        flt_pct = fleet_shortcircuit.get(gate_key)
        if op_pct is not None and flt_pct is not None and flt_pct > 0:
            ratio_sc = op_pct / flt_pct
            if ratio_sc > 1.4 and op_pct > 70:
                flags.append(f'High {label}: {op_pct:.0f}% (fleet avg {flt_pct:.0f}%)')
                score += 2
            elif ratio_sc > 1.25 and op_pct > 60:
                flags.append(f'Elevated {label}: {op_pct:.0f}% (fleet avg {flt_pct:.0f}%)')
                score += 1

    # Attrition — only flag if operator handled >= 10 HH transitions
    attr = (op.get('attrition') or {}).get('_overall', {})
    attr_pct  = attr.get('pct', 0)
    attr_n    = attr.get('n_total', 0)
    if attr_n >= 10:
        if attr_pct > 20:
            flags.append(f'{attr_pct:.1f}% attrition rate ({attr_n} HH transitions handled)')
            score += 2
        elif attr_pct > 12:
            flags.append(f'{attr_pct:.1f}% attrition rate ({attr_n} HH transitions)')
            score += 1

    # Time flags
    tf = op.get('time_flags', {})
    if tf.get('n_late_night', 0) > 3:
        flags.append(f"{tf['n_late_night']} interviews after 10pm or before 6am")
        score += 1

    # Missing rate — flag only if significantly above fleet median
    n_int = op.get('n_interviews', 0)
    miss_pct = (op.get('missing_rate') or {}).get('_overall', 0)
    miss_excess = miss_pct - fleet_missing_median
    if n_int >= 5 and fleet_missing_median >= 0:
        if miss_excess > 15:
            flags.append(f'Missing rate {miss_pct:.1f}% (fleet median {fleet_missing_median:.1f}%, +{miss_excess:.1f}pp above)')
            score += 2
        elif miss_excess > 8:
            flags.append(f'Missing rate {miss_pct:.1f}% vs fleet median {fleet_missing_median:.1f}%')
            score += 1

    if score >= 4:
        return 'red', flags
    elif score >= 2:
        return 'amber', flags
    else:
        return 'green', flags


# ── MAIN ──────────────────────────────────────────────────────────────────────
def main():
    print('  [interviewer] Loading passport data...')
    m00 = load_passport()

    overall_median_dur = float(m00['dur_tot'].dropna().median()) if 'dur_tot' in m00.columns else 30.0

    # Fleet-level module duration stats
    fleet_stats = {}
    for col in MODULE_DUR:
        if col in m00.columns:
            v = m00[col].dropna()
            fleet_stats[col] = {
                'mean': float(v.mean()) if len(v) > 0 else None,
                'std':  float(v.std())  if len(v) > 1 else None,
            }

    print('  [interviewer] Computing skip violations...')
    skip_viols = compute_skip_violations(m00)

    print('  [interviewer] Computing short-circuit rates...')
    shortcircuit, fleet_sc = compute_shortcircuit(m00)

    print('  [interviewer] Computing missing rates...')
    missing = compute_missing(m00)

    print('  [interviewer] Computing attrition...')
    attrition = compute_attrition(m00)

    # Compute fleet-level missing median (for relative comparison)
    _miss_vals = [
        missing.get(int(iid), {}).get('_overall', 0)
        for iid in m00['int_id'].unique()
        if missing.get(int(iid))
    ]
    import statistics as _stats
    fleet_missing_median = round(_stats.median(_miss_vals), 1) if _miss_vals else 0.0

    print('  [interviewer] Building per-operator profiles...')
    operators = []
    for iid, grp in m00.groupby('int_id'):
        iid = int(iid)
        n = len(grp)

        # Rounds worked in
        rounds_worked = sorted(grp['round'].unique().tolist())
        n_per_round = {str(int(r)): int((grp['round'] == r).sum())
                       for r in rounds_worked}

        # Duration
        dur = duration_metrics(grp, overall_median_dur)

        # Module durations
        mod_dur = module_duration_zscores(grp, fleet_stats)

        # Call attempts
        ca = grp['call_attemp'].dropna() if 'call_attemp' in grp.columns else pd.Series(dtype=float)
        call_attempts = {
            'mean':       safe_round(float(ca.mean())) if len(ca) > 0 else None,
            'pct_3plus':  pct(int((ca >= 3).sum()), len(ca)),
        }

        # Replacements
        if 'interview_record' in grp.columns:
            n_rep = int((grp['interview_record'] == 2).sum())
        else:
            n_rep = 0
        replacements = {'n': n_rep, 'pct': pct(n_rep, n)}

        # Time flags
        tf = compute_time_flags(grp)

        op = {
            'int_id':        iid,
            'n_interviews':  n,
            'rounds':        rounds_worked,
            'n_per_round':   n_per_round,
            'duration':      dur,
            'module_dur':    mod_dur,
            'call_attempts': call_attempts,
            'replacements':  replacements,
            'skip_violations': skip_viols.get(iid, {'_total': 0}),
            'shortcircuit':  shortcircuit.get(iid, {}),
            'missing_rate':  missing.get(iid, {'_overall': 0.0}),
            'attrition':     attrition.get(iid, {'_overall': {'n_dropped':0,'n_total':0,'pct':0.0}}),
            'time_flags':    tf,
        }

        rag, flags = rag_score(op, overall_median_dur, fleet_sc, fleet_missing_median)
        op['rag']   = rag
        op['flags'] = flags
        operators.append(op)

    # Sort: red first, then amber, then green; within each, by n_interviews desc
    rag_order = {'red': 0, 'amber': 1, 'green': 2}
    operators.sort(key=lambda o: (rag_order.get(o['rag'], 3), -o['n_interviews']))

    # Fleet summary
    fleet_summary = {
        'n_operators':       len(operators),
        'median_dur':        safe_round(overall_median_dur),
        'fleet_shortcircuit': fleet_sc,
        'n_red':   sum(1 for o in operators if o['rag'] == 'red'),
        'n_amber': sum(1 for o in operators if o['rag'] == 'amber'),
        'n_green': sum(1 for o in operators if o['rag'] == 'green'),
    }

    output = {'fleet': fleet_summary, 'operators': operators}
    out_path = os.path.join(_CACHE, 'interviewer_data.json')
    with open(out_path, 'w') as f:
        json.dump(output, f, separators=(',', ':'))

    print(f'  [interviewer] Written -> {out_path}')
    n_red   = fleet_summary['n_red']
    n_amber = fleet_summary['n_amber']
    n_green = fleet_summary['n_green']
    print(f'  [interviewer] {len(operators)} operators: {n_red} red / {n_amber} amber / {n_green} green')


if __name__ == '__main__':
    main()
