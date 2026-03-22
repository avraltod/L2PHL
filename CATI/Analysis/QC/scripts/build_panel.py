#!/usr/bin/env python3
"""
build_panel.py — Panel tracking analysis for L2PHL CATI survey
Generates cache/panel_data.json used by the Panel tab in the QC dashboard.

Tracks:
  - Per-household participation across rounds (panel matrix)
  - Attrition / new entry per round relative to R1 baseline
  - Attrition profile: urban/rural & region composition of stayers vs leavers vs new
  - PSU coverage vs targets (urban=6 HH/PSU, rural=7 HH/PSU) — problem PSU list
  - HH counts by region x urban x round
  - Participation pattern distribution
  - Call intervals: days between consecutive interviews per HH, flag < 20 days
"""
import os as _os
_HERE  = _os.path.dirname(_os.path.abspath(__file__))
_QC    = _os.path.dirname(_HERE)
_CACHE = _os.path.join(_QC, 'cache')
_HF    = _os.path.join(_os.path.dirname(_QC), 'HF')

import json, sys
import pandas as pd
import numpy as np

ROUNDS = [1, 2, 3, 4, 5]
URBAN_TARGET  = 6   # HH per urban PSU
RURAL_TARGET  = 7   # HH per rural PSU

REGION_NAMES = {
    1:  'Region I',    2:  'Region II',   3:  'Region III',
    4:  'Region IV-A', 5:  'Region V',    6:  'Region VI',
    7:  'Region VII',  8:  'Region VIII', 9:  'Region IX',
    10: 'Region X',    11: 'Region XI',   12: 'Region XII',
    13: 'NCR',         14: 'CAR',         16: 'Region XIII',
    17: 'MIMAROPA',    18: 'NIR',         19: 'BARMM',
}

def load_data():
    pp = pd.read_stata(
        _os.path.join(_HF, 'l2phl_M00_passport.dta'),
        convert_categoricals=False
    )
    # Deduplicate (one row per HH per round)
    pp = pp.drop_duplicates(subset=['round','hhid'])
    pp['round'] = pp['round'].fillna(0).astype(int)
    pp = pp[pp['round'].isin(ROUNDS)].copy()

    # Derive region code from first 2 chars of PSU string
    pp['region'] = pp['psu'].astype(str).str[:2].astype(int)

    # Combine date fields: R1 uses start_date; R2-R5 use date_of_interview
    pp['int_date'] = pp['start_date'].combine_first(pp['date_of_interview'])

    # Core HH-per-round frame
    hh = pp[['round','hhid','urban','stratum','psu','region','int_date']].copy()

    # Stable HH metadata (first observed round)
    meta = (hh.sort_values('round')
              .groupby('hhid')
              .first()
              .reset_index()[['hhid','region','urban','stratum','psu']])
    return hh, meta


def build_panel_matrix(hh, meta):
    """Return pivot: hhid x round (1/0) + metadata."""
    pivot = (hh.groupby(['hhid','round']).size()
               .unstack(fill_value=0)
               .clip(upper=1)
               .reindex(columns=ROUNDS, fill_value=0))
    pivot.columns = [int(c) for c in pivot.columns]
    pivot['rounds_present'] = pivot[ROUNDS].sum(axis=1)
    pivot['pattern'] = pivot[ROUNDS].apply(
        lambda r: ''.join(str(int(v)) for v in r), axis=1)
    pivot = pivot.reset_index().merge(meta, on='hhid', how='left')
    return pivot


def build_attrition(pivot):
    """Retention / new-entry per round vs R1 baseline."""
    base = set(pivot[pivot[1]==1]['hhid'])
    rows = []
    for rnd in ROUNDS:
        present = set(pivot[pivot[rnd]==1]['hhid'])
        rows.append({
            'round':    rnd,
            'n':        len(present),
            'retained': len(base & present),
            'dropped':  len(base - present),
            'new_in':   len(present - base),
        })
    return rows


def build_attrition_profile(pivot):
    """
    Per round-transition (R1->R2, R2->R3, ...), the urban/rural & region
    composition of three groups:
      - retained : present in both prev and curr round
      - dropped  : present in prev, absent in curr
      - new_in   : absent in prev, present in curr
    Returns a list of dicts, one per transition.
    """
    def profile(hh_set):
        if not hh_set:
            return {'n': 0, 'n_urban': 0, 'n_rural': 0, 'by_region': {}}
        sub = pivot[pivot['hhid'].isin(hh_set)].copy()
        n   = len(sub)
        n_u = int((sub['urban'] == 1.0).sum())
        n_r = int((sub['urban'] == 2.0).sum())
        by_reg = {}
        for reg, grp in sub.groupby('region'):
            try:
                reg_key = int(reg)
            except Exception:
                reg_key = 0
            by_reg[str(reg_key)] = {
                'n':       int(len(grp)),
                'n_urban': int((grp['urban'] == 1.0).sum()),
                'n_rural': int((grp['urban'] == 2.0).sum()),
                'name':    REGION_NAMES.get(reg_key, f'Region {reg_key}'),
            }
        return {'n': n, 'n_urban': n_u, 'n_rural': n_r, 'by_region': by_reg}

    transitions = []
    for i in range(1, len(ROUNDS)):
        prev_r = ROUNDS[i - 1]
        curr_r = ROUNDS[i]

        prev_set = set(pivot[pivot[prev_r] == 1]['hhid'])
        curr_set = set(pivot[pivot[curr_r] == 1]['hhid'])

        retained_hh = prev_set & curr_set
        dropped_hh  = prev_set - curr_set
        new_hh      = curr_set - prev_set

        transitions.append({
            'from_round': prev_r,
            'to_round':   curr_r,
            'label':      f'R{prev_r}\u2192R{curr_r}',
            'retained':   profile(retained_hh),
            'dropped':    profile(dropped_hh),
            'new_in':     profile(new_hh),
        })
    return transitions


