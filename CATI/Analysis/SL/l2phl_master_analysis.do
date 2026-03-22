* ═══════════════════════════════════════════════════════════════════════════════
* L2PHL CATI PANEL SURVEY — MASTER ANALYSIS DO-FILE
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
* DATA FILES  (CATI/Analysis/HF/)
*   l2phl_M00_passport.dta   — Survey tracking / timing / call log
*   l2phl_M01_roster.dta     — HH roster (demographics, education)
*   l2phl_M03_shock.dta      — Shocks, utilities
*   l2phl_M04_employment.dta — Employment (R1–R3 complete; R4–R5 sparse)
*   l2phl_M05_income.dta     — Income
*   l2phl_M06_finance.dta    — Finance / mobile money / loans
*   l2phl_M07_health.dta     — Health (Round 5 only)
*   l2phl_M08_fies.dta       — Food Insecurity Experience Scale
*   l2phl_M09_views.dta      — Life satisfaction / economic perceptions
*
* SURVEY DESIGN
*   svyset psu [pweight=hhw], strata(stratum)   // HH-level modules
*   svyset psu [pweight=indw], strata(stratum)  // Individual-level modules
*
* NOTES
*   - FIES items coded 1=yes, 2=no  (recode before computing score)
*   - M04 structurally sparse in R4–R5 (roster filter change; use R1–R3)
*   - M07 (Health) administered Round 5 only; M08 (FIES) all rounds
*   - hhw = household weight  |  indw = individual weight
*   - region: 1=NCR  2=Luzon (ex-NCR)  3=Visayas  4=Mindanao
* ═══════════════════════════════════════════════════════════════════════════════

* ── Globals ────────────────────────────────────────────────────────────────────
global HF  "CATI/Analysis/HF"
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

* ── Survey design ────────────────────────────────────────────────────────────
svyset psu [pweight=hhw], strata(stratum)

* ── Table 1-A: Mod-severe rate by round ─────────────────────────────────────
svy: mean mod_sev, over(round)
* R1=41.0%  R2=31.0%  R3=26.8%  R4=21.5%  R5=18.2%  (–22.8 ppt R1→R5)

* ── Table 1-B: Severity distribution R5 ─────────────────────────────────────
svy: mean food_sec severe mod_sev if round==5
* food_sec=52.4%  severe=3.7%  mod_sev=18.2%

* ── Table 1-C: Item-level prevalence R1 and R5 ───────────────────────────────
svy: mean f08_a_b f08_b_b f08_c_b f08_d_b f08_e_b if round==1
* Worried=57.4%  Limited variety=52.4%  Fewer meals=44.5%
* Hungry=32.1%   Whole day=14.8%
svy: mean f08_a_b f08_b_b f08_c_b f08_d_b f08_e_b if round==5
* Worried=39.2%  Limited variety=27.8%  Fewer meals=21.4%
* Hungry=14.8%   Whole day=6.5%

* ── Table 1-D: Regional breakdown R5 ────────────────────────────────────────
svy: mean mod_sev if round==5, over(region)
* NCR=16.4%  Luzon=19.1%  Visayas=15.5%  Mindanao=14.3%

* ── Figure 1: Trend line for storytline chart ────────────────────────────────
* (export for Chart.js — values to paste into HTML)
* Round:      1     2     3     4     5
* mod_sev(%): 41.0  31.0  26.8  21.5  18.2

