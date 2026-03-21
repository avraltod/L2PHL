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

DQ  = json.dumps(dq_raw,       separators=(',',':'))
MT  = json.dumps(module_tables, separators=(',',':'))
AQ  = json.dumps(all_qs,        separators=(',',':'))

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
const DQ = """ + DQ + """;
const MT = """ + MT + """;
const AQ = """ + AQ + """;

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
</script>
</body>
</html>"""

out = _os.path.join(_OUTPUT, 'l2ph_dq_dashboard.html')
# Replace placeholders with actual JSON data
content = HTML
content = content.replace('""" + DQ + """', DQ)
content = content.replace('""" + MT + """', MT)
content = content.replace('""" + AQ + """', AQ)
with open(out,'w') as f:
    f.write(content)
print(f'Generated: {out} ({round(os.path.getsize(out)/1024,1)} KB)')
