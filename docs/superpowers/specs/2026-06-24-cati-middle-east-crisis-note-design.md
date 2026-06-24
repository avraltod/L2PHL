# CATI Middle East Crisis — Rapid Note Design Spec

**Date:** 2026-06-24
**Author:** AP (Avralt-Od Purevjav) · requested by Sharon ("get the crisis note out asap")
**Status:** Approved design → build.
**Type:** One-time rapid analytical brief (NOT the reproducible-storyline pipeline — speed prioritized).

## Purpose

A 2-page World Bank brief on **how the Middle East crisis is perceived to be affecting Filipino households**, using the new Views questions added to the CATI panel in R6 (fielded ~Apr/May 2026) and repeated in R7 (~May 2026).

## The questions (M09 Views, new in R6–R7)

| Var | Question |
|-----|----------|
| V13 | Perceived impact of Middle East–crisis disruptions on the Philippines |
| V14 | How concerned the household is that it will affect *them* |
| V15_A/B/C | Top-3 ranked **channels** of impact (fuel/food prices, OFW jobs/remittances, …) |
| V16 | Agree/disagree: "the government is doing enough to respond" |
| V17 | Prices in the **past 30 days** (typical / faster / much faster) — felt inflation |
| V18 | Prices expected in the **next 30 days** — inflation expectations |

**Cross-cut:** shocks-module **coping mechanisms** (`sh2_*` — borrowing, savings, cutting spending, assistance) among the concerned / price-pressured households.

## Breakdowns (every metric)
- **Overall**
- **By location** — region (NCR / Luzon ex-NCR / Visayas / Mindanao)
- **By income quintile**
- **R6 → R7** movement where meaningful

## Data plan

Source data lives outside the pooled HF datasets (the new questions were not re-pooled):
- **V13–V18 + `sh2_*` + `hhid`:** raw Kobo exports — `CATI/Round06/xls/L2PHL_CATI_R06_-_all_versions_*.xlsx` and `CATI/Round07/xls/L2PHL_CATI_R07_-_all_versions_*.xlsx` (R7 export confirmed to contain V13–V18, the `sh2_` sheet, and `hhid`; ~17k rows incl. repeats).
- **Region, weight, income quintile:** `CAPI/S2S/target_hh_imputed.dta` (survey-to-survey imputed) — carries `hhid`, `region`, `urban`, `hhweight`, and imputed per-capita income `pcinc_imp_*` (MI draws). **Income quintile = weighted quintiles of mean(`pcinc_imp_*`) per household**, merged to CATI households by `hhid`.

Workflow (Stata via MCP, user-authorized):
1. Import each round's raw export → keep `hhid`, V13–V18, V15 ranks, `sh2_*`; tag round.
2. Build the household income quintile from S2S imputed per-capita income (mean of MI draws, `hhweight`-weighted `xtile`).
3. Merge by `hhid` → region + `hhweight` + quintile.
4. Weighted distributions of each metric: overall, by region, by quintile, per round; plus the concerned×coping cross-tab.
5. Export the figures into the 2-page Word brief (docx/export-docx skills).

## Deliverable

`CATI/Analysis/SL/` (or a `briefs/` folder) — `L2PHL_CATI_MiddleEast_Crisis_Note_Jun2026.docx`: headline finding, 4–6 compact charts/tables (impact & concern; top channels; government response; price felt vs expected; coping cross), each with the region + quintile breakdown, R6→R7. World Bank tone and number conventions (`rules/world-bank-style.md`).

## Open / to-confirm during build
- **Quintile construction** — using mean-of-MI-draws weighted quintiles from S2S `pcinc_imp_*`; if Sharon/team has an official quintile cut (e.g. in `CAPI/S2S/s2s_diagnostics.xlsx`), substitute it.
- **`hhid` join keys** — confirm the raw export `hhid` matches the S2S `hhid` (handle `vhhid`/`replacement_hhid` if needed).
- **V15 channel coding** — map the `middle_east_top` value labels to readable channel names.

## Out of scope
- Reproducible pipeline / `build_*_story` integration (one-time note).
- The other R6 additions (IC/ID transfers, N1/N3 internet, F08 FIES) — separate work.
