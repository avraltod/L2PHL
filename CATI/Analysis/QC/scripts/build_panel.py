#!/usr/bin/env python3
"""
build_panel.py — Panel tracking analysis for L2PHL CATI survey
Generates cache/panel_data.json used by the Panel tab in the QC dashboard.

Tracks:
  - Per-household participation across rounds (panel matrix)
  - Attrition / new entry per round relative to R1 baseline
  - PSU coverage vs targets (urban=6 HH/PSU, rural=7 HH/PSU)
  - HH counts by region x urban x round
  - Participation pattern distribution
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
    # One row per HH per round
    hh = pp.drop_duplicates(subset=['round','hhid'])[
        ['round','hhid','urban','stratum','psu']
    ].copy()
    hh['round'] = hh['round'].fillna(0).astype(int)
    hh = hh[hh['round'].isin(ROUNDS)]

    # Derive region code from first 2 chars of PSU string
    hh['region'] = hh['psu'].astype(str).str[:2].astype(int)

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

    psu_long = pd.concat(rows).merge(psu_info, on='psu', how='left')
    psu_long['target'] = psu_long['urban'].apply(
        lambda u: URBAN_TARGET if u == 1.0 else RURAL_TARGET)
    psu_long['diff']   = psu_long['count'] - psu_long['target']
    psu_long['status'] = psu_long['diff'].apply(
        lambda x: 'on_target' if x == 0 else ('over' if x > 0 else 'under'))
    return psu_long

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

def main():
    print("  [panel] Loading passport data...")
    hh, meta = load_data()

    print("  [panel] Building panel matrix...")
    pivot = build_panel_matrix(hh, meta)

    print("  [panel] Computing attrition...")
    attrition = build_attrition(pivot)

    print("  [panel] Computing PSU coverage...")
    psu_long = build_psu_coverage(hh, meta)

    print("  [panel] Building region summary...")
    reg_df = build_region_summary(hh, meta)

    # ── Assemble output ──────────────────────────────────────────────────────

    # Pattern distribution (top patterns)
    pattern_counts = (pivot['pattern'].value_counts()
                             .reset_index()
                             .rename(columns={'pattern':'pattern','count':'n'})
                             .head(20)
                             .to_dict(orient='records'))

    # Participation consistency buckets
    always_in  = int((pivot['rounds_present'] == 5).sum())
    r1_only    = int(((pivot[1]==1) & (pivot['rounds_present']==1)).sum())
    never_r1   = int((pivot[1]==0).sum())
    all_hhs    = len(pivot)

    # PSU coverage detail — per PSU per round (for heatmap)
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

    # PSU status summary per round
    psu_status = build_psu_status_summary(psu_long)

    # Region x urban x round HH counts
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

    # Per-round HH counts (for chart)
    round_counts = {str(r): int((pivot[r]==1).sum()) for r in ROUNDS}

    out = {
        'all_hhs':       all_hhs,
        'always_in':     always_in,
        'r1_only':       r1_only,
        'never_r1':      never_r1,
        'round_counts':  round_counts,
        'attrition':     attrition,
        'pattern_dist':  pattern_counts,
        'psu_status':    psu_status,
        'psu_detail':    psu_detail,
        'reg_summary':   reg_summary,
        'urban_target':  URBAN_TARGET,
        'rural_target':  RURAL_TARGET,
    }

    out_path = _os.path.join(_CACHE, 'panel_data.json')
    with open(out_path, 'w') as f:
        json.dump(out, f, separators=(',', ':'))
    print(f"  [panel] Written → {out_path}")

if __name__ == '__main__':
    main()