def build_psu_coverage(hh, meta):
    """Per-PSU per-round HH count vs target."""
    psu_info = meta.groupby('psu').agg(
        urban=('urban','first'),
        region=('region','first'),
        stratum=('stratum','first')
    ).reset_index()

    rows = []
    for rnd in ROUNDS:
        rnd_data = (hh[hh['round']==rnd][['hhid']]
                    .merge(meta[['hhid','psu']], on='hhid', how='left'))
        counts = (rnd_data.groupby('psu')['hhid'].count()
                          .reset_index()
                          .rename(columns={'hhid':'count'}))
        counts['round'] = rnd
        rows.append(counts)

    # Include all known PSUs even if they appear in 0 HHs some round
    all_psus = psu_info[['psu']].copy()
    expanded = []
    for i, rnd_df in enumerate(rows):
        rnd_val = ROUNDS[i]
        merged = all_psus.merge(rnd_df, on='psu', how='left')
        merged['count'] = merged['count'].fillna(0).astype(int)
        merged['round'] = rnd_val
        expanded.append(merged)

    psu_long = pd.concat(expanded).merge(psu_info, on='psu', how='left')
    psu_long['target'] = psu_long['urban'].apply(
        lambda u: URBAN_TARGET if u == 1.0 else RURAL_TARGET)
    psu_long['diff']   = psu_long['count'] - psu_long['target']
    psu_long['status'] = psu_long['diff'].apply(
        lambda x: 'on_target' if x == 0 else ('over' if x > 0 else 'under'))
    return psu_long


def build_psu_problem_list(psu_long):
    """
    List of PSUs that are under-target in at least one round.
    Sorted by most rounds under target (worst first).
    """
    under_psus = set(psu_long[psu_long['status']=='under']['psu'])
    result = []
    for psu_id, grp in psu_long[psu_long['psu'].isin(under_psus)].groupby('psu'):
        grp = grp.sort_values('round')
        urban_val  = grp['urban'].iloc[0]
        region_val = grp['region'].iloc[0]
        target     = int(grp['target'].iloc[0])
        counts     = {str(int(row['round'])): int(row['count'])
                      for _, row in grp.iterrows()}
        n_under    = int((grp['status'] == 'under').sum())
        n_zero     = int((grp['count'] == 0).sum())
        r1_row     = grp[grp['round']==1]
        r1_count   = int(r1_row['count'].iloc[0]) if len(r1_row) else 0

        try:
            reg_int = int(region_val) if pd.notna(region_val) else 0
            reg_name = REGION_NAMES.get(reg_int, f'Region {reg_int}')
        except Exception:
            reg_int  = 0
            reg_name = '?'

        result.append({
            'psu':         str(psu_id),
            'urban':       int(urban_val) if pd.notna(urban_val) else None,
            'urban_label': 'Urban' if urban_val == 1.0 else 'Rural',
            'region':      reg_int,
            'region_name': reg_name,
            'target':      target,
            'r1_count':    r1_count,
            'counts':      counts,
            'n_under':     n_under,
            'n_zero':      n_zero,
        })

    result.sort(key=lambda x: (-x['n_under'], -x['n_zero']))
    return result


def build_region_summary(hh, meta):
    """HH count by region x urban x round."""
    rows = []
    for rnd in ROUNDS:
        r = (hh[hh['round']==rnd][['hhid']]
             .merge(meta[['hhid','region','urban']], on='hhid', how='left'))
        s = (r.groupby(['region','urban'])['hhid'].count()
              .reset_index().rename(columns={'hhid':'count'}))
        s['round'] = rnd
        rows.append(s)
    df = pd.concat(rows)
    df['region_name'] = df['region'].map(REGION_NAMES).fillna(df['region'].astype(str))
    df['urban_label'] = df['urban'].map({1.0:'Urban', 2.0:'Rural'}).fillna('Unknown')
    return df


def build_psu_status_summary(psu_long):
    """Per-round count of PSUs: on_target / over / under."""
    return (psu_long.groupby(['round','status'])['psu']
                    .count().unstack(fill_value=0)
                    .reindex(columns=['on_target','over','under'], fill_value=0)
                    .reset_index()
                    .to_dict(orient='records'))


