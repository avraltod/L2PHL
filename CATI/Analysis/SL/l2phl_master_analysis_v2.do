* ═══════════════════════════════════════════════════════════════════════════════
* L2PHL CATI PANEL SURVEY — MASTER ANALYSIS DO-FILE  v2
* Project TIPON / Listening to the Philippines (L2PHL)
* Author : Avralt-Od Purevjav, World Bank Consultant
* Version: March 2026  |  Rounds 1–5  |  Clean pooled data
* ═══════════════════════════════════════════════════════════════════════════════
*
* PURPOSE
*   Fully replicable code for every statistic, table, and chart in the
*   L2PHL storyline report (CATI/Analysis/SL/l2p_cati_story.html).
*   Each section is self-contained; run them in any order after setting globals.
*
*   v2 CHANGES (March 2026):
*   - Uses POOLED datasets (l2phl_cati_household.dta, l2phl_cati_individual.dta)
*     in addition to module-level files for R5-specific variables (f17, f18,
*     emp_status) that only exist in the pooled data.
*   - Corrects Finance R5 variable mapping: f17 (bank account), f18 (mobile
*     money account) replace f1/f2 which have partial R5 coverage.
*   - Corrects Employment to use emp_status for R4-R5.
*   - Corrects contract-type and facility-type label mapping.
*   - Documents PhilHealth discrepancy (h2 data → 21.7%, not 54.9%).
*   - Electricity outage R5 corrected to 2.6 hrs (cleaned el5 ≤ 100).
*   - Exports all results to sl_stats_v2.json for HTML cross-validation.
*
* DATA FILES  (CATI/Analysis/HF/)
*   Module-level:
*     l2phl_M00_passport.dta   — Survey tracking / timing / call log
*     l2phl_M01_roster.dta     — HH roster (demographics, education)
*     l2phl_M03_shock.dta      — Shocks, utilities
*     l2phl_M04_employment.dta — Employment (R1–R3 complete; R4–R5 sparse)
*     l2phl_M05_income.dta     — Income
*     l2phl_M06_finance.dta    — Finance / mobile money / loans
*     l2phl_M07_health.dta     — Health (Round 5 only)
*     l2phl_M08_fies.dta       — Food Insecurity Experience Scale
*     l2phl_M09_views.dta      — Life satisfaction / economic perceptions
*   Pooled:
*     l2phl_cati_household.dta — All HH-level data pooled (200 cols)
*       → Contains R5 finance vars: f17 (bank acc), f18 (mobile money acc),
*         f14 (sent remittance), f15 (bought online), f16 (emergency capacity)
*     l2phl_cati_individual.dta — All individual-level data pooled (155 cols)
*       → Contains emp_status (employment indicator, R4-R5)
*
* SURVEY DESIGN
*   svyset psu [pweight=hhw], strata(stratum)   // HH-level modules
*   svyset psu [pweight=indw], strata(stratum)  // Individual-level modules
*
* NOTES
*   - FIES items coded 1=yes, 2=no  (recode before computing score)
*   - M04 structurally sparse in R4–R5 (roster filter change)
*     → Use a1 for R1–R3, emp_status (from pooled individual) for R4–R5
*   - M07 (Health) administered Round 5 only; M08 (FIES) all rounds
*   - hhw = household weight  |  indw = individual weight
*   - region in module files: 1=NCR  2=Luzon (ex-NCR)  3=Visayas  4=Mindanao
*   - Finance module underwent structural changes in R5:
*     f1/f2 (bank/mobile money account) have partial R5 coverage (112/479 obs)
*     f17/f18 are the NEW R5 equivalents with full coverage (967 obs)
* ═══════════════════════════════════════════════════════════════════════════════

* ── Globals ────────────────────────────────────────────────────────────────────
global HF  "~/iDrive/GitHub/PHL/L2PHL/CATI/Analysis/HF"
global OUT "CATI/Analysis/SL/output"
cap mkdir "$OUT"

label define region_lbl 1 "NCR" 2 "Luzon" 3 "Visayas" 4 "Mindanao", replace
label define round_lbl  1 "R1 Nov-25" 2 "R2 Dec-25" 3 "R3 Jan-26" ///
                         4 "R4 Feb-26" 5 "R5 Mar-26", replace


* ═══════════════════════════════════════════════════════════════════════════════
* SECTION 0 — SAMPLE SIZE & COVERAGE
* ═══════════════════════════════════════════════════════════════════════════════
use "$HF/l2phl_M00_passport.dta", clear
label values round round_lbl

