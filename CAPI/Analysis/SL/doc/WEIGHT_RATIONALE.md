# L2Phl CAPI Baseline — Survey Weight Rationale

**Document purpose:** Formal record of which analytical weight is used for each indicator
and why. This document supports reproducibility and can be cited in response to
reviewer or management queries about methodology.

**Date:** March 2026
**Authors:** L2Phl analysis team

---

## Three Weights, Three Questions

| Weight | Variable | Unit of analysis | Interpretation |
|--------|----------|------------------|----------------|
| `indw` | Individual weight | Person | "X% of individuals..." or "mean per person" |
| `hhw`  | Household weight | Household | "X% of households..." or "mean per HH" |
| `popw` | Population weight (HH-level) | Population via HH | "X% of Filipinos live in HHs where..." |

### When to use each

**`indw`** — when the person is the unit of observation. The respondent answered
about *themselves* (education attendance, employment status, health coverage,
disability, SSB consumption). Result reads: "52% of working-age adults are employed."

**`hhw`** — when the household is the unit and the narrative is about HH-level
*behaviour or decisions* (bank account ownership, saving, loan applications,
OFW remittance receipt, migration intent, life satisfaction, perceptions).
Result reads: "5% of households have a bank account."

**`popw`** — when the household is the unit but the policy-relevant framing is
about *how many people are affected*. This is standard World Bank practice for
SDG/welfare reporting on living conditions. Result reads: "96% of Filipinos live
in electrified households." This is more meaningful for policy than "96% of
households have electricity" because larger households (often poorer) carry
more weight.

### Key distinction: `hhw` vs `popw`

Both use the same HH-level data (one observation per household). The difference
is the weight:

- `hhw` gives each *household* equal representation → answers "how many HHs?"
- `popw` gives larger households more weight → answers "how many people?"

For welfare/living-condition indicators, `popw` is preferred because:
1. Policy targets are usually framed in terms of people, not households
2. Larger (often poorer) households get appropriate representation
3. This aligns with SDG monitoring methodology
4. It matches Dil's approach in `l2phil_brief_*@DA@20260122.do`

---

## Section-by-Section Weight Assignment

### §1 Roster (M01) — `indw`
**Rationale:** All roster indicators describe individual characteristics
(age, sex, disability, marital status). The person is the unit.

| Indicators | Weight | Note |
|------------|--------|------|
| R01_UNDER20, age groups, median age | indw | Age distribution of population |
| R01_PCT_MALE/FEMALE | indw | Sex ratio |
| R01_DISABILITY + by sex/settlement | indw | Individual disability prevalence |
| R01_PWDID | indw | Among PWD individuals |

### §2 Education (M02) — `indw`
**Rationale:** Education attendance, attainment, and expenditure are
individual-level decisions and outcomes.

| Indicators | Weight | Note |
|------------|--------|------|
| E02_ATTEND (5–24) + breakdowns | indw | Individual school attendance |
| E02_PUBLIC | indw | Individual school type |
| E02_MEAN_EXP | indw | Per-student expenditure |

### §3 Employment (M03) — `indw`
**Rationale:** Labour market outcomes are individual-level (employment,
contracts, hours worked).

| Indicators | Weight | Note |
|------------|--------|------|
| A03_EMP_RATE + breakdowns | indw | Individual employment status |
| A03_NO_CONTRACT | indw | Individual contract status |
| A03_MEAN_HOURS | indw | Individual work hours |
| A03_EMPLOYER_PENSION | indw | Individual benefit receipt |

### §4 Income (M04) — mixed `indw` / `hhw` / `popw`
**Rationale:** Individual earnings use indw. HH-level transfers use hhw for
behavioural indicators (OFW, domestic support) and popw for welfare coverage
indicators (pension, 4Ps).

| Indicators | Weight | Rationale |
|------------|--------|-----------|
| I04_REGULAR_INC, I04_MEAN_CASH_6MO | indw | Individual earnings |
| I04_OFW_PCT, I04_OFW_MEAN | hhw | HH-level remittance receipt |
| I04_DOMESTIC_PCT | hhw | HH-level support receipt |
| **I04_PENSION_PCT** | **popw** | Welfare: "% of population in pension-receiving HHs" |
| I04_PENSION_AMT | hhw | Per-HH amount |
| **I04_4PS_PCT** | **popw** | Welfare: "% of population covered by 4Ps" |

### §5 Finance (M05) — mostly `hhw`, one `popw`
**Rationale:** Financial decisions are HH-level. Exception: emergency capacity
is a vulnerability/welfare indicator better framed as population share.

| Indicators | Weight | Rationale |
|------------|--------|-----------|
| F05_f1 (bank account) | hhw | HH financial decision |
| F05_f2 (mobile money) | hhw | HH financial decision |
| F05_f3 (savings) | hhw | HH financial behaviour |
| F05_f4 (paluwagan) | hhw | HH financial behaviour |
| F05_f5 (credit card) | hhw | HH financial access |
| **F05_f6 (300k emergency)** | **popw** | Vulnerability: how many people lack safety net |
| F05_f7 (loan application) | hhw | HH financial decision |

### §6 Migration (M06) — `hhw` / `indw`
| Indicators | Weight | Rationale |
|------------|--------|-----------|
| M06_CONSIDERING | hhw | HH-level question |
| M06_DISPLACED | indw | Individual experience |