def _chi2_cramer(obs):
    """Chi-squared stat and Cramer's V from contingency table (numpy only)."""
    obs = np.array(obs, dtype=float)
    row_sums = obs.sum(axis=1, keepdims=True)
    col_sums = obs.sum(axis=0, keepdims=True)
    total    = obs.sum()
    expected = row_sums * col_sums / total
    with np.errstate(divide='ignore', invalid='ignore'):
        chi2 = float(np.nansum((obs - expected)**2 / expected))
    k = min(obs.shape) - 1
    v = float(np.sqrt(chi2 / (total * k))) if total * k > 0 else 0.0
    dof = (obs.shape[0]-1) * (obs.shape[1]-1)
    # Wilson-Hilferty chi2 approximation to normal for p-value
    if dof > 0 and chi2 > 0:
        z = ((chi2/dof)**(1/3) - (1 - 2/(9*dof))) / np.sqrt(2/(9*dof))
        # standard normal survival (Abramowitz approximation)
        az = abs(z)
        t_ = 1/(1 + 0.2316419*az)
        poly = t_*(0.319381530 + t_*(-0.356563782 + t_*(1.781477937
               + t_*(-1.821255978 + t_*1.330274429))))
        p = (1/np.sqrt(2*np.pi))*np.exp(-az**2/2)*poly
        p = float(np.clip(p, 0, 0.5))  # one-tail; chi2 uses upper tail
    else:
        p = 1.0
    return chi2, v, p, dof


def _ttest_2samp(a, b):
    """Welch t-test (numpy only). Returns t, p, mean_a, mean_b."""
    a = np.asarray(a, dtype=float)
    b = np.asarray(b, dtype=float)
    a = a[~np.isnan(a)]
    b = b[~np.isnan(b)]
    na, nb = len(a), len(b)
    if na < 2 or nb < 2:
        return 0.0, 1.0, float(np.nanmean(a)), float(np.nanmean(b))
    va, vb = float(np.var(a, ddof=1)), float(np.var(b, ddof=1))
    se = np.sqrt(va/na + vb/nb)
    t  = (a.mean() - b.mean()) / se if se > 0 else 0.0
    dof = (va/na + vb/nb)**2 / ((va/na)**2/(na-1) + (vb/nb)**2/(nb-1))
    # Approximate p via WH
    x = abs(t)
    t_ = 1/(1 + 0.2316419*x)
    poly = t_*(0.319381530 + t_*(-0.356563782 + t_*(1.781477937
           + t_*(-1.821255978 + t_*1.330274429))))
    p = 2*(1/np.sqrt(2*np.pi))*np.exp(-x**2/2)*poly   # two-tailed
    p = float(np.clip(p, 0, 1.0))
    return float(t), p, float(a.mean()), float(b.mean())


def _sig_label(p):
    if p < 0.001: return '***'
    if p < 0.01:  return '**'
    if p < 0.05:  return '*'
    if p < 0.10:  return '†'
    return 'ns'


def load_aux_characteristics():
    """
    Load per-HH-round characteristics from M04 (employment) and M06 (finance)
    that are not in the passport file.
    Returns a df indexed by (hhid, round).
    """
    aux_frames = []

    # M04: respondent (isfmid==1) employment status — available R3+ only
    try:
        m04 = pd.read_stata(_os.path.join(_HF, 'l2phl_M04_employment.dta'),
                            convert_categoricals=False)
        resp = (m04[m04['isfmid']==1]
                .drop_duplicates(subset=['hhid','round'])
                [['hhid','round','emp_status']])
        resp['employed'] = (resp['emp_status']==1).astype(float)
        # Only trust rounds where emp_status actually has data (R1/R2 are all-zero)
        valid_rounds = resp.groupby('round')['employed'].sum()
        valid_rounds = valid_rounds[valid_rounds > 0].index.tolist()
        resp = resp[resp['round'].isin(valid_rounds)][['hhid','round','employed']]
        aux_frames.append(resp)
    except Exception as e:
        print(f"  [panel] Warning: could not load M04: {e}")

    # M06: has bank/savings account (f1==1) — one row per HH per round
    try:
        m06 = pd.read_stata(_os.path.join(_HF, 'l2phl_M06_finance.dta'),
                            convert_categoricals=False)
        fin = (m06.drop_duplicates(subset=['hhid','round'])
               [['hhid','round','f1','f2']])
        fin['has_account'] = (fin['f1']==1).astype(float)
        fin['has_savings']  = (fin['f2']==1).astype(float)
        aux_frames.append(fin[['hhid','round','has_account','has_savings']])
    except Exception as e:
        print(f"  [panel] Warning: could not load M06: {e}")

    if not aux_frames:
        return pd.DataFrame(columns=['hhid','round'])

    from functools import reduce
    merged = reduce(lambda a, b: pd.merge(a, b, on=['hhid','round'], how='outer'),
                    aux_frames)
    return merged