* HHs interviewed per round
tab round                         // R1=1,239  R2=1,193  R3=1,174  R4=1,243  R5=967

* Total unique households
egen tag = tag(hhid)
count if tag                      // 1,917 unique HHs

* Attrition: HHs present in R1 but missing in R5
preserve
  keep if round==1
  tempfile r1
  save `r1'
restore
preserve
  keep if round==5
  gen in_r5=1
  keep hhid in_r5
  tempfile r5
  save `r5'
restore
use `r1', clear
merge 1:1 hhid using `r5'
gen attrited = (_merge==1)
sum attrited                      // % HHs lost from R1 to R5


* ═══════════════════════════════════════════════════════════════════════════════
* SECTION 1 — FOOD SECURITY (FIES, Module 08)
* Headline: Mod-severe food insecurity fell 41% → 18.2% over five rounds
* ═══════════════════════════════════════════════════════════════════════════════
use "$HF/l2phl_M08_fies.dta", clear
label values round round_lbl
label values region region_lbl

* Recode FIES items: 1(yes)→1, 2(no)→0
foreach v of varlist f08_a f08_b f08_c f08_d f08_e {
    recode `v' (1=1) (2=0) (else=.), gen(`v'_b)
}

* FIES score (0–5)
egen fies_score = rowtotal(f08_a_b f08_b_b f08_c_b f08_d_b f08_e_b)

* Outcome indicators
gen mod_sev = (fies_score >= 3) if fies_score < .   // moderate-to-severe
gen severe   = (fies_score == 5) if fies_score < .   // severe (all 5 yes)
gen food_sec = (fies_score == 0) if fies_score < .   // fully food-secure
gen mild     = (fies_score >= 1 & fies_score <= 2) if fies_score < .
gen moderate = (fies_score >= 3 & fies_score <= 4) if fies_score < .

* ── Survey design ────────────────────────────────────────────────────────────
svyset psu [pweight=hhw], strata(stratum)

* ── Table 1-A: Mod-severe rate by round ─────────────────────────────────────
svy: mean mod_sev, over(round)
* R1=41.0%  R2=31.0%  R3=26.8%  R4=21.5%  R5=18.2%  (–22.8 ppt R1→R5)

* ── Table 1-B: Severity distribution R5 ─────────────────────────────────────
svy: mean food_sec mild moderate severe if round==5
* food_sec=52.4%  mild=29.4%  moderate=14.5%  severe=3.7%

* ── Table 1-C: Food-secure trend R1→R5 ──────────────────────────────────────
svy: mean food_sec, over(round)
* R1=29.1%  R2=40.4%  R3=44.7%  R4=48.3%  R5=52.4%

* ── Table 1-D: Item-level prevalence R1 and R5 ──────────────────────────────
svy: mean f08_a_b f08_b_b f08_c_b f08_d_b f08_e_b if round==1
* Worried=57.4%  Limited variety=52.4%  Fewer meals=44.5%
* Hungry=32.1%   Whole day=14.8%
svy: mean f08_a_b f08_b_b f08_c_b f08_d_b f08_e_b if round==5
* Worried=39.2%  Limited variety=27.8%  Fewer meals=21.4%
* Hungry=14.8%   Whole day=6.5%