* ── Figure 2: FIES item bar chart R5 ────────────────────────────────────────
* Item          R1%    R5%
* f08_a         57.4   39.2   (Worried)
* f08_b         52.4   27.8   (Limited variety)
* f08_c         44.5   21.4   (Fewer meals)
* f08_d         32.1   14.8   (Hungry, didn't eat)
* f08_e         14.8    6.5   (Whole day without food)


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
replace el5 = . if el5 < 0 | el5 == 99   // clean outliers

* n5  = internet disruption last month (1=yes, 2=no)
gen internet_dis = (n5==1) if n5 < .

* sh3 = water disruption last month (1=yes, 2=no)
gen water_dis = (sh3==1) if sh3 < .

* sh4 = days water disrupted (conditional on sh3==1)

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

* ── Table 2-C: Coping mechanisms R5 (among shocked) ─────────────────────────
* sh2_1_1..9 = coping strategies for first shock
* 1=Used savings  2=Borrowed from family  3=Reduced food  4=Sold assets
* 5=Govt transfer  6=Remittance  7=Worked more
foreach i of numlist 1/7 {
    cap svy: mean sh2_1_`i' if round==5 & any_shock==1
}

* ── Table 2-D: Utilities disruption R5 ───────────────────────────────────────
svy: mean water_dis internet_dis if round==5
* Water disruption: 9.8%    Internet disruption: 15.0%

svy: mean el5 if round==5    // Mean electricity outage hours: 2.8 hrs/week

svy: mean sh4 if round==5 & water_dis==1   // Mean water disruption: 4.2 days

* ── Table 2-E: Shock rate by region R5 ──────────────────────────────────────
svy: mean any_shock if round==5, over(region)
* NCR=14.0%  Luzon=30.8%  Visayas=17.2%  Mindanao=7.4%


* ═══════════════════════════════════════════════════════════════════════════════
* SECTION 3 — FINANCE & MOBILE MONEY (Module 06)
* Headline: Mobile money at 20.8% and rising; bank deposits stable at 4%
* ═══════════════════════════════════════════════════════════════════════════════
use "$HF/l2phl_M06_finance.dta", clear
label values round round_lbl

* f1  = has bank deposit account (1=yes, 2=no)
* f2  = has mobile money account (1=yes, 2=no)
* f3  = used bank last 30 days (1=yes, 2=no)
* f6  = used mobile wallet last 30 days (1=yes, 2=no)
* f7  = took a loan last 30 days (1=yes, 2=no)
* f8_1..7 = loan purpose (multiple select)
* f9  = primary loan source
* f10 = managed to save (1=yes, 2=no)

foreach v of varlist f1 f2 f3 f6 f7 f10 {
    gen `v'_y = (`v'==1) if `v' < .
}

svyset psu [pweight=hhw], strata(stratum)

* ── Table 3-A: Key finance indicators R5 ─────────────────────────────────────
svy: mean f1_y f2_y f3_y f6_y f7_y f10_y if round==5
* Bank deposit:    4.1%   Mobile money:  20.8%
* Used bank:      12.9%   Used mobile:    3.5%
* Took loan:      18.1%   Saved:         17.0%

* ── Table 3-B: Mobile money trend R1→R5 ─────────────────────────────────────
svy: mean f2_y, over(round)
* R1=14.9%  R2=16.2%  R3=18.7%  R4=18.9%  R5=20.8%

* ── Table 3-C: Loan purpose R5 (among borrowers) ────────────────────────────
* f8_1=Medical  f8_2=Housing  f8_3=Business  f8_4=Food  f8_5=Education
* f8_6=Ceremonial  f8_7=Debt repayment
svy: mean f8_1 f8_2 f8_3 f8_4 f8_5 f8_6 f8_7 if round==5 & f7_y==1
* Medical/health: top purpose; followed by housing and business

* ── Table 3-D: Loan source R5 (among borrowers) ─────────────────────────────
* f9: 1=formal bank  2=informal lender  3=cooperative  4=pawnshop  5=govt
tab f9 if round==5 & f7_y==1
* 2=informal: most common  1=formal bank: second


* ═══════════════════════════════════════════════════════════════════════════════
* SECTION 4 — HEALTH (Module 07, Round 5 only)
* Headline: PhilHealth at 21.7%; OOP still the norm for 36.6% of care-seekers
* ═══════════════════════════════════════════════════════════════════════════════
use "$HF/l2phl_M07_health.dta", clear
* Module 07 is individual-level and Round 5 only (4,393 observations)

* h2  = PhilHealth status: 1=member+card  2=member no card  3=dependent  4=none
* h3  = sought outpatient care last 30 days (facility code, . if none)
* h4  = facility type: 1=barangay health  2=rural health unit  3=public hosp
*                      4=private clinic   5=private hospital
* h7  = OOP payment amount (0 if none)
* h9a = paid OOP for outpatient consult (1=yes, 2=no)
* h9b = able to afford? (1=yes, 2=no; recoded from OOP indicator)
* h12 = hospitalized in past 12 months (1=yes, 2=no)
* h17 = chronic illness indicator (1-5 severity/type)

gen philhealth  = (h2 <= 3) if h2 < .              // members + dependants
gen sought_care = (h3 >= 1 & h3 <= 50) if h3 < .   // sought outpatient care
gen paid_oop    = (h9a == 1) if h9a < .             // paid OOP for consult
gen hosp12      = (h12 == 1) if h12 < .             // hospitalized last 12m

svyset psu [pweight=indw], strata(stratum)

* ── Table 4-A: PhilHealth coverage ───────────────────────────────────────────
svy: mean philhealth
* Overall: 21.7%
svy: mean philhealth, over(region)
* NCR=31.2%  Luzon=27.2%  Visayas=17.7%  Mindanao=20.0%

* ── Table 4-B: Health care seeking ──────────────────────────────────────────
svy: mean sought_care
* Only 4–5% sought outpatient care in past 30 days

* ── Table 4-C: OOP payment rate (among care-seekers) ────────────────────────
svy: mean paid_oop if sought_care==1
* 36.6% of care-seekers paid out-of-pocket

* ── Table 4-D: Facility type distribution ───────────────────────────────────
tab h4 if sought_care==1
* 1=Barangay health: 37.1%   4=Private clinic: 35.0%
* 3=Public hospital: 11.5%   2=Rural health unit: 10.8%
* 5=Private hospital: 5.6%

* ── Table 4-E: Hospitalization ──────────────────────────────────────────────
svy: mean hosp12
* Hospitalization rate in past 12 months


* ═══════════════════════════════════════════════════════════════════════════════
* SECTION 5 — EMPLOYMENT & INCOME (Modules 04 & 05)
* IMPORTANT: M04 structurally sparse in R4–R5 due to roster filter change.
*            Use R1–R3 for employment estimates.
* Headline: Employment rate ~3% R1 (worked last 7 days, incl. all HH members)
* ═══════════════════════════════════════════════════════════════════════════════
use "$HF/l2phl_M04_employment.dta", clear
label values round round_lbl

* a1  = worked last 7 days (1=yes, 2=no)
* a3  = industry code (major occupation)
* a4  = class of worker
* a8  = gig/platform work (1=yes, 2=no)
* a10 = days worked last week (if a1==1)
* a11 = hours worked last week (if a1==1)
* a16 = has written contract (1=yes, 2=no, 3=verbal, 99=don't know)

gen worked      = (a1==1) if a1 < .
gen no_contract = (a16==2) if a16 < .   // no written contract
gen gig_work    = (a8==1) if a8 < .     // platform/gig work
gen hours       = a11 if a1==1          // hours worked last week (conditional)

svyset psu [pweight=indw], strata(stratum)

* ── Table 5-A: Employment rate by round (R1–R3 only) ─────────────────────────
svy: mean worked if round<=3, over(round)
* R1=3.0%  R2=2.7%  R3=1.9%  (note: denominator = all HH members incl. children)

* NOTE: Employment rates R4–R5 not reliable. a1 missing >95% due to roster
* filter change restricting M04 to a subset of HH members.

* ── Table 5-B: Contract & hours R1 ──────────────────────────────────────────
svy: mean no_contract if round==1 & worked==1
* No written contract: ~7.8% of workers in R1

svy: mean hours if round==1
* Mean hours worked last week: 30.8 hrs (conditional on working)

svy: mean gig_work if round<=3
* Gig/platform work: 0.6% of all HH members

* ── Section 5 note for report ─────────────────────────────────────────────────
* The employment module was restructured between R3 and R4. Analysis of
* employment dynamics should use R1–R3 only until the R4–R5 data is reconfirmed.

* ── Income (Module 05) ────────────────────────────────────────────────────────
use "$HF/l2phl_M05_income.dta", clear

* ia2 = has regular income (1=yes, 2=no)
* ia7 = total income last 30 days (PHP; among earners)

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
*   v9_a  Economy will improve
*   v9_c  Job situation will improve
*   v9_e  Prices will rise (further)
*   v9_f  Difficult to save money
*   v9_g  Income will increase
*   v9_i  Things in general will get better
*   v9_j  Children will have better lives
*   v9_k  Optimistic about own health
*   v9_l  Community will improve
*   v9_m  Satisfied with government performance

gen satisfied    = (v1 <= 2) if v1 < .    // satisfied or very satisfied
gen dissatisfied = (v1 >= 4) if v1 < .    // dissatisfied or very dissatisfied

svyset psu [pweight=hhw], strata(stratum)

* ── Table 6-A: Mean life satisfaction by round ───────────────────────────────
svy: mean v1, over(round)
* R1=2.8  R2=2.8  R3=2.8  R4=2.8  R5=2.9  (stable; lower=more satisfied)

svy: mean satisfied dissatisfied if round==5
* Satisfied/very satisfied: 31.4%    Dissatisfied/very: 18.3%

* ── Table 6-B: Economic situation by round ───────────────────────────────────
svy: mean v5, over(round)
* R1=3.2  R2=3.2  R3=3.3  R4=3.3  R5=3.2  (3=about the same)

* ── Table 6-C: Perception scores R5 (mean; 1=agree strongly…5=disagree) ──────
svy: mean v9_a v9_c v9_e v9_f v9_g v9_i v9_j v9_k v9_l v9_m if round==5
* Prices will rise (v9_e):       3.7   (agree that prices will keep rising)
* Difficult to save (v9_f):      4.0   (strong agreement)
* Economy will improve (v9_a):   3.1   (uncertain)
* Satisfied w/ govt (v9_m):      2.9   (mildly satisfied)


* ═══════════════════════════════════════════════════════════════════════════════
* SECTION 7 — PANEL ATTRITION BIAS CHECK
* ═══════════════════════════════════════════════════════════════════════════════
use "$HF/l2phl_M00_passport.dta", clear
label values round round_lbl

* Compare HHs that stayed through R5 vs those that dropped out
gen stayed_r5 = .
by hhid (round): replace stayed_r5 = (round[_N]==5)

* Attrition rate from R1 to R5
count if round==1                   // base
count if round==1 & stayed_r5==0    // attrited

* Merge with M08 for food security attrition bias
preserve
  keep if round==1
  merge 1:1 hhid round using "$HF/l2phl_M08_fies.dta", keepusing(f08_a f08_b f08_c f08_d f08_e hhw)
  recode f08_a (1=1)(2=0), gen(f08_a_b)
  gen worried = f08_a_b
  * Compare worried rate: stayers vs leavers
  svyset psu [pweight=hhw], strata(stratum)
  svy: mean worried, over(stayed_r5)
  * If stayers and leavers differ significantly, attrition may introduce bias
restore


* ═══════════════════════════════════════════════════════════════════════════════
* END OF MASTER ANALYSIS DO-FILE
* ═══════════════════════════════════════════════════════════════════════════════
* For questions: apurevjav@worldbank.com
* Last updated: March 2026