def build_leaver_vs_new(hh, meta, aux):
    """
    Per-transition comparison: households that LEFT (prev round, not curr round)
    vs households that ENTERED (not in prev round, in curr round).
    Uses characteristics from the round when each group was observed:
    - Leavers: characteristics from PREVIOUS round
    - New entries: characteristics from CURRENT round
    Returns list of per-transition dicts.
    """
    # Build HH-round characteristics: merge hh with aux and passport-level vars
    pp = pd.read_stata(
        _os.path.join(_HF, 'l2phl_M00_passport.dta'),
        convert_categoricals=False
    )
    pp = pp.drop_duplicates(subset=['hhid','round'])
    pp['region'] = pp['psu'].astype(str).str[:2].astype(int)
    # gender is in M01 roster (HH head = fmid==1), not M00 — merge it in
    if 'gender' not in pp.columns:
        try:
            _m01 = pd.read_stata(_os.path.join(_HF, 'l2phl_M01_roster.dta'),
                                 convert_categoricals=False)
            _head = (_m01[_m01['fmid']==1][['hhid','round','gender']]
                     .drop_duplicates(subset=['hhid','round']))
            pp = pp.merge(_head, on=['hhid','round'], how='left')
        except Exception:
            pp['gender'] = float('nan')

    chars = pp[['hhid','round','hhsize','urban','gender','region']].copy()
    if len(aux) > 0 and 'hhid' in aux.columns:
        chars = chars.merge(aux, on=['hhid','round'], how='left')

    aux_vars = [c for c in ['employed','has_account','has_savings']
                if c in chars.columns]

    transitions = []
    for prev_r, curr_r in zip(ROUNDS[:-1], ROUNDS[1:]):
        prev_hhs = set(hh[hh['round']==prev_r]['hhid'])
        curr_hhs = set(hh[hh['round']==curr_r]['hhid'])
        leavers_ids = prev_hhs - curr_hhs
        new_ids     = curr_hhs - prev_hhs

        leavers_df = chars[(chars['round']==prev_r) &
                           (chars['hhid'].isin(leavers_ids))].copy()
        new_df     = chars[(chars['round']==curr_r) &
                           (chars['hhid'].isin(new_ids))].copy()

        def compare_var(var, ldf, ndf, is_binary=False, positive_val=1.0):
            l_vals = ldf[var].dropna()
            n_vals = ndf[var].dropna()
            if len(l_vals)==0 or len(n_vals)==0:
                return None
            if is_binary:
                l_pct = float((l_vals==positive_val).mean()*100)
                n_pct = float((n_vals==positive_val).mean()*100)
                n_l = len(l_vals); n_n = len(n_vals)
                obs = np.array([
                    [(l_vals==positive_val).sum(), (l_vals!=positive_val).sum()],
                    [(n_vals==positive_val).sum(), (n_vals!=positive_val).sum()],
                ])
                chi2, v, p, _ = _chi2_cramer(obs)
                return {
                    'leavers': round(l_pct, 1), 'new': round(n_pct, 1),
                    'diff': round(n_pct - l_pct, 1),
                    'chi2': round(chi2, 2), 'v': round(v, 3),
                    'p': round(p, 4), 'sig': _sig_label(p),
                    'n_leavers': n_l, 'n_new': n_n,
                }
            else:
                t, p2, ml, mn = _ttest_2samp(l_vals, n_vals)
                return {
                    'leavers': round(ml, 2), 'new': round(mn, 2),
                    'diff': round(mn - ml, 2),
                    't': round(t, 2),
                    'p': round(p2, 4), 'sig': _sig_label(p2),
                    'n_leavers': len(l_vals), 'n_new': len(n_vals),
                }

        def compare_region(ldf, ndf):
            l_regs = ldf['region'].dropna().value_counts().sort_index()
            n_regs = ndf['region'].dropna().value_counts().sort_index()
            all_r  = sorted(set(l_regs.index) | set(n_regs.index))
            obs = np.array([[int(l_regs.get(r,0)) for r in all_r],
                            [int(n_regs.get(r,0)) for r in all_r]])
            chi2, v, p, _ = _chi2_cramer(obs)
            # Per-region % of each group
            by_reg = {}
            for r in all_r:
                try:
                    rk = int(r)
                except Exception:
                    rk = 0
                l_n = int(l_regs.get(r, 0)); l_tot = len(ldf['region'].dropna())
                n_n = int(n_regs.get(r, 0)); n_tot = len(ndf['region'].dropna())
                by_reg[str(rk)] = {
                    'name':    REGION_NAMES.get(rk, f'Region {rk}'),
                    'l_pct':   round(l_n/l_tot*100, 1) if l_tot>0 else 0,
                    'n_pct':   round(n_n/n_tot*100, 1) if n_tot>0 else 0,
                    'l_n':     l_n, 'n_n': n_n,
                }
            return {
                'chi2': round(chi2, 2), 'v': round(v, 3),
                'p': round(p, 4), 'sig': _sig_label(p),
                'by_region': by_reg,
            }

        vars_compared = {}
        vars_compared['urban']    = compare_var('urban', leavers_df, new_df,
                                                is_binary=True, positive_val=1.0)
        vars_compared['hhsize']   = compare_var('hhsize', leavers_df, new_df)
        vars_compared['female']   = compare_var('gender', leavers_df, new_df,
                                                is_binary=True, positive_val=2.0)
        if 'employed' in chars.columns:
            vars_compared['employed'] = compare_var('employed', leavers_df, new_df,
                                                    is_binary=True, positive_val=1.0)
        if 'has_account' in chars.columns:
            vars_compared['has_account'] = compare_var('has_account', leavers_df, new_df,
                                                       is_binary=True, positive_val=1.0)
        vars_compared['region'] = compare_region(leavers_df, new_df)

        # Any significant differences?
        sig_vars = [k for k, v in vars_compared.items()
                    if v is not None and v.get('p', 1) < 0.05]
        verdict = 'DIFFERENT' if sig_vars else 'SIMILAR'

        transitions.append({
            'label':       f'R{prev_r}\u2192R{curr_r}',
            'from_round':  prev_r,
            'to_round':    curr_r,
            'n_leavers':   len(leavers_ids),
            'n_new':       len(new_ids),
            'verdict':     verdict,
            'sig_vars':    sig_vars,
            'vars':        vars_compared,
        })

    return transitions