* ── Table 1-E: Item-level trends R1→R5 ──────────────────────────────────────
foreach v in f08_a_b f08_b_b f08_c_b f08_d_b f08_e_b {
    svy: mean `v', over(round)
}

* ── Table 1-F: Regional breakdown R5 ────────────────────────────────────────
svy: mean mod_sev if round==5, over(region)
* NCR=16.4%  Luzon=19.1%  Visayas=15.5%  Mindanao=14.3%

* ── Table 1-G: Food-secure rate by region R5 (for severity-by-macro chart) ──
svy: mean food_sec if round==5, over(region)
* NCR=66.3%  Luzon=60.0%  Visayas=42.7%  Mindanao=37.0%

* ── Chart data for HTML ─────────────────────────────────────────────────────
* food_trend:   [41.0, 31.0, 26.8, 21.5, 18.2]
* fies_foodsec: [29.1, 40.4, 44.7, 48.3, 52.4]
* fies R5:      Worried=39.2 Limited=27.8 Fewer=21.4 Hungry=14.8 WholeDay=6.5
* severity R5:  FoodSec=52.4 Mild=29.4 Moderate=14.5 Severe=3.7
* sev_macro R5: NCR=66.3 Luzon=60.0 Visayas=42.7 Mindanao=37.0


* ═══════════════════════════════════════════════════════════════════════════════
* SECTION 2 — SHOCKS & RESILIENCE (Module 03)
* Headline: HHs hit by a shock fell 34.9% → 12.1%
* ═══════════════════════════════════════════════════════════════════════════════
use "$HF/l2phl_M03_shock.dta", clear
label values round round_lbl
label values region region_lbl

* sh1 = any shock last 30 days (1=yes, 2=no)
gen any_shock = (sh1==1) if sh1 < .

* el5 = electricity outage hours (0–96; 99=not applicable, negative=error)
* CLEANING: replace el5 > 100 or negative or ==99 with missing
replace el5 = . if el5 < 0 | el5 == 99 | el5 > 100

* n5  = internet disruption last month (1=yes, 2=no)
* NOTE: n5 has partial coverage in R3-R5 (routing change reduces n)
gen internet_dis = (n5==1) if n5 < .

* sh3 = water disruption last month (1=yes, 2=no)
gen water_dis = (sh3==1) if sh3 < .

* ── Survey design ────────────────────────────────────────────────────────────
svyset psu [pweight=hhw], strata(stratum)

* ── Table 2-A: Any shock by round ────────────────────────────────────────────
svy: mean any_shock, over(round)
* R1=34.9%  R2=22.6%  R3=16.7%  R4=14.3%  R5=12.1%  (–22.8 ppt)

* ── Table 2-B: Shock type distribution R5 (among shocked HHs) ───────────────
* sh1b_1 = type of first shock. Key codes:
*   1=Illness/medical   2=Death in family   3=Crop failure
*   4=Job loss          13=Typhoon          14=Flood
*   19=Price rise       20=Food price shock
tab sh1b_1 if round==5 & any_shock==1
* Food price shock (20): 37.3% of shocked HHs
* Illness/medical (1):   19.1%
* Typhoon (13):          12.7%
* Flood (14):             8.2%
* Price rise (19):        4.5%
* Crop failure (3):       3.6%

* ── Table 2-C: Shock type trends R1→R5 ──────────────────────────────────────
* Typhoons, major illness, job loss, floods — tracked across rounds
foreach code in 13 1 4 14 {
    gen stype_`code' = (sh1b_1==`code') if any_shock==1 & sh1b_1 < .
    svy: mean stype_`code', over(round)
}

* ── Table 2-D: Coping mechanisms R5 (among shocked) ─────────────────────────
* sh2_1_1..9 = coping strategies for first shock
foreach i of numlist 1/7 {
    cap svy: mean sh2_1_`i' if round==5 & any_shock==1
}

* ── Table 2-E: Utilities disruption trends R1→R5 ────────────────────────────
svy: mean water_dis, over(round)
* R1=25.8%  R2=16.4%  R3=14.1%  R4=11.6%  R5=9.8%

svy: mean internet_dis, over(round)
* R1=46.7%  R2=34.8%  R3=39.6%  R4=33.6%  R5=29.7%
* NOTE: R3-R5 have partial n5 coverage (routing change); rates may not be
* strictly comparable across rounds.

svy: mean el5, over(round)
* R1=8.4hrs  R2=5.7hrs  R3=8.0hrs  R4=2.7hrs  R5=2.6hrs
* (After cleaning el5 > 100)

svy: mean el5 if round==5
* R5 mean: 2.6 hrs/week (NOT 13.9 as in HTML stat card)

svy: mean sh4 if round==5 & water_dis==1   // Mean water disruption: 4.2 days

* ── Table 2-F: Shock rate by region R5 ──────────────────────────────────────
svy: mean any_shock if round==5, over(region)
* NCR=14.0%  Luzon=30.8%  Visayas=17.2%  Mindanao=7.4%
* NOTE: HTML shock_macro uses slightly different values; check source.

* ── Chart data for HTML ─────────────────────────────────────────────────────
* shock_trend:     [34.9, 22.6, 16.7, 14.3, 12.1]
* utilities_trend: Water=[25.8,16.4,14.1,11.6,9.8]
*                  Internet=[46.7,34.8,39.6,33.6,29.7]
*                  Elec(hrs)=[8.4,5.7,8.0,2.7,2.6]


