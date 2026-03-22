#!/usr/bin/env python3
import os as _os
_HERE   = _os.path.dirname(_os.path.abspath(__file__))   # scripts/
_QC     = _os.path.dirname(_HERE)                         # Analysis/QC/
_CACHE  = _os.path.join(_QC, 'cache')
_OUTPUT = _os.path.join(_QC, 'output')

"""Generate enhanced L2PH DQ dashboard v3 — per-module, per-question, per-round"""
import json, os

with open(_os.path.join(_CACHE, 'dq_data.json')) as f:
    dq_raw = json.load(f)
with open(_os.path.join(_CACHE, 'module_tables.json')) as f:
    module_tables = json.load(f)
with open(_os.path.join(_CACHE, 'all_questions.json')) as f:
    all_qs = json.load(f)
_panel_path = _os.path.join(_CACHE, 'panel_data.json')
if _os.path.exists(_panel_path):
    with open(_panel_path) as f:
        panel_raw = json.load(f)
else:
    panel_raw = {}

DQ  = json.dumps(dq_raw,       separators=(',',':'))
MT  = json.dumps(module_tables, separators=(',',':'))
AQ  = json.dumps(all_qs,        separators=(',',':'))
PAN = json.dumps(panel_raw,     separators=(',',':'))

HTML = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>L2PH Data Quality Dashboard v3</title>
<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.min.js"></script>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:'Segoe UI',Helvetica,sans-serif;background:#f0f2f5;color:#222;display:flex;min-height:100vh}