def build_attrition_bias(hh, meta):
    """
    Round-to-round selection bias: for each transition R_prev -> R_curr,
    compare households that STAYED (in both rounds) vs those that DROPPED
    (in R_prev, absent in R_curr), using characteristics from R_prev.

    Also computes per-round regional composition drift.
    """
    pp = pd.read_stata(
        _os.path.join(_HF, 'l2phl_M00_passport.dta'),
        convert_categoricals=False
    )
    pp = pp.drop_duplicates(subset=['hhid','round'])
    pp['region'] = pp['psu'].astype(str).str[:2].astype(int)
    # gender is in M01 roster (HH head = fmid==1), not M00 — merge it in
    if 'gender' not in pp.columns:
        try:
            _m01 = pd.read_stata(_os.path.join(_HF, 'l2phl_M01_roster.dta'),
                                 convert_categoricals=False)
            _head = (_m01[_m01['fmid']==1][['hhid','round','gender']]
                     .drop_duplicates(subset=['hhid','round']))
            pp = pp.merge(_head, on=['hhid','round'], how='left')
        except Exception:
            pp['gender'] = float('nan')

    # Load employment (valid R4+) and finance for all rounds
    emp_hh = pd.DataFrame(columns=['hhid','round','employed'])
    fin_hh = pd.DataFrame(columns=['hhid','round','has_account'])
    try:
        m04 = pd.read_stata(_os.path.join(_HF, 'l2phl_M04_employment.dta'),
                            convert_categoricals=False)
        resp = m04[m04['isfmid']==1].drop_duplicates(subset=['hhid','round'])
        resp = resp.copy()
        resp['employed'] = (resp['emp_status']==1).astype(float)
        valid_r = resp.groupby('round')['employed'].sum()
        valid_r = valid_r[valid_r > 0].index.tolist()
        emp_hh = resp[resp['round'].isin(valid_r)][['hhid','round','employed']]
    except Exception:
        pass
    try:
        m06 = pd.read_stata(_os.path.join(_HF, 'l2phl_M06_finance.dta'),
                            convert_categoricals=False)
        fin = m06.drop_duplicates(subset=['hhid','round']).copy()
        fin['has_account'] = (fin['f1']==1).astype(float)
        fin_hh = fin[['hhid','round','has_account']]
    except Exception:
        pass

    chars = pp[['hhid','round','hhsize','urban','gender','region']].copy()
    chars = chars.merge(emp_hh, on=['hhid','round'], how='left')
    chars = chars.merge(fin_hh, on=['hhid','round'], how='left')

    # ── Per-transition retained vs dropped comparison ──────────────────────
    transitions = []
    for prev_r, curr_r in zip(ROUNDS[:-1], ROUNDS[1:]):
        prev_hhs = set(hh[hh['round']==prev_r]['hhid'])
        curr_hhs = set(hh[hh['round']==curr_r]['hhid'])
        retained_ids = prev_hhs & curr_hhs
        dropped_ids  = prev_hhs - curr_hhs

        # Use characteristics from PREVIOUS round for both groups
        ret_df = chars[(chars['round']==prev_r) & (chars['hhid'].isin(retained_ids))]
        drp_df = chars[(chars['round']==prev_r) & (chars['hhid'].isin(dropped_ids))]

        def cmp_binary(col, pos_val=1.0):
            rv = ret_df[col].dropna(); dv = drp_df[col].dropna()
            if len(rv)==0 or len(dv)==0: return None
            r_pct = float((rv==pos_val).mean()*100)
            d_pct = float((dv==pos_val).mean()*100)
            obs = np.array([[(rv==pos_val).sum(),(rv!=pos_val).sum()],
                             [(dv==pos_val).sum(),(dv!=pos_val).sum()]])
            chi2, v, p, _ = _chi2_cramer(obs)
            return {'retained': round(r_pct,1), 'dropped': round(d_pct,1),
                    'diff': round(r_pct-d_pct,1),
                    'chi2': round(chi2,2), 'v': round(v,3),
                    'p': round(p,4), 'sig': _sig_label(p)}

        def cmp_continuous(col):
            rv = ret_df[col].dropna(); dv = drp_df[col].dropna()
            if len(rv)==0 or len(dv)==0: return None
            t, p, mr, md = _ttest_2samp(rv, dv)
            return {'retained': round(mr,2), 'dropped': round(md,2),
                    'diff': round(mr-md,2),
                    't': round(t,2),
                    'p': round(p,4), 'sig': _sig_label(p)}

        def cmp_region():
            r_regs = ret_df['region'].dropna().value_counts().sort_index()
            d_regs = drp_df['region'].dropna().value_counts().sort_index()
            all_r  = sorted(set(r_regs.index)|set(d_regs.index))
            obs = np.array([[int(r_regs.get(r,0)) for r in all_r],
                            [int(d_regs.get(r,0)) for r in all_r]])
            chi2, v, p, _ = _chi2_cramer(obs)
            r_tot = len(ret_df['region'].dropna())
            d_tot = len(drp_df['region'].dropna())
            by_reg = {}
            for r in all_r:
                try: rk = int(r)
                except: rk = 0
                by_reg[str(rk)] = {
                    'name':    REGION_NAMES.get(rk, f'Region {rk}'),
                    'r_pct':   round(int(r_regs.get(r,0))/r_tot*100,1) if r_tot>0 else 0,
                    'd_pct':   round(int(d_regs.get(r,0))/d_tot*100,1) if d_tot>0 else 0,
                    'r_n':     int(r_regs.get(r,0)),
                    'd_n':     int(d_regs.get(r,0)),
                }
            return {'chi2': round(chi2,2), 'v': round(v,3),
                    'p': round(p,4), 'sig': _sig_label(p), 'by_reg': by_reg}

        var_results = {}
        var_results['urban']       = cmp_binary('urban', pos_val=1.0)
        var_results['hhsize']      = cmp_continuous('hhsize')
        var_results['female']      = cmp_binary('gender', pos_val=2.0)
        if 'employed' in chars.columns:
            e = cmp_binary('employed', pos_val=1.0)
            if e is not None: var_results['employed'] = e
        if 'has_account' in chars.columns:
            a = cmp_binary('has_account', pos_val=1.0)
            if a is not None: var_results['has_account'] = a
        var_results['region']      = cmp_region()

        sig_vars = [k for k,v in var_results.items()
                    if v and v.get('p',1) < 0.05]
        verdict  = 'BIASED' if sig_vars else 'OK'

        # Per-region retention rates for this transition
        reg_ret_rates = []
        for rk, rd in var_results['region']['by_reg'].items():
            r_tot_reg = rd['r_n'] + rd['d_n']
            ret_pct   = round(rd['r_n']/r_tot_reg*100, 1) if r_tot_reg > 0 else None
            reg_ret_rates.append({
                'region': int(rk), 'name': rd['name'],
                'n': r_tot_reg, 'retained': rd['r_n'], 'dropped': rd['d_n'],
                'pct_retained': ret_pct,
            })
        reg_ret_rates.sort(key=lambda x: x['pct_retained'] or 0)

        transitions.append({
            'label':        f'R{prev_r}\u2192R{curr_r}',
            'from_round':   prev_r,
            'to_round':     curr_r,
            'n_prev':       len(prev_hhs),
            'n_retained':   len(retained_ids),
            'n_dropped':    len(dropped_ids),
            'verdict':      verdict,
            'sig_vars':     sig_vars,
            'vars':         var_results,
            'reg_ret_rates': reg_ret_rates,
        })

    # ── Overall verdict: how many transitions show significant bias ────────
    n_biased   = sum(1 for t in transitions if t['verdict']=='BIASED')
    worst_vars = sorted({v for t in transitions for v in t['sig_vars']})
    if n_biased >= 3:
        verdict = 'HIGH'
    elif n_biased >= 1:
        verdict = 'MODERATE'
    else:
        verdict = 'LOW'

    # ── Sample composition drift: each region's % share per round ─────────
    comp_drift = []
    all_regions_seen = sorted(meta['region'].dropna().astype(int).unique())
    for reg in all_regions_seen:
        row = {
            'region':       int(reg),
            'region_name':  REGION_NAMES.get(int(reg), f'Region {int(reg)}'),
            'pct_per_round': {}
        }
        for rnd in ROUNDS:
            rnd_hhs   = hh[hh['round']==rnd]
            total_rnd = len(rnd_hhs)
            reg_hhs   = rnd_hhs.merge(meta[['hhid','region']], on='hhid',
                                       how='left', suffixes=('','_meta'))
            reg_col = ('region_meta'
                       if 'region_meta' in reg_hhs.columns and 'region' not in reg_hhs.columns
                       else 'region')
            n_reg = int((reg_hhs[reg_col]==reg).sum())
            row['pct_per_round'][str(rnd)] = (
                round(n_reg/total_rnd*100, 2) if total_rnd > 0 else 0)
        # Drift = latest complete round minus R1
        complete_rounds = [r for r in ROUNDS
                           if len(hh[hh['round']==r]) > 500]
        latest = max(complete_rounds) if complete_rounds else ROUNDS[-1]
        row['drift'] = round(
            row['pct_per_round'].get(str(latest), 0)
            - row['pct_per_round'].get('1', 0), 2)
        comp_drift.append(row)
    comp_drift.sort(key=lambda x: -abs(x['drift']))

    return {
        'verdict':          verdict,
        'n_biased_trans':   n_biased,
        'worst_vars':       worst_vars,
        'transitions':      transitions,
        'comp_drift':       comp_drift,
    }