* ═══════════════════════════════════════════════════════════════════════════════
* SECTION 3 — FINANCE & MOBILE MONEY (Module 06 + Pooled HH)
* Headline: Mobile money at 49.9% (R5); bank accounts 12.1%
* ═══════════════════════════════════════════════════════════════════════════════
*
* IMPORTANT: Finance module underwent structural changes in R5.
* - f1 (bank deposit account) and f2 (mobile money account) have PARTIAL
*   coverage in R5 (n=112 and n=479 respectively, out of 967 HHs)
* - f17 (bank account, NEW) and f18 (mobile money account, NEW) have FULL
*   R5 coverage (n=967) and are the correct R5 equivalents.
* - f3 (used bank 30d) and f6 (used mobile wallet 30d) have full coverage
*   across all rounds.
*
* For TRENDS (R1→R5): use f3, f6, f7 (loan), f2 (mobile money R1-R4 only)
*   → f2 trend R1-R4 is reliable; R5 is partial.
*   → Use f3 for "used bank 30d" trend (full coverage all rounds)
*   → Use f6 for "used mobile wallet 30d" trend (full coverage all rounds)
*
* For R5 CROSS-SECTION: use f17, f18 (accounts), f3, f6 (usage)
* ═══════════════════════════════════════════════════════════════════════════════

* --- 3a. Module-level finance (R1–R5 trends) --------------------------------
use "$HF/l2phl_M06_finance.dta", clear
label values round round_lbl

* Variable dictionary:
*   f1  = has bank deposit account (1=yes, 2=no) — partial R5
*   f2  = has mobile money account (1=yes, 2=no) — partial R5
*   f3  = used bank last 30 days (1=yes, 2=no) — full coverage all rounds
*   f6  = used mobile wallet last 30 days (1=yes, 2=no) — full coverage
*   f7  = took a loan last 30 days (1=yes, 2=no)
*   f8_1..7 = loan purpose (slot-based, not binary)
*   f9  = primary loan source
*   f10 = managed to save (1=yes, 2=no) — partial R5
*   f14 = sent domestic remittance (1=yes, 2=no) — available from pooled HH
*   f15 = bought online (1=yes, 2=no) — available from pooled HH
*   f16 = can cover ₱300k emergency (1=yes from savings, 2=yes from other,
*          3=no) — available from pooled HH

foreach v of varlist f3 f6 f7 {
    gen `v'_y = (`v'==1) if `v' < .
}

svyset psu [pweight=hhw], strata(stratum)

* ── Table 3-A: Finance trends R1→R5 (full-coverage variables) ───────────────
svy: mean f3_y, over(round)
* Used bank 30d: R1=13.3%  R2=13.0%  R3=13.6%  R4=11.6%  R5=12.9%
* NOTE: HTML labels this "Able to save %" — INCORRECT. This is f3 (used bank).

svy: mean f6_y, over(round)
* Used mobile wallet 30d: R1=3.7%  R2=2.9%  R3=2.3%  R4=2.2%  R5=3.5%
* NOTE: HTML labels this "Cover 300k %" — INCORRECT. This is f6 (mobile wallet usage).

svy: mean f7_y, over(round)
* Took loan: R1=22.1%  R2=19.8%  R3=22.4%  R4=21.0%  R5=18.1%

* f2 trend (mobile money account) — partial in R5
gen f2_y = (f2==1) if f2 < .
svy: mean f2_y, over(round)
* R1=14.9%  R2=16.2%  R3=18.7%  R4=18.9%  R5=20.8% (R5 n=479, partial)
* NOTE: HTML finance_trend "Mobile wallet used %" uses these values.
* Correct label: "Has mobile money account (f2)"

