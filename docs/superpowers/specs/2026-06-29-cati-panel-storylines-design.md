# L2Phl CATI Panel Storylines — Design

**Date:** 2026-06-29
**Status:** Approved (brainstorming) — ready for plan (Slice 1)
**Project:** L2Phl / Project TIPON · CATI Panel (Listening to the Philippines)

## Goal

An interactive, theme-based **scrollytelling** site for the CATI panel (Rounds 1–8) — a hub landing page plus 9 message-driven topic pages — that is far more engaging and visible than a Word document. Built on the existing `CATI/Analysis/SL/` data-binding + drift-check + QC-grounding spine.

## Audience

World Bank poverty/operational staff **and government counterparts** (PSA, NEDA, DSWD). Substantive evidence and trends, but polished and visual. Not a leadership-only skim, not a public-comms piece — a credible analytical product that reads well.

## Design decisions (validated in brainstorming)

- **Structure:** a topic-based **hub** (landing + per-theme pages), not one long narrative and not a module-by-module layout.
- **Themes, not modules:** each topic is a **message** that draws on whatever modules serve it (e.g. "Uneven recovery" spans all modules via breakdowns).
- **Reading experience:** combine **scrollytelling** (a chart that pins and morphs as you scroll) + **skimmable headline stats** + **interactive charts** (the user can toggle breakdowns / scrub rounds).
- **Breakdowns:** overall · **income quintile** (from baseline `pcinc_imp_mean`) · **region** (PSGC) · **urban/rural** · **sex/age**. Each chart declares which breakdowns it supports (sex/age only for individual-level indicators).
- **Palette:** official WBG — Navy `#002244`, Blue `#009FDA`, Green `#00A651` (positive), PH Red `#CE1126` (alerts), PH Gold `#FCD116` (highlights), cream `#f5f0e8` (paper).
- **Build:** hand-authored topic narratives + **one shared scrollytelling/chart engine** inlined into each **self-contained** HTML at build time (matches the project's "self-contained single file" convention). Not a spec-generator, not a single mega-app.

## Information architecture

### Hub — `CATI/Analysis/SL/html/l2p_cati_hub.html`
- Navy WBG hero: title ("Recovery is measurable. Vulnerability is not gone."), one-line framing, sample chips (2,470 households · Nov 2025 → Jun 2026 · 18 regions).
- A responsive grid of **9 message cards**, each: theme title, "draws on · <modules>", headline stat, a real-shape sparkline (R1–R8), colored by direction (green gain / red concern / blue rise / gold highlight). Each card links to its topic page.

### 9 topic pages — `CATI/Analysis/SL/html/l2p_cati_<theme>.html`

| # | Theme (message) | Draws on | Headline hook (illustrative; data-bound at build) |
|---|---|---|---|
| 1 | Recovery is measurable | Food · Shocks | food insecurity 41% → 18%; shocks 35% → 12% |
| 2 | Vulnerability hasn't moved | Finance · Employment · Shocks | ~2% can cover an emergency; assistance flat |
| 3 | The digital shift | Finance | mobile money → ~50% |
| 4 | Work without security | Employment · Income | ~72% no contract; employment ~52% |
| 5 | Lifelines | Migration · Finance | Christmas remittance surge ~24% (R3) |
| 6 | ⚠ The Middle East crisis | Views (V13–V18) · Migration · Finance | exposure & remittance risk (R6–R8) + rapid note |
| 7 | Uneven recovery | ALL (by income & region) | the equity lens — who recovers, who lags |
| 8 | Health under pressure | Health · Shocks | coverage & out-of-pocket (deep rounds R5, R8) |
| 9 | The national mood | Views | life satisfaction ~2.85/5; AI worry |

## Reading experience (per topic page)

1. **Hero:** kicker (`Theme N · <modules>`), big title, framing sentence. WBG colors on cream paper.
2. **3–6 scroll "beats."** Each beat = a **sticky interactive chart** (one column) + **scrolling prose** (other column). As the reader scrolls a beat into view, the engine advances the chart — to a later round, or to a different breakdown (e.g. beat 1 shows the overall decline; beat 2 switches to income quintile and the poorest-20% line stays high).
3. **Interactive chart** (Chart.js): breakdown toggle chips (only those the indicator supports), a **round scrubber** (R1–R8), **hover tooltips** with the exact weighted value. The chart is also directly explorable, not only scroll-driven.
4. **Headline stats** are **data-bound** `data-stat` spans — injected from JSON at build, never hand-typed, drift-checked.
5. **Footer:** source line (indicator, weighted), and any ⚠ QC caveat badge if a claim rests on an open firm issue.

## Data architecture

- **`l2phl_master_analysis.do`** (extended): for each storyline indicator, compute the **R1–R8 series** for **overall** and for each supported **breakdown** (income quintile, region, urban/rural, sex/age). Income quintiles derive from the **baseline imputed per-capita income** (`pcinc_imp_mean`) linked to panel households via the PSGC/household crosswalk already proven in the Middle East crisis note (~99% match). Region grouping: full 18 regions, with an optional NCR/Luzon/Visayas/Mindanao rollup for readability.
- **`_series_emit.do`** (new, sibling of `_stat_emit.do`): writes **`sl_series.json`** — keyed by indicator → `{ rounds: [...], overall: [...], by_quintile: {q1:[...],...}, by_region: {...}, by_urbanrural: {...}, by_sexage: {...} }`. Only the breakdowns an indicator supports are emitted.
- **`sl_stats.json`** (existing): continues to hold point stats for prose `data-stat` spans.
- Schema documented in `CATI/Analysis/SL/docs/sl_series_schema.md`.

## Build & files (`CATI/Analysis/SL/`)

- **`storyline.css`** — shared WBG theme + scrollytelling layout (sticky chart column, beat spacing, hero, hub grid, chips, scrubber).
- **`storyline.js`** — shared engine: scroll-driven beat detection (IntersectionObserver), chart state machine (round + breakdown), Chart.js construction/teardown, breakdown-toggle + scrubber + tooltip handlers. Reads embedded series JSON.
- **`build_storyline.py`** — for each topic: read the topic's HTML template (hero + beats + prose with `data-stat` spans), **inline** `storyline.css` + `storyline.js` + Chart.js CDN tag + that topic's slice of `sl_series.json`, inject point stats into the spans, and write a **self-contained** file to `html/`. Also build the hub from the theme registry (cards + sparklines). Keep the existing **`--check`** drift gate (build fails if any bound number disagrees with the data).
- Topic content lives in per-topic template files (hero + beats + authored prose), one per theme, so each story is independently editable.

## QC integration (reuse existing)

- **Drift-check:** `build_storyline.py --check` verifies every bound number matches the current data; nonzero exit blocks publish.
- **Grounding / badges:** reuse `grounding.py` + `storyline_badges.py` so any claim resting on an **open firm issue** gets a ⚠ caveat; self-heals when issues resolve.

## Testing

Reuse the `CATI/Analysis/SL/tests/` pattern (pytest):
- **Series emitter:** shape/keys of `sl_series.json` (rounds length, breakdown presence per indicator, no NaNs leaking).
- **Builder:** inlining (engine + Chart.js present, file self-contained), data-binding (spans populated; `--check` passes on matching data and fails on injected drift).
- **Engine logic** (where testable in Python/node): breakdown availability gating, round bounds.

## Phasing — two spec→plan→implement cycles

This is large; build it in two slices, each its own plan.

### Slice 1 — vertical slice (FIRST plan)
Prove the whole stack on one flagship topic:
- Stata: extend the analysis + new `_series_emit.do` → `sl_series.json` **for the indicators in Topic 1 ("Recovery is measurable")** with all supported breakdowns.
- `storyline.css` + `storyline.js` (the shared engine).
- `build_storyline.py` producing **Topic 1** as a self-contained scrollytelling page + a **hub shell** (hero + the 9 cards, only Topic 1 linked live).
- Tests + `--check` gate.
- Output reviewed in a browser.

### Slice 2 — remaining topics (LATER plan)
- Author the other 8 topic templates (prose + beats), extend the series emission to all indicators, wire all 9 hub cards live, finalize the hub.

## Out of scope (YAGNI)

- No CMS / live data refresh — regenerate from Stata each round (matches current workflow).
- No spec-generator or single mega-app (explicitly rejected).
- No public-facing comms styling beyond the WBG analytical look.
- Sex/age breakdowns only where the indicator is individual-level.