MIN_CALL_INTERVAL = 20   # days — anything below this is flagged as a violation

def build_call_intervals(hh):
    """
    Days between consecutive interviews per HH.
    Returns:
      - per_round summary (median, mean, min, max, n_total, n_under)
      - violations: HH-round pairs where gap < MIN_CALL_INTERVAL days
    """
    df = (hh[['hhid','round','int_date','urban','region','psu']]
          .dropna(subset=['int_date'])
          .sort_values(['hhid','round'])
          .copy())

    df['prev_date']  = df.groupby('hhid')['int_date'].shift(1)
    df['prev_round'] = df.groupby('hhid')['round'].shift(1)
    df['days_gap']   = (df['int_date'] - df['prev_date']).dt.days

    gaps = df.dropna(subset=['days_gap']).copy()
    gaps['days_gap'] = gaps['days_gap'].astype(int)

    # Per-round summary
    summary = []
    for rnd in ROUNDS[1:]:
        rnd_gaps  = gaps[gaps['round'] == rnd]['days_gap']
        n_total   = int(len(rnd_gaps))
        n_under = int((rnd_gaps < MIN_CALL_INTERVAL).sum())
        if n_total == 0:
            summary.append({'round': rnd, 'n_total': 0, 'n_under': 0,
                             'pct_under': 0.0,
                             'median': None, 'mean': None,
                             'min': None, 'max': None})
        else:
            summary.append({
                'round':    rnd,
                'n_total':  n_total,
                'n_under':  n_under,
                'pct_under': round(n_under / n_total * 100, 1),
                'median':   int(rnd_gaps.median()),
                'mean':     round(float(rnd_gaps.mean()), 1),
                'min':      int(rnd_gaps.min()),
                'max':      int(rnd_gaps.max()),
            })

    # Violation list (gap < MIN_CALL_INTERVAL days)
    viol = gaps[gaps['days_gap'] < MIN_CALL_INTERVAL].copy()
    violations = []
    for _, row in viol.iterrows():
        region_val = row.get('region')
        try:
            reg_int  = int(region_val) if pd.notna(region_val) else 0
            reg_name = REGION_NAMES.get(reg_int, f'Region {reg_int}')
        except Exception:
            reg_int  = 0
            reg_name = '?'
        violations.append({
            'hhid':       int(row['hhid']),
            'round':      int(row['round']),
            'prev_round': int(row['prev_round']),
            'days_gap':   int(row['days_gap']),
            'urban_label':'Urban' if row.get('urban')==1.0 else 'Rural',
            'region':     reg_int,
            'region_name':reg_name,
            'psu':        str(row['psu']),
        })
    violations.sort(key=lambda x: (x['round'], x['days_gap']))

    # Per-HH per-round gaps lookup: {hhid: {round: days_gap}}
    # round here is the "arrival" round (the one being interviewed)
    gaps_lookup = {}
    for _, row in gaps.iterrows():
        hid = int(row['hhid'])
        rnd = int(row['round'])
        if hid not in gaps_lookup:
            gaps_lookup[hid] = {}
        gaps_lookup[hid][rnd] = int(row['days_gap'])

    return summary, violations, gaps_lookup