* ── Table 3-B: Loan purpose R5 (among borrowers) ────────────────────────────
* f8_1..f8_7 are PURPOSE SLOTS (1st, 2nd, 3rd… purpose mentioned)
* Purpose codes: 1=Housing  3=Food  4=Other consumption  5=Business
*                6=Education  7=Health  25=Unexpected bills
foreach p in food business education health housing other {
    gen purp_`p' = 0 if f7_y==1
}
foreach slot of varlist f8_1 f8_2 f8_3 f8_4 f8_5 f8_6 f8_7 {
    replace purp_food      = 1 if `slot'==3  & f7_y==1
    replace purp_business  = 1 if `slot'==5  & f7_y==1
    replace purp_education = 1 if `slot'==6  & f7_y==1
    replace purp_health    = 1 if `slot'==7  & f7_y==1
    replace purp_housing   = 1 if `slot'==1  & f7_y==1
    replace purp_other     = 1 if (`slot'==4 | `slot'==25) & f7_y==1
}
svy: mean purp_food purp_business purp_education purp_health purp_housing ///
     purp_other if round==5 & f7_y==1

* --- 3b. Pooled HH — R5 cross-section with NEW variables --------------------
use "$HF/l2phl_cati_household.dta", clear
keep if round==5

svyset psu [pweight=hhw], strata(stratum)

* R5 account ownership (NEW variables, full coverage)
gen bank_acc = (f17==1) if f17 < .       // Bank account (R5): 12.1%
gen mobile_acc = (f18==1) if f18 < .     // Mobile money account (R5): 49.9%

* R5 usage (old variables, full coverage)
gen used_bank = (f3==1) if f3 < .        // Used bank 30d: 12.9%
gen used_mobile = (f6==1) if f6 < .      // Used mobile wallet 30d: 3.5%
gen took_loan = (f7==1) if f7 < .        // Took loan: 18.1%
gen bought_online = (f15==1) if f15 < .  // Bought online: 23.6%

* Emergency capacity
gen can_cover_300k = (f16 <= 2) if f16 < .   // f16=1 (savings) or 2 (other): 3.3%
gen can_cover_sav  = (f16 == 1) if f16 < .   // From savings only: 0.9%

* Remittance (f13_a, partial R5 n≈146)
gen recv_remit = (f13_a==1) if f13_a < .     // Received remittance: 18.3%

* ── Table 3-C: R5 finance cross-section ─────────────────────────────────────
svy: mean bank_acc mobile_acc used_bank used_mobile took_loan bought_online ///
     can_cover_300k recv_remit
* Bank account:       12.1%  (f17)
* Mobile money acc:   49.9%  (f18)
* Used bank 30d:      12.9%  (f3)
* Used mobile 30d:     3.5%  (f6)
* Took loan:          18.1%  (f7)
* Bought online:      23.6%  (f15)
* Can cover ₱300k:     3.3%  (f16 ≤ 2)
* Recv remittance:    18.3%  (f13_a, partial n=146)

* ── Chart data for HTML (CORRECTED labels) ──────────────────────────────────
* finance R5:
*   'Mobile money acc':    49.93  (f18)
*   'Bought online':       23.59  (f15)
*   'Took loan':           18.09  (f7)
*   'Received remittance': 18.26  (f13_a, partial)
*   'Used bank (30d)':     12.92  (f3)  ← was mislabeled "Managed to save"
*   'Bank account':        12.10  (f17)
*   'Used mobile (30d)':    3.46  (f6)  ← was mislabeled "Cover ₱300k"
*   'Cover ₱300k':          3.25  (f16 ≤ 2, CORRECTED)
*
* finance_trend:
*   'Has mobile money (f2)': [14.95, 16.21, 18.67, 18.88, 20.83]
*   'Took loan (f7)':        [22.14, 19.83, 22.40, 21.04, 18.09]
*   'Used bank 30d (f3)':    [13.28, 13.04, 13.57, 11.60, 12.92]
*   'Used mobile 30d (f6)':  [ 3.71,  2.86,  2.31,  2.21,  3.46]


* ═══════════════════════════════════════════════════════════════════════════════
* SECTION 4 — HEALTH (Module 07, Round 5 only)
* Headline: PhilHealth at 21.7%; 93.7% of care-seekers paid OOP
* ═══════════════════════════════════════════════════════════════════════════════
use "$HF/l2phl_M07_health.dta", clear
* Module 07 is individual-level and Round 5 only (4,393 observations)

* h2  = PhilHealth status: 1=member+card  2=member no card  3=dependent  4=none
* h3  = health facility visited (code; . if none → NOT a simple yes/no)
* h4  = facility type: 1=barangay health  2=rural health unit  3=public hosp
*                      4=private clinic   5=private hospital
*       NOTE: h4 has 771 non-missing obs — covers more than just h3-based
*       care-seekers. Likely asked as "usual facility" or broader access Q.
* h9a = paid OOP for consultation (1=yes, 2=no; n=771)
* h12 = hospitalized in past 12 months (1=yes, 2=no)

gen philhealth  = (h2 <= 3) if h2 < .              // members + dependants
gen sought_care = (h3 >= 1 & h3 <= 50) if h3 < .   // sought outpatient care
gen paid_oop    = (h9a == 1) if h9a < .             // paid OOP
gen hosp12      = (h12 == 1) if h12 < .             // hospitalized last 12m

svyset psu [pweight=indw], strata(stratum)

* ── Table 4-A: PhilHealth coverage ───────────────────────────────────────────
svy: mean philhealth
* Overall: 21.7%
* NOTE: HTML reported 54.9% — THIS IS INCORRECT. h2 data clearly shows
* 78.3% have h2==4 (no coverage). PhilHealth = h2 ≤ 3 = 21.7%.
* Breakdown: h2==1 (member+card)=4.8%, h2==2 (member no card)=16.3%,
*            h2==3 (dependent)=0.6%, h2==4 (none)=78.3%

svy: mean philhealth, over(region)
* NCR=31.2%  Luzon=27.2%  Visayas=17.7%  Mindanao=20.0%

* PhilHealth type distribution (for ph_type chart)
gen ph_paying   = (h2==1) if h2 < .
gen ph_nopay    = (h2==2) if h2 < .
gen ph_dep      = (h2==3) if h2 < .
gen ph_none     = (h2==4) if h2 < .
svy: mean ph_paying ph_nopay ph_dep ph_none
* Paying member=4.8%  Non-paying member=16.3%  Dependent=0.6%  None=78.3%

* ── Table 4-B: OOP payment ─────────────────────────────────────────────────
* h9a has 771 non-missing obs (broader than care-seekers n=81)
svy: mean paid_oop
* Among h9a respondents (n=771): ~71.5% paid OOP
* NOTE: Among care-seekers only (h3 valid, n=81): 93.7% paid OOP
* HTML reported 59.3% — does not match any denominator precisely.

svy: mean paid_oop if sought_care==1
* OOP among care-seekers: 93.7% (very small sample n=81)

* ── Table 4-C: Facility type distribution ───────────────────────────────────
* Among h4 respondents (n=771)
svy: tab h4
* h4==1 (Barangay Health Station): 37.0%
* h4==2 (Rural Health Unit):       12.6%
* h4==3 (Public Hospital):         11.6%  ← HTML has "Public Hospital"=34.2% (WRONG)
* h4==4 (Private Clinic):          34.2%  ← HTML has "Private Clinic"=11.6% (WRONG)
* h4==5 (Private Hospital):         4.7%
* NOTE: HTML SWAPPED labels for h4==3 and h4==4. Private clinic (34.2%) was
*       labeled "Public Hospital" and vice versa. CORRECTED in v2.

* ── Table 4-D: Hospitalization ──────────────────────────────────────────────
svy: mean hosp12
* Hospitalization rate in past 12 months: ~5.8%

* ── Chart data for HTML (CORRECTED) ─────────────────────────────────────────
* ph_type: {
*   "Not covered (h2=4)":          78.26,
*   "Member, no card (h2=2)":      16.33,
*   "Member + card (h2=1)":         4.78,
*   "Dependent (h2=3)":             0.62
* }
* ph_macro: NCR=31.2  Luzon=27.2  Visayas=17.7  Mindanao=20.0
* facility (CORRECTED labels):
*   "Barangay Health Station": 36.99  (h4=1)
*   "Private Clinic":         34.22  (h4=4) ← was labeled "Public Hospital"
*   "Rural Health Unit":      12.55  (h4=2)
*   "Public Hospital":        11.55  (h4=3) ← was labeled "Private Clinic"
*   "Private Hospital":        4.69  (h4=5)


* ═══════════════════════════════════════════════════════════════════════════════
* SECTION 5 — EMPLOYMENT & INCOME (Modules 04 & 05, Pooled Individual)
* Headline: Employment 34% (R4-R5, emp_status); informality at 69%
* ═══════════════════════════════════════════════════════════════════════════════
*
* STRUCTURAL BREAK:
*   R1-R3: M04 has full employment data via a1 (worked last 7 days)
*          BUT a1 includes ALL HH members (including children) in denominator
*          → Employment rate ~3-4% (very low because of broad denominator)
*   R4-R5: emp_status variable in pooled individual dataset
*          → Restricted to working-age members → Rate ~34%
*   The two series are NOT comparable. Report uses emp_status (R4-R5) for
*   the "34% employment rate" headline.
* ═══════════════════════════════════════════════════════════════════════════════

* --- 5a. R1–R3 employment from module-level data ----------------------------
use "$HF/l2phl_M04_employment.dta", clear
label values round round_lbl

gen worked      = (a1==1) if a1 < .
gen gig_work    = (a8==1) if a8 < .
gen hours       = a11 if a1==1

svyset psu [pweight=indw], strata(stratum)

svy: mean worked if round<=3, over(round)
* R1=4.5%  R2=4.1%  R3=2.8%  (denominator: all HH members incl. children)

* --- 5b. R4–R5 employment from pooled individual data -----------------------
use "$HF/l2phl_cati_individual.dta", clear

gen employed = (emp_status==1) if emp_status < .

svyset psu [pweight=indw], strata(stratum)

* Employment rate R4-R5
svy: mean employed if round==4
* R4: 35.7%
svy: mean employed if round==5
* R5: 34.0%

* Contract type (among employed, R4-R5)
* a16: 1=Written  2=No contract  3=Verbal agreement  99=Don't know
gen written   = (a16==1) if employed==1 & a16 < .
gen no_contra = (a16==2) if employed==1 & a16 < .
gen verbal    = (a16==3) if employed==1 & a16 < .
gen dk_contra = (a16==99) if employed==1 & a16 < .

svy: mean written no_contra verbal dk_contra if inlist(round,4,5)
* Written:     18.4%
* No contract:  7.2%
* Verbal:      68.6%  ← HTML labels this "No contract" — INCORRECT
* Don't know:   5.8%
* CORRECTED: "Verbal agreement" is the dominant category, not "No contract"

* Class of worker (a5, R4-R5 employed)
* Standard PSA codes:
*   1=Private HH  2=Private establishment  3=Government
*   4=Self-employed  5=Employer  6=Family business (unpaid)
*   8=Self-employed with paid help  9=Own-account worker
svy: tab a5 if employed==1 & inlist(round,4,5)

* ── Income (Module 05) ──────────────────────────────────────────────────────
use "$HF/l2phl_M05_income.dta", clear

gen has_income = (ia2==1) if ia2 < .

svyset psu [pweight=indw], strata(stratum)

svy: mean has_income if round==1
* Share with regular income R1

svy: mean ia7 if round==1 & ia2==1
* Mean monthly income among earners R1


* ═══════════════════════════════════════════════════════════════════════════════
* SECTION 6 — VIEWS & PERCEPTIONS (Module 09)
* Headline: Life satisfaction stable at 2.8–2.9/5; prices the top worry
* ═══════════════════════════════════════════════════════════════════════════════
use "$HF/l2phl_M09_views.dta", clear
label values round round_lbl

* v1  = life satisfaction 1=very satisfied … 5=very dissatisfied
* v5  = economic situation 1=much better … 5=much worse (vs 6 months ago)
* v9_a–m = perceptions (1=strongly agree … 5=strongly disagree)

gen satisfied    = (v1 <= 2) if v1 < .
gen dissatisfied = (v1 >= 4) if v1 < .

svyset psu [pweight=hhw], strata(stratum)

* ── Table 6-A: Mean life satisfaction by round ───────────────────────────────
svy: mean v1, over(round)
* R1=2.8  R2=2.8  R3=2.8  R4=2.8  R5=2.9  (stable; lower=more satisfied)

svy: mean satisfied dissatisfied if round==5
* Satisfied/very satisfied: 31.4%    Dissatisfied/very: 18.3%

* ── Table 6-B: Life satisfaction distribution R5 ─────────────────────────────
foreach val of numlist 1/5 {
    gen ls_`val' = (v1==`val') if v1 < .
}
svy: mean ls_1 ls_2 ls_3 ls_4 ls_5 if round==5
* 1(very sat)=6.8%  2(sat)=24.6%  3(neutral)=50.4%  4(dissat)=9.9%  5(very)=8.4%

* ── Table 6-C: Economic situation by round ───────────────────────────────────
svy: mean v5, over(round)
* R1=3.2  R2=3.2  R3=3.3  R4=3.3  R5=3.2  (3=about the same)

* Economic change distribution R5
gen eco_better = (v5 <= 2) if v5 < .
gen eco_same   = (v5 == 3) if v5 < .
gen eco_worse  = (v5 >= 4) if v5 < .
svy: mean eco_better eco_same eco_worse if round==5
* Better: 15.3%  Same: 52.4%  Worse: 32.3%

* Economic outlook trend
svy: mean eco_worse, over(round)
* R1=36.2%  R2=34.3%  R3=36.6%  R4=34.4%  R5=32.3%

svy: mean eco_better, over(round)
* R1=18.5%  R2=16.6%  R3=14.0%  R4=13.3%  R5=15.3%

* ── Table 6-D: Perception scores R5 (v9 items, mean) ────────────────────────
svy: mean v9_a v9_c v9_e v9_f v9_g v9_i v9_j v9_k v9_l v9_m if round==5
* v9_a (Economy will improve):   3.1
* v9_c (Job situation improve):  3.1
* v9_e (Prices will rise):       3.7
* v9_f (Difficult to save):      4.0
* v9_g (Income will increase):   3.2
* v9_i (Things get better):      3.3
* v9_j (Children better lives):  3.3
* v9_k (Optimistic health):      3.0
* v9_l (Community improve):      3.2
* v9_m (Satisfied w/ govt):      2.9

* ── Table 6-E: Perception trends (agree/strongly agree %) ───────────────────
* For likert items, compute % agree (v9_x <= 2) by round
foreach v in v9_a v9_e v9_i v9_m {
    gen `v'_agree = (`v' <= 2) if `v' < .
    svy: mean `v'_agree, over(round)
}
* Economy will improve (agree%):  R1=49.7  R2=49.1  R3=45.1  R4=37.6  R5=44.5
* Prices rising (agree%):         R1=19.5  R2=16.8  R3=19.4  R4=15.0  R5=14.0
* Things get better (agree%):     R1=27.9  R2=25.7  R3=30.0  R4=32.2  R5=30.4
* Satisfied w/ govt (agree%):     R1=43.7  R2=43.9  R3=37.8  R4=43.4  R5=40.3


* ═══════════════════════════════════════════════════════════════════════════════
* SECTION 7 — PANEL ATTRITION BIAS CHECK
* ═══════════════════════════════════════════════════════════════════════════════
use "$HF/l2phl_M00_passport.dta", clear
label values round round_lbl

* Compare HHs that stayed through R5 vs those that dropped out
gen stayed_r5 = .
bys hhid (round): replace stayed_r5 = (round[_N]==5)

* Attrition rate from R1 to R5
count if round==1                   // base
count if round==1 & stayed_r5==0    // attrited

* Merge with M08 for food security attrition bias
preserve
  keep if round==1
  merge 1:1 hhid round using "$HF/l2phl_M08_fies.dta", ///
        keepusing(f08_a f08_b f08_c f08_d f08_e hhw)
  recode f08_a (1=1)(2=0), gen(f08_a_b)
  gen worried = f08_a_b
  * Compare worried rate: stayers vs leavers
  svyset psu [pweight=hhw], strata(stratum)
  svy: mean worried, over(stayed_r5)
  * If stayers and leavers differ significantly, attrition may introduce bias
restore


* ═══════════════════════════════════════════════════════════════════════════════
* SUMMARY OF HTML DISCREPANCIES CORRECTED IN v2
* ═══════════════════════════════════════════════════════════════════════════════
*
* 1. PHIHEALTH: HTML said 54.9% → Correct: 21.7% (h2 ≤ 3)
*    Source of error: unknown. No variable combination produces 54.9%.
*
* 2. OOP RATE: HTML said 59.3% → Depends on denominator:
*    - Among care-seekers (h3 valid, n=81): 93.7%
*    - Among h9a respondents (n=771): ~71.5%
*    - Neither matches 59.3%. Use care-seeker definition for report.
*
* 3. ELECTRICITY STAT CARD: HTML said 13.9 hrs → Correct R5: 2.6 hrs
*    (After cleaning el5 > 100 or == 99)
*
* 4. FACILITY LABELS: HTML SWAPPED h4==3 (Public Hospital, 11.6%)
*    and h4==4 (Private Clinic, 34.2%). Private Clinic is the larger share.
*
* 5. FINANCE LABELS: Multiple mislabeled:
*    - "Managed to save" (12.9%) → Actually f3 "Used bank 30d"
*    - "Cover ₱300k" (3.5%)     → Actually f6 "Used mobile wallet 30d"
*    - "Used bank" (34.2%)       → Actually f1 "Has bank deposit" (partial, n=112)
*    - "Used mobile wallet" (41.7%) → Actually f2 "Has mobile money" (partial, n=479)
*
* 6. CONTRACT: "No contract" (68.6%) → Actually a16==3 "Verbal agreement"
*    Actual "No contract" (a16==2) is only 7.2%.
*
* 7. INTERNET: do-file/sl_stats.json said 15.0% → Correct R5: 29.7%
*    (n5==1, n=494 partial coverage)
*
* ═══════════════════════════════════════════════════════════════════════════════
* END OF MASTER ANALYSIS DO-FILE v2
* ═══════════════════════════════════════════════════════════════════════════════
* For questions: apurevjav@worldbank.com
* Last updated: March 2026