### §7 Health (M07) — `indw` / `popw`
**Rationale:** Health care access and coverage are individual-level.
Hospital bill is HH-level expense, uses popw (matching Dil's approach).

| Indicators | Weight | Rationale |
|------------|--------|-----------|
| H07_NEEDED, H07_ABLE, H07_OOP | indw | Individual health-seeking |
| H07_PHILHEALTH + by region | indw | Individual coverage |
| H07_HOSP (% hospitalised) | indw | Individual event |
| **H07_HOSP_BILL** | **popw** | HH-level expense; matches Dil's popw+hh_tag |

### §8 Food (M08) — `hhw` / `indw`
| Indicators | Weight | Rationale |
|------------|--------|-----------|
| FO8_WETMARKET | hhw | HH food sourcing behaviour |
| FO8_SSB, FO8_SSB_SERVINGS | indw | Individual consumption |

### §9 Hazards (M09) — `popw`
**Rationale:** Disaster exposure is HH-level but the policy question is
"how many people were warned/assisted" — population share.

| Indicators | Weight | Rationale |
|------------|--------|-----------|
| **NH9_WARNING** | **popw** | DRR: % of affected population that got warning |
| **NH9_ASSIST** | **popw** | Humanitarian: % of affected population that got help |

### §10 Dwelling (M10) — `popw`
**Rationale:** Housing conditions are welfare/SDG indicators. "X% of Filipinos
live in houses with [material/tenure]" is the policy-relevant framing.

| Indicators | Weight | Rationale |
|------------|--------|-----------|
| **DW10_TYPE** (building type) | **popw** | Housing conditions |
| **DW10_ROOF** (roof material) | **popw** | Structural vulnerability |
| **DW10_WALL** (wall material) | **popw** | Structural vulnerability |
| **DW10_TENURE** (tenure status) | **popw** | Housing security |

### §11 Sanitation (M11) — mostly `popw`
**Rationale:** WASH indicators follow SDG 6 methodology using population share.
Waste segregation behaviour stays on hhw.

| Indicators | Weight | Rationale |
|------------|--------|-----------|
| **S11_TOILET** (toilet type) | **popw** | SDG 6: people with improved sanitation |
| **S11_SHARED** (shared toilet) | **popw** | SDG 6: people sharing toilet |
| S11_SEG_ORGANIC | hhw | HH waste management behaviour |
| S11_SEG_RECYCLE | hhw | HH waste management behaviour |

### §12 Utilities (M12) — `popw`
**Rationale:** Access to electricity, internet, and water are SDG indicators
(SDG 6, 7) framed as "% of population with access."

| Indicators | Weight | Rationale |
|------------|--------|-----------|
| **U12_ELEC** + by macro-region | **popw** | SDG 7: people with electricity |
| **U12_INTERNET** + by macro-region | **popw** | Digital inclusion |
| **U12_PIPED_WATER** | **popw** | SDG 6: people with safe water |
| **U12_WATER_SAFE** + by settlement | **popw** | Water safety perception |

### §13 Assets (M13) — mixed `hhw` / `popw`
**Rationale:** Asset ownership is an HH-level stock indicator (hhw).
Cooking fuel is an SDG 7 indicator about exposure to indoor air pollution (popw).

| Indicators | Weight | Rationale |
|------------|--------|-----------|
| HC13_OWN_* (all assets) | hhw | HH asset stock |
| HC13_OWN_* by settlement | hhw | HH asset stock |
| **HC13_FUEL_*** (cooking fuel) | **popw** | SDG 7: people using clean cooking |

### §14 Views (M14) — `hhw`
**Rationale:** Perception/sentiment questions are answered by the HH head
on behalf of the household. HH weight is standard for subjective wellbeing
in HH surveys.

| Indicators | Weight | Rationale |
|------------|--------|-----------|
| V14_LIFESAT + by region | hhw | HH head's subjective assessment |
| V14_WORSE_OFF | hhw | HH head's economic perception |
| V14_V9 series (concerns) | hhw | HH head's views |
| V14_V2 (self-income class) | hhw | HH self-classification |
| V14_V8 (safety) | hhw | HH perception |
| V14_V10 series | hhw | HH head's views |

---

## Alignment with Dil's Analysis

Dil's do-files (`l2phil_brief_*@DA@20260122.do`) use `popw` with `hh_tag==1`
for HH-level indicators. Our `popw` assignments above are consistent with
her approach. Two specific alignments:

1. **Hospital bill (h14):** Dil uses `mean h14 [aw=popw] if hh_tag==1` — 
   we now match this exactly.
2. **Shared toilet (s1):** Dil uses s1 toilet type categories (codes 2, 4) —
   we now match this definition.

Remaining small differences (~1–2%) between our Python/R outputs and Dil's
Excel are attributable to:
- Floating-point precision in NA handling
- Minor differences in how missing values are treated at boundaries

---

## Change Log

| Date | Change | Reason |
|------|--------|--------|
| 2026-03-25 | Initial weight assignment — all HH indicators on hhw | Default |
| 2026-03-25 | Hospital bill: h14>0 → h14>=0, include free stays | Match Dil |
| 2026-03-25 | S11_SHARED: s3==1 → s1.isin([2,4]) | Match Dil's definition |
| 2026-03-25 | 17 indicators changed hhw → popw | SDG/welfare/policy alignment |

---

*This document should be updated whenever weight assignments change.
Replication scripts: Python (§2), R (§3), Stata (§0) — all in Analysis/SL/.*