def main():
    print("  [panel] Loading passport data...")
    hh, meta = load_data()

    print("  [panel] Building panel matrix...")
    pivot = build_panel_matrix(hh, meta)

    print("  [panel] Computing attrition...")
    attrition = build_attrition(pivot)

    print("  [panel] Computing attrition profiles (stayers/leavers/new)...")
    attrition_profile = build_attrition_profile(pivot)

    print("  [panel] Computing PSU coverage...")
    psu_long = build_psu_coverage(hh, meta)

    print("  [panel] Building PSU problem list...")
    psu_problem_list = build_psu_problem_list(psu_long)

    print("  [panel] Building region summary...")
    reg_df = build_region_summary(hh, meta)

    print("  [panel] Computing call intervals...")
    call_interval_summary, call_violations, gaps_lookup = build_call_intervals(hh)

    print("  [panel] Loading auxiliary characteristics (employment, finance)...")
    aux = load_aux_characteristics()

    print("  [panel] Running leavers-vs-new-entries comparison...")
    leaver_vs_new = build_leaver_vs_new(hh, meta, aux)

    print("  [panel] Running attrition bias analysis...")
    attrition_bias = build_attrition_bias(hh, meta)

    # ── Assemble output ──────────────────────────────────────────────────────

    pattern_counts = (pivot['pattern'].value_counts()
                             .reset_index()
                             .rename(columns={'pattern':'pattern','count':'n'})
                             .head(20)
                             .to_dict(orient='records'))

    always_in  = int((pivot['rounds_present'] == 5).sum())
    r1_only    = int(((pivot[1]==1) & (pivot['rounds_present']==1)).sum())
    never_r1   = int((pivot[1]==0).sum())
    all_hhs    = len(pivot)

    psu_detail = []
    for _, row in psu_long.iterrows():
        psu_detail.append({
            'psu':    str(row['psu']),
            'round':  int(row['round']),
            'count':  int(row['count']),
            'target': int(row['target']),
            'diff':   int(row['diff']),
            'status': row['status'],
            'region': int(row['region']) if pd.notna(row['region']) else None,
            'urban':  int(row['urban'])  if pd.notna(row['urban'])  else None,
            'stratum':int(row['stratum'])if pd.notna(row['stratum'])else None,
        })

    psu_status = build_psu_status_summary(psu_long)

    reg_summary = []
    for (reg, urb), grp in reg_df.groupby(['region','urban_label']):
        entry = {
            'region': int(reg),
            'region_name': REGION_NAMES.get(int(reg), f'Region {int(reg)}'),
            'urban_label': urb,
            'counts': {str(int(row['round'])): int(row['count'])
                       for _, row in grp.iterrows()},
        }
        reg_summary.append(entry)
    reg_summary.sort(key=lambda x: (x['region'], x['urban_label']))

    round_counts = {str(r): int((pivot[r]==1).sum()) for r in ROUNDS}

    # ── Household-level panel matrix ─────────────────────────────────────────
    print("  [panel] Building household matrix...")
    hh_matrix = []
    for _, row in pivot.iterrows():
        presence = {str(r): int(row[r]) for r in ROUNDS}
        participated = [r for r in ROUNDS if row[r] == 1]
        first_r = min(participated) if participated else None
        last_r  = max(participated) if participated else None

        # Status label
        if row['rounds_present'] == 5:
            status = 'All Rounds'
        elif first_r == 1 and last_r == max(ROUNDS):
            status = 'Intermittent'
        elif first_r == 1 and last_r < max(ROUNDS):
            status = 'Left Panel'
        elif first_r is not None and first_r > 1 and last_r == max(ROUNDS):
            status = 'New Entry'
        elif first_r is not None and first_r > 1 and last_r < max(ROUNDS):
            status = 'New Entry → Left'
        else:
            status = 'Intermittent'

        reg_int = int(row['region']) if pd.notna(row.get('region')) else 0
        urb_val = row.get('urban')
        hid     = int(row['hhid'])
        hh_gaps = gaps_lookup.get(hid, {})
        # days_gap[r] = days since previous interview to reach round r (None if first appearance)
        days_gap = {str(r): hh_gaps.get(r, None) for r in ROUNDS}
        hh_matrix.append({
            'hhid':         hid,
            'psu':          str(row['psu']) if pd.notna(row.get('psu')) else '',
            'region':       reg_int,
            'region_name':  REGION_NAMES.get(reg_int, f'Region {reg_int}'),
            'urban':        int(urb_val) if pd.notna(urb_val) else None,
            'urban_label':  'Urban' if urb_val == 1.0 else 'Rural',
            'pattern':      str(row['pattern']),
            'rounds_present': int(row['rounds_present']),
            'first_round':  first_r,
            'last_round':   last_r,
            'status':       status,
            'presence':     presence,
            'days_gap':     days_gap,
        })
    hh_matrix.sort(key=lambda x: x['hhid'])

    out = {
        'all_hhs':               all_hhs,
        'always_in':             always_in,
        'r1_only':               r1_only,
        'never_r1':              never_r1,
        'round_counts':          round_counts,
        'attrition':             attrition,
        'attrition_profile':     attrition_profile,
        'pattern_dist':          pattern_counts,
        'psu_status':            psu_status,
        'psu_detail':            psu_detail,
        'psu_problem_list':      psu_problem_list,
        'reg_summary':           reg_summary,
        'urban_target':          URBAN_TARGET,
        'rural_target':          RURAL_TARGET,
        'call_interval_summary': call_interval_summary,
        'call_violations':       call_violations,
        'attrition_bias':        attrition_bias,
        'leaver_vs_new':         leaver_vs_new,
        'hh_matrix':             hh_matrix,
    }

    out_path = _os.path.join(_CACHE, 'panel_data.json')
    with open(out_path, 'w') as f:
        json.dump(out, f, separators=(',', ':'))
    print(f"  [panel] Written -> {out_path}")

if __name__ == '__main__':
    main()