/* ── SIDEBAR ── */
#sidebar{width:235px;min-width:235px;background:#1a2332;color:#cdd5e0;display:flex;flex-direction:column;position:fixed;top:0;left:0;height:100vh;overflow-y:auto;z-index:100;scrollbar-width:thin;scrollbar-color:#2d3f55 #1a2332}
#sidebar .logo{padding:14px 16px;border-bottom:1px solid #2d3f55}
#sidebar .logo strong{display:block;font-size:14px;color:#fff;margin-bottom:1px}
#sidebar .logo span{color:#7d9ab8;font-size:10.5px}
#sidebar .nav-section{padding:10px 16px 3px;font-size:9.5px;text-transform:uppercase;letter-spacing:.08em;color:#506070;font-weight:600}
#sidebar a{display:flex;align-items:center;gap:7px;padding:7px 14px;color:#cdd5e0;text-decoration:none;font-size:12.5px;border-left:3px solid transparent;transition:.12s}
#sidebar a:hover{background:#243347;color:#fff}
#sidebar a.active{background:#1d3150;color:#4db8ff;border-left-color:#4db8ff}
.dot{width:8px;height:8px;border-radius:50%;flex-shrink:0}
.nav-count{margin-left:auto;background:#2d3f55;color:#aab8c8;font-size:10px;padding:1px 6px;border-radius:10px}
.nav-count.red{background:#c0392b;color:#fff}
.nav-count.yellow{background:#e67e22;color:#fff}

/* ── MAIN ── */
#main{margin-left:235px;flex:1;padding:22px;min-width:0}
.page{display:none}.page.active{display:block}
h1{font-size:21px;font-weight:700;margin-bottom:4px}
.subtitle{color:#666;font-size:12.5px;margin-bottom:18px}

/* ── CARDS ── */
.card{background:#fff;border-radius:10px;box-shadow:0 1px 4px rgba(0,0,0,.08);padding:18px;margin-bottom:18px}
.card h2{font-size:14.5px;font-weight:600;margin-bottom:12px;color:#333;display:flex;align-items:center;gap:8px;flex-wrap:wrap}
.badge{font-size:10.5px;padding:2px 7px;border-radius:10px;font-weight:600}
.badge-red{background:#fde;color:#c0392b}.badge-yellow{background:#fff3cd;color:#856404}
.badge-green{background:#d4edda;color:#155724}.badge-blue{background:#cce5ff;color:#004085}
.badge-grey{background:#f0f0f0;color:#555}.badge-purple{background:#f0e6ff;color:#6c3483}

/* ── STATS ROW ── */
.stats-row{display:flex;gap:10px;flex-wrap:wrap;margin-bottom:16px}
.stat-box{background:#fff;border-radius:8px;padding:10px 16px;min-width:110px;box-shadow:0 1px 3px rgba(0,0,0,.07);border:1px solid #e8ebef;text-align:center}
.stat-box .num{font-size:26px;font-weight:700;line-height:1.1}
.stat-box .lbl{font-size:10.5px;color:#666;margin-top:2px}
.stat-box.red .num{color:#e74c3c}.stat-box.yellow .num{color:#e67e22}
.stat-box.green .num{color:#27ae60}.stat-box.blue .num{color:#2980b9}
.stat-box.purple .num{color:#8e44ad}

/* ── NOTE BOXES ── */
.note-box{padding:9px 13px;border-radius:6px;font-size:12px;margin-bottom:12px;line-height:1.5}
.note-info{background:#e8f4fd;border-left:4px solid #3498db;color:#1a5276}
.note-warn{background:#fff8e1;border-left:4px solid #f39c12;color:#7d4e00}
.note-ok{background:#eafaf1;border-left:4px solid #2ecc71;color:#1a5c32}
.note-flag{background:#fff0f0;border-left:4px solid #e74c3c;color:#7b0000}
.note-purple{background:#f5eef8;border-left:4px solid #8e44ad;color:#4a235a}

/* ── VIOL ROWS ── */
.viol-row{display:flex;align-items:flex-start;gap:10px;padding:10px 12px;border-radius:7px;margin-bottom:8px}
.viol-row.high{background:#fff5f5;border-left:4px solid #e74c3c}
.viol-row.medium{background:#fffdf0;border-left:4px solid #f39c12}
.viol-row.ok{background:#f5fff8;border-left:4px solid #2ecc71}
.viol-icon{font-size:18px;flex-shrink:0;margin-top:1px}
.viol-text strong{display:block;font-size:12.5px;margin-bottom:2px}
.viol-text .viol-path{font-size:11px;color:#777;font-family:monospace;margin:2px 0}
.viol-text .viol-note{font-size:11.5px;color:#555;margin-top:3px;line-height:1.4}
.viol-pills{display:flex;gap:4px;flex-wrap:wrap;margin-top:5px}
.vpill{border-radius:10px;padding:2px 8px;font-size:10.5px;font-weight:600;border:1px solid}
.vpill-red{background:#fde;border-color:#f5c6cb;color:#c0392b}
.vpill-yellow{background:#fff3cd;border-color:#ffc107;color:#856404}
.vpill-green{background:#d4edda;border-color:#c3e6cb;color:#155724}
.vpill-grey{background:#f0f0f0;border-color:#ddd;color:#666}

/* ── CHART ── */
.chart-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(320px,1fr));gap:14px}
.chart-box{background:#fff;border-radius:8px;padding:12px;box-shadow:0 1px 3px rgba(0,0,0,.07);border:1px solid #e8ebef}
.chart-box.flagged{border-left:4px solid #e74c3c}.chart-box.warn{border-left:4px solid #f39c12}
.ch-title{font-size:12.5px;font-weight:600;margin-bottom:2px;color:#222}
.ch-sub{font-size:11px;color:#888;margin-bottom:7px;line-height:1.35}
.ch-note{font-size:10.5px;color:#555;background:#f7f9fc;padding:4px 7px;border-radius:4px;margin-top:5px;line-height:1.4}

/* ── HEATMAP ── */
.heatmap-wrap{overflow-x:auto}
.heatmap{border-collapse:collapse;font-size:11.5px;width:100%}
.heatmap th,.heatmap td{padding:5px 9px;text-align:center;border-bottom:1px solid #f2f2f2}
.heatmap th{background:#f7f9fc;font-weight:600;color:#555;font-size:10.5px;text-transform:uppercase;position:sticky;top:0}
.heatmap td.vn{text-align:left;font-family:monospace;font-size:11px;white-space:nowrap;max-width:160px;overflow:hidden;text-overflow:ellipsis}
.hm-cell{border-radius:3px;font-weight:500;min-width:48px}

/* ── MODULE TABS ── */
.mod-tabs{display:flex;gap:3px;flex-wrap:wrap;margin-bottom:12px}
.mtab{padding:5px 11px;border-radius:5px;background:#f0f2f5;border:1px solid #dde;cursor:pointer;font-size:11.5px;font-weight:500;color:#444;transition:.12s}
.mtab.active,.mtab:hover{background:#1d3150;color:#fff;border-color:#1d3150}

/* ── MODULE GRID ── */
.mod-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:10px}
.mod-card{border-radius:8px;padding:12px;border:1px solid #e5e8ec;position:relative;overflow:hidden;cursor:pointer;transition:.12s}
.mod-card:hover{box-shadow:0 2px 8px rgba(0,0,0,.12)}
.mod-card.red{border-left:4px solid #e74c3c;background:#fff9f9}
.mod-card.yellow{border-left:4px solid #f39c12;background:#fffef5}
.mod-card.green{border-left:4px solid #2ecc71;background:#f5fff8}
.mod-card .mname{font-weight:700;font-size:12.5px;margin-bottom:5px;color:#222}
.mod-card .mstat{font-size:11.5px;color:#555;margin:1px 0;line-height:1.4}
.mod-card .mstat.warn{color:#c0392b;font-weight:600}
.rag-chip{position:absolute;top:8px;right:8px;font-size:9.5px;padding:2px 6px;border-radius:10px;font-weight:700}

/* ── LEGEND ── */
.legend{display:flex;gap:12px;flex-wrap:wrap;font-size:11.5px;margin-bottom:10px}
.legend-item{display:flex;align-items:center;gap:5px}
.legend-dot{width:11px;height:11px;border-radius:2px}

/* ═════════════════════════════════════════
   PER-QUESTION TRACKER STYLES
   ═════════════════════════════════════════ */

/* Round presence matrix */
.qtrack-table{width:100%;border-collapse:collapse;font-size:12px;margin-bottom:6px}
.qtrack-table th{background:#f0f4fa;padding:5px 8px;font-size:10.5px;font-weight:600;color:#555;text-transform:uppercase;border-bottom:2px solid #dde;text-align:center;position:sticky;top:0;z-index:2}
.qtrack-table th.left{text-align:left}
.qtrack-table td{padding:6px 8px;border-bottom:1px solid #eef;vertical-align:middle}
.qtrack-table td.var-name{font-family:monospace;font-weight:700;font-size:12px;color:#1a2332;white-space:nowrap}
.qtrack-table td.q-title{font-size:11.5px;color:#333;max-width:220px}
.qtrack-table td.q-text{font-size:11px;color:#666;max-width:280px;font-style:italic}
.qtrack-table tr:hover td{background:#f5f8ff}

/* Presence pill */
.pres{display:inline-block;width:28px;height:22px;border-radius:4px;font-size:10px;font-weight:700;line-height:22px;text-align:center;cursor:default}
.pres.yes{background:#d4edda;color:#155724}
.pres.no{background:#f8d7da;color:#721c24}
.pres.na{background:#f0f0f0;color:#999}

/* Change tags */
.chg-tag{display:inline-flex;align-items:center;gap:3px;border-radius:10px;padding:2px 7px;font-size:10px;font-weight:600;margin:1px;white-space:nowrap}
.chg-new{background:#d4edda;color:#155724;border:1px solid #c3e6cb}
.chg-drop{background:#f8d7da;color:#721c24;border:1px solid #f5c6cb}
.chg-title{background:#fff3cd;color:#856404;border:1px solid #ffc107}
.chg-skip{background:#cce5ff;color:#004085;border:1px solid #bee5eb}
.chg-code{background:#f5eef8;color:#6c3483;border:1px solid #d7bde2}
.chg-check{background:#e8f4fd;color:#1a5276;border:1px solid #aed6f1}

/* DQ issue inline */
.dq-inline{display:inline-flex;align-items:center;gap:3px;border-radius:4px;padding:2px 7px;font-size:10px;font-weight:600;margin:1px}
.dq-skip{background:#fff0f0;color:#c0392b;border:1px solid #f5c6cb}
.dq-mand{background:#fff8e1;color:#7d4e00;border:1px solid #ffc107}
.dq-oor{background:#f5eef8;color:#6c3483;border:1px solid #d7bde2}

/* Round filter pills */
.round-filters{display:flex;gap:5px;flex-wrap:wrap;margin-bottom:12px;align-items:center}
.rfil{padding:4px 11px;border-radius:14px;background:#f0f2f5;border:1px solid #dde;cursor:pointer;font-size:11.5px;font-weight:500;color:#444;transition:.12s}
.rfil.active{background:#2980b9;color:#fff;border-color:#2980b9}
.rfil-label{font-size:11px;color:#888;margin-right:3px}

/* Expandable detail panel */
.q-detail{display:none;background:#f7f9ff;border-radius:6px;padding:10px 14px;margin:-4px 0 6px;border-left:3px solid #3498db;font-size:11.5px;line-height:1.55}
.q-detail.open{display:block}
.q-detail dl{display:grid;grid-template-columns:auto 1fr;gap:2px 10px}
.q-detail dt{font-weight:600;color:#555;font-size:10.5px;text-transform:uppercase;white-space:nowrap}
.q-detail dd{color:#333;margin:0}
.q-detail .skip-rules{margin-top:6px}
.q-detail .skip-rule-row{display:flex;gap:6px;margin:2px 0;align-items:flex-start}
.q-detail .skip-round{font-size:9.5px;font-weight:700;background:#1d3150;color:#fff;border-radius:10px;padding:1px 6px;min-width:28px;text-align:center;flex-shrink:0;margin-top:1px}
.q-detail .skip-text{font-size:11px;color:#333;font-family:monospace}

/* Module page header */
.mod-page-header{display:flex;align-items:center;gap:12px;margin-bottom:14px;flex-wrap:wrap}
.mod-page-header h1{margin-bottom:0}
.mod-round-summary{display:flex;gap:6px;flex-wrap:wrap}
.mrs-pill{display:flex;align-items:center;gap:4px;border-radius:12px;padding:3px 10px;font-size:11px;font-weight:600;border:1px solid}
.mrs-ok{background:#d4edda;color:#155724;border-color:#c3e6cb}
.mrs-warn{background:#fff3cd;color:#856404;border-color:#ffc107}
.mrs-flag{background:#f8d7da;color:#721c24;border-color:#f5c6cb}
.mrs-na{background:#f0f0f0;color:#999;border-color:#ddd}

/* Question type badge */
.qtype{font-size:9.5px;padding:1px 6px;border-radius:8px;font-weight:600;background:#e8f4fd;color:#004085;border:1px solid #bee5eb}

/* DQ count badge on question row */
.dq-cnt{display:inline-flex;align-items:center;justify-content:center;width:18px;height:18px;border-radius:50%;font-size:9px;font-weight:700;vertical-align:middle;margin-left:3px}
.dq-cnt.red{background:#e74c3c;color:#fff}
.dq-cnt.yellow{background:#f39c12;color:#fff}

/* Sticky round header in question table */
.sticky-round{position:sticky;top:0;z-index:3}

/* Summary bar at top of module page */
.mod-dq-bar{display:flex;gap:8px;margin-bottom:14px;flex-wrap:wrap}
.mdb-item{flex:1;min-width:100px;background:#fff;border-radius:7px;padding:8px 12px;border:1px solid #e8ebef;box-shadow:0 1px 3px rgba(0,0,0,.05)}
.mdb-item .mdb-num{font-size:22px;font-weight:700;line-height:1}
.mdb-item .mdb-lbl{font-size:10px;color:#666;margin-top:2px}
.mdb-item.red .mdb-num{color:#e74c3c}
.mdb-item.yellow .mdb-num{color:#e67e22}
.mdb-item.green .mdb-num{color:#27ae60}
.mdb-item.blue .mdb-num{color:#2980b9}
.mdb-item.purple .mdb-num{color:#8e44ad}

/* Change summary header per round transition */
.round-change-header{background:#f0f4fa;border-radius:6px;padding:6px 12px;margin:10px 0 6px;font-size:12px;font-weight:600;color:#1a2332;display:flex;align-items:center;gap:8px}
.rch-arrow{color:#aaa;font-size:14px}

/* Search / filter */
.q-search{padding:5px 10px;border:1px solid #dde;border-radius:6px;font-size:12px;width:220px;outline:none}
.q-search:focus{border-color:#3498db}

hr{border:none;border-top:1px solid #eee;margin:14px 0}
.source-tag{font-size:9.5px;background:#e8f4fd;color:#1a5276;padding:1px 5px;border-radius:8px;font-weight:500;vertical-align:middle;margin-left:5px}
.toggle-row{cursor:pointer;user-select:none}
.toggle-row:hover td{background:#eef3ff !important}
.toggle-btn{font-size:11px;color:#3498db;border:none;background:none;cursor:pointer;padding:0;vertical-align:middle}
</style>
</head>
<body>
<nav id="sidebar">
  <div class="logo">
    <strong>L2PH · Data Quality</strong>
    <span>Per-module · Per-question · Per-round</span>
  </div>

  <div class="nav-section">Overview</div>
  <a href="#" onclick="return showPage('overview')" id="nav-overview" class="active">
    <span class="dot" style="background:#4db8ff"></span>Dashboard Overview
  </a>

  <div class="nav-section">Data Issues</div>
  <a href="#" onclick="return showPage('skip')" id="nav-skip">
    <span class="dot" style="background:#e74c3c"></span>Skip Violations
    <span class="nav-count red" id="nc-skip">—</span>
  </a>
  <a href="#" onclick="return showPage('mandatory')" id="nav-mandatory">
    <span class="dot" style="background:#e67e22"></span>Mandatory Missing
    <span class="nav-count yellow" id="nc-mand">—</span>
  </a>
  <a href="#" onclick="return showPage('oor')" id="nav-oor">
    <span class="dot" style="background:#8e44ad"></span>Out-of-Range Values
  </a>
  <a href="#" onclick="return showPage('missing')" id="nav-missing">
    <span class="dot" style="background:#95a5a6"></span>Missing Data Heatmap
  </a>
  <a href="#" onclick="return showPage('interview')" id="nav-interview">
    <span class="dot" style="background:#2ecc71"></span>Interview Quality
  </a>

  <div class="nav-section">Panel Structure</div>
  <a href="#" onclick="return showPage('panel')" id="nav-panel">
    <span class="dot" style="background:#8e44ad"></span>Panel Tracking
  </a>
  <div class="nav-section">Questionnaire Changes</div>
  <a href="#" onclick="return showPage('changes')" id="nav-changes">
    <span class="dot" style="background:#f1c40f"></span>All Changes by Round
  </a>

  <div class="nav-section">Module Deep-Dive</div>
  <div id="mod-nav-links"></div>
</nav>

<div id="main">
<!-- ═══════ OVERVIEW ═══════ -->
<div id="page-overview" class="page active">
<h1>Data Quality Overview</h1>
<p class="subtitle">L2PH "Listening to the Philippines" Panel Survey · Rounds 1–5 · Questionnaire-grounded checks</p>
<div class="note-info note-box">
  <strong>New in v3:</strong> Each module now has a deep-dive page showing every question, its presence across rounds, questionnaire changes (new/dropped/renamed/skip-logic), and data quality issues linked to the question.
  Click any module card or the module links in the sidebar to explore.
</div>
<div id="ov-stats" class="stats-row"></div>
<div class="card">
  <h2>Module-Level Quality Summary <span class="badge badge-blue">Click a card to view details</span></h2>
  <div id="mod-grid" class="mod-grid"></div>
</div>
<div class="card">
  <h2>Sample Counts per Round</h2>
  <div style="height:260px"><canvas id="sampleChart"></canvas></div>
</div>
<div class="card">
  <h2>Questionnaire Change Summary by Round</h2>
  <div id="change-summary-bar"></div>
</div>
</div>

<!-- ═══════ SKIP VIOLATIONS ═══════ -->
<div id="page-skip" class="page">
<h1>Skip Pattern Violations</h1>
<p class="subtitle">Rows where a follow-up question is filled despite the gate answer routing away from it</p>
<div class="note-warn note-box">
  <strong>What is a skip violation?</strong> E.g. A1=2 ("did not work last week") routes to A26, skipping A10/A11. If A10 is filled for that row it is a violation. Empty strings are excluded.
</div>
<div id="skip-stats" class="stats-row"></div>
<div id="skip-list"></div>
<div class="chart-grid" id="skip-charts" style="margin-top:14px"></div>
</div>

<!-- ═══════ MANDATORY MISSING ═══════ -->
<div id="page-mandatory" class="page">
<h1>Mandatory Fields — Unexpectedly Missing</h1>
<p class="subtitle">Follow-up questions that should be filled given the gate answer but are blank</p>
<div class="note-warn note-box">
  E.g. H2=1/2/3 means health care was needed → H2A (was care obtained?) must be answered. Blank H2A is a mandatory-missing failure.
</div>
<div id="mand-stats" class="stats-row"></div>
<div id="mand-list"></div>
<div class="chart-grid" id="mand-charts" style="margin-top:14px"></div>
</div>

<!-- ═══════ OUT-OF-RANGE ═══════ -->
<div id="page-oor" class="page">
<h1>Out-of-Range Values</h1>
<p class="subtitle">Values outside the bounds specified in the questionnaire programming instructions</p>
<div class="note-info note-box">
  Valid ranges from questionnaire notes e.g. "A10: 0–7 days", "A11: 0–168 hours", "SH4: 1–30 days".
  Zero-duration modules (dur_xx=0) indicate the Kobo timer was not running when that module was administered.
</div>
<div id="oor-stats" class="stats-row"></div>
<div id="oor-list"></div>
<div class="chart-grid" id="oor-charts" style="margin-top:14px"></div>
</div>

<!-- ═══════ MISSING HEATMAP ═══════ -->
<div id="page-missing" class="page">
<h1>Missing Data Heatmap</h1>
<p class="subtitle">% missing by variable and round — red cells flag structural absence or near-complete missingness</p>
<div class="note-info note-box">
  High missingness on roster/new-member variables (D25, D28, D30 etc.) is expected because they only apply to a small subset of respondents.
  Module-level tabs below let you focus on specific sections.
</div>
<div class="mod-tabs" id="hm-tabs"></div>
<div class="legend">
  <div class="legend-item"><div class="legend-dot" style="background:#1a9641"></div> 0%</div>
  <div class="legend-item"><div class="legend-dot" style="background:#a6d96a"></div> 1–20%</div>
  <div class="legend-item"><div class="legend-dot" style="background:#ffffbf"></div> 21–50%</div>
  <div class="legend-item"><div class="legend-dot" style="background:#fdae61"></div> 51–80%</div>
  <div class="legend-item"><div class="legend-dot" style="background:#d73027"></div> >80%</div>
</div>
<div id="hm-content"></div>
</div>

<!-- ═══════ INTERVIEW QUALITY ═══════ -->
<div id="page-interview" class="page">
<h1>Interview Quality</h1>
<p class="subtitle">Duration distributions, partial interviews, call attempts, and excess interviews</p>
<div id="int-stats" class="stats-row"></div>
<div class="chart-grid">
  <div class="chart-box"><div class="ch-title">Interview Duration (minutes)</div><div class="ch-sub">P25/Median/P75 by round</div><div style="height:200px"><canvas id="durChart"></canvas></div></div>
  <div class="chart-box"><div class="ch-title">Duration Categories (%)</div><div class="ch-sub">Share per duration band by round</div><div style="height:200px"><canvas id="durCatChart"></canvas></div></div>
</div>
<div class="chart-grid" style="margin-top:14px">
  <div class="chart-box"><div class="ch-title">Module Duration (median min)</div><div class="ch-sub">Time spent per module by round</div><div style="height:200px"><canvas id="modDurChart"></canvas></div></div>
  <div class="chart-box"><div class="ch-title">Partial Interviews</div><div class="ch-sub">Count by round</div><div style="height:200px"><canvas id="partialChart"></canvas></div></div>
</div>
<div class="chart-grid" style="margin-top:14px">
  <div class="chart-box"><div class="ch-title">Call Attempts</div><div class="ch-sub">Mean attempts and 3+ attempts count</div><div style="height:200px"><canvas id="callChart"></canvas></div></div>
</div>
</div>

<!-- ═══════ PANEL TRACKING ═══════ -->
<div id="page-panel" class="page">
<h1>Panel Structure &amp; Household Tracking</h1>
<p class="subtitle">Participation across rounds · Attrition bias · PSU coverage vs targets · In / out households</p>
<div id="panel-bias-banner"></div>
<div class="card" style="margin-top:10px">
  <h2>🔬 Attrition Bias Analysis <span id="panel-bias-verdict-badge"></span></h2>
  <p style="font-size:12px;color:#666;margin-bottom:12px">Round-to-round selection bias: for each transition (R1→R2, R2→R3, …) are households that <em>stay</em> systematically different from those that <em>drop out</em>? Characteristics compared using data from the <em>previous</em> round.</p>
  <div id="panel-bias-table"></div>
  <div class="chart-grid" style="margin-top:14px">
    <div class="chart-box">
      <div class="ch-title">Regional Retention Rate by Transition <span id="bias-reg-chart-label" style="font-weight:normal;font-size:11px;color:#888">(R1→R2)</span></div>
      <div class="ch-sub">Click a transition tab above to update — sorted lowest to highest</div>
      <div style="height:340px"><canvas id="panelBiasRegChart"></canvas></div>
    </div>
    <div class="chart-box">
      <div class="ch-title">Sample Composition Drift</div>
      <div class="ch-sub">Each region's share of total sample: R1 vs latest complete round (pp change)</div>
      <div style="height:340px"><canvas id="panelBiasDriftChart"></canvas></div>
    </div>
  </div>
  <div style="margin-top:14px">
    <div class="ch-title" style="margin-bottom:6px">Retention Rate Heatmap — Region × Transition</div>
    <p style="font-size:11.5px;color:#666;margin-bottom:8px">% of previous-round HHs retained per transition, by region. Red &lt;50%, orange 50–65%, yellow 65–75%, green ≥75%.</p>
    <div id="panel-trans-heatmap"></div>
  </div>
</div>
<div id="panel-stats" class="stats-row" style="margin-top:10px"></div>
<div id="panel-attrition-note" class="note-box note-info" style="margin-bottom:14px"></div>
<div class="chart-grid">
  <div class="chart-box"><div class="ch-title">Households per Round</div><div class="ch-sub">Retained from R1 vs new entries</div><div style="height:220px"><canvas id="panelAttrChart"></canvas></div></div>
  <div class="chart-box"><div class="ch-title">Participation Pattern Distribution</div><div class="ch-sub">Top patterns (1=present, 0=absent per round)</div><div style="height:220px"><canvas id="panelPatChart"></canvas></div></div>
</div>
<div class="card" style="margin-top:6px">
  <h2>🏠 Household Panel Tracker <span id="hh-matrix-badge" class="badge badge-blue"></span></h2>
  <p style="font-size:12px;color:#666;margin-bottom:10px">Every household across all rounds — when they joined, when they left, and their full participation history. Green = interviewed, Red = absent.</p>
  <div style="display:flex;gap:8px;flex-wrap:wrap;align-items:center;margin-bottom:10px">
    <input id="hh-search" type="text" placeholder="Search by HHID or PSU…"
      style="padding:6px 10px;border:1px solid #ccc;border-radius:4px;font-size:12.5px;width:200px">
    <select id="hh-region-filter" style="padding:6px 8px;border:1px solid #ccc;border-radius:4px;font-size:12.5px">
      <option value="">All Regions</option>
    </select>
    <div id="hh-status-filter" style="display:flex;gap:4px;flex-wrap:wrap"></div>
    <div id="hh-urban-filter" style="display:flex;gap:4px"></div>
    <button onclick="window._hhDownloadCsv()" style="margin-left:auto;padding:5px 12px;background:#1a2332;color:#fff;border:none;border-radius:4px;cursor:pointer;font-size:12px">⬇ Download CSV</button>
  </div>
  <div id="hh-matrix-table"></div>
  <div id="hh-matrix-pagination" style="margin-top:8px;display:flex;gap:4px;align-items:center;flex-wrap:wrap"></div>
</div>
<div class="card" style="margin-top:6px">
  <h2>📍 PSU Coverage vs Targets <span class="badge badge-blue">Urban: 6 HH/PSU &nbsp;|&nbsp; Rural: 7 HH/PSU</span></h2>
  <div id="panel-psu-status"></div>
</div>
<div class="card">
  <h2>🗺️ Household Counts by Region, Urban/Rural &amp; Round</h2>
  <div id="panel-region-table"></div>
</div>
<div class="card">
  <h2>🔄 Round-by-Round In / Out Summary</h2>
  <p style="font-size:12px;color:#666;margin-bottom:10px">Tracked relative to R1 baseline. "New" = households not seen in R1.</p>
  <div id="panel-inout-table"></div>
</div>
<div class="card">
  <h2>🔁 Leavers vs. New Entries — Are Replacements Representative? <span id="lvn-verdict-badge" class="badge"></span></h2>
  <p style="font-size:12px;color:#666;margin-bottom:12px">For each transition, compares households that <strong>left</strong> (using their last-observed characteristics) against households that <strong>entered</strong> (using first-observed characteristics). If replacements differ from leavers, the survey composition is shifting.</p>
  <div id="panel-lvn-summary"></div>
  <div class="chart-grid" style="margin-top:14px">
    <div class="chart-box">
      <div class="ch-title">% Urban: Leavers vs New Entries</div>
      <div class="ch-sub">Are new entries more/less urban than those who left?</div>
      <div style="height:220px"><canvas id="lvnUrbanChart"></canvas></div>
    </div>
    <div class="chart-box">
      <div class="ch-title">Mean HH Size: Leavers vs New Entries</div>
      <div class="ch-sub">Are new households larger/smaller?</div>
      <div style="height:220px"><canvas id="lvnHhsizeChart"></canvas></div>
    </div>
  </div>
  <div style="margin-top:14px">
    <div class="ch-title" style="margin-bottom:6px">Regional Composition: Leavers vs New Entries</div>
    <p style="font-size:11.5px;color:#666;margin-bottom:8px">Each region's share of leavers vs share of new entries per transition. Large differences indicate regional replacement bias.</p>
    <div id="panel-lvn-region"></div>
  </div>
</div>
<div class="card">
  <h2>👥 Attrition Composition — Who Stays, Who Leaves, Who Is New?</h2>
  <p style="font-size:12px;color:#666;margin-bottom:12px">Urban/Rural split of retained, dropped, and new-entry households per round transition.</p>
  <div id="panel-attrition-profile"></div>
  <div class="chart-grid" style="margin-top:14px">
    <div class="chart-box"><div class="ch-title">Urban/Rural Mix by Group</div><div class="ch-sub">% Urban among retained vs dropped vs new (each transition)</div><div style="height:240px"><canvas id="panelAttrProfileChart"></canvas></div></div>
    <div class="chart-box"><div class="ch-title">Volume by Group per Transition</div><div class="ch-sub">Absolute HH counts</div><div style="height:240px"><canvas id="panelAttrVolumeChart"></canvas></div></div>
  </div>
</div>
<div class="card">
  <h2>⚠️ PSU Problem Tracker <span class="badge badge-red">Under-Target Only</span></h2>
  <p style="font-size:12px;color:#666;margin-bottom:8px">PSUs that are below their household target in at least one round. Sorted by most rounds under target. Over-target is not flagged.</p>
  <div id="panel-psu-filter" style="margin-bottom:10px"></div>
  <div id="panel-psu-problems"></div>
</div>
<div class="card">
  <h2>🔗 Within-PSU Refusal Clustering Risk <span class="badge badge-red">Field Action Required</span></h2>
  <p style="font-size:12px;color:#666;margin-bottom:8px">Cross-reference of under-target PSUs with round-to-round attrition rates by region. Regions flagged HIGH show both elevated attrition AND PSU coverage problems — two failure modes that compound each other and cannot both be fixed by weighting alone.</p>
  <div id="panel-refusal-risk"></div>
</div>
<div class="card">
  <h2>📅 Call Interval Tracker <span id="panel-call-badge" class="badge badge-red"></span></h2>
  <p style="font-size:12px;color:#666;margin-bottom:10px">Days between consecutive interviews for the same household. Minimum required interval is 30 days.</p>
  <div id="panel-call-summary"></div>
  <div style="margin-top:14px">
    <div class="ch-title" style="margin-bottom:6px">Households Called Too Early (&lt;30 days since last interview)</div>
    <div id="panel-call-violations"></div>
  </div>
</div>
</div>

<!-- ═══════ ALL CHANGES BY ROUND ═══════ -->
<div id="page-changes" class="page">
<h1>All Questionnaire Changes by Round</h1>
<p class="subtitle">Every new question, dropped question, wording change, skip-logic change, and code-list change across R2–R5</p>
<div class="note-purple note-box">
  Changes are detected by comparing questionnaire workbooks for each consecutive round pair. The "presence" column shows which rounds include each variable.
</div>
<div id="changes-filters" class="round-filters" style="margin-bottom:14px"></div>
<div id="changes-content"></div>
</div>

<!-- ═══════ MODULE DEEP-DIVE PAGES (generated) ═══════ -->
<div id="module-pages-container"></div>

</div><!-- /main -->

<script>
// ── DATA ──────────────────────────────────────────────────────────────────────
const DQ  = """ + DQ  + """;
const MT  = """ + MT  + """;
const AQ  = """ + AQ  + """;
const PAN = """ + PAN + """;

const ROUNDS = [1,2,3,4,5];
const RLABELS = {1:'R1 (Nov)',2:'R2 (Dec)',3:'R3 (Jan)',4:'R4 (Feb)',5:'R5 (Mar)'};
const R_COLORS = ['#3498db','#2ecc71','#e67e22','#e74c3c','#8e44ad'];
const MODULES = ['M00','M01','M02','M03','M04','M05','M06','M07','M08','M09'];
const MOD_NAMES = {
  M00:'Introduction / Passport',M01:'Demographics / Roster',M02:'Education',
  M03:'Shocks',M04:'Employment',M05:'Income',M06:'Finance',
  M07:'Health',M08:'Food & Non-Food',M09:'Opinions & Views'
};

// ── ROUTING ──────────────────────────────────────────────────────────────────
let currentPage = 'overview';
function showPage(id){
  document.querySelectorAll('.page').forEach(p=>p.classList.remove('active'));
  document.querySelectorAll('#sidebar a').forEach(a=>a.classList.remove('active'));
  const pg = document.getElementById('page-'+id);
  if(pg) pg.classList.add('active');
  const nav = document.getElementById('nav-'+id);
  if(nav) nav.classList.add('active');
  currentPage = id;
  return false;
}

// ── HELPERS ──────────────────────────────────────────────────────────────────
function hmColor(v){
  if(v===null||v===undefined) return '#eee';
  if(v<=0) return '#1a9641';
  if(v<=20) return '#a6d96a';
  if(v<=50) return '#ffffbf';
  if(v<=80) return '#fdae61';
  return '#d73027';
}
function hmText(v){
  if(v===null||v===undefined) return '—';
  return v.toFixed(0)+'%';
}
function makeBar(id,labels,datasets,extraOpts={}){
  const el=document.getElementById(id); if(!el)return;
  new Chart(el.getContext('2d'),{type:'bar',data:{labels,datasets},options:{
    responsive:true,maintainAspectRatio:false,
    plugins:{legend:{display:false,labels:{font:{size:10},boxWidth:8}},...(extraOpts.plugins||{})},
    scales:{x:{ticks:{font:{size:10}}},y:{ticks:{font:{size:10}}},...(extraOpts.scales||{})},
    ...extraOpts
  }});
}
function makeLine(id,labels,datasets,extraOpts={}){
  const el=document.getElementById(id); if(!el)return;
  new Chart(el.getContext('2d'),{type:'line',data:{labels,datasets},options:{
    responsive:true,maintainAspectRatio:false,
    plugins:{legend:{display:true,labels:{font:{size:10},boxWidth:8}},...(extraOpts.plugins||{})},
    scales:{x:{ticks:{font:{size:10}}},y:{ticks:{font:{size:10}}},...(extraOpts.scales||{})},
    ...extraOpts
  }});
}

// ── SIDEBAR MODULE LINKS ──────────────────────────────────────────────────────
function buildModNavLinks(){
  const c = document.getElementById('mod-nav-links');
  const rag_map = {};
  MODULES.forEach(m=>{rag_map[m]=DQ.module_summary[m]?.rag||'green'});
  const rag_colors = {red:'#e74c3c',yellow:'#f39c12',green:'#2ecc71'};
  c.innerHTML = MODULES.map(m=>`
    <a href="#" onclick="return showPage('mod-${m}')" id="nav-mod-${m}">
      <span class="dot" style="background:${rag_colors[rag_map[m]||'green']}"></span>
      ${m} ${MOD_NAMES[m].split('/')[0].split(' ').slice(0,2).join(' ')}
    </a>`).join('');
}

// ── OVERVIEW ─────────────────────────────────────────────────────────────────
function buildOverview(){
  buildModNavLinks();

  // Top stats
  const totalSkip = DQ.skip_issues.reduce((s,x)=>s+Object.values(x.counts_by_round).reduce((a,v)=>a+(v||0),0),0);
  const totalMand = DQ.mandatory_issues.reduce((s,x)=>s+Object.values(x.counts_by_round).reduce((a,v)=>a+(v||0),0),0);
  const totalOOR  = DQ.oor_issues.reduce((s,x)=>s+Object.values(x.counts||{}).reduce((a,v)=>a+(v||0),0),0);

  document.getElementById('nc-skip').textContent = totalSkip;
  document.getElementById('nc-mand').textContent = totalMand;
  if(totalSkip>0) document.getElementById('nc-skip').className='nav-count red';
  if(totalMand>0) document.getElementById('nc-mand').className='nav-count yellow';

  document.getElementById('ov-stats').innerHTML = `
    <div class="stat-box ${totalSkip>0?'red':'green'}"><div class="num">${totalSkip}</div><div class="lbl">Skip violations</div></div>
    <div class="stat-box ${totalMand>0?'yellow':'green'}"><div class="num">${totalMand}</div><div class="lbl">Mandatory missing</div></div>
    <div class="stat-box ${totalOOR>0?'yellow':'green'}"><div class="num">${totalOOR}</div><div class="lbl">Out-of-range values</div></div>
    <div class="stat-box blue"><div class="num">${MODULES.length}</div><div class="lbl">Modules tracked</div></div>
    <div class="stat-box blue"><div class="num">5</div><div class="lbl">Rounds (R1–R5)</div></div>
    <div class="stat-box purple"><div class="num">${countAllQChanges()}</div><div class="lbl">Questionnaire changes</div></div>
  `;

  // Module grid
  const mg = document.getElementById('mod-grid');
  mg.innerHTML = MODULES.map(m=>{
    const s = DQ.module_summary[m]||{};
    const rag = s.rag||'green';
    const ragLabel = {red:'⚠ Issues',yellow:'⚡ Watch',green:'✓ OK'};
    const ragChipBg = {red:'#fde',yellow:'#fff3cd',green:'#d4edda'};
    const ragChipColor = {red:'#c0392b',yellow:'#856404',green:'#155724'};

    // Count questionnaire changes for this module
    const rows = MT[m]||[];
    const newQ = rows.filter(r=>r.status&&r.status.startsWith('New')).length;
    const droppedQ = rows.filter(r=>r.status&&r.status.startsWith('Dropped')).length;
    const changedQ = rows.filter(r=>r.title_changes||r.skip_changes).length;

    return `<div class="mod-card ${rag}" onclick="showPage('mod-${m}')">
      <div class="rag-chip" style="background:${ragChipBg[rag]};color:${ragChipColor[rag]}">${ragLabel[rag]}</div>
      <div class="mname">${m} – ${MOD_NAMES[m]}</div>
      <div class="mstat ${s.n_skip_violations>0?'warn':''}">Skip violations: ${s.n_skip_violations||0}</div>
      <div class="mstat ${s.n_mandatory_missing>0?'warn':''}">Mandatory missing: ${s.n_mandatory_missing||0}</div>
      <div class="mstat">Avg missing: ${(s.avg_missing_pct||0).toFixed(1)}%</div>
      ${newQ?`<div class="mstat warn">+${newQ} new question${newQ>1?'s':''}</div>`:''}
      ${droppedQ?`<div class="mstat warn">−${droppedQ} dropped</div>`:''}
      ${changedQ?`<div class="mstat">~${changedQ} changed</div>`:''}
    </div>`;
  }).join('');

  // Sample chart
  setTimeout(()=>{
    const sc = DQ.sample_counts;
    makeBar('sampleChart', MODULES,
      ROUNDS.map((r,i)=>({
        label: RLABELS[r],
        data: MODULES.map(m=>sc[m]?sc[m][r]??0:0),
        backgroundColor: R_COLORS[i], borderRadius:3
      })),
      {plugins:{legend:{display:true,labels:{font:{size:10},boxWidth:8}}},
       scales:{x:{ticks:{font:{size:10},maxRotation:0}},y:{ticks:{font:{size:10}}}}}
    );
  },50);

  buildChangeSummaryBar();
}

function countAllQChanges(){
  let n=0;
  MODULES.forEach(m=>{
    (MT[m]||[]).forEach(row=>{
      if(row.status&&(row.status.startsWith('New')||row.status.startsWith('Dropped'))) n++;
      if(row.title_changes) n++;
      if(row.skip_changes) n++;
    });
  });
  return n;
}

function buildChangeSummaryBar(){
  const container = document.getElementById('change-summary-bar');
  // Count changes by round
  const rounds = ['R2','R3','R4','R5'];
  const prev   = {R2:'R1',R3:'R2',R4:'R3',R5:'R4'};
  let html = '<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:10px">';
  rounds.forEach(rnd=>{
    let newQ=0,dropped=0,changed=0;
    MODULES.forEach(m=>{
      (MT[m]||[]).forEach(row=>{
        const inC = row[`in_${rnd}`]==='✓';
        const inP = row[`in_${prev[rnd]}`]==='✓';
        const rIdx = ['R1','R2','R3','R4','R5'].indexOf(rnd);
        const isFirst = ['R1','R2','R3','R4','R5'].slice(0,rIdx).every(pr=>row[`in_${pr}`]!=='✓');
        if(inC&&isFirst) newQ++;
        if(!inC&&inP) dropped++;
        if(inC&&inP&&(row.title_changes||row.skip_changes)) changed++;
      });
    });
    html += `<div class="card" style="margin:0;padding:14px">
      <div style="font-weight:700;font-size:14px;color:#1a2332;margin-bottom:8px">${rnd} vs ${prev[rnd]}</div>
      ${newQ?`<div class="chg-tag chg-new" style="margin-bottom:4px">+${newQ} new question${newQ>1?'s':''}</div><br>`:''}
      ${dropped?`<div class="chg-tag chg-drop" style="margin-bottom:4px">−${dropped} dropped</div><br>`:''}
      ${changed?`<div class="chg-tag chg-title" style="margin-bottom:4px">~${changed} changed</div>`:''}
      ${!newQ&&!dropped&&!changed?'<span style="font-size:12px;color:#888">No structural changes</span>':''}
    </div>`;
  });
  html += '</div>';
  container.innerHTML = html;
}

// ── SKIP VIOLATIONS ──────────────────────────────────────────────────────────
function buildSkip(){
  const issues = DQ.skip_issues;
  const withViolations = issues.filter(x=>Object.values(x.counts_by_round).some(v=>v>0));
  const total = issues.reduce((s,x)=>s+Object.values(x.counts_by_round).reduce((a,v)=>a+(v||0),0),0);

  document.getElementById('skip-stats').innerHTML = `
    <div class="stat-box ${total>0?'red':'green'}"><div class="num">${total}</div><div class="lbl">Total violations</div></div>
    <div class="stat-box ${withViolations.length>0?'yellow':'green'}"><div class="num">${withViolations.length}</div><div class="lbl">Checks with violations</div></div>
    <div class="stat-box blue"><div class="num">${issues.length}</div><div class="lbl">Total checks</div></div>
  `;

  const list = document.getElementById('skip-list');
  list.innerHTML = issues.map(x=>{
    const total = Object.values(x.counts_by_round).reduce((a,v)=>a+(v||0),0);
    const sev = x.severity||'medium';
    const icon = sev==='high'?'🔴':'🟡';
    const pills = ROUNDS.map(r=>{
      const v=x.counts_by_round[r]||0, p=x.pct_by_round?.[r]||0;
      const cls = v>0?'vpill-red':v===0&&x.counts_by_round[r]!==null?'vpill-green':'vpill-grey';
      return `<span class="vpill ${cls}">R${r}: ${v} (${p.toFixed(1)}%)</span>`;
    }).join('');
    return `<div class="viol-row ${sev}">
      <div class="viol-icon">${icon}</div>
      <div class="viol-text">
        <strong>${x.module}: ${x.rule}</strong>
        <div class="viol-path">${x.variable}</div>
        <div class="viol-note">${x.note||''}</div>
        <div class="viol-pills">${pills}</div>
      </div>
    </div>`;
  }).join('');

  setTimeout(()=>{
    const charts = document.getElementById('skip-charts');
    withViolations.forEach((x,i)=>{
      const cid = `sc_${i}`;
      charts.innerHTML += `<div class="chart-box flagged">
        <div class="ch-title">${x.module}: ${x.variable.split('→')[0].trim()}</div>
        <div class="ch-sub">${x.rule}</div>
        <div style="height:160px"><canvas id="${cid}"></canvas></div>
      </div>`;
      setTimeout(()=>makeBar(cid, ROUNDS.map(r=>`R${r}`), [{
        label:'Violations', data:ROUNDS.map(r=>x.counts_by_round[r]||0),
        backgroundColor: ROUNDS.map(r=>(x.counts_by_round[r]||0)>0?'#e74c3c':'#2ecc71'), borderRadius:4
      }]),30);
    });
  },50);
}

// ── MANDATORY MISSING ────────────────────────────────────────────────────────
function buildMandatory(){
  const issues = DQ.mandatory_issues;
  const withFails = issues.filter(x=>Object.values(x.counts_by_round).some(v=>v>0));
  const total = issues.reduce((s,x)=>s+Object.values(x.counts_by_round).reduce((a,v)=>a+(v||0),0),0);

  document.getElementById('mand-stats').innerHTML = `
    <div class="stat-box ${total>0?'yellow':'green'}"><div class="num">${total}</div><div class="lbl">Total failures</div></div>
    <div class="stat-box blue"><div class="num">${issues.length}</div><div class="lbl">Total checks</div></div>
  `;

  document.getElementById('mand-list').innerHTML = issues.map(x=>{
    const sev = x.severity||'medium';
    const pills = ROUNDS.map(r=>{
      const v=x.counts_by_round[r]||0;
      const cls=v>0?'vpill-red':v===0&&x.counts_by_round[r]!==null?'vpill-green':'vpill-grey';
      return `<span class="vpill ${cls}">R${r}: ${v}</span>`;
    }).join('');
    return `<div class="viol-row ${sev}">
      <div class="viol-icon">${sev==='high'?'🔴':'🟡'}</div>
      <div class="viol-text">
        <strong>${x.module}: ${x.rule}</strong>
        <div class="viol-path">${x.variable}</div>
        <div class="viol-note">${x.note||''}</div>
        <div class="viol-pills">${pills}</div>
      </div>
    </div>`;
  }).join('');
}

// ── OOR ──────────────────────────────────────────────────────────────────────
function buildOOR(){
  const issues = DQ.oor_issues;
  const total = issues.reduce((s,x)=>s+Object.values(x.counts||{}).reduce((a,v)=>a+(v||0),0),0);
  document.getElementById('oor-stats').innerHTML = `
    <div class="stat-box ${total>0?'yellow':'green'}"><div class="num">${total}</div><div class="lbl">Total out-of-range</div></div>
    <div class="stat-box blue"><div class="num">${issues.length}</div><div class="lbl">Variables checked</div></div>
  `;
  document.getElementById('oor-list').innerHTML = issues.map(x=>{
    const sev=x.severity||'medium';
    const pills = ROUNDS.map(r=>{
      const v=x.counts?.[r]||0;
      const cls=v>0?'vpill-red':'vpill-green';
      return `<span class="vpill ${cls}">R${r}: ${v}</span>`;
    }).join('');
    return `<div class="viol-row ${sev}">
      <div class="viol-icon">${sev==='high'?'🔴':'🟡'}</div>
      <div class="viol-text">
        <strong>${x.module}: ${x.label||x.variable}</strong>
        <div class="viol-path">${x.variable} — ${x.rule}</div>
        <div class="viol-note">${x.note||''}</div>
        <div class="viol-pills">${pills}</div>
      </div>
    </div>`;
  }).join('');

  setTimeout(()=>{
    const charts = document.getElementById('oor-charts');
    issues.filter(x=>Object.values(x.counts||{}).some(v=>v>0)).forEach((x,i)=>{
      const cid=`oor_${i}`;
      charts.innerHTML += `<div class="chart-box warn">
        <div class="ch-title">${x.module}: ${x.label||x.variable}</div>
        <div class="ch-sub">${x.rule}</div>
        <div style="height:150px"><canvas id="${cid}"></canvas></div>
      </div>`;
      setTimeout(()=>makeBar(cid,ROUNDS.map(r=>`R${r}`),[{
        label:'Out-of-range',data:ROUNDS.map(r=>x.counts?.[r]||0),
        backgroundColor:ROUNDS.map(r=>(x.counts?.[r]||0)>0?'#f39c12':'#2ecc71'),borderRadius:4
      }]),30);
    });
  },50);
}

// ── PANEL TRACKING ───────────────────────────────────────────────────────────
function buildPanel(){
  if(!PAN || !PAN.attrition) return;
  const p = PAN;
  const rounds = [1,2,3,4,5];
  const rLabels = rounds.map(r=>'R'+r);

  // ── Attrition Bias Analysis ──
  const bias = p.attrition_bias;
  if(bias){
    // ── Banner ──────────────────────────────────────────────────────────────
    const bannerEl = document.getElementById('panel-bias-banner');
    if(bannerEl){
      const colors = {HIGH:'#e74c3c', MODERATE:'#e67e22', LOW:'#27ae60'};
      const icons  = {HIGH:'🔴', MODERATE:'🟡', LOW:'🟢'};
      const msgs   = {
        HIGH:     `HIGH — Significant selection bias in ${bias.n_biased_trans} of ${(bias.transitions||[]).length} round-to-round transitions. Households that stay are systematically different from those that leave in multiple waves.`,
        MODERATE: `MODERATE — Differences detected in ${bias.n_biased_trans} transition(s). Panel may be selectively retaining certain household types.`,
        LOW:      'LOW — No significant differences detected between retained and dropped households in any transition.',
      };
      const wvars = (bias.worst_vars||[]);
      bannerEl.innerHTML=`<div style="background:${colors[bias.verdict]}18;border-left:4px solid ${colors[bias.verdict]};padding:12px 16px;border-radius:4px;margin-bottom:12px">
        <strong style="color:${colors[bias.verdict]};font-size:13px">${icons[bias.verdict]} Selection Bias Verdict: ${bias.verdict}</strong>
        <p style="margin:4px 0 0 0;font-size:12.5px;color:#333">${msgs[bias.verdict]}</p>
        ${wvars.length ? `<p style="margin:4px 0 0 0;font-size:12px;color:#555">Variables significant in ≥1 transition: <strong>${wvars.join(', ')}</strong></p>` : ''}
      </div>`;
    }

    // ── Badge ────────────────────────────────────────────────────────────────
    const badgeEl = document.getElementById('panel-bias-verdict-badge');
    if(badgeEl){
      const bc={HIGH:'badge-red',MODERATE:'badge-yellow',LOW:'badge-green'};
      badgeEl.className=`badge ${bc[bias.verdict]||'badge-blue'}`;
      badgeEl.textContent=bias.verdict+' CONCERN';
    }

    // ── Per-transition comparison table (tabbed) ──────────────────────────
    const biasTableEl = document.getElementById('panel-bias-table');
    const bTrans = bias.transitions||[];
    if(biasTableEl && bTrans.length){
      const VAR_LABELS = {
        urban:'% Urban', hhsize:'HH Size (mean)', female:'% Female head',
        employed:'% Employed', has_account:'% Has bank account',
        has_savings:'% Has savings',
      };
      // Tab buttons
      let tabHtml=`<div style="display:flex;gap:6px;margin-bottom:10px;flex-wrap:wrap">`;
      bTrans.forEach((t,idx)=>{
        const bc2=t.verdict==='BIASED'?'#e74c3c':'#27ae60';
        const isFirst=(idx===0);
        tabHtml+=`<button onclick="showBiasTab(${idx})" id="bias-tab-btn-${idx}"
          style="padding:5px 13px;border:2px solid ${bc2};border-radius:4px;
                 background:${isFirst?bc2:'transparent'};color:${isFirst?'#fff':bc2};
                 cursor:pointer;font-size:12px;font-weight:600">
          ${t.label} ${t.verdict==='BIASED'?'⚠️':'✓'}
        </button>`;
      });
      tabHtml+=`</div>`;

      // Per-transition panels
      let panelsHtml='';
      bTrans.forEach((t,idx)=>{
        const vars=t.vars||{};
        const varKeys=['urban','hhsize','female','employed','has_account'];
        panelsHtml+=`<div id="bias-panel-${idx}" style="display:${idx===0?'block':'none'}">
          <p style="font-size:11.5px;color:#666;margin:0 0 8px">
            Comparing <strong>${t.n_retained}</strong> retained vs
            <strong>${t.n_dropped}</strong> dropped households
            (n prev round = ${t.n_prev}) — characteristics from R${t.from_round}.
          </p>
          <div style="overflow-x:auto">
          <table style="width:100%;border-collapse:collapse;font-size:12.5px;min-width:540px">
          <thead><tr style="background:#1a2332;color:#fff">
            <th style="padding:7px 10px;text-align:left">Variable</th>
            <th style="padding:7px 10px;text-align:center">Retained</th>
            <th style="padding:7px 10px;text-align:center">Dropped</th>
            <th style="padding:7px 10px;text-align:center">Diff</th>
            <th style="padding:7px 10px;text-align:center">Test stat</th>
            <th style="padding:7px 10px;text-align:center">p-value</th>
            <th style="padding:7px 10px;text-align:center">Sig.</th>
          </tr></thead><tbody>`;

        varKeys.forEach((vk,ri)=>{
          const v=vars[vk]; if(!v) return;
          const isSig=(v.p<0.05);
          const rowBg=isSig?'#fff3cd':(ri%2===0?'#f8f9fa':'#fff');
          const sigClr=v.p<0.05?'#e74c3c':v.p<0.10?'#e67e22':'#555';
          const isCont=(vk==='hhsize');
          const rDisp=isCont?v.retained:(v.retained+'%');
          const dDisp=isCont?v.dropped:(v.dropped+'%');
          const rawDiff=v.diff;
          const diffSign=rawDiff>0?'+':'';
          const diffUnit=isCont?'':' pp';
          const diffClr=Math.abs(rawDiff)>(isCont?0.3:5)?'#e74c3c':'#555';
          const statDisp=isCont?`t=${v.t}`:`χ²=${v.chi2}`;
          panelsHtml+=`<tr style="background:${rowBg}">
            <td style="padding:7px 10px;font-weight:600">${VAR_LABELS[vk]||vk}${isSig?' ⚠️':''}</td>
            <td style="padding:7px 10px;text-align:center">${rDisp}</td>
            <td style="padding:7px 10px;text-align:center">${dDisp}</td>
            <td style="padding:7px 10px;text-align:center;color:${diffClr}">${diffSign}${rawDiff}${diffUnit}</td>
            <td style="padding:7px 10px;text-align:center;font-family:monospace;font-size:11px">${statDisp}</td>
            <td style="padding:7px 10px;text-align:center;font-family:monospace;font-size:11px;color:${sigClr}">${v.p}</td>
            <td style="padding:7px 10px;text-align:center;font-weight:700;color:${sigClr}">${v.sig}</td>
          </tr>`;
        });

        // Region row
        const reg=vars['region'];
        if(reg){
          const isSig=(reg.p<0.05);
          const rowBg=isSig?'#fff3cd':'#f8f9fa';
          const sigClr=reg.p<0.05?'#e74c3c':reg.p<0.10?'#e67e22':'#555';
          panelsHtml+=`<tr style="background:${rowBg}">
            <td style="padding:7px 10px;font-weight:600">Region (composition)${isSig?' ⚠️':''}</td>
            <td style="padding:7px 10px;text-align:center;color:#888" colspan="3">(see chart & heatmap below)</td>
            <td style="padding:7px 10px;text-align:center;font-family:monospace;font-size:11px">χ²=${reg.chi2}, V=${reg.v}</td>
            <td style="padding:7px 10px;text-align:center;font-family:monospace;font-size:11px;color:${sigClr}">${reg.p}</td>
            <td style="padding:7px 10px;text-align:center;font-weight:700;color:${sigClr}">${reg.sig}</td>
          </tr>`;
        }

        panelsHtml+=`</tbody></table></div>
          <p style="font-size:11px;color:#888;margin-top:6px">*** p&lt;0.001 &nbsp;** p&lt;0.01 &nbsp;* p&lt;0.05 &nbsp;† p&lt;0.10 &nbsp;ns=not significant</p>
        </div>`;
      });

      biasTableEl.innerHTML=tabHtml+panelsHtml;

      // Tab switching + chart update
      let _biasRegChartInst=null;
      window._biasUpdateRegChart=function(idx){
        const t=bTrans[idx]; if(!t) return;
        const rr=(t.reg_ret_rates||[]).slice().sort((a,b)=>(a.pct_retained||0)-(b.pct_retained||0));
        const labels=rr.map(r=>r.name);
        const vals=rr.map(r=>r.pct_retained||0);
        const colors2=vals.map(v=>v<50?'#e74c3c':v<65?'#e67e22':v<75?'#f39c12':'#27ae60');
        const lbl=document.getElementById('bias-reg-chart-label');
        if(lbl) lbl.textContent=`(${t.label})`;
        if(_biasRegChartInst){ _biasRegChartInst.destroy(); _biasRegChartInst=null; }
        const canvas=document.getElementById('panelBiasRegChart');
        if(!canvas) return;
        _biasRegChartInst=new Chart(canvas,{
          type:'bar',
          data:{
            labels:labels,
            datasets:[{
              label:`% Retained ${t.label}`,
              data:vals,
              backgroundColor:colors2,
              borderRadius:3,
            }]
          },
          options:{
            indexAxis:'y',
            responsive:true, maintainAspectRatio:false,
            plugins:{
              legend:{display:false},
              tooltip:{callbacks:{label:c=>{
                const r=rr[c.dataIndex];
                return `${c.raw}% retained (n=${r.n}, ret=${r.retained}, drop=${r.dropped})`;
              }}}
            },
            scales:{
              x:{min:0,max:100,title:{display:true,text:'% Retained',font:{size:11}},ticks:{callback:v=>v+'%'}},
              y:{ticks:{font:{size:10.5}}}
            }
          }
        });
      };

      window.showBiasTab=function(idx){
        bTrans.forEach((_,i)=>{
          const panel=document.getElementById('bias-panel-'+i);
          const btn=document.getElementById('bias-tab-btn-'+i);
          if(panel) panel.style.display=(i===idx)?'block':'none';
          if(btn){
            const bc2=bTrans[i].verdict==='BIASED'?'#e74c3c':'#27ae60';
            btn.style.background=(i===idx)?bc2:'transparent';
            btn.style.color=(i===idx)?'#fff':bc2;
          }
        });
        window._biasUpdateRegChart(idx);
      };
      window._biasUpdateRegChart(0);
    }

    // ── Composition drift chart (unchanged — uses bias.comp_drift) ─────────
    const driftData = [...(bias.comp_drift||[])].sort((a,b)=>a.drift-b.drift);
    const driftColors = driftData.map(r=>r.drift<0?'#e74c3c':'#27ae60');
    new Chart(document.getElementById('panelBiasDriftChart'),{
      type:'bar',
      data:{
        labels: driftData.map(r=>r.region_name),
        datasets:[{
          label:'Share change (pp)',
          data: driftData.map(r=>r.drift),
          backgroundColor: driftColors,
          borderRadius:3,
        }]
      },
      options:{
        indexAxis:'y',
        responsive:true, maintainAspectRatio:false,
        plugins:{
          legend:{display:false},
          tooltip:{callbacks:{label:c=>{
            const r=driftData[c.dataIndex];
            const rounds=Object.keys(r.pct_per_round||{}).sort();
            const r1=r.pct_per_round['1']||0;
            const rLast=r.pct_per_round[rounds[rounds.length-1]]||0;
            return `${c.raw>0?'+':''}${c.raw}pp  (R1=${r1}%  → R${rounds[rounds.length-1]}=${rLast}%)`;
          }}}
        },
        scales:{
          x:{title:{display:true,text:'Share change (pp)',font:{size:11}}},
          y:{ticks:{font:{size:10.5}}}
        }
      }
    });

    // ── Retention heatmap: Region × Transition ────────────────────────────
    const hmEl = document.getElementById('panel-trans-heatmap');
    if(hmEl && bTrans.length){
      // Collect all regions across all transitions
      const regKeySet=new Set();
      const regNameMap={};
      bTrans.forEach(t=>(t.reg_ret_rates||[]).forEach(r=>{
        const k=String(r.region);
        regKeySet.add(k);
        regNameMap[k]=r.name;
      }));
      const allRegKeys=[...regKeySet].sort((a,b)=>parseInt(a)-parseInt(b));

      let html=`<div style="overflow-x:auto"><table style="border-collapse:collapse;font-size:11.5px;min-width:480px">
        <thead><tr style="background:#1a2332;color:#fff">
          <th style="padding:6px 10px;text-align:left">Region</th>
          ${bTrans.map(t=>{
            const bc2=t.verdict==='BIASED'?'#e74c3c50':'#27ae6030';
            return `<th style="padding:6px 8px;text-align:center;background:${bc2}">${t.label}${t.verdict==='BIASED'?' ⚠️':''}</th>`;
          }).join('')}
        </tr></thead><tbody>`;

      allRegKeys.forEach((rk,i)=>{
        const bg=i%2===0?'#f8f9fa':'#fff';
        html+=`<tr style="background:${bg}">
          <td style="padding:5px 10px;font-weight:600">${regNameMap[rk]||rk}</td>`;
        bTrans.forEach(t=>{
          const rd=(t.reg_ret_rates||[]).find(r=>String(r.region)===rk);
          const pct=rd?rd.pct_retained:null;
          const cellBg=pct===null?'#f0f0f0':pct<50?'#fde8e8':pct<65?'#fff3cd':pct<75?'#fef9e7':'#d4edda';
          const textClr=pct===null?'#aaa':pct<50?'#c0392b':pct<65?'#856404':'#155724';
          const tip=rd?`title="${rd.retained} ret / ${rd.dropped} drop (n=${rd.n})"` :'';
          html+=`<td style="padding:5px 8px;text-align:center;background:${cellBg};color:${textClr};font-weight:600" ${tip}>
            ${pct!==null?pct+'%':'—'}</td>`;
        });
        html+=`</tr>`;
      });
      html+=`</tbody></table></div>`;
      hmEl.innerHTML=html;
    }
  }

  // ── Stats row ──
  const statsEl = document.getElementById('panel-stats');
  if(statsEl){
    const retPct = p.attrition[4] ? Math.round(p.attrition[4].retained/p.attrition[0].n*100) : '?';
    statsEl.innerHTML = [
      {n:p.all_hhs,    lbl:'Unique HHs (all rounds)', cls:'purple'},
      {n:p.attrition[0].n, lbl:'R1 Baseline', cls:'blue'},
      {n:p.always_in,  lbl:'Present in all 5 rounds', cls:'green'},
      {n:p.r1_only,    lbl:'R1 only (never seen again)', cls:'yellow'},
      {n:p.never_r1,   lbl:'Never in R1 (new entries)', cls:''},
      {n:retPct+'%',   lbl:'R1 HHs retained by R5', cls:retPct<60?'red':'green'},
    ].map(s=>`<div class="stat-box ${s.cls}"><div class="num">${s.n}</div><div class="lbl">${s.lbl}</div></div>`).join('');
  }

  // ── Attrition note ──
  const noteEl = document.getElementById('panel-attrition-note');
  if(noteEl){
    const a5 = p.attrition[4];
    noteEl.innerHTML = `<strong>R5 retention:</strong> ${a5.retained} of ${p.attrition[0].n} R1 baseline households (${Math.round(a5.retained/p.attrition[0].n*100)}%) were re-interviewed in Round 5. ${a5.new_in} households appear in R5 that were not in the R1 sample.`;
  }

  // ── Attrition stacked bar ──
  const retArr  = p.attrition.map(r=>r.retained);
  const newArr  = p.attrition.map(r=>r.new_in);
  const dropArr = p.attrition.map(r=>r.dropped);
  new Chart(document.getElementById('panelAttrChart'),{
    type:'bar',
    data:{
      labels: rLabels,
      datasets:[
        {label:'Retained from R1', data:retArr,  backgroundColor:'#2980b9'},
        {label:'New (not in R1)',   data:newArr,  backgroundColor:'#27ae60'},
      ]
    },
    options:{responsive:true,maintainAspectRatio:false,
      plugins:{legend:{position:'bottom',labels:{font:{size:11}}}},
      scales:{x:{stacked:true},y:{stacked:true,beginAtZero:true,
        title:{display:true,text:'Households',font:{size:11}}}}}
  });

  // ── Pattern distribution bar ──
  const topPat = p.pattern_dist.slice(0,10);
  new Chart(document.getElementById('panelPatChart'),{
    type:'bar',
    data:{
      labels: topPat.map(x=>x.pattern),
      datasets:[{label:'HHs', data:topPat.map(x=>x.n),
        backgroundColor: topPat.map(x=>{
          const ones = (x.pattern.match(/1/g)||[]).length;
          return ones===5?'#27ae60':ones>=3?'#2980b9':ones===1?'#e67e22':'#e74c3c';
        })}]
    },
    options:{responsive:true,maintainAspectRatio:false,
      plugins:{legend:{display:false},
        tooltip:{callbacks:{label:c=>`${c.raw} HHs`}}},
      scales:{x:{ticks:{font:{size:10}}},
              y:{beginAtZero:true,title:{display:true,text:'Households',font:{size:11}}}}}
  });

  // ── Household panel tracker ───────────────────────────────────────────────
  if(p.hh_matrix && p.hh_matrix.length){
    const HHM = p.hh_matrix;
    const PAGE_SIZE = 50;
    const STATUS_COLORS = {
      'All Rounds':       {bg:'#d4edda', txt:'#155724'},
      'Left Panel':       {bg:'#fde8e8', txt:'#7b1c1c'},
      'New Entry':        {bg:'#cce5ff', txt:'#004085'},
      'New Entry → Left': {bg:'#fff3cd', txt:'#856404'},
      'Intermittent':     {bg:'#e2e3e5', txt:'#383d41'},
    };
    const ROUNDS_DISP = [1,2,3,4,5];

    // Badge
    const matBadge = document.getElementById('hh-matrix-badge');
    if(matBadge) matBadge.textContent = `${HHM.length} households`;

    // Populate region dropdown
    const regSel = document.getElementById('hh-region-filter');
    if(regSel){
      const regSet = {};
      HHM.forEach(h=>{if(h.region) regSet[h.region]=h.region_name;});
      Object.keys(regSet).sort((a,b)=>parseInt(a)-parseInt(b)).forEach(k=>{
        const opt=document.createElement('option');
        opt.value=k; opt.textContent=regSet[k];
        regSel.appendChild(opt);
      });
      regSel.addEventListener('change',()=>{_hhState.region=regSel.value;_hhState.page=0;renderHH();});
    }

    // Status filter buttons
    const statusFilterEl = document.getElementById('hh-status-filter');
    const STATUS_LIST = ['All Rounds','Left Panel','New Entry','New Entry → Left','Intermittent'];
    if(statusFilterEl){
      const counts = {};
      STATUS_LIST.forEach(s=>{counts[s]=HHM.filter(h=>h.status===s).length;});
      [['All',''],...STATUS_LIST.map(s=>[s,s])].forEach(([label,val])=>{
        const n = val===''?HHM.length:counts[val]||0;
        const btn=document.createElement('button');
        btn.textContent=`${label} (${n})`;
        btn.className='round-btn'+(val===''?' active':'');
        btn.style.fontSize='11px';
        btn.addEventListener('click',()=>{
          statusFilterEl.querySelectorAll('button').forEach(b=>b.classList.remove('active'));
          btn.classList.add('active');
          _hhState.status=val; _hhState.page=0; renderHH();
        });
        statusFilterEl.appendChild(btn);
      });
    }

    // Urban/Rural filter
    const urbanFilterEl = document.getElementById('hh-urban-filter');
    if(urbanFilterEl){
      [['All',''],['Urban','1'],['Rural','2']].forEach(([label,val])=>{
        const btn=document.createElement('button');
        btn.textContent=label; btn.className='round-btn'+(val===''?' active':'');
        btn.style.fontSize='11px';
        btn.addEventListener('click',()=>{
          urbanFilterEl.querySelectorAll('button').forEach(b=>b.classList.remove('active'));
          btn.classList.add('active');
          _hhState.urban=val; _hhState.page=0; renderHH();
        });
        urbanFilterEl.appendChild(btn);
      });
    }

    // Search box
    const searchEl = document.getElementById('hh-search');
    if(searchEl) searchEl.addEventListener('input',()=>{_hhState.query=searchEl.value.trim().toLowerCase();_hhState.page=0;renderHH();});

    // State
    const _hhState = {page:0, status:'', region:'', urban:'', query:''};

    function getFiltered(){
      return HHM.filter(h=>{
        if(_hhState.status && h.status!==_hhState.status) return false;
        if(_hhState.region && String(h.region)!==_hhState.region) return false;
        if(_hhState.urban && String(h.urban)!==_hhState.urban) return false;
        if(_hhState.query){
          const q=_hhState.query;
          if(!String(h.hhid).includes(q) && !h.psu.includes(q)) return false;
        }
        return true;
      });
    }

    function renderHH(){
      const filtered = getFiltered();
      const total = filtered.length;
      const start = _hhState.page * PAGE_SIZE;
      const page  = filtered.slice(start, start+PAGE_SIZE);
      const tableEl  = document.getElementById('hh-matrix-table');
      const pageEl   = document.getElementById('hh-matrix-pagination');

      // Table
      let html=`<p style="font-size:11.5px;color:#555;margin:0 0 6px">Showing ${Math.min(start+1,total)}–${Math.min(start+PAGE_SIZE,total)} of ${total} households</p>
        <div style="overflow-x:auto">
        <table style="width:100%;border-collapse:collapse;font-size:12px;min-width:640px">
        <thead><tr style="background:#1a2332;color:#fff">
          <th style="padding:6px 9px;text-align:left;cursor:pointer">HHID</th>
          <th style="padding:6px 9px;text-align:left">PSU</th>
          <th style="padding:6px 9px;text-align:left">Region</th>
          <th style="padding:6px 8px;text-align:center">Type</th>
          ${ROUNDS_DISP.map(r=>`<th style="padding:6px 8px;text-align:center;min-width:48px">R${r}${r>1?'<br><span style="font-weight:normal;font-size:9px;opacity:0.8">days</span>':''}</th>`).join('')}
          <th style="padding:6px 9px;text-align:center">Rounds</th>
          <th style="padding:6px 9px;text-align:center">Status</th>
        </tr></thead><tbody>`;

      page.forEach((h,i)=>{
        const rowBg = i%2===0?'#f8f9fa':'#fff';
        const uTag = h.urban===1
          ?`<span style="background:#cce5ff;color:#004085;border-radius:3px;padding:1px 5px;font-size:10px">Urban</span>`
          :`<span style="background:#d4edda;color:#155724;border-radius:3px;padding:1px 5px;font-size:10px">Rural</span>`;
        const sc = STATUS_COLORS[h.status]||{bg:'#eee',txt:'#333'};
        const dg = h.days_gap||{};
        const roundCells = ROUNDS_DISP.map(r=>{
          const present = h.presence[String(r)]===1;
          const days = dg[String(r)]!=null ? dg[String(r)] : null;
          // Cell colour when present: driven by days gap (R1 has no gap)
          let cellBg, cellTxt;
          if(!present){
            cellBg='#fde8e8'; cellTxt='#c0392b';
          } else if(r===1 || days===null){
            cellBg='#d4edda'; cellTxt='#155724';       // first appearance
          } else if(days < 30){
            cellBg='#e74c3c'; cellTxt='#fff';           // violation — red
          } else if(days < 60){
            cellBg='#fff3cd'; cellTxt='#856404';        // tight — amber
          } else {
            cellBg='#d4edda'; cellTxt='#155724';        // normal — green
          }
          const daysLabel = (r>1 && days!==null)
            ? `<div style="font-size:9.5px;font-weight:400;margin-top:1px;opacity:0.85">${days}d</div>`
            : (r===1 && present ? `<div style="font-size:9px;opacity:0.6;margin-top:1px">—</div>` : '');
          const tick = present ? '✓' : '✗';
          return `<td style="padding:3px 5px;text-align:center;background:${cellBg};color:${cellTxt};font-weight:700;font-size:13px;line-height:1.2">
            ${tick}${daysLabel}</td>`;
        }).join('');
        html+=`<tr style="background:${rowBg}">
          <td style="padding:5px 9px;font-family:monospace;font-size:11px;font-weight:600">${h.hhid}</td>
          <td style="padding:5px 9px;font-family:monospace;font-size:10.5px;color:#555">${h.psu}</td>
          <td style="padding:5px 9px;font-size:11.5px">${h.region_name}</td>
          <td style="padding:5px 8px;text-align:center">${uTag}</td>
          ${roundCells}
          <td style="padding:5px 9px;text-align:center;font-weight:700">${h.rounds_present}/5</td>
          <td style="padding:5px 9px;text-align:center">
            <span style="background:${sc.bg};color:${sc.txt};border-radius:3px;padding:2px 7px;font-size:10.5px;font-weight:600;white-space:nowrap"
              title="First: R${h.first_round||'?'}  Last: R${h.last_round||'?'}">${h.status}</span>
          </td>
        </tr>`;
      });
      html+=`</tbody></table></div>
        <div style="display:flex;gap:14px;flex-wrap:wrap;margin-top:7px;font-size:11px;align-items:center">
          <span style="color:#888">Days since previous interview:</span>
          <span><span style="background:#d4edda;color:#155724;padding:1px 7px;border-radius:3px;font-weight:600">✓ —</span> First appearance</span>
          <span><span style="background:#d4edda;color:#155724;padding:1px 7px;border-radius:3px;font-weight:600">✓ 60d+</span> Normal</span>
          <span><span style="background:#fff3cd;color:#856404;padding:1px 7px;border-radius:3px;font-weight:600">✓ 30–59d</span> Tight</span>
          <span><span style="background:#e74c3c;color:#fff;padding:1px 7px;border-radius:3px;font-weight:600">✓ &lt;30d</span> Violation</span>
          <span><span style="background:#fde8e8;color:#c0392b;padding:1px 7px;border-radius:3px;font-weight:600">✗</span> Absent</span>
          <span style="color:#aaa">| Hover status badge for first/last round</span>
        </div>`;
      if(tableEl) tableEl.innerHTML=html;

      // Pagination
      const totalPages = Math.ceil(total/PAGE_SIZE);
      let pHtml='';
      if(totalPages>1){
        pHtml+=`<span style="font-size:12px;color:#555">Page ${_hhState.page+1} of ${totalPages}</span>`;
        if(_hhState.page>0)
          pHtml+=`<button class="round-btn" style="font-size:11px" onclick="_hhState.page--;renderHH()">◀ Prev</button>`;
        // Show up to 7 page buttons around current
        const pStart=Math.max(0,_hhState.page-3);
        const pEnd=Math.min(totalPages-1,_hhState.page+3);
        for(let pg=pStart;pg<=pEnd;pg++){
          pHtml+=`<button class="round-btn${pg===_hhState.page?' active':''}" style="font-size:11px;min-width:30px"
            onclick="_hhState.page=${pg};renderHH()">${pg+1}</button>`;
        }
        if(_hhState.page<totalPages-1)
          pHtml+=`<button class="round-btn" style="font-size:11px" onclick="_hhState.page++;renderHH()">Next ▶</button>`;
      }
      if(pageEl) pageEl.innerHTML=pHtml;
    }

    // CSV download
    window._hhDownloadCsv=function(){
      const filtered=getFiltered();
      const header=['hhid','psu','region','region_name','urban_label','R1','R2','R3','R4','R5','days_to_R2','days_to_R3','days_to_R4','days_to_R5','rounds_present','first_round','last_round','status','pattern'];
      const rows=filtered.map(h=>{
        const dg=h.days_gap||{};
        return [
          h.hhid, h.psu, h.region, h.region_name, h.urban_label,
          h.presence['1'], h.presence['2'], h.presence['3'], h.presence['4'], h.presence['5'],
          dg['2']!=null?dg['2']:'', dg['3']!=null?dg['3']:'',
          dg['4']!=null?dg['4']:'', dg['5']!=null?dg['5']:'',
          h.rounds_present, h.first_round||'', h.last_round||'', h.status, h.pattern
        ];
      });
      const csv=[header,...rows].map(r=>r.join(',')).join('\\n');
      const a=document.createElement('a');
      a.href='data:text/csv;charset=utf-8,'+encodeURIComponent(csv);
      a.download='l2phl_panel_households.csv';
      a.click();
    };

    renderHH();
  }

  // ── PSU status table ──
  const psuEl = document.getElementById('panel-psu-status');
  if(psuEl && p.psu_status){
    const tgt = `Urban PSUs: target ${p.urban_target} HH &nbsp;|&nbsp; Rural PSUs: target ${p.rural_target} HH`;
    let html = `<p class="note-box note-info" style="margin-bottom:10px;font-size:12px">${tgt}</p>`;
    html += `<table style="width:100%;border-collapse:collapse;font-size:12.5px">
      <thead><tr style="background:#1a2332;color:#fff">
        <th style="padding:7px 10px;text-align:left">Round</th>
        <th style="padding:7px 10px;text-align:center">Total PSUs</th>
        <th style="padding:7px 10px;text-align:center;background:#27ae60">On Target</th>
        <th style="padding:7px 10px;text-align:center;background:#e67e22">Under Target</th>
        <th style="padding:7px 10px;text-align:center;background:#2980b9">Over Target</th>
        <th style="padding:7px 10px;text-align:center">% On Target</th>
      </tr></thead><tbody>`;
    p.psu_status.forEach((row,i)=>{
      const tot = (row.on_target||0)+(row.under||0)+(row.over||0);
      const pct = tot>0?Math.round(row.on_target/tot*100):0;
      const bg  = i%2===0?'#f8f9fa':'#fff';
      html += `<tr style="background:${bg}">
        <td style="padding:6px 10px;font-weight:600">R${row.round}</td>
        <td style="padding:6px 10px;text-align:center">${tot}</td>
        <td style="padding:6px 10px;text-align:center;color:#27ae60;font-weight:600">${row.on_target||0}</td>
        <td style="padding:6px 10px;text-align:center;color:#e67e22;font-weight:600">${row.under||0}</td>
        <td style="padding:6px 10px;text-align:center;color:#2980b9;font-weight:600">${row.over||0}</td>
        <td style="padding:6px 10px;text-align:center">
          <div style="background:#eee;border-radius:4px;overflow:hidden;height:14px;min-width:80px">
            <div style="background:${pct>=70?'#27ae60':'#e67e22'};width:${pct}%;height:100%"></div>
          </div>
          <span style="font-size:11px">${pct}%</span>
        </td>
      </tr>`;
    });
    html += `</tbody></table>`;
    psuEl.innerHTML = html;
  }

  // ── Region x Urban x Round table ──
  const regEl = document.getElementById('panel-region-table');
  if(regEl && p.reg_summary){
    // Group by region
    const regMap = {};
    p.reg_summary.forEach(r=>{
      const key = r.region_name;
      if(!regMap[key]) regMap[key] = {region:r.region, name:r.region_name, rows:[]};
      regMap[key].rows.push(r);
    });
    const sortedRegs = Object.values(regMap).sort((a,b)=>a.region-b.region);

    let html = `<table style="width:100%;border-collapse:collapse;font-size:12px">
      <thead><tr style="background:#1a2332;color:#fff">
        <th style="padding:7px 10px;text-align:left">Region</th>
        <th style="padding:7px 10px;text-align:left">Urban/Rural</th>`;
    rounds.forEach(r=>html+=`<th style="padding:7px 10px;text-align:center">R${r}</th>`);
    html += `<th style="padding:7px 10px;text-align:center">Total</th></tr></thead><tbody>`;

    sortedRegs.forEach((reg,ri)=>{
      reg.rows.sort((a,b)=>a.urban_label.localeCompare(b.urban_label));
      reg.rows.forEach((row,j)=>{
        const bg = ri%2===0?'#f8f9fa':'#fff';
        const rowTotal = rounds.reduce((s,r)=>s+(row.counts[String(r)]||0),0);
        html += `<tr style="background:${bg}">`;
        if(j===0) html += `<td style="padding:6px 10px;font-weight:600;vertical-align:top" rowspan="${reg.rows.length}">${reg.name}</td>`;
        const uLabel = row.urban_label==='Urban'
          ? `<span style="background:#cce5ff;color:#004085;border-radius:3px;padding:1px 5px;font-size:10.5px">Urban</span>`
          : `<span style="background:#d4edda;color:#155724;border-radius:3px;padding:1px 5px;font-size:10.5px">Rural</span>`;
        html += `<td style="padding:6px 10px">${uLabel}</td>`;
        rounds.forEach(r=>{
          const cnt = row.counts[String(r)]||0;
          const clr = cnt===0?'#ccc':'#222';
          html += `<td style="padding:6px 10px;text-align:center;color:${clr};font-weight:${cnt>0?600:400}">${cnt||'—'}</td>`;
        });
        html += `<td style="padding:6px 10px;text-align:center;font-weight:700">${rowTotal}</td>`;
        html += `</tr>`;
      });
    });
    html += `</tbody></table>`;
    regEl.innerHTML = html;
  }

  // ── In/Out summary table ──
  const inoutEl = document.getElementById('panel-inout-table');
  if(inoutEl && p.attrition){
    const baseN = p.attrition[0].n;
    let html = `<table style="width:100%;border-collapse:collapse;font-size:12.5px">
      <thead><tr style="background:#1a2332;color:#fff">
        <th style="padding:7px 10px">Round</th>
        <th style="padding:7px 10px;text-align:center">Total HHs</th>
        <th style="padding:7px 10px;text-align:center;background:#2980b9">Retained from R1</th>
        <th style="padding:7px 10px;text-align:center;background:#e74c3c">Not seen from R1</th>
        <th style="padding:7px 10px;text-align:center;background:#27ae60">New entries</th>
        <th style="padding:7px 10px;text-align:center">Retention %</th>
      </tr></thead><tbody>`;
    p.attrition.forEach((row,i)=>{
      const retPct = Math.round(row.retained/baseN*100);
      const bg = i%2===0?'#f8f9fa':'#fff';
      html += `<tr style="background:${bg}">
        <td style="padding:7px 10px;font-weight:700">R${row.round}</td>
        <td style="padding:7px 10px;text-align:center;font-weight:600">${row.n}</td>
        <td style="padding:7px 10px;text-align:center;color:#2980b9;font-weight:600">${row.retained}</td>
        <td style="padding:7px 10px;text-align:center;color:#e74c3c;font-weight:600">${row.dropped}</td>
        <td style="padding:7px 10px;text-align:center;color:#27ae60;font-weight:600">${row.new_in}</td>
        <td style="padding:7px 10px;text-align:center">
          <div style="background:#eee;border-radius:4px;overflow:hidden;height:14px;min-width:80px;display:inline-block;width:60px">
            <div style="background:${retPct>=70?'#27ae60':retPct>=50?'#e67e22':'#e74c3c'};width:${retPct}%;height:100%"></div>
          </div>
          <span style="font-size:11px;margin-left:4px">${retPct}%</span>
        </td>
      </tr>`;
    });
    html += `</tbody></table>`;
    inoutEl.innerHTML = html;
  }

  // ── Leavers vs New Entries ──
  if(p.leaver_vs_new){
    const lvn = p.leaver_vs_new;
    const transLabels = lvn.map(t=>t.label);

    // Overall verdict badge
    const allDiff = lvn.every(t=>t.verdict==='DIFFERENT');
    const anyDiff = lvn.some(t=>t.verdict==='DIFFERENT');
    const lvnBadge = document.getElementById('lvn-verdict-badge');
    if(lvnBadge){
      const cls = allDiff?'badge-red':anyDiff?'badge-yellow':'badge-green';
      const txt = allDiff?'REGIONAL BIAS IN EVERY ROUND':anyDiff?'DIFFERENCES FOUND':'SIMILAR';
      lvnBadge.className=`badge ${cls}`;
      lvnBadge.textContent=txt;
    }

    // Summary table
    const sumEl = document.getElementById('panel-lvn-summary');
    if(sumEl){
      const allVarKeys = [...new Set(lvn.flatMap(t=>Object.keys(t.vars).filter(k=>k!=='region')))];
      const varLabels = {urban:'% Urban',hhsize:'HH Size',female:'% Female',employed:'% Employed',has_account:'% Has Bank Acct'};

      let html=`<div style="overflow-x:auto"><table style="width:100%;border-collapse:collapse;font-size:12px;min-width:600px">
        <thead>
        <tr style="background:#1a2332;color:#fff">
          <th style="padding:7px 10px" rowspan="2">Variable</th>
          ${lvn.map(t=>`<th colspan="3" style="padding:7px 8px;text-align:center;border-left:1px solid #334">${t.label}</th>`).join('')}
        </tr>
        <tr style="background:#2c3e50;color:#ccc;font-size:11px">
          ${lvn.map(()=>`<th style="padding:4px 6px;text-align:center;border-left:1px solid #334">Leavers</th><th style="padding:4px 6px;text-align:center">New</th><th style="padding:4px 6px;text-align:center">Δ</th>`).join('')}
        </tr></thead><tbody>`;

      allVarKeys.forEach((vk,i)=>{
        const bg=i%2===0?'#f8f9fa':'#fff';
        html+=`<tr style="background:${bg}"><td style="padding:6px 10px;font-weight:600">${varLabels[vk]||vk}</td>`;
        lvn.forEach(t=>{
          const res=t.vars[vk];
          if(!res){
            html+=`<td colspan="3" style="padding:6px 8px;text-align:center;color:#ccc;border-left:1px solid #eee">n/a</td>`;
          } else {
            const diff=res.diff;
            const diffClr=res.p<0.05?'#e74c3c':res.p<0.10?'#e67e22':'#555';
            const diffStr=(diff>=0?'+':'')+diff+(vk!=='hhsize'?'pp':'');
            html+=`<td style="padding:6px 8px;text-align:center;border-left:1px solid #eee">${res.leavers}</td>
              <td style="padding:6px 8px;text-align:center">${res.new}</td>
              <td style="padding:6px 8px;text-align:center">
                <span style="color:${diffClr};font-weight:${res.p<0.10?700:400}">${diffStr}</span>
                <span style="font-size:10px;color:${diffClr};display:block">${res.sig}</span>
              </td>`;
          }
        });
        html+=`</tr>`;
      });

      // Region row
      html+=`<tr style="background:#fff3cd"><td style="padding:6px 10px;font-weight:700">Region composition</td>`;
      lvn.forEach(t=>{
        const r=t.vars.region;
        if(!r){ html+=`<td colspan="3" style="padding:6px 8px;text-align:center;color:#ccc;border-left:1px solid #eee">n/a</td>`; return; }
        const clr=r.p<0.001?'#e74c3c':r.p<0.01?'#e67e22':r.p<0.05?'#f39c12':'#27ae60';
        html+=`<td colspan="2" style="padding:6px 8px;text-align:center;border-left:1px solid #eee;font-size:11px">χ²=${r.chi2} V=${r.v}</td>
          <td style="padding:6px 8px;text-align:center"><span style="color:${clr};font-weight:700">${r.sig}</span><span style="font-size:10px;color:${clr};display:block">p=${r.p}</span></td>`;
      });
      html+=`</tr></tbody></table></div>
        <p style="font-size:11px;color:#888;margin-top:6px">Δ = new minus leavers &nbsp;|&nbsp; *** p&lt;0.001 &nbsp;** p&lt;0.01 &nbsp;* p&lt;0.05 &nbsp;† p&lt;0.10 &nbsp;ns=not significant</p>`;
      sumEl.innerHTML=html;
    }

    // Urban chart: leavers vs new per transition
    new Chart(document.getElementById('lvnUrbanChart'),{
      type:'bar',
      data:{
        labels: transLabels,
        datasets:[
          {label:'Leavers % Urban', data: lvn.map(t=>t.vars.urban?.leavers||null), backgroundColor:'#e74c3c', borderRadius:3},
          {label:'New entries % Urban', data: lvn.map(t=>t.vars.urban?.new||null), backgroundColor:'#27ae60', borderRadius:3},
        ]
      },
      options:{responsive:true,maintainAspectRatio:false,
        plugins:{legend:{position:'bottom',labels:{font:{size:11}}},
          tooltip:{callbacks:{label:c=>`${c.dataset.label}: ${c.raw}%`}}},
        scales:{x:{},y:{min:40,max:80,title:{display:true,text:'% Urban',font:{size:11}},ticks:{callback:v=>v+'%'}}}}
    });

    // HHsize chart
    new Chart(document.getElementById('lvnHhsizeChart'),{
      type:'bar',
      data:{
        labels: transLabels,
        datasets:[
          {label:'Leavers', data: lvn.map(t=>t.vars.hhsize?.leavers||null), backgroundColor:'#e74c3c', borderRadius:3},
          {label:'New entries', data: lvn.map(t=>t.vars.hhsize?.new||null), backgroundColor:'#27ae60', borderRadius:3},
        ]
      },
      options:{responsive:true,maintainAspectRatio:false,
        plugins:{legend:{position:'bottom',labels:{font:{size:11}}}},
        scales:{x:{},y:{min:3,title:{display:true,text:'Mean HH size',font:{size:11}}}}}
    });

    // Regional composition table per transition
    const regLvnEl = document.getElementById('panel-lvn-region');
    if(regLvnEl){
      const allRegKeys = [...new Set(lvn.flatMap(t=>Object.keys(t.vars.region?.by_region||{})))].sort((a,b)=>+a-+b);
      const regNames = {};
      lvn.forEach(t=>Object.entries(t.vars.region?.by_region||{}).forEach(([k,v])=>{ if(!regNames[k]) regNames[k]=v.name; }));

      let html=`<div style="overflow-x:auto"><table style="border-collapse:collapse;font-size:11px;min-width:600px">
        <thead><tr style="background:#1a2332;color:#fff">
          <th style="padding:6px 10px">Region</th>
          ${lvn.map(t=>`<th colspan="2" style="padding:6px 8px;text-align:center;border-left:1px solid #334">${t.label}</th>`).join('')}
        </tr>
        <tr style="background:#2c3e50;color:#ccc;font-size:10.5px">
          <th style="padding:4px 10px"></th>
          ${lvn.map(()=>`<th style="padding:4px 6px;text-align:center;border-left:1px solid #334">Leavers%</th><th style="padding:4px 6px;text-align:center">New%</th>`).join('')}
        </tr></thead><tbody>`;

      allRegKeys.forEach((rk,i)=>{
        const bg=i%2===0?'#f8f9fa':'#fff';
        html+=`<tr style="background:${bg}"><td style="padding:5px 10px;font-weight:600">${regNames[rk]||rk}</td>`;
        lvn.forEach(t=>{
          const rd=t.vars.region?.by_region?.[rk];
          if(!rd){ html+=`<td colspan="2" style="padding:5px 6px;text-align:center;color:#ccc;border-left:1px solid #eee">—</td>`; return; }
          const diff=rd.n_pct-rd.l_pct;
          const diffClr=Math.abs(diff)>5?'#e74c3c':Math.abs(diff)>2?'#e67e22':'#555';
          html+=`<td style="padding:5px 6px;text-align:center;border-left:1px solid #eee">${rd.l_pct}%</td>
            <td style="padding:5px 6px;text-align:center"><span style="color:${diffClr};font-weight:${Math.abs(diff)>5?700:400}">${rd.n_pct}%</span></td>`;
        });
        html+=`</tr>`;
      });
      // Chi2 row
      html+=`<tr style="background:#fff3cd;font-weight:700">
        <td style="padding:6px 10px">Regional χ²</td>
        ${lvn.map(t=>{const r=t.vars.region; const clr=r?.p<0.001?'#e74c3c':r?.p<0.01?'#e67e22':'#f39c12'; return `<td colspan="2" style="padding:6px 8px;text-align:center;border-left:1px solid #eee"><span style="color:${clr}">${r?.sig||'—'} (p=${r?.p||'?'})</span></td>`;}).join('')}
      </tr>`;
      html+=`</tbody></table></div>`;
      regLvnEl.innerHTML=html;
    }
  }

  // ── Attrition composition profile ──
  if(p.attrition_profile){
    const prof = p.attrition_profile;
    const transLabels = prof.map(t=>t.label);

    // Urban % by group per transition
    const pctUrban = grp => grp.n>0 ? Math.round(grp.n_urban/grp.n*100) : 0;
    const retPct  = prof.map(t=>pctUrban(t.retained));
    const dropPct = prof.map(t=>pctUrban(t.dropped));
    const newPct  = prof.map(t=>pctUrban(t.new_in));

    new Chart(document.getElementById('panelAttrProfileChart'),{
      type:'bar',
      data:{
        labels: transLabels,
        datasets:[
          {label:'Retained % Urban', data:retPct,  backgroundColor:'#2980b9'},
          {label:'Dropped % Urban',  data:dropPct, backgroundColor:'#e74c3c'},
          {label:'New-entry % Urban',data:newPct,  backgroundColor:'#27ae60'},
        ]
      },
      options:{responsive:true,maintainAspectRatio:false,
        plugins:{legend:{position:'bottom',labels:{font:{size:11}}},
          tooltip:{callbacks:{label:c=>`${c.dataset.label}: ${c.raw}%`}}},
        scales:{x:{},y:{beginAtZero:true,max:100,
          title:{display:true,text:'% Urban',font:{size:11}}}}}
    });

    // Volume chart
    const retN  = prof.map(t=>t.retained.n);
    const dropN = prof.map(t=>t.dropped.n);
    const newN  = prof.map(t=>t.new_in.n);
    new Chart(document.getElementById('panelAttrVolumeChart'),{
      type:'bar',
      data:{
        labels: transLabels,
        datasets:[
          {label:'Retained', data:retN,  backgroundColor:'#2980b9'},
          {label:'Dropped',  data:dropN, backgroundColor:'#e74c3c'},
          {label:'New',      data:newN,  backgroundColor:'#27ae60'},
        ]
      },
      options:{responsive:true,maintainAspectRatio:false,
        plugins:{legend:{position:'bottom',labels:{font:{size:11}}}},
        scales:{x:{},y:{beginAtZero:true,
          title:{display:true,text:'Households',font:{size:11}}}}}
    });

    // Composition table
    const profEl = document.getElementById('panel-attrition-profile');
    if(profEl){
      let html=`<table style="width:100%;border-collapse:collapse;font-size:12px;margin-bottom:6px">
        <thead><tr style="background:#1a2332;color:#fff">
          <th style="padding:7px 10px">Transition</th>
          <th colspan="2" style="padding:7px 10px;text-align:center;background:#2980b9">Retained</th>
          <th colspan="2" style="padding:7px 10px;text-align:center;background:#e74c3c">Dropped</th>
          <th colspan="2" style="padding:7px 10px;text-align:center;background:#27ae60">New Entry</th>
        </tr>
        <tr style="background:#2c3e50;color:#ccc;font-size:11px">
          <th style="padding:4px 10px"></th>
          <th style="padding:4px 10px;text-align:center">n</th><th style="padding:4px 10px;text-align:center">%Urban</th>
          <th style="padding:4px 10px;text-align:center">n</th><th style="padding:4px 10px;text-align:center">%Urban</th>
          <th style="padding:4px 10px;text-align:center">n</th><th style="padding:4px 10px;text-align:center">%Urban</th>
        </tr></thead><tbody>`;
      prof.forEach((t,i)=>{
        const bg=i%2===0?'#f8f9fa':'#fff';
        const pu=g=>g.n>0?Math.round(g.n_urban/g.n*100)+'%':'—';
        html+=`<tr style="background:${bg}">
          <td style="padding:6px 10px;font-weight:700">${t.label}</td>
          <td style="padding:6px 10px;text-align:center;color:#2980b9;font-weight:600">${t.retained.n}</td>
          <td style="padding:6px 10px;text-align:center">${pu(t.retained)}</td>
          <td style="padding:6px 10px;text-align:center;color:#e74c3c;font-weight:600">${t.dropped.n}</td>
          <td style="padding:6px 10px;text-align:center">${pu(t.dropped)}</td>
          <td style="padding:6px 10px;text-align:center;color:#27ae60;font-weight:600">${t.new_in.n}</td>
          <td style="padding:6px 10px;text-align:center">${pu(t.new_in)}</td>
        </tr>`;
      });
      html+=`</tbody></table>`;
      profEl.innerHTML=html;
    }
  }

  // ── PSU problem tracker ──
  if(p.psu_problem_list){
    const filterEl = document.getElementById('panel-psu-filter');
    const probEl   = document.getElementById('panel-psu-problems');
    let psuFilter  = 'all';

    function renderPsuProblems(){
      let list = p.psu_problem_list;
      if(psuFilter==='urban') list=list.filter(x=>x.urban===1);
      if(psuFilter==='rural') list=list.filter(x=>x.urban===2);
      const show = list.slice(0,100);
      let html=`<p style="font-size:11.5px;color:#555;margin-bottom:8px">Showing ${show.length} of ${list.length} under-target PSUs (out of ${p.psu_problem_list.length} total). Over-target PSUs are excluded.</p>`;
      html+=`<div style="overflow-x:auto"><table style="width:100%;border-collapse:collapse;font-size:11.5px;min-width:600px">
        <thead><tr style="background:#1a2332;color:#fff">
          <th style="padding:6px 8px;text-align:left">PSU</th>
          <th style="padding:6px 8px;text-align:left">Region</th>
          <th style="padding:6px 8px;text-align:center">Type</th>
          <th style="padding:6px 8px;text-align:center">Target</th>
          ${rounds.map(r=>`<th style="padding:6px 8px;text-align:center">R${r}</th>`).join('')}
          <th style="padding:6px 8px;text-align:center;background:#e74c3c">Rounds Under</th>
          <th style="padding:6px 8px;text-align:center;background:#c0392b">Rounds Zero</th>
        </tr></thead><tbody>`;
      show.forEach((psu,i)=>{
        const bg=i%2===0?'#f8f9fa':'#fff';
        const uTag=psu.urban===1
          ?`<span style="background:#cce5ff;color:#004085;border-radius:3px;padding:1px 5px;font-size:10px">Urban</span>`
          :`<span style="background:#d4edda;color:#155724;border-radius:3px;padding:1px 5px;font-size:10px">Rural</span>`;
        const cellColor=cnt=>cnt===0?'background:#fde8e8;color:#c0392b;font-weight:700':
                              cnt<psu.target?'background:#fff3cd;color:#856404;font-weight:600':
                              cnt===psu.target?'background:#d4edda;color:#155724;font-weight:600':
                              'color:#2980b9;font-weight:600';
        html+=`<tr style="background:${bg}">
          <td style="padding:5px 8px;font-family:monospace;font-size:10.5px">${psu.psu}</td>
          <td style="padding:5px 8px">${psu.region_name}</td>
          <td style="padding:5px 8px;text-align:center">${uTag}</td>
          <td style="padding:5px 8px;text-align:center;font-weight:700">${psu.target}</td>
          ${rounds.map(r=>{
            const cnt=psu.counts[String(r)]??'—';
            return `<td style="padding:5px 8px;text-align:center;${typeof cnt==='number'?cellColor(cnt):''}">${cnt}</td>`;
          }).join('')}
          <td style="padding:5px 8px;text-align:center">
            <span style="background:${psu.n_under===5?'#e74c3c':psu.n_under>=3?'#e67e22':'#f39c12'};color:#fff;border-radius:3px;padding:2px 7px;font-size:11px;font-weight:700">${psu.n_under}/5</span>
          </td>
          <td style="padding:5px 8px;text-align:center">
            ${psu.n_zero>0?`<span style="background:#c0392b;color:#fff;border-radius:3px;padding:2px 7px;font-size:11px;font-weight:700">${psu.n_zero}</span>`:`<span style="color:#888">0</span>`}
          </td>
        </tr>`;
      });
      html+=`</tbody></table></div>`;
      if(probEl) probEl.innerHTML=html;
    }

    if(filterEl){
      filterEl.innerHTML=[
        {v:'all',l:`All PSUs (${p.psu_problem_list.length})`},
        {v:'urban',l:`Urban only (${p.psu_problem_list.filter(x=>x.urban===1).length})`},
        {v:'rural',l:`Rural only (${p.psu_problem_list.filter(x=>x.urban===2).length})`},
      ].map(b=>`<button onclick="window._psuFilter='${b.v}';document.querySelectorAll('#panel-psu-filter button').forEach(x=>x.classList.remove('active'));this.classList.add('active');${''}"
        class="round-btn${psuFilter===b.v?' active':''}" style="margin-right:6px" id="psu-btn-${b.v}">${b.l}</button>`).join('');
      filterEl.querySelectorAll('button').forEach(btn=>{
        btn.addEventListener('click',()=>{
          psuFilter=btn.id.replace('psu-btn-','');
          filterEl.querySelectorAll('button').forEach(b=>b.classList.remove('active'));
          btn.classList.add('active');
          renderPsuProblems();
        });
      });
    }
    renderPsuProblems();
  }

  // ── Within-PSU refusal clustering risk ───────────────────────────────────
  const refusalEl = document.getElementById('panel-refusal-risk');
  if(refusalEl && p.psu_problem_list && bias && (bias.transitions||[]).length){

    // Step 1: aggregate PSU problem counts by region
    const regPsu = {};
    p.psu_problem_list.forEach(psu=>{
      const rk=String(psu.region);
      if(!regPsu[rk]) regPsu[rk]={name:psu.region_name, total:0, chronic:0, zero:0};
      regPsu[rk].total++;
      if(psu.n_under>=3) regPsu[rk].chronic++;
      if(psu.n_zero>0)   regPsu[rk].zero++;
    });

    // Step 2: build per-region retention lookup from bias.transitions
    const regRetMap = {};
    bias.transitions.forEach(t=>{
      (t.reg_ret_rates||[]).forEach(r=>{
        const rk=String(r.region);
        if(!regRetMap[rk]) regRetMap[rk]={name:r.name};
        regRetMap[rk][t.label]=r.pct_retained;
      });
    });

    // Step 3: merge all regions and classify risk
    const allRks=new Set([...Object.keys(regPsu),...Object.keys(regRetMap)]);
    const rows=[];
    allRks.forEach(rk=>{
      const pi=regPsu[rk]; const ri=regRetMap[rk];
      if(!pi && !ri) return;
      const name=(pi||ri).name||rk;
      const nTotal  = pi?pi.total:0;
      const nChronic= pi?pi.chronic:0;
      const nZero   = pi?pi.zero:0;
      // Lowest retention across any transition
      let lowestRet=100;
      if(ri) bias.transitions.forEach(t=>{
        const pct=ri[t.label];
        if(pct!==undefined && pct<lowestRet) lowestRet=pct;
      });
      const hasPsu=(nChronic>0||nZero>0);
      const hasAttr=(lowestRet<65);
      const risk=hasPsu&&hasAttr?'HIGH':hasPsu||hasAttr?'MODERATE':'LOW';
      rows.push({rk,name,nTotal,nChronic,nZero,lowestRet,risk,ri});
    });
    const rOrder={HIGH:0,MODERATE:1,LOW:2};
    rows.sort((a,b)=>{
      if(rOrder[a.risk]!==rOrder[b.risk]) return rOrder[a.risk]-rOrder[b.risk];
      return b.nChronic-a.nChronic;
    });

    const nHigh=rows.filter(r=>r.risk==='HIGH').length;
    const nMod =rows.filter(r=>r.risk==='MODERATE').length;
    const tLabels=bias.transitions.map(t=>t.label);

    let html=`<div style="background:#fde8e8;border-left:4px solid #e74c3c;padding:12px 16px;border-radius:4px;margin-bottom:14px;font-size:12px;color:#333">
      <strong>⚠️ Methodological note for fieldwork team</strong><br>
      Post-stratification weights correct for <em>between-PSU</em> regional imbalances, but
      <em>within-PSU</em> refusal clustering cannot be fixed by weighting. If the households
      that refused replacement share characteristics (same community norms, socioeconomic profile,
      or local trust in the survey), the responding sample within those PSUs is already self-selected
      before any weight is applied. <strong>${nHigh} region${nHigh!==1?'s':''} below are flagged HIGH</strong>
      — they show both elevated round-to-round attrition <em>and</em> chronic PSU shortfalls.
      These require field-level intervention (re-contact, community entry strategy) rather than
      statistical correction. <strong>${nMod} region${nMod!==1?'s':''} are MODERATE</strong> — one
      of the two problems is present.
    </div>
    <div style="overflow-x:auto">
    <table style="width:100%;border-collapse:collapse;font-size:12px;min-width:640px">
    <thead><tr style="background:#1a2332;color:#fff">
      <th style="padding:7px 10px;text-align:left">Region</th>
      <th style="padding:7px 10px;text-align:center">Under-target<br><span style="font-weight:normal;font-size:10px">PSUs</span></th>
      <th style="padding:7px 10px;text-align:center;background:#8e1e1e">Chronic<br><span style="font-weight:normal;font-size:10px">≥3 rounds under</span></th>
      <th style="padding:7px 10px;text-align:center;background:#6d1212">Ever-zero<br><span style="font-weight:normal;font-size:10px">0 HHs in any round</span></th>
      ${tLabels.map(l=>`<th style="padding:7px 8px;text-align:center">% Ret<br><span style="font-weight:normal;font-size:10px">${l}</span></th>`).join('')}
      <th style="padding:7px 10px;text-align:center">Risk</th>
    </tr></thead><tbody>`;

    rows.forEach((r,i)=>{
      const bg=i%2===0?'#f8f9fa':'#fff';
      const rBadge={HIGH:'badge-red',MODERATE:'badge-yellow',LOW:'badge-green'};
      html+=`<tr style="background:${bg}">
        <td style="padding:6px 10px;font-weight:600">${r.name}</td>
        <td style="padding:6px 10px;text-align:center">${r.nTotal>0?r.nTotal:'—'}</td>
        <td style="padding:6px 10px;text-align:center">${r.nChronic>0
          ?`<span style="background:#e74c3c;color:#fff;border-radius:3px;padding:1px 7px;font-weight:700">${r.nChronic}</span>`:'—'}</td>
        <td style="padding:6px 10px;text-align:center">${r.nZero>0
          ?`<span style="background:#c0392b;color:#fff;border-radius:3px;padding:1px 7px;font-weight:700">${r.nZero}</span>`:'—'}</td>
        ${bias.transitions.map(t=>{
          const pct=r.ri?r.ri[t.label]:null;
          if(pct==null) return `<td style="padding:6px 8px;text-align:center;color:#aaa">—</td>`;
          const cBg=pct<50?'#fde8e8':pct<65?'#fff3cd':pct<75?'#fef9e7':'#d4edda';
          const cTxt=pct<50?'#c0392b':pct<65?'#856404':'#155724';
          return `<td style="padding:6px 8px;text-align:center;background:${cBg};color:${cTxt};font-weight:600">${pct}%</td>`;
        }).join('')}
        <td style="padding:6px 10px;text-align:center">
          <span class="badge ${rBadge[r.risk]}">${r.risk}</span>
        </td>
      </tr>`;
    });

    html+=`</tbody></table></div>
    <p style="font-size:11px;color:#888;margin-top:7px">
      <strong>Risk = HIGH</strong>: region has ≥1 chronic or ever-zero PSU AND retention dropped below 65% in at least one transition. &nbsp;
      <strong>MODERATE</strong>: one of the two problems present. &nbsp;
      Retention columns show % of previous-round HHs still present in each transition (colour scale: red &lt;50%, orange 50–65%, green ≥75%).
    </p>`;

    refusalEl.innerHTML=html;
  }

  // ── Call interval summary and violations ──
  if(p.call_interval_summary){
    const totalViol = (p.call_violations||[]).length;
    const badgeEl = document.getElementById('panel-call-badge');
    if(badgeEl) badgeEl.textContent=`${totalViol} violations across all rounds`;

    const sumEl = document.getElementById('panel-call-summary');
    if(sumEl){
      let html=`<table style="width:100%;border-collapse:collapse;font-size:12.5px">
        <thead><tr style="background:#1a2332;color:#fff">
          <th style="padding:7px 10px">Round</th>
          <th style="padding:7px 10px;text-align:center">HHs with prev. interview</th>
          <th style="padding:7px 10px;text-align:center;background:#e74c3c">Called &lt;30 days</th>
          <th style="padding:7px 10px;text-align:center">% Early</th>
          <th style="padding:7px 10px;text-align:center">Median gap (days)</th>
          <th style="padding:7px 10px;text-align:center">Min</th>
          <th style="padding:7px 10px;text-align:center">Max</th>
        </tr></thead><tbody>`;
      p.call_interval_summary.forEach((row,i)=>{
        const bg=i%2===0?'#f8f9fa':'#fff';
        const pct=row.pct_under30||0;
        const pctClr=pct>50?'#e74c3c':pct>20?'#e67e22':'#27ae60';
        html+=`<tr style="background:${bg}">
          <td style="padding:7px 10px;font-weight:700">R${row.round}</td>
          <td style="padding:7px 10px;text-align:center">${row.n_total}</td>
          <td style="padding:7px 10px;text-align:center;color:#e74c3c;font-weight:700">${row.n_under30}</td>
          <td style="padding:7px 10px;text-align:center">
            <span style="color:${pctClr};font-weight:700">${pct}%</span>
          </td>
          <td style="padding:7px 10px;text-align:center;font-weight:600">${row.median??'—'}</td>
          <td style="padding:7px 10px;text-align:center;color:${row.min<30?'#e74c3c':'#222'};font-weight:${row.min<30?700:400}">${row.min??'—'}</td>
          <td style="padding:7px 10px;text-align:center">${row.max??'—'}</td>
        </tr>`;
      });
      html+=`</tbody></table>`;
      sumEl.innerHTML=html;
    }

    const violEl = document.getElementById('panel-call-violations');
    if(violEl && p.call_violations){
      const viols = p.call_violations.slice(0,200);
      let html=`<p style="font-size:11.5px;color:#555;margin-bottom:8px">Showing ${viols.length} of ${p.call_violations.length} violations (&lt;30 days since last interview).</p>`;
      html+=`<div style="overflow-x:auto"><table style="width:100%;border-collapse:collapse;font-size:11.5px;min-width:500px">
        <thead><tr style="background:#1a2332;color:#fff">
          <th style="padding:6px 10px">HH ID</th>
          <th style="padding:6px 10px;text-align:center">Round</th>
          <th style="padding:6px 10px;text-align:center">Prev Round</th>
          <th style="padding:6px 10px;text-align:center;background:#e74c3c">Days Gap</th>
          <th style="padding:6px 10px;text-align:center">Urban/Rural</th>
          <th style="padding:6px 10px;text-align:left">Region</th>
          <th style="padding:6px 10px;text-align:left">PSU</th>
        </tr></thead><tbody>`;
      viols.forEach((v,i)=>{
        const bg=i%2===0?'#f8f9fa':'#fff';
        const gapClr=v.days_gap<20?'#c0392b':v.days_gap<25?'#e74c3c':'#e67e22';
        html+=`<tr style="background:${bg}">
          <td style="padding:5px 10px;font-weight:600">${v.hhid}</td>
          <td style="padding:5px 10px;text-align:center">R${v.round}</td>
          <td style="padding:5px 10px;text-align:center;color:#888">R${v.prev_round}</td>
          <td style="padding:5px 10px;text-align:center">
            <span style="background:${gapClr};color:#fff;border-radius:3px;padding:2px 8px;font-weight:700">${v.days_gap}d</span>
          </td>
          <td style="padding:5px 10px;text-align:center">
            ${v.urban_label==='Urban'
              ?`<span style="background:#cce5ff;color:#004085;border-radius:3px;padding:1px 5px;font-size:10px">Urban</span>`
              :`<span style="background:#d4edda;color:#155724;border-radius:3px;padding:1px 5px;font-size:10px">Rural</span>`}
          </td>
          <td style="padding:5px 10px">${v.region_name}</td>
          <td style="padding:5px 10px;font-family:monospace;font-size:10.5px">${v.psu}</td>
        </tr>`;
      });
      html+=`</tbody></table></div>`;
      violEl.innerHTML=html;
    }
  }
}

// ── MISSING HEATMAP ──────────────────────────────────────────────────────────
let hmCurrentMod='M00';
function buildMissing(){
  const tabs=document.getElementById('hm-tabs');
  tabs.innerHTML=MODULES.map(m=>`<span class="mtab${m===hmCurrentMod?' active':''}" onclick="switchHM('${m}')">${m}</span>`).join('');
  renderHM(hmCurrentMod);
}
function switchHM(m){
  hmCurrentMod=m;
  document.querySelectorAll('#hm-tabs .mtab').forEach((t,i)=>t.classList.toggle('active',MODULES[i]===m));
  renderHM(m);
}
function renderHM(mod){
  const rows = DQ.heatmap_data[mod]||[];
  if(!rows.length){document.getElementById('hm-content').innerHTML='<p style="color:#888;padding:10px">No data.</p>';return;}
  let html=`<div class="heatmap-wrap"><table class="heatmap"><thead><tr>
    <th class="left" style="min-width:150px">Variable</th>
    ${ROUNDS.map(r=>`<th>R${r}</th>`).join('')}
    <th>RAG</th></tr></thead><tbody>`;
  rows.forEach(row=>{
    const rag=row.rag||'green';
    const ragDot={red:'🔴',yellow:'🟡',green:'🟢'}[rag]||'⚪';
    html+=`<tr><td class="vn">${row.var}</td>`;
    ROUNDS.forEach(r=>{
      const v=row[r];
      const bg=hmColor(v), tc=v>50?'#333':'#333';
      html+=`<td><div class="hm-cell" style="background:${bg};color:${tc}">${hmText(v)}</div></td>`;
    });
    html+=`<td>${ragDot}</td></tr>`;
  });
  html+='</tbody></table></div>';
  document.getElementById('hm-content').innerHTML=html;
}

// ── INTERVIEW QUALITY ────────────────────────────────────────────────────────
function buildInterview(){
  const meta=DQ.interview_meta;
  const dur=meta.duration?.by_round||{};
  const modDur=meta.module_durations?.by_module||{};
  const partial=meta.partial_interviews?.by_round||{};
  const excess=meta.excess_interviews?.by_round||{};
  const calls=meta.call_attempts?.by_round||{};

  const totalShort=ROUNDS.reduce((s,r)=>{const d=dur[r];return s+(d?(d.very_short||0)+(d.short||0):0)},0);
  const totalPartial=Object.values(partial).reduce((s,v)=>s+(v||0),0);
  const totalExcess=Object.values(excess).reduce((s,v)=>s+(v||0),0);

  document.getElementById('int-stats').innerHTML=`
    <div class="stat-box ${totalShort>10?'red':'yellow'}"><div class="num">${totalShort}</div><div class="lbl">Short interviews (&lt;20 min)</div></div>
    <div class="stat-box ${totalPartial>0?'yellow':'green'}"><div class="num">${totalPartial}</div><div class="lbl">Partial interviews</div></div>
    <div class="stat-box ${totalExcess>0?'yellow':'green'}"><div class="num">${totalExcess}</div><div class="lbl">Excess interviews</div></div>
    <div class="stat-box blue"><div class="num">5</div><div class="lbl">Rounds covered</div></div>
  `;

  setTimeout(()=>{
    makeBar('durChart',ROUNDS.map(r=>`R${r}`),[
      {label:'P25',data:ROUNDS.map(r=>dur[r]?.p25??null),backgroundColor:'rgba(52,152,219,.3)',borderRadius:0},
      {label:'Median',data:ROUNDS.map(r=>dur[r]?.p50??null),backgroundColor:'rgba(52,152,219,.85)',borderRadius:4},
      {label:'P75',data:ROUNDS.map(r=>dur[r]?.p75??null),backgroundColor:'rgba(52,152,219,.3)',borderRadius:0},
    ],{y:{ticks:{callback:v=>`${v}m`}},plugins:{legend:{display:true,labels:{font:{size:10},boxWidth:8}}}});

    const stacks=['very_short','short','normal','long','very_long'];
    const sColors=['#e74c3c','#e67e22','#2ecc71','#f39c12','#c0392b'];
    const sLabels=['<10m','10–20m','20–60m','60–120m','>2h'];
    makeBar('durCatChart',ROUNDS.map(r=>`R${r}`),
      stacks.map((k,i)=>({label:sLabels[i],
        data:ROUNDS.map(r=>{const d2=dur[r];return d2&&d2.n?Math.round((d2[k]||0)/d2.n*100):0}),
        backgroundColor:sColors[i],borderRadius:2})),
      {y:{stacked:true,ticks:{callback:v=>`${v}%`}},scales:{x:{stacked:true},y:{stacked:true}},
       plugins:{legend:{display:true,labels:{font:{size:10},boxWidth:8}}}});

    const mLabels=Object.keys(modDur);
    makeBar('modDurChart',mLabels,ROUNDS.map((r,i)=>({
      label:`R${r}`,data:mLabels.map(m=>modDur[m]?.[r]??null),
      backgroundColor:R_COLORS[i],borderRadius:3})),
      {y:{ticks:{callback:v=>`${v}m`}},plugins:{legend:{display:true,labels:{font:{size:10},boxWidth:8}}}});

    makeBar('partialChart',ROUNDS.map(r=>`R${r}`),[{
      label:'Partial',data:ROUNDS.map(r=>partial[r]??0),
      backgroundColor:ROUNDS.map(r=>(partial[r]||0)>5?'#e74c3c':'#f39c12'),borderRadius:4}]);

    const cMean=Object.fromEntries(Object.entries(calls).map(([r,v])=>[r,v?.mean??null]));
    const c3p=Object.fromEntries(Object.entries(calls).map(([r,v])=>[r,v?.attempts_3plus??null]));
    makeBar('callChart',ROUNDS.map(r=>`R${r}`),[
      {label:'Mean attempts',data:ROUNDS.map(r=>cMean[r]??null),backgroundColor:'#3498db',borderRadius:4},
      {label:'3+ attempts',data:ROUNDS.map(r=>c3p[r]??null),backgroundColor:'#e74c3c',borderRadius:4}],
      {y:{min:0},plugins:{legend:{display:true,labels:{font:{size:10},boxWidth:8}}}});
  },50);
}

// ── ALL CHANGES PAGE ──────────────────────────────────────────────────────────
let changesRoundFilter = 'all';
function buildChanges(){
  const filters = document.getElementById('changes-filters');
  filters.innerHTML = `<span class="rfil-label">Show round:</span>
    ${['all','R2','R3','R4','R5'].map(r=>`<span class="rfil${r===changesRoundFilter?' active':''}" onclick="setChangesFilter('${r}')">${r==='all'?'All Rounds':r}</span>`).join('')}`;
  renderChanges();
}
function setChangesFilter(r){
  changesRoundFilter=r;
  buildChanges();
}
function renderChanges(){
  const allRounds=['R2','R3','R4','R5'];
  const prevR={R2:'R1',R3:'R2',R4:'R3',R5:'R4'};
  const toShow = changesRoundFilter==='all'?allRounds:[changesRoundFilter];
  let html='';

  toShow.forEach(rnd=>{
    let changes=[];
    MODULES.forEach(m=>{
      (MT[m]||[]).forEach(row=>{
        const inC=row[`in_${rnd}`]==='✓', inP=row[`in_${prevR[rnd]}`]==='✓';
        const rIdx=['R1','R2','R3','R4','R5'].indexOf(rnd);
        const isFirst=['R1','R2','R3','R4','R5'].slice(0,rIdx).every(pr=>row[`in_${pr}`]!=='✓');
        if(inC&&isFirst) changes.push({type:'new',var:row.variable,mod:m,title:row.question_title,text:row.english_text,detail:`First appears in ${rnd}`});
        if(!inC&&inP) changes.push({type:'drop',var:row.variable,mod:m,title:row.question_title,text:row.english_text,detail:`Present in ${prevR[rnd]}, absent in ${rnd}+`});
        if(inC&&inP){
          if(row.title_changes&&row.title_changes.includes(`${prevR[rnd]}→${rnd}`)){
            const detail=row.title_changes.split('|').find(x=>x.includes(`${prevR[rnd]}→${rnd}`))||row.title_changes;
            changes.push({type:'title',var:row.variable,mod:m,title:row.question_title,text:'',detail:detail.trim()});
          }
          if(row.skip_changes&&row.skip_changes.includes(rnd)){
            const detail=row.skip_changes.split('|').find(x=>x.includes(rnd))||row.skip_changes;
            changes.push({type:'skip',var:row.variable,mod:m,title:row.question_title,text:'',detail:detail.trim()});
          }
        }
      });
    });

    if(!changes.length) return;
    html+=`<div class="round-change-header">
      <span class="badge badge-blue">${rnd}</span>
      <span class="rch-arrow">vs</span>
      <span class="badge badge-grey">${prevR[rnd]}</span>
      <span style="color:#666;font-size:12px;margin-left:8px">${changes.length} change${changes.length>1?'s':''}</span>
    </div>`;

    const typeIcon={new:'➕',drop:'➖',title:'✏️',skip:'🔀',code:'📋'};
    const typeTag={new:'chg-new',drop:'chg-drop',title:'chg-title',skip:'chg-skip',code:'chg-code'};
    const typeLabel={new:'New Question',drop:'Dropped',title:'Wording Change',skip:'Skip Logic',code:'Code Change'};

    html+=`<div class="card" style="margin-bottom:12px"><table style="width:100%;border-collapse:collapse;font-size:12px">
      <thead><tr style="background:#f7f9fc">
        <th style="padding:5px 8px;text-align:left;font-size:10.5px;color:#555;text-transform:uppercase">Mod</th>
        <th style="padding:5px 8px;text-align:left">Variable</th>
        <th style="padding:5px 8px;text-align:left">Change</th>
        <th style="padding:5px 8px;text-align:left">Question Title</th>
        <th style="padding:5px 8px;text-align:left">Detail</th>
      </tr></thead><tbody>`;

    changes.forEach((c,ci)=>{
      const bg=ci%2===0?'#fff':'#f9f9f9';
      html+=`<tr style="background:${bg};border-bottom:1px solid #eee">
        <td style="padding:5px 8px"><span class="badge badge-blue" style="font-size:10px">${c.mod}</span></td>
        <td style="padding:5px 8px;font-family:monospace;font-weight:700;font-size:12px">${c.var}</td>
        <td style="padding:5px 8px"><span class="chg-tag ${typeTag[c.type]}">${typeIcon[c.type]} ${typeLabel[c.type]}</span></td>
        <td style="padding:5px 8px;font-size:11.5px;color:#333">${c.title}</td>
        <td style="padding:5px 8px;font-size:11px;color:#555">${c.detail}</td>
      </tr>`;
    });

    html+='</tbody></table></div>';
  });

  document.getElementById('changes-content').innerHTML=html||'<p style="color:#888;padding:20px">No changes detected for selected filters.</p>';
}

// ══════════════════════════════════════════════════════════════════════════════
// MODULE DEEP-DIVE PAGES
// ══════════════════════════════════════════════════════════════════════════════
function buildAllModulePages(){
  const container = document.getElementById('module-pages-container');
  MODULES.forEach(m=>{
    const div = document.createElement('div');
    div.id = `page-mod-${m}`;
    div.className = 'page';
    div.innerHTML = buildModulePage(m);
    container.appendChild(div);
  });
}

function buildModulePage(mod){
  const rows = MT[mod]||[];
  const s = DQ.module_summary[mod]||{};
  const heatRows = DQ.heatmap_data[mod]||[];
  const skipIssues = DQ.skip_issues.filter(x=>x.module===mod);
  const mandIssues = DQ.mandatory_issues.filter(x=>x.module===mod);
  const oorIssues  = DQ.oor_issues.filter(x=>x.module===mod);

  // Build DQ lookup by variable (lowercase)
  const dqByVar = {};
  skipIssues.forEach(x=>{
    const vars = x.variable.split(/[→,\s]+/).filter(v=>v.match(/^[A-Za-z]/));
    vars.forEach(v=>{
      const vl=v.toLowerCase();
      if(!dqByVar[vl]) dqByVar[vl]={skip:[],mand:[],oor:[]};
      dqByVar[vl].skip.push(x);
    });
  });
  mandIssues.forEach(x=>{
    const vars = x.variable.split(/[→,\s]+/).filter(v=>v.match(/^[A-Za-z]/));
    vars.forEach(v=>{
      const vl=v.toLowerCase();
      if(!dqByVar[vl]) dqByVar[vl]={skip:[],mand:[],oor:[]};
      dqByVar[vl].mand.push(x);
    });
  });
  oorIssues.forEach(x=>{
    const vl=(x.variable||'').toLowerCase();
    if(!dqByVar[vl]) dqByVar[vl]={skip:[],mand:[],oor:[]};
    dqByVar[vl].oor.push(x);
  });

  const totalSkipViol = skipIssues.reduce((s,x)=>s+Object.values(x.counts_by_round).reduce((a,v)=>a+(v||0),0),0);
  const totalMandMiss = mandIssues.reduce((s,x)=>s+Object.values(x.counts_by_round).reduce((a,v)=>a+(v||0),0),0);
  const newQs    = rows.filter(r=>r.status&&r.status.startsWith('New')).length;
  const droppedQs= rows.filter(r=>r.status&&r.status.startsWith('Dropped')).length;
  const changedQs= rows.filter(r=>r.title_changes||r.skip_changes).length;

  // Per-round question presence counts
  const presCount = {};
  ['R1','R2','R3','R4','R5'].forEach(r=>{presCount[r]=rows.filter(x=>x[`in_${r}`]==='✓').length});

  // Build the HTML
  let html = `
  <div class="mod-page-header">
    <div>
      <h1>${mod} – ${MOD_NAMES[mod]}</h1>
      <p class="subtitle">Per-question tracker · Questionnaire changes · Data quality issues</p>
    </div>
    <div class="mod-round-summary">
      ${['R1','R2','R3','R4','R5'].map(r=>{
        const n=presCount[r];
        const cls = n===0?'mrs-na':'mrs-ok';
        return `<div class="${cls} mrs-pill">R${r.slice(1)}: ${n}q</div>`;
      }).join('')}
    </div>
  </div>

  <div class="mod-dq-bar">
    <div class="mdb-item ${totalSkipViol>0?'red':'green'}"><div class="mdb-num">${totalSkipViol}</div><div class="mdb-lbl">Skip violations</div></div>
    <div class="mdb-item ${totalMandMiss>0?'yellow':'green'}"><div class="mdb-num">${totalMandMiss}</div><div class="mdb-lbl">Mandatory missing</div></div>
    <div class="mdb-item blue"><div class="mdb-num">${rows.length}</div><div class="mdb-lbl">Unique questions</div></div>
    <div class="mdb-item ${newQs>0?'purple':'green'}"><div class="mdb-num">${newQs}</div><div class="mdb-lbl">New questions</div></div>
    <div class="mdb-item ${droppedQs>0?'yellow':'green'}"><div class="mdb-num">${droppedQs}</div><div class="mdb-lbl">Dropped questions</div></div>
    <div class="mdb-item ${changedQs>0?'yellow':'green'}"><div class="mdb-num">${changedQs}</div><div class="mdb-lbl">Changed</div></div>
  </div>`;

  // Question tracker table
  html += `
  <div class="card">
    <h2>Question-Level Cross-Round Tracker
      <span class="badge badge-grey" style="cursor:pointer" onclick="toggleAllDetails('${mod}')">Toggle All Details</span>
    </h2>
    <div class="note-info note-box" style="margin-bottom:10px">
      ✓ = present in that round &nbsp;|&nbsp; — = absent &nbsp;|&nbsp; Click any row for full details incl. skip logic per round.
      Coloured tags show questionnaire changes; 🔴/🟡 icons flag DQ issues in the actual data.
    </div>

    <div class="heatmap-wrap">
    <table class="qtrack-table" id="qtable-${mod}">
    <thead class="sticky-round">
      <tr>
        <th class="left" style="min-width:80px">Variable</th>
        <th class="left" style="min-width:160px">Question Title</th>
        <th style="min-width:42px">R1</th>
        <th style="min-width:42px">R2</th>
        <th style="min-width:42px">R3</th>
        <th style="min-width:42px">R4</th>
        <th style="min-width:42px">R5</th>
        <th class="left" style="min-width:130px">Changes</th>
        <th class="left" style="min-width:100px">DQ Issues</th>
        <th class="left" style="min-width:90px">Type</th>
      </tr>
    </thead>
    <tbody>`;

  rows.forEach((row,ri)=>{
    const v = row.variable||'';
    const vl = v.toLowerCase();
    const dq = dqByVar[vl]||{skip:[],mand:[],oor:[]};
    const hasDQ = dq.skip.length+dq.mand.length+dq.oor.length>0;
    const rowBg = row.status&&row.status.startsWith('New')?'#f0fff4':
                  row.status&&row.status.startsWith('Dropped')?'#fff5f5':
                  (row.title_changes||row.skip_changes)?'#fffef0':'';

    // Build change tags
    let changeTags='';
    if(row.status&&row.status.startsWith('New')) changeTags+=`<span class="chg-tag chg-new">➕ ${row.status}</span>`;
    if(row.status&&row.status.startsWith('Dropped')) changeTags+=`<span class="chg-tag chg-drop">➖ ${row.status}</span>`;
    if(row.title_changes) changeTags+=`<span class="chg-tag chg-title" title="${row.title_changes.replace(/"/g,"'")}">✏️ Wording</span>`;
    if(row.skip_changes) changeTags+=`<span class="chg-tag chg-skip" title="${row.skip_changes.replace(/"/g,"'")}">🔀 Skip logic</span>`;

    // DQ badges
    let dqTags='';
    const skipViol = dq.skip.reduce((s,x)=>s+Object.values(x.counts_by_round).reduce((a,v2)=>a+(v2||0),0),0);
    const mandViol = dq.mand.reduce((s,x)=>s+Object.values(x.counts_by_round).reduce((a,v2)=>a+(v2||0),0),0);
    if(skipViol>0) dqTags+=`<span class="dq-inline dq-skip">🔴 Skip: ${skipViol}</span>`;
    if(mandViol>0) dqTags+=`<span class="dq-inline dq-mand">🟡 Mand: ${mandViol}</span>`;
    if(dq.oor.length>0) dqTags+=`<span class="dq-inline dq-oor">⚠ OOR</span>`;

    // Presence cells
    const pres = ['R1','R2','R3','R4','R5'].map(r=>{
      const p = row[`in_${r}`]==='✓';
      return `<td style="text-align:center"><span class="pres ${p?'yes':'no'}">${p?'✓':'—'}</span></td>`;
    }).join('');

    // Expandable detail row id
    const did=`det-${mod}-${ri}`;

    html+=`
    <tr class="toggle-row" onclick="toggleDetail('${did}')" style="${rowBg?`background:${rowBg}`:''}">
      <td class="var-name">${v} <button class="toggle-btn">▾</button></td>
      <td class="q-title">${(row.question_title||'').substring(0,60)}${(row.question_title||'').length>60?'…':''}</td>
      ${pres}
      <td>${changeTags||'<span style="color:#aaa;font-size:11px">—</span>'}</td>
      <td>${dqTags||'<span style="color:#aaa;font-size:11px">—</span>'}</td>
      <td><span class="qtype">${row.question_type||'—'}</span></td>
    </tr>
    <tr><td colspan="10" style="padding:0">
      <div class="q-detail" id="${did}">${buildDetailPanel(row,dq)}</div>
    </td></tr>`;
  });

  html+=`</tbody></table></div></div>`;

  // Missing data mini-heatmap for this module
  if(heatRows.length>0){
    html+=`<div class="card">
      <h2>Missing Data — ${mod} Variables</h2>
      <div class="heatmap-wrap"><table class="heatmap"><thead><tr>
        <th class="left">Variable</th>
        ${ROUNDS.map(r=>`<th>R${r}</th>`).join('')}
        <th>RAG</th></tr></thead><tbody>`;
    heatRows.forEach(row2=>{
      const rag=row2.rag||'green';
      html+=`<tr><td class="vn">${row2.var}</td>`;
      ROUNDS.forEach(r=>{
        const v=row2[r];
        html+=`<td><div class="hm-cell" style="background:${hmColor(v)}">${hmText(v)}</div></td>`;
      });
      const ragDot={red:'🔴',yellow:'🟡',green:'🟢'}[rag]||'⚪';
      html+=`<td>${ragDot}</td></tr>`;
    });
    html+=`</tbody></table></div></div>`;
  }

  return html;
}

function buildDetailPanel(row, dq){
  const rounds = ['R1','R2','R3','R4','R5'];

  // English text (most recent)
  const engText = row.english_text||'';

  // Skip logic per round
  let skipHTML='';
  const hasSkip = rounds.some(r=>row[`skip_${r.toLowerCase()}`]);
  if(hasSkip){
    skipHTML=`<div class="skip-rules"><strong>Skip Logic by Round:</strong>`;
    rounds.forEach(r=>{
      const sr = row[`skip_${r.toLowerCase()}`];
      if(sr) skipHTML+=`<div class="skip-rule-row">
        <span class="skip-round">${r}</span>
        <span class="skip-text">${sr}</span>
      </div>`;
    });
    skipHTML+=`</div>`;
  }

  // Data check notes
  const dcNotes = ['R3','R4','R5'].map(r=>row[`data_check_${r.toLowerCase()}`]).filter(Boolean);
  let dcHTML='';
  if(dcNotes.length){
    dcHTML=`<div style="margin-top:6px"><strong>Data Check Notes (from questionnaire):</strong><ul style="margin:3px 0 0 16px">`;
    dcNotes.forEach(n=>dcHTML+=`<li style="font-size:11px;color:#1a5276">${n}</li>`);
    dcHTML+=`</ul></div>`;
  }

  // DQ issue details
  let dqHTML='';
  if(dq.skip.length||dq.mand.length||dq.oor.length){
    dqHTML=`<div style="margin-top:6px"><strong>Data Quality Issues (from actual data):</strong>`;
    dq.skip.forEach(x=>{
      const total=Object.values(x.counts_by_round).reduce((a,v)=>a+(v||0),0);
      dqHTML+=`<div class="dq-inline dq-skip" style="display:block;border-radius:5px;margin:3px 0;padding:4px 8px;max-width:100%">
        <strong>Skip violation:</strong> ${x.rule} — total ${total} rows
        <div style="font-size:10px;margin-top:2px">${rounds.map(r=>`R${r}:${x.counts_by_round[r]||0}`).join(' · ')}</div>
      </div>`;
    });
    dq.mand.forEach(x=>{
      const total=Object.values(x.counts_by_round).reduce((a,v)=>a+(v||0),0);
      dqHTML+=`<div class="dq-inline dq-mand" style="display:block;border-radius:5px;margin:3px 0;padding:4px 8px;max-width:100%">
        <strong>Mandatory missing:</strong> ${x.rule} — total ${total} rows
        <div style="font-size:10px;margin-top:2px">${rounds.map(r=>`R${r}:${x.counts_by_round[r]||0}`).join(' · ')}</div>
      </div>`;
    });
    dq.oor.forEach(x=>{
      dqHTML+=`<div class="dq-inline dq-oor" style="display:block;border-radius:5px;margin:3px 0;padding:4px 8px;max-width:100%">
        <strong>Out-of-range:</strong> ${x.rule} — ${x.label||x.variable}
        <div style="font-size:10px;margin-top:2px">${rounds.map(r=>`R${r}:${x.counts?.[r]||0}`).join(' · ')}</div>
      </div>`;
    });
    dqHTML+=`</div>`;
  }

  return `
    <dl>
      <dt>Title</dt><dd>${row.question_title||'—'}</dd>
      <dt>Type</dt><dd>${row.question_type||'—'}</dd>
      <dt>Status</dt><dd>${row.status||'—'}</dd>
      <dt>Rounds</dt><dd>${['R1','R2','R3','R4','R5'].filter(r=>row[`in_${r}`]==='✓').join(', ')}</dd>
      ${row.english_text?`<dt>Question Text</dt><dd style="font-style:italic">${engText}</dd>`:''}
      ${row.title_changes?`<dt>Title Change</dt><dd style="color:#856404">${row.title_changes}</dd>`:''}
      ${row.remarks?`<dt>Remarks</dt><dd style="color:#555">${row.remarks}</dd>`:''}
    </dl>
    ${skipHTML}${dcHTML}${dqHTML}`;
}

function toggleDetail(id){
  const el=document.getElementById(id);
  if(el) el.classList.toggle('open');
}
function toggleAllDetails(mod){
  const table=document.getElementById(`qtable-${mod}`);
  if(!table)return;
  const panels=table.querySelectorAll('.q-detail');
  const anyOpen=[...panels].some(p=>p.classList.contains('open'));
  panels.forEach(p=>p.classList.toggle('open',!anyOpen));
}

// ── INIT ──────────────────────────────────────────────────────────────────────
buildOverview();
buildSkip();
buildMandatory();
buildOOR();
buildMissing();
buildInterview();
buildChanges();
buildAllModulePages();
buildPanel();
</script>
</body>
</html>"""

out = _os.path.join(_OUTPUT, 'l2ph_dq_dashboard.html')
# Replace placeholders with actual JSON data
content = HTML
content = content.replace('""" + DQ  + """', DQ)
content = content.replace('""" + MT  + """', MT)
content = content.replace('""" + AQ  + """', AQ)
content = content.replace('""" + PAN + """', PAN)
with open(out,'w') as f:
    f.write(content)
print(f'Generated: {out} ({round(os.path.getsize(out)/1024,1)} KB)')
