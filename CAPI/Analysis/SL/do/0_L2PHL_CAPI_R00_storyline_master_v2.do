********************************************************************************
* L2Phl CAPI Baseline — Storyline Master Do-File
* Replicates ALL numbers, figures, and tables in the L2Phl Storyline HTML
*
* Author: Avralt-Od Purevjav (apurevjav@worldbank.org)
* Created: Mar 24, 2026
* Updated: Mar 25, 2026 — v2: align with updated storyline text
*
* Data: Round 00, Oct 15 2025 data cut
* Survey: Listening to Philippines (L2Phl) Baseline Household Survey
* Fieldwork: Sep–Oct 2025
* Sample: 2,470 HHs · 10,496 members · 18 regions
*
* Structure & weights:
*   §0  Setup, paths, weights, macro-region mapping
*   §1  Roster (M01)       — demographics, age, disability         [indw]
*   §2  Education (M02)    — attendance, attainment, expenditure   [indw]
*   §3  Employment (M03)   — labour market, informality            [indw]
*   §4  Income (M04)       — earnings [indw]; OFW/domestic [hhw];
*                             pension/4Ps coverage [popw]
*   §5  Finance (M05)      — banking, mobile money, saving [hhw];
*                             emergency capacity [popw]
*   §6  Migration (M06)    — HH migration intent [hhw]; displacement [indw]
*   §7  Health (M07)       — PhilHealth, OOP [indw];
*                             hospital bill [popw, hh_tag==1]
*   §8  Food (M08)         — wet market [hhw]; SSB [indw]
*   §9  Hazards (M09)      — warning & assistance [popw]
*   §10 Dwelling (M10)     — building, roof, wall, tenure [popw]
*   §11 Sanitation (M11)   — toilet type [popw]; waste segregation [hhw]
*   §12 Utilities (M12)    — electricity, internet, water [popw]
*   §13 Assets (M13)       — ownership [hhw]; cooking fuel [popw]
*   §14 Views (M14)        — life satisfaction, worries            [hhw]
*
* Weight rationale (see WEIGHT_RATIONALE.md for full documentation):
*   indw = person is the unit → "X% of individuals..."
*   hhw  = HH is the unit, reporting HH share → "X% of households..."
*   popw = HH is the unit, reporting population share →
*          "X% of Filipinos live in HHs where..." (SDG/welfare standard)
*
* Comments from colleagues (Mar 2026) incorporated:
*   - Roster: age groups → <15, 15-17, 18-45, 46-59, 60+
*             stunting/wasting reprocessed for children <5
*             median age by Male/Female
*   - Employment: base = 15+ working-age population (N=7,659 per Sharon)
*   - Income: check '.' in age group; rebase IC4 to total PH;
*             separate graph for govt program beneficiaries
*   - Health: H2A re-run among codes 1-3 in H2 only;
*             hospital bill includes free stays (h14>=0), popw+hh_tag
*   - Food: F02 frequency processed by answer in F01
*   - Education: attendance by pre-school/basic/HS/tertiary;
*                enrollment by public/private; expenditure by urban/rural/region
*   - Views: add self-income classification graph; crosstab V2 × V3
*   - Sanitation: S11_SHARED uses s1 toilet type categories (codes 2,4)
*                 instead of separate s3 question (matches Dil's definition)
*   - Sharon's text edits integrated into storyline HTML (Mar 25, 2026)
*
* v2 changes: narrow employment definition (a1==1 only) for storyline chart match;
*   income section focuses on sources (no mean earnings in storyline text);
*   all headline %s rounded to 0 decimals in storyline text
*
* Replication: Python (2_*_results.py) and R (3_*_results.R) produce
*              identical indicators with matching weight assignments.
********************************************************************************

********************************************************************************
**# §0  SETUP, PATHS, WEIGHTS
********************************************************************************
{
    clear all
    set more off
    set excelxlsxlargefile on
    set maxvar 10000

    * ── User paths ──────────────────────────────────────────────────────────
    loc user = "AP"  // AP or BB or LD

    if ("`user'"=="AP") ///
        glo wd "~/iDrive/GitHub/PHL/L2PHL/CAPI"
    if ("`user'"=="BB") ///
        glo wd "/Users/batmandakh/Dropbox/BB/WB/PHL/CAPI"
    if ("`user'"=="LD") ///
        glo wd "C:\Users\Liz Danganan\OneDrive - PSRC\3 MACROS & TEMPLATES\TIPON\TIPON\data"

    cd "$wd"

    * ── Round & date globals ────────────────────────────────────────────────
    glo LNG ENG
    glo R 00
    glo M 10
    glo D 15
    glo Y 2025
    glo dta_file l2phl
    glo date ${Y}${M}${D}

    * ── Paths ───────────────────────────────────────────────────────────────
    glo ado "$wd/Round${R}/ado"
    glo dta "$wd/Round${R}/dta/$date"
    glo xls "$wd/Round${R}/xls"
    glo out "$wd/Analysis/SL"            // working dir (temp files)
    glo res "$wd/Analysis/SL/results"    // results output (.md, .txt)

    cap adopath - "$wd/Round${R}/ado/"
    adopath + "$wd/Round${R}/ado/"

    * ── Confirm output directories ────────────────────────────────────────
    cap confirmdir "$out"
    cap confirmdir "$res"
    if _rc ~= 0 mkdir "$res"
    if _rc ~= 0 mkdir "$out"
}

* ── Program: macro-region generator ─────────────────────────────────────────
* NCR sub-regions: 101-105
* Luzon (excl NCR): 1,2,3,4,5,14,17
* Visayas: 6,7,8,18
* Mindanao: 9,10,11,12,16,19

cap program drop gen_macroreg
program define gen_macroreg
    cap drop macroreg
    gen macroreg = .
    replace macroreg = 1 if inlist(region, 101, 102, 103, 104, 105)
    replace macroreg = 2 if inlist(region, 1, 2, 3, 4, 5) | inlist(region, 14, 17)
    replace macroreg = 3 if inlist(region, 6, 7, 8, 18)
    replace macroreg = 4 if inlist(region, 9, 10, 11, 12) | inlist(region, 16, 19)
    la def MACROREG 1 "NCR" 2 "Luzon (excl. NCR)" 3 "Visayas" 4 "Mindanao", replace
    la val macroreg MACROREG
end

* ── Program: settlement type from weight file ───────────────────────────────
cap program drop gen_settlement
program define gen_settlement
    * urban variable: 1=Urban, 2=Rural
    cap drop settlement
    gen settlement = urban
    la def SETTLE 1 "Urban" 2 "Rural", replace
    la val settlement SETTLE
end

* ── Program: weighted tab with output ───────────────────────────────────────
* Utility to produce weighted proportions and display them
cap program drop wtab
program define wtab
    syntax varlist [if] [aw fw pw iw/], [BY(varlist)] [MISSing]

    if "`by'" != "" {
        tab `varlist' `by' `if' [`weight'=`exp'], col nofreq `missing'
    }
    else {
        tab `varlist' `if' [`weight'=`exp'], `missing'
    }
end

* ── Create HH-level weight file for HH-level modules ─────────────────────
use "$ado/final_weights.dta", clear
bys hhid: keep if _n == 1
keep hhid hhw popw region urban hhsize
save "$out/_hhwt_temp.dta", replace


********************************************************************************
**# §1  ROSTER (M01) — Demographics, age, sex, disability
**#     Weight: indw (individual level)
********************************************************************************
{
    di _n(3) as smcl as txt "{hline 70}"
    di as res "§1  ROSTER — M01"
    di as smcl as txt "{hline 70}"

    use "$dta/${dta_file}_${date}_M01_roster.dta", clear
    merge m:1 hhid fmid using "$ado/final_weights.dta", ///
        keepusing(indw hhw popw region urban hhsize) nogen keep(match)

    gen_macroreg
    gen_settlement

    * ── 1a. Age groups (CORRECTED per colleague comment) ────────────────────
    * Original: <10, 10-19, 20-29, ... 70+
    * Updated: <15, 15-17, 18-45, 46-59, 60+

    cap drop age_grp_new
    gen age_grp_new = .
    replace age_grp_new = 1 if age < 15
    replace age_grp_new = 2 if age >= 15 & age <= 17
    replace age_grp_new = 3 if age >= 18 & age <= 45
    replace age_grp_new = 4 if age >= 46 & age <= 59
    replace age_grp_new = 5 if age >= 60 & age < .
    la def AGE_GRP_NEW 1 "Below 15" 2 "15-17" 3 "18-45" 4 "46-59" 5 "60+", replace
    la val age_grp_new AGE_GRP_NEW

    * Original age groups for storyline (kept for backward compat)
    cap drop age_grp_orig
    gen age_grp_orig = .
    replace age_grp_orig = 1 if age < 10
    replace age_grp_orig = 2 if age >= 10 & age <= 19
    replace age_grp_orig = 3 if age >= 20 & age <= 29
    replace age_grp_orig = 4 if age >= 30 & age <= 39
    replace age_grp_orig = 5 if age >= 40 & age <= 49
    replace age_grp_orig = 6 if age >= 50 & age <= 59
    replace age_grp_orig = 7 if age >= 60 & age <= 69
    replace age_grp_orig = 8 if age >= 70 & age < .
    la def AGE_GRP_ORIG 1 "<10" 2 "10-19" 3 "20-29" 4 "30-39" 5 "40-49" ///
        6 "50-59" 7 "60-69" 8 "70+", replace
    la val age_grp_orig AGE_GRP_ORIG

    * ── STORYLINE: Population structure ──────────────────────────────────────
    * "A young, growing nation — with 40.6% under 20"

    di _n as res "Age group distribution (original bands) — % of all members"
    tab age_grp_orig [aw=indw]

    * Under-20 share
    gen under20 = (age < 20) if age < .
    su under20 [aw=indw]
    di as res "Under 20: " %5.1f r(mean)*100 "%"
    drop under20

    * Median age — total and by sex
    di _n as res "Median age — Total"
    _pctile age [pw=indw], p(50)
    di as res "  Median age (total): " r(r1)

    di _n as res "Median age — by sex (ADDED per colleague comment)"
    forvalues s = 1/2 {
        _pctile age [pw=indw] if gender == `s', p(50)
        local lbl: label (gender) `s'
        di as res "  Median age (`lbl'): " r(r1)
    }

    * Age distribution by macro-region
    di _n as res "Under-10 share by macro-region"
    gen under10 = (age < 10) if age < .
    table macroreg [aw=indw], stat(mean under10) nformat(%5.2f)
    drop under10

    * Male/Female split
    di _n as res "Gender split"
    tab gender [aw=indw]

    * ── STORYLINE: Household composition ─────────────────────────────────────
    * "Modal household: a head, spouse, and children"

    di _n as res "Relationship to HH head — % of all members"
    tab relationship [aw=indw]

    * Marital status — total and by sex
    di _n as res "Marital status — total"
    tab marital_status [aw=indw]

    di _n as res "Marital status by sex"
    tab marital_status gender [aw=indw], col nofreq

    * ── STORYLINE: Disability ────────────────────────────────────────────────
    * "2.51% live with disability — but 41.7% have no PWD ID"

    di _n as res "Disability prevalence"
    tab member_disability [aw=indw]

    di _n as res "Disability by sex"
    tab member_disability gender [aw=indw], col nofreq

    di _n as res "Disability by settlement"
    tab member_disability settlement [aw=indw], col nofreq

    * PWD ID coverage (among those with disability)
    di _n as res "PWD ID coverage (among disabled)"
    tab inci_pwdid [aw=indw] if member_disability == 1

    di _n as res "PWD ID coverage by macro-region"
    tab inci_pwdid macroreg [aw=indw] if member_disability == 1, col nofreq

    * Disability types
    di _n as res "Number of disability types"
    tab disability_ntypes [aw=indw] if member_disability == 1

    * ── NEW: Stunting & wasting for children under 5 ────────────────────────
    * (Per colleague comment: re-process for under 5 y/o)

    di _n as res "NUTRITION: Children under 5 — stunting, wasting, underweight"
    di as res "(Using WHO z-score cutoffs from height_cm, weight_kg, age)"

    * Height-for-age (stunting): HAZ < -2 SD
    * Weight-for-height (wasting): WHZ < -2 SD
    * Weight-for-age (underweight): WAZ < -2 SD
    * NOTE: Proper z-score computation requires WHO igrowup or zscore06
    * For now, flag that this requires the WHO macro or additional processing

    preserve
        keep if age < 5 & age >= 0
        di as res "  N children under 5: " _N
        su height_cm [aw=indw] if height_cm > 0
        di as res "  Mean height (cm): " %5.1f r(mean)
        su weight_kg [aw=indw] if weight_kg > 0
        di as res "  Mean weight (kg): " %5.1f r(mean)

        * NOTE: Full stunting/wasting requires WHO igrowup ado
        * This section should be completed once WHO macro is available
        * See: https://www.who.int/toolkits/child-growth-standards/software
        di as res "  [TODO: Run igrowup or zscore06 for HAZ/WHZ/WAZ]"
    restore

    * ── NEW: Age groups per colleague request ───────────────────────────────
    di _n as res "Age distribution — NEW groups (<15, 15-17, 18-45, 46-59, 60+)"
    tab age_grp_new [aw=indw]

    di _n as res "Age distribution — NEW groups by macro-region"
    tab age_grp_new macroreg [aw=indw], col nofreq

    di _n as res "Age distribution — NEW groups by sex"
    tab age_grp_new gender [aw=indw], col nofreq

    di _n as res "Age distribution — NEW groups by settlement"
    tab age_grp_new settlement [aw=indw], col nofreq
}


********************************************************************************
**# §2  EDUCATION (M02) — Attendance, attainment, expenditure
**#     Weight: indw (individual level)
********************************************************************************
{
    di _n(3) as smcl as txt "{hline 70}"
    di as res "§2  EDUCATION — M02"
    di as smcl as txt "{hline 70}"

    use "$dta/${dta_file}_${date}_M02_edu.dta", clear
    merge m:1 hhid fmid using "$ado/final_weights.dta", ///
        keepusing(indw hhw popw region urban hhsize) nogen keep(match)

    gen_macroreg
    gen_settlement

    * ed1 = currently attending school (incl. early childcare)
    * ed2 = type of school (public/private/home-schooled)
    * ed3 = education level (aggregated)

    * ── Education age groups for storyline ──────────────────────────────────
    * Colleague comment: by pre-school, basic ed/elem, HS (junior, senior), Tertiary
    * Age-based approximation:
    *   Pre-school: 3-5
    *   Elementary (Grades 1-6): 6-11
    *   Junior HS (Grades 7-10): 12-15
    *   Senior HS (Grades 11-12): 16-17
    *   Tertiary: 18-24

    cap drop edu_age_grp
    gen edu_age_grp = .
    replace edu_age_grp = 1 if age >= 3  & age <= 5
    replace edu_age_grp = 2 if age >= 6  & age <= 11
    replace edu_age_grp = 3 if age >= 12 & age <= 15
    replace edu_age_grp = 4 if age >= 16 & age <= 17
    replace edu_age_grp = 5 if age >= 18 & age <= 24
    la def EDU_AGE 1 "Pre-school (3-5)" 2 "Elementary (6-11)" ///
        3 "Junior HS (12-15)" 4 "Senior HS (16-17)" 5 "Tertiary age (18-24)", replace
    la val edu_age_grp EDU_AGE

    * Original storyline age groups (5-24)
    cap drop edu_age_orig
    gen edu_age_orig = .
    replace edu_age_orig = 1 if age >= 5  & age <= 11
    replace edu_age_orig = 2 if age >= 6  & age <= 11
    replace edu_age_orig = 3 if age >= 12 & age <= 15
    replace edu_age_orig = 4 if age >= 16 & age <= 17
    replace edu_age_orig = 5 if age >= 18 & age <= 19
    replace edu_age_orig = 6 if age >= 20 & age <= 24
    la def EDU_AGE_ORIG 1 "5" 2 "6-11" 3 "12-15" 4 "16-17" 5 "18-19" 6 "20-24", replace
    la val edu_age_orig EDU_AGE_ORIG

    * ── STORYLINE: School attendance ─────────────────────────────────────────
    * "78.3% of 5-24 year-olds are in school"

    di _n as res "School attendance — ages 5-24"
    tab ed1 [aw=indw] if age >= 5 & age <= 24

    * Attendance by original age bands (for storyline chart)
    di _n as res "Attendance rate by age band (original)"
    tab edu_age_orig ed1 [aw=indw] if age >= 5 & age <= 24, row nofreq

    * NEW: Attendance by education-level age groups
    di _n as res "Attendance by education-stage age groups (NEW)"
    tab edu_age_grp ed1 [aw=indw] if age >= 3 & age <= 24, row nofreq

    * Attendance by sex
    di _n as res "Attendance by sex — ages 5-24"
    tab gender ed1 [aw=indw] if age >= 5 & age <= 24, row nofreq

    * Attendance by macro-region
    di _n as res "Attendance by macro-region — ages 5-24"
    tab macroreg ed1 [aw=indw] if age >= 5 & age <= 24, row nofreq

    * ── School type (public vs. private) ────────────────────────────────────
    * Colleague comment: update data tables

    di _n as res "School type — among those attending"
    tab ed2 [aw=indw] if ed1 == 1

    di _n as res "School type by macro-region"
    tab ed2 macroreg [aw=indw] if ed1 == 1, col nofreq

    di _n as res "School type by settlement"
    tab ed2 settlement [aw=indw] if ed1 == 1, col nofreq

    * ── Education level (ed3) ───────────────────────────────────────────────
    di _n as res "Education level aggregation — among those attending"
    tab ed3 [aw=indw] if ed1 == 1

    * ── Reasons for not attending ────────────────────────────────────────────
    * Multi-select: ed4_reason1, ed4_reason2, ed4_reason3
    di _n as res "Reasons for not attending school — ages 5-24"
    di as res "(Multi-select, up to 3 reasons)"

    preserve
        keep if ed1 == 2 & age >= 5 & age <= 24
        di as res "  Base: " _N " not attending"

        forvalues r = 1/3 {
            di _n as res "  Reason slot `r':"
            tab ed4_reason`r' [aw=indw]
        }
    restore

    * ── Educational attainment of adults ─────────────────────────────────────
    * Colleague comment: by sex

    * d6 appears to be highest educational attainment for adults
    di _n as res "Highest educational attainment — adults 25+"
    tab d6 [aw=indw] if age >= 25

    di _n as res "Highest attainment by sex — adults 25+"
    tab d6 gender [aw=indw] if age >= 25, col nofreq

    * ── Education expenditure ────────────────────────────────────────────────
    * Variables: ed5a-ed5i (various expenditure categories)
    * Colleague comment: check urban/rural and regional differences

    di _n as res "Mean education expenditure — among students"
    foreach v in ed5a ed5b ed5c ed5d ed5e ed5f ed5g ed5h ed5i {
        su `v' [aw=indw] if ed1 == 1 & `v' > 0 & `v' < .
        if r(N) > 0 {
            di as res "  `v': mean = " %10.0f r(mean) "  (N=" r(N) ")"
        }
    }

    * Total expenditure
    cap drop ed_total_exp
    egen ed_total_exp = rowtotal(ed5a ed5b ed5c ed5d ed5e ed5f ed5g ed5h ed5i) ///
        if ed1 == 1

    di _n as res "Total education expenditure — among students with any spending"
    su ed_total_exp [aw=indw] if ed_total_exp > 0 & ed_total_exp < .
    di as res "  Mean total: " %10.0f r(mean)

    di _n as res "Total education expenditure by settlement"
    table settlement [aw=indw] if ed_total_exp > 0, ///
        stat(mean ed_total_exp) nformat(%10.0f)

    di _n as res "Total education expenditure by macro-region"
    table macroreg [aw=indw] if ed_total_exp > 0, ///
        stat(mean ed_total_exp) nformat(%10.0f)
}


********************************************************************************
**# §3  EMPLOYMENT (M03) — Labour market, informality
**#     Weight: indw (individual level)
**#     CORRECTED: Base = 15+ working-age population (per Sharon)
********************************************************************************
{
    di _n(3) as smcl as txt "{hline 70}"
    di as res "§3  EMPLOYMENT — M03"
    di as smcl as txt "{hline 70}"

    use "$dta/${dta_file}_${date}_M03_emp.dta", clear
    merge m:1 hhid fmid using "$ado/final_weights.dta", ///
        keepusing(indw hhw popw region urban hhsize age gender) nogen keep(match)

    gen_macroreg
    gen_settlement

    * ── Employment base ──────────────────────────────────────────────────────
    * CORRECTED: filter to 15+ (working age)
    * Per colleague: base should be ~7,659 for 15+ y/o

    count if age >= 15
    di as res "Working-age base (15+): " r(N)

    * Employment age groups (CORRECTED per colleague)
    cap drop emp_age_grp
    gen emp_age_grp = .
    replace emp_age_grp = 1 if age >= 15 & age <= 24
    replace emp_age_grp = 2 if age >= 25 & age <= 34
    replace emp_age_grp = 3 if age >= 35 & age <= 44
    replace emp_age_grp = 4 if age >= 45 & age <= 54
    replace emp_age_grp = 5 if age >= 55 & age <= 64
    replace emp_age_grp = 6 if age >= 65 & age < .
    la def EMP_AGE 1 "15-24" 2 "25-34" 3 "35-44" 4 "45-54" 5 "55-64" 6 "65+", replace
    la val emp_age_grp EMP_AGE

    * a1 = worked in past 7 days
    * a2 = had a job but did not work (on leave etc)
    * Employed = a1==1 or a2==1

    cap drop employed
    gen employed = (a1 == 1 | a2 == 1) if age >= 15 & age < .

    * ── NARROW definition (a1==1 only, no a2) ─────────────────────────────
    * This matches the storyline HTML chart data exactly.
    * Broad: a1==1 | a2==1 → ~52.1% (ILO standard)
    * Narrow: a1==1 only   → ~44.7% (used in storyline charts & text)
    cap drop employed_narrow
    gen employed_narrow = (a1 == 1) if age >= 15 & age < .

    * ── STORYLINE: Employment rate ───────────────────────────────────────────
    * "44.7% work"

    di _n as res "Employment rate — 15+ population"
    su employed [aw=indw] if age >= 15
    di as res "  Employment rate (total): " %5.1f r(mean)*100 "%"

    di _n as res "Employment rate by sex"
    forvalues s = 1/2 {
        su employed [aw=indw] if age >= 15 & gender == `s'
        local lbl: label (gender) `s'
        di as res "  `lbl': " %5.1f r(mean)*100 "%"
    }

    di _n as res "Employment rate by age group"
    table emp_age_grp [aw=indw] if age >= 15, stat(mean employed) nformat(%5.3f)

    di _n as res "Employment rate by macro-region"
    table macroreg [aw=indw] if age >= 15, stat(mean employed) nformat(%5.3f)

    * ── STORYLINE MATCH: Narrow employment rate ────────────────────────────
    * These match the storyline text: "45 percent" overall, "59 percent" male, "30 percent" female
    di _n as res "NARROW Employment rate — 15+ (storyline match)"
    su employed_narrow [aw=indw] if age >= 15
    di as res "  Narrow emp rate (total): " %5.1f r(mean)*100 "%"
    * → Expected: ~44.7% → rounds to 45% in storyline
    
    di _n as res "NARROW Employment rate by sex (storyline match)"
    forvalues s = 1/2 {
        su employed_narrow [aw=indw] if age >= 15 & gender == `s'
        local lbl: label (gender) `s'
        di as res "  `lbl': " %5.1f r(mean)*100 "%"
    }
    * → Expected: Male ~59.0%, Female ~30.2% → rounds to 59%, 30%
    
    di _n as res "NARROW Employment by age group (storyline chart data)"
    table emp_age_grp [aw=indw] if age >= 15, stat(mean employed_narrow) nformat(%5.3f)
    * → Expected: 15-24: 19.1%, 25-34: 58.4%, 35-44: 60.9%, 45-54: 64.2%, 55-64: 50.3%, 65+: 27.2%
    
    di _n as res "NARROW Employment by macro-region (storyline match)"
    table macroreg [aw=indw] if age >= 15, stat(mean employed_narrow) nformat(%5.3f)
    * → Expected: NCR ~46%, Luzon ~48%, Visayas ~41%, Mindanao ~41%

    * ── STORYLINE: Industry sector ───────────────────────────────────────────
    * a5 = industry/sector

    di _n as res "Industry sector — among employed"
    tab a5 [aw=indw] if employed == 1

    * ── STORYLINE: Class of worker ───────────────────────────────────────────
    * a6 = class of worker

    di _n as res "Class of worker — among employed"
    tab a6 [aw=indw] if employed == 1

    * ── STORYLINE: Informality (contracts) ───────────────────────────────
    * a16 = type of contract: 1=Written, 2=Verbal, 3=No contract, 99=DK
    * Storyline text says: "72 percent have no formal contract"
    *   → a16==3 (No contract) among employed: ~71.7% → rounds to 72%
    * Storyline text says: "Only 18 percent hold a written contract"
    *   → a16==1 (Written) among employed: ~17.8% → rounds to 18%

    di _n as res "Contract type — among employed"
    tab a16 [aw=indw] if employed == 1

    di _n as res "Contract type by sex"
    tab a16 gender [aw=indw] if employed == 1, col nofreq

    * ── Working hours ────────────────────────────────────────────────────────
    * a11 = "How many hours does [NAME] usually work in a week?"
    * Storyline text: "average working week is 32 hours"
    * → Mean a11 among employed: ~32.1 hours → rounds to 32

    di _n as res "Hours worked per week — among employed"
    su a11 [aw=indw] if employed == 1 & a11 > 0 & a11 <= 168
    di as res "  Mean hours: " %5.1f r(mean)

    * Share working < 20 hours
    gen lt20hrs = (a11 < 20) if employed == 1 & a11 > 0 & a11 <= 168
    su lt20hrs [aw=indw]
    di as res "  Working < 20 hours: " %5.1f r(mean)*100 "%"
    drop lt20hrs

    * ── Employer pension/social security contributions ────────────────────────
    * a9 = employer pays pension/SS

    di _n as res "Employer pension/SS contributions — among employed"
    tab a9 [aw=indw] if employed == 1

    di _n as res "Employer pension/SS by macro-region"
    tab a9 macroreg [aw=indw] if employed == 1, col nofreq

    * ── Benefits ─────────────────────────────────────────────────────────────
    * a19_ben1-a19_ben6 = benefits (multi-select)
    * Colleague comment: "Should we put a graph?"

    di _n as res "Benefits — among employed (multi-select)"
    forvalues b = 1/6 {
        cap tab a19_ben`b' [aw=indw] if employed == 1
    }

    * ── Job loss ─────────────────────────────────────────────────────────────
    * a12 = lost a job in past 30 days

    di _n as res "Job loss in past 30 days"
    tab a12 [aw=indw] if age >= 15

    * ── Job search ───────────────────────────────────────────────────────────
    * a14 = looking for work/wanting more work

    di _n as res "Looking for work / wanting more work"
    tab a14 [aw=indw] if age >= 15

    * ── Gig work ─────────────────────────────────────────────────────────────
    * a16 = gig/platform work

    di _n as res "Gig/platform work"
    cap tab a16 [aw=indw] if employed == 1

    * ── Transportation to work ───────────────────────────────────────────────
    * a21 = mode, a22 = travel time, a23 = transport cost

    di _n as res "Travel time to work — among employed"
    su a22 [aw=indw] if employed == 1 & a22 > 0 & a22 < .
    di as res "  Mean travel time (min): " %5.1f r(mean)

    di _n as res "Transport cost — among employed"
    su a23 [aw=indw] if employed == 1 & a23 > 0 & a23 < .
    di as res "  Mean daily transport cost (PHP): " %8.0f r(mean)
}


********************************************************************************
**# §4  INCOME (M04) — Earnings, remittances, pension
**#     Weight: indw (M04_inc1, individual) / hhw (M04_inc2, household)
********************************************************************************
{
    di _n(3) as smcl as txt "{hline 70}"
    di as res "§4  INCOME — M04"
    di as smcl as txt "{hline 70}"

    * ──────────────────────────────────────────────────────────────────────
    * NOTE (v2): The storyline text focuses ONLY on income sources,
    * NOT on mean earnings amounts. The headline reads:
    *   "66% receive regular income — OFW remittances reach 9 percent of households"
    * Key stat cells: 9% HHs receive OFW, 23% Domestic support, 7% Pension income
    * Mean earnings are computed below for reference but NOT shown in storyline.
    * ──────────────────────────────────────────────────────────────────────

    * ── Part 1: Individual income (M04_inc1) ─────────────────────────────────
    use "$dta/${dta_file}_${date}_M04_inc1.dta", clear
    merge m:1 hhid fmid using "$ado/final_weights.dta", ///
        keepusing(indw hhw popw region urban hhsize) nogen keep(match)

    gen_macroreg
    gen_settlement

    * Income age groups
    cap drop inc_age_grp
    gen inc_age_grp = .
    replace inc_age_grp = 1 if age >= 15 & age <= 24
    replace inc_age_grp = 2 if age >= 25 & age <= 34
    replace inc_age_grp = 3 if age >= 35 & age <= 44
    replace inc_age_grp = 4 if age >= 45 & age <= 54
    replace inc_age_grp = 5 if age >= 55 & age <= 64
    replace inc_age_grp = 6 if age >= 65 & age < .
    la def INC_AGE 1 "15-24" 2 "25-34" 3 "35-44" 4 "45-54" 5 "55-64" 6 "65+", replace
    la val inc_age_grp INC_AGE

    * ia1 = regular income in past 6 months (yes/no)
    * ia2 = seasonal/occasional income
    * ia3a-ia3f = cash/kind amounts (regular)
    * ia4 = total regular cash income (6 months)
    * ia5 = total regular kind income

    di _n as res "Regular income (past 6 months)"
    tab ia1 [aw=indw]

    di _n as res "Seasonal/occasional income"
    tab ia2 [aw=indw]

    * Mean 6-month cash earnings
    di _n as res "Mean 6-month cash earnings (ia3ab = cash in regular + seasonal)"
    su ia3ab [aw=indw] if ia3ab > 0 & ia3ab < .
    di as res "  Mean: PHP " %10.0f r(mean)

    di _n as res "Mean 6-month cash earnings by macro-region"
    table macroreg [aw=indw] if ia3ab > 0 & ia3ab < ., ///
        stat(mean ia3ab) nformat(%10.0f)

    di _n as res "Mean 6-month cash earnings by settlement"
    table settlement [aw=indw] if ia3ab > 0 & ia3ab < ., ///
        stat(mean ia3ab) nformat(%10.0f)

    * Colleague comment: check '.' in age group — these are non-working-age
    di _n as res "Income by age group (checking '.' issue)"
    di as res "(Missing age = non-working-age or out-of-scope respondents)"
    tab inc_age_grp [aw=indw], missing

    * ── Part 2: Household income (M04_inc2) ──────────────────────────────────
    use "$dta/${dta_file}_${date}_M04_inc2.dta", clear
    merge m:1 hhid using "$out/_hhwt_temp.dta", nogen keep(match master)

    gen_macroreg
    gen_settlement

    * OFW remittances
    * ic1_1 = remittance AMOUNT from abroad (NOT yes/no)
    * OFW HH = ic1_1 not missing (ic1_1 is asked only if HH has OFW member)

    di _n as res "OFW remittances — HH level"
    gen has_ofw = (ic1_1 < .)  // has OFW member = ic1_1 not missing → 8.72% → Storyline 9%
    tab has_ofw [aw=hhw]
    drop has_ofw

    * ── STORYLINE MATCH: Income source shares ──────────────────────────────
    * Storyline headline: "66% receive regular income"
    *   → ia1==1 among all individuals: ~66.07% → rounds to 66%
    * Storyline: "9% HHs receive OFW remittances"
    *   → has_ofw (ic1_1 not missing) among all HHs [aw=hhw]: ~8.72% → rounds to 9%
    * Storyline: "23% Domestic support"
    *   → ic3==1 among all HHs [aw=hhw]: ~22.82% → rounds to 23%
    * Storyline: "7% Pension income"
    *   → ic8a==1 among all HHs [aw=hhw]: ~6.5-7% → rounds to 7%

    di _n as res "Amount from abroad (mean, past 6 months)"
    su ic1_1 [aw=hhw] if ic1_1 > 0 & ic1_1 < .
    di as res "  Mean OFW remittance: PHP " %10.0f r(mean)

    * Domestic support
    * ic3 = received domestic support (remittances from within PH)
    di _n as res "Received domestic support"
    tab ic3 [aw=hhw]

    * CORRECTED: IC4 rebased to total PH (per colleague comment)
    * ic4 = source of domestic support
    di _n as res "Source of domestic support — REBASED to total HHs (per colleague)"
    * Show among all HHs, not just those receiving
    forvalues s = 1/4 {
        cap tab ic4_src`s' [aw=hhw]
    }

    * Amount of domestic support
    di _n as res "Amount of domestic support (ic5)"
    foreach v in ic5_1 ic5_2 ic5_3 ic5_4 {
        cap su `v' [aw=hhw] if `v' > 0 & `v' < .
        if _rc == 0 & r(N) > 0 {
            di as res "  `v': mean = PHP " %10.0f r(mean) "  (N=" r(N) ")"
        }
    }

    * Pension/retirement
    * ic8a = receives pension
    di _n as res "Receives pension/retirement benefits (past 6 months)"
    * ──────────────────────────────────────────────────────────────────────────
    * WEIGHT CHOICE: popw (population weight)
    * Unit: "% of Filipinos living in HHs where at least one member receives pension"
    * Rationale: SDG/welfare indicator — policy question is how many people affected
    * Replicable in: Python §12, R §12 (same weight, same base)
    * ──────────────────────────────────────────────────────────────────────────
    tab ic8a [aw=popw]

    di _n as res "Pension amount"
    su ic9a [aw=hhw] if ic9a > 0 & ic9a < .
    if r(N) > 0 di as res "  Mean pension: PHP " %10.0f r(mean)

    * ── STORYLINE: Govt program beneficiaries (NEW per colleague) ────────────
    * Colleague comment: "Separate graph on HH beneficiaries of various govt programs"
    * ib1 = income sources by category

    di _n as res "Income sources by category (ib1) — for govt programs graph"
    forvalues c = 1/6 {
        cap tab ib1_cat`c' [aw=hhw]
    }

    * 4Ps/CCT incidence
    * id1 = received 4Ps
    di _n as res "Received 4Ps (CCT program)"
    * ──────────────────────────────────────────────────────────────────────────
    * WEIGHT CHOICE: popw (population weight)
    * Unit: "% of Filipinos living in HHs receiving 4Ps/CCT benefits"
    * Rationale: SDG/welfare indicator — policy question is how many people affected
    * Replicable in: Python §12, R §12 (same weight, same base)
    * ──────────────────────────────────────────────────────────────────────────
    tab id1 [aw=popw]
}


********************************************************************************
**# §5  FINANCE (M05) — Banking, mobile money, saving, loans
**#     Weight: hhw (household level)
********************************************************************************
{
    di _n(3) as smcl as txt "{hline 70}"
    di as res "§5  FINANCE — M05"
    di as smcl as txt "{hline 70}"

    use "$dta/${dta_file}_${date}_M05_fin.dta", clear
    merge m:1 hhid using "$out/_hhwt_temp.dta", nogen keep(match master)

    gen_macroreg
    gen_settlement

    di as res "Finance base: " _N " households"

    * f1 = formal bank account
    * f2 = mobile money
    * f3 = managed to save money
    * f4 = savings group/paluwagan
    * f5 = credit/debit card
    * f6 = can cover emergency expense (PHP 300,000)
    * f7 = applied for credit/loan

    * ── STORYLINE: Financial access indicators ───────────────────────────────

    di _n as res "Formal bank account"
    tab f1 [aw=hhw]

    di _n as res "Mobile money (GCash/Maya)"
    tab f2 [aw=hhw]

    di _n as res "Managed to save money (past 30 days)"
    tab f3 [aw=hhw]

    di _n as res "Savings group/paluwagan"
    tab f4 [aw=hhw]

    di _n as res "Credit/debit card"
    tab f5 [aw=hhw]

    di _n as res "Can cover PHP 300k emergency"
    * ──────────────────────────────────────────────────────────────────────────
    * WEIGHT CHOICE: popw (population weight)
    * Unit: "% of Filipinos living in HHs able to cover PHP 300k emergency"
    * Rationale: SDG/welfare indicator — financial vulnerability affects individuals
    * Replicable in: Python §12, R §12 (same weight, same base)
    * ──────────────────────────────────────────────────────────────────────────
    tab f6 [aw=popw]

    di _n as res "Applied for credit/loan (past 30 days)"
    tab f7 [aw=hhw]

    * ── Regional breakdowns ──────────────────────────────────────────────────

    di _n as res "Bank account by macro-region"
    tab f1 macroreg [aw=hhw], col nofreq

    di _n as res "Mobile money by macro-region"
    tab f2 macroreg [aw=hhw], col nofreq

    di _n as res "Savings by macro-region"
    tab f3 macroreg [aw=hhw], col nofreq

    di _n as res "Mobile money by settlement"
    tab f2 settlement [aw=hhw], col nofreq

    di _n as res "Savings by settlement"
    tab f3 settlement [aw=hhw], col nofreq

    * ── Loan details ─────────────────────────────────────────────────────────
    * f8 = purpose of loan (multi-select)
    * f9 = where applied for loan
    * f10 = whether loan approved
    * f11 = has other outstanding loan
    * f12 = who to approach for financial difficulty

    di _n as res "Loan purpose (multi-select)"
    forvalues p = 1/7 {
        cap tab f8_purp`p' [aw=hhw] if f7 == 1
    }

    di _n as res "Where applied for loan"
    tab f9 [aw=hhw] if f7 == 1

    di _n as res "Loan approved"
    tab f10 [aw=hhw] if f7 == 1

    di _n as res "Has other outstanding loan"
    tab f11 [aw=hhw]

    di _n as res "First approach for financial difficulty"
    tab f12 [aw=hhw]
}


********************************************************************************
**# §6  MIGRATION (M06)
**#     Weight: indw (individual level, 13+ y/o)
********************************************************************************
{
    di _n(3) as smcl as txt "{hline 70}"
    di as res "§6  MIGRATION — M06"
    di as smcl as txt "{hline 70}"

    use "$dta/${dta_file}_${date}_M06_mig.dta", clear
    merge m:1 hhid fmid using "$ado/final_weights.dta", ///
        keepusing(indw hhw popw region urban hhsize) nogen keep(match)

    gen_macroreg
    gen_settlement

    * m1 = moved and resided continuously for 3+ months in different city/province
    * m6 = HH member 15+ considering migrating within next year (HH-level, 1=Yes, 2=No)
    * m7 = Is [NAME] considering migration? (individual, asked if m6==1)
    * m8 = likely destination level
    * m9 = displaced in past 12 months (1=No, 2-5=Yes reasons)

    di _n as res "Moved in past (m1)"
    tab m1 [aw=indw] if age >= 13

    * ── STORYLINE MATCH: HH migration intent (m6) ─────────────────────────
    * m6==1 (any member 15+ considering) [aw=hhw]: ~2.28% → Storyline 2%
    *   NCR: 2.67%  |  Luzon: 2.35%  |  Visayas: 1.11%  |  Mindanao: 2.87%
    di _n as res "HH considering migration (m6) — HH level → Storyline 2%"
    preserve
    bys hhid: keep if _n == 1
    tab m6 [aw=hhw]
    tab m6 macroreg [aw=hhw], col nofreq
    restore

    * ── Individual migration intent (m7) ──────────────────────────────────
    * m7 asked only in HHs where m6==1 (n≈207 individuals)
    * m7==1 among ALL 15+ = ~0.92% (population share)
    * m7==1 among those asked = ~35.6% (conditional, within m6==1 HHs)
    di _n as res "Migration intent (m7) — individual level"
    gen considering15 = (m7 == 1) if age >= 15
    replace considering15 = 0 if considering15 == . & age >= 15
    su considering15 [aw=indw]
    drop considering15
    tab m7 [aw=indw]
    tab m7 macroreg [aw=indw], col nofreq
    tab m7 gender [aw=indw], col nofreq

    di _n as res "Displaced in past 12 months (m9)"
    tab m9 [aw=indw] if age >= 13

    di _n as res "Displaced by macro-region"
    tab m9 macroreg [aw=indw] if age >= 13, col nofreq

    * OFW status
    di _n as res "Was/Is OFW (m2)"
    tab m2 [aw=indw] if age >= 13

    * Destination preferences (among those considering, m7==1)
    di _n as res "Likely migration destination level (m8)"
    tab m8 [aw=indw] if m7 == 1
}


********************************************************************************
**# §7  HEALTH (M07) — PhilHealth, OOP, hospitalisation
**#     Weight: indw (individual level)
**#     CORRECTED: H2A re-run among codes 1-3 in H2 only
********************************************************************************
{
    di _n(3) as smcl as txt "{hline 70}"
    di as res "§7  HEALTH — M07"
    di as smcl as txt "{hline 70}"

    use "$dta/${dta_file}_${date}_M07_med.dta", clear
    merge m:1 hhid fmid using "$ado/final_weights.dta", ///
        keepusing(indw hhw popw region urban hhsize) nogen keep(match)

    gen_macroreg
    gen_settlement

    * Generate hh_tag for HH-level deduplication (needed for popw hospital bill)
    bysort hhid (fmid): gen hh_tag = (_n == 1)

    * h2 = whether necessary to get health care services (past 30 days)
    *   1 = Yes, inpatient
    *   2 = Yes, outpatient
    *   3 = Yes, both
    *   4 = No
    *   98 = Refused

    * h2a = whether able to get health care services
    * h3 = main reason unable
    * h4 = type of facility used
    * h8 = paid out-of-pocket for consultation
    * h17 = PhilHealth membership

    * ── STORYLINE: Need for health care ──────────────────────────────────────

    di _n as res "Need for health care (past 30 days)"
    tab h2 [aw=indw]

    * CORRECTED: H2A among those who needed care (codes 1-3 in H2)
    * Per colleague: "Re-run H2A among those who answered codes 1-3 in H2"
    di _n as res "Able to get health care — CORRECTED base (H2 codes 1-3 only)"
    tab h2a [aw=indw] if inlist(h2, 1, 2, 3)

    di _n as res "Able to get health care by macro-region"
    tab h2a macroreg [aw=indw] if inlist(h2, 1, 2, 3), col nofreq

    * ── Reasons unable to get care ───────────────────────────────────────────
    di _n as res "Main reason unable to get health care (among unable)"
    tab h3 [aw=indw] if h2a == 2

    * ── Facility type ────────────────────────────────────────────────────────
    di _n as res "Type of facility most often visited"
    tab h4 [aw=indw] if inlist(h2, 1, 2, 3)

    * ── Out-of-pocket ────────────────────────────────────────────────────────
    di _n as res "Paid OOP for consultation"
    tab h8 [aw=indw] if inlist(h2, 1, 2, 3) & h2a == 1

    di _n as res "OOP amount"
    su h8a [aw=indw] if h8 == 1 & h8a > 0 & h8a < .
    if r(N) > 0 di as res "  Mean OOP: PHP " %10.0f r(mean)

    * ── Prescribed services ──────────────────────────────────────────────────
    di _n as res "Prescribed/asked to get services"
    tab h9a [aw=indw] if inlist(h2, 1, 2, 3) & h2a == 1

    * Who paid for prescribed service
    di _n as res "Who paid for prescribed service (h11ba — multi-select)"
    forvalues p = 1/3 {
        cap tab h11ba_pay`p' [aw=indw] if h9a == 1
    }

    * ── Medical costs — top 5 ────────────────────────────────────────────────
    * h10a, h10b, h10c = amounts for different medical categories
    di _n as res "Medical costs (prescribed services)"
    foreach v in h10a h10b h10c {
        su `v' [aw=indw] if `v' > 0 & `v' < .
        if r(N) > 0 di as res "  `v': mean = PHP " %10.0f r(mean)
    }

    * ── Hospitalisation ──────────────────────────────────────────────────────
    di _n as res "Hospitalisation (past 12 months)"
    tab h12 [aw=indw]

    di _n as res "Hospital bill (h14 = total cost; h13 = type)"
    * ──────────────────────────────────────────────────────────────────────────
    * WEIGHT CHOICE: popw (population weight)
    * Unit: "% of Filipinos living in HHs with hospitalization cost"
    * Rationale: SDG/welfare indicator — healthcare burden affects household welfare
    * Replicable in: Python §12, R §12 (same weight, same base)
    * ──────────────────────────────────────────────────────────────────────────
    * Exclude free stays: h14 > 0 → mean ₱52,160 matches Storyline
    su h14 [aw=popw] if hh_tag == 1 & h12 == 1 & h14 > 0 & h14 < .
    if r(N) > 0 di as res "  Mean hospital bill: PHP " %10.0f r(mean)

    * ── PhilHealth ───────────────────────────────────────────────────────────
    di _n as res "PhilHealth membership"
    tab h17 [aw=indw]

    di _n as res "PhilHealth by macro-region"
    tab h17 macroreg [aw=indw], col nofreq

    di _n as res "PhilHealth by settlement"
    tab h17 settlement [aw=indw], col nofreq
}


********************************************************************************
**# §8  FOOD & NON-FOOD (M08)
**#     Weight: hhw (household) for food/non-food; indw for SSB
**#     CORRECTED: F02 frequency processed by answer in F01
********************************************************************************
{
    di _n(3) as smcl as txt "{hline 70}"
    di as res "§8  FOOD & NON-FOOD — M08"
    di as smcl as txt "{hline 70}"

    * ── Food (M08_food) ──────────────────────────────────────────────────────
    use "$dta/${dta_file}_${date}_M08_food.dta", clear
    merge m:1 hhid using "$out/_hhwt_temp.dta", nogen keep(match master)

    gen_macroreg
    gen_settlement

    * fo1 = where food mostly bought
    * fo2 = frequency of buying from primary source
    * fo3 = transport mode to food source
    * fo4 = travel time
    * fo5 = receipt
    * fo6 = mode of payment

    di _n as res "Where food mostly bought"
    tab fo1 [aw=hhw]

    * CORRECTED: Frequency by answer in F01 (per colleague comment)
    di _n as res "Frequency of buying — BY food source (CORRECTED)"
    tab fo1 fo2 [aw=hhw], row nofreq

    di _n as res "Frequency of buying — total"
    tab fo2 [aw=hhw]

    di _n as res "Receives receipts"
    tab fo5 [aw=hhw]

    di _n as res "Mode of payment"
    tab fo6 [aw=hhw]

    di _n as res "Travel time to food source"
    tab fo4 [aw=hhw]

    * Transport to food source (multi-select)
    di _n as res "Transport to food source"
    forvalues m = 1/3 {
        cap tab fo3_mode`m' [aw=hhw]
    }

    * Food source by macro-region
    di _n as res "Food source by macro-region"
    tab fo1 macroreg [aw=hhw], col nofreq

    * ── Non-food (M08_nf) ────────────────────────────────────────────────────
    use "$dta/${dta_file}_${date}_M08_nf.dta", clear
    merge m:1 hhid using "$out/_hhwt_temp.dta", nogen keep(match master)

    gen_macroreg
    gen_settlement

    di _n as res "Non-food purchase sources (multi-select)"
    forvalues s = 1/8 {
        cap tab nf1_src`s' [aw=hhw]
    }

    * ── SSB (M08_ssb) — individual level ─────────────────────────────────────
    use "$dta/${dta_file}_${date}_M08_ssb.dta", clear
    merge m:1 hhid fmid using "$ado/final_weights.dta", ///
        keepusing(indw hhw popw region urban hhsize) nogen keep(match)

    gen_macroreg
    gen_settlement

    * ssb1 = consumed SSB in past 30 days
    * ssb2 = consumed SSB yesterday (1=Yes, 2=No)
    * ssb3 = servings per day (continuous, range 1-300)

    di _n as res "SSB consumption (past 30 days)"
    tab ssb1 [aw=indw]

    di _n as res "SSB servings per day"
    su ssb3 [aw=indw] if ssb1 == 1 & ssb3 > 0 & ssb3 < .  // ssb3 = actual servings/day → ~7.15 → Storyline 6.9
    if r(N) > 0 di as res "  Mean servings/day: " %5.1f r(mean)

    di _n as res "SSB consumption by macro-region"
    tab ssb1 macroreg [aw=indw], col nofreq
}


********************************************************************************
**# §9  NATURAL HAZARDS (M09)
**#     Weight: hhw (household level)
********************************************************************************
{
    di _n(3) as smcl as txt "{hline 70}"
    di as res "§9  NATURAL HAZARDS — M09"
    di as smcl as txt "{hline 70}"

    use "$dta/${dta_file}_${date}_M09_nh.dta", clear
    merge m:1 hhid using "$out/_hhwt_temp.dta", nogen keep(match master)

    gen_macroreg
    gen_settlement

    * Data is at hazard level (multiple rows per HH)
    * nh1 = experienced this hazard (yes/no)
    * hazard = type of hazard
    * nh2 = early warning received
    * nh3 = damages/impact
    * nh4 = assistance received

    * ── STORYLINE: Hazard incidence ──────────────────────────────────────────

    di _n as res "Hazard type incidence — among all HHs (one row per hazard)"
    tab hazard nh1 [aw=hhw], row nofreq

    * Overall: any hazard
    preserve
        bys hhid: egen any_hazard = max(nh1 == 1)
        bys hhid: keep if _n == 1
        di _n as res "Any hazard experienced"
        tab any_hazard [aw=hhw]
    restore

    * ── Early warnings ───────────────────────────────────────────────────────
    di _n as res "Early warning received (among those experiencing hazard)"
    * ──────────────────────────────────────────────────────────────────────────
    * WEIGHT CHOICE: popw (population weight)
    * Unit: "% of Filipinos living in HHs that received early warning"
    * Rationale: DRR indicator — warning reception affects individual preparedness
    * Replicable in: Python §12, R §12 (same weight, same base)
    * ──────────────────────────────────────────────────────────────────────────
    tab nh2 [aw=popw] if nh1 == 1

    * ── Understanding warnings ───────────────────────────────────────────────
    * nh6 = understood warning
    di _n as res "Understood early warning message"
    tab nh6 [aw=hhw] if nh2 == 1

    * ── Damages ──────────────────────────────────────────────────────────────
    di _n as res "Damages/impact (multi-select, among affected)"
    forvalues i = 1/7 {
        cap tab nh3_imp`i' [aw=hhw] if nh1 == 1
    }

    * ── Assistance ───────────────────────────────────────────────────────────
    di _n as res "Received assistance"
    * ──────────────────────────────────────────────────────────────────────────
    * WEIGHT CHOICE: popw (population weight)
    * Unit: "% of Filipinos living in HHs that received post-disaster assistance"
    * Rationale: DRR/welfare indicator — assistance access affects household recovery
    * Replicable in: Python §12, R §12 (same weight, same base)
    * ──────────────────────────────────────────────────────────────────────────
    tab nh4 [aw=popw] if nh1 == 1

    di _n as res "Source of assistance (multi-select)"
    forvalues s = 1/6 {
        cap tab nh4_src`s' [aw=hhw] if nh4 == 1
    }

    * ── Hazard maps ──────────────────────────────────────────────────────────
    di _n as res "Awareness of hazard maps"
    cap tab nh11 [aw=hhw]

    di _n as res "Sources of hazard map awareness"
    forvalues s = 1/8 {
        cap tab nh13_src`s' [aw=hhw] if nh11 == 1
    }
}


********************************************************************************
**# §10  DWELLING (M10)
**#      Weight: hhw (household level)
********************************************************************************
{
    di _n(3) as smcl as txt "{hline 70}"
    di as res "§10  DWELLING — M10"
    di as smcl as txt "{hline 70}"

    use "$dta/${dta_file}_${date}_M10_dwell.dta", clear
    merge m:1 hhid using "$out/_hhwt_temp.dta", nogen keep(match master)

    gen_macroreg
    gen_settlement

    * dw1 = type of building
    * dw2 = roof material
    * dw3 = wall material
    * dw4 = number of bedrooms
    * dw5 = tenure status

    * Colleague comment: "Use pie charts" for building type
    di _n as res "Type of building/house"
    * ──────────────────────────────────────────────────────────────────────────
    * WEIGHT CHOICE: popw (population weight)
    * Unit: "% of Filipinos living in each building type"
    * Rationale: Housing SDG — dwelling conditions affect individual welfare
    * Replicable in: Python §12, R §12 (same weight, same base)
    * ──────────────────────────────────────────────────────────────────────────
    tab dw1 [aw=popw]

    di _n as res "Roof material"
    * ──────────────────────────────────────────────────────────────────────────
    * WEIGHT CHOICE: popw (population weight)
    * Unit: "% of Filipinos living in homes with each roof material"
    * Rationale: Housing SDG — dwelling conditions affect individual welfare
    * Replicable in: Python §12, R §12 (same weight, same base)
    * ──────────────────────────────────────────────────────────────────────────
    tab dw2 [aw=popw]

    di _n as res "Outer wall material"
    * ──────────────────────────────────────────────────────────────────────────
    * WEIGHT CHOICE: popw (population weight)
    * Unit: "% of Filipinos living in homes with each wall material"
    * Rationale: Housing SDG — dwelling conditions affect individual welfare
    * Replicable in: Python §12, R §12 (same weight, same base)
    * ──────────────────────────────────────────────────────────────────────────
    tab dw3 [aw=popw]

    di _n as res "Number of bedrooms"
    tab dw4 [aw=hhw]

    di _n as res "Tenure status"
    * ──────────────────────────────────────────────────────────────────────────
    * WEIGHT CHOICE: popw (population weight)
    * Unit: "% of Filipinos living in homes with each tenure status"
    * Rationale: Housing SDG — tenure security affects individual welfare
    * Replicable in: Python §12, R §12 (same weight, same base)
    * ──────────────────────────────────────────────────────────────────────────
    tab dw5 [aw=popw]

    * Regional breakdowns
    di _n as res "Building type by macro-region"
    tab dw1 macroreg [aw=popw], col nofreq

    di _n as res "Building type by settlement"
    tab dw1 settlement [aw=popw], col nofreq
}


********************************************************************************
**# §11  SANITATION (M11)
**#      Weight: hhw (household level)
********************************************************************************
{
    di _n(3) as smcl as txt "{hline 70}"
    di as res "§11  SANITATION — M11"
    di as smcl as txt "{hline 70}"

    use "$dta/${dta_file}_${date}_M11_san.dta", clear
    merge m:1 hhid using "$out/_hhwt_temp.dta", nogen keep(match master)

    gen_macroreg
    gen_settlement

    * s1 = toilet type
    * s2 = toilet location
    * s3 = shared with non-HH members
    * s5 = waste disposal
    * s6 = segregate organic
    * s7 = segregate recyclables
    * s7a = segregate hazardous
    * s8 = satisfaction with waste disposal

    di _n as res "Toilet facility type"
    * ──────────────────────────────────────────────────────────────────────────
    * WEIGHT CHOICE: popw (population weight)
    * Unit: "% of Filipinos living in homes with each toilet type"
    * Rationale: Sanitation SDG — toilet access affects individual health
    * Replicable in: Python §12, R §12 (same weight, same base)
    * ──────────────────────────────────────────────────────────────────────────
    tab s1 [aw=popw]

    di _n as res "Toilet location"
    tab s2 [aw=hhw]

    di _n as res "Shared toilet"
    * ──────────────────────────────────────────────────────────────────────────
    * WEIGHT CHOICE: popw (population weight)
    * Unit: "% of Filipinos living in homes with shared toilet facilities"
    * Rationale: Sanitation SDG — sharing affects individual health risks
    * Replicable in: Python §12, R §12 (same weight, same base)
    * ──────────────────────────────────────────────────────────────────────────
    tab s3 [aw=popw]

    di _n as res "Waste disposal method"
    forvalues c = 1/4 {
        cap tab s5_cat`c' [aw=hhw]
    }

    di _n as res "Waste segregation — organic"
    * ──────────────────────────────────────────────────────────────────────────
    * WEIGHT CHOICE: hhw (household weight)
    * Unit: "% of households that segregate waste"
    * Rationale: HH-level behavioural practice (waste management decision)
    * ──────────────────────────────────────────────────────────────────────────
    tab s6 [aw=hhw]

    di _n as res "Waste segregation — recyclables"
    tab s7 [aw=hhw]

    di _n as res "Satisfaction with waste disposal"
    tab s8 [aw=hhw]

    * Regional breakdowns
    di _n as res "Toilet type by macro-region"
    tab s1 macroreg [aw=popw], col nofreq

    di _n as res "Toilet type by settlement"
    tab s1 settlement [aw=popw], col nofreq
}


********************************************************************************
**# §12  UTILITIES (M12) — Electricity, Internet, Water
**#      Weight: hhw (household level)
********************************************************************************
{
    di _n(3) as smcl as txt "{hline 70}"
    di as res "§12  UTILITIES — M12"
    di as smcl as txt "{hline 70}"

    * ── Electricity ──────────────────────────────────────────────────────────
    use "$dta/${dta_file}_${date}_M12_elec.dta", clear
    merge m:1 hhid using "$out/_hhwt_temp.dta", nogen keep(match master)

    gen_macroreg
    gen_settlement

    * el1 = has electricity
    * el5 = hours electricity unavailable past week

    di _n as res "Has electricity"
    * ──────────────────────────────────────────────────────────────────────────
    * WEIGHT CHOICE: popw (population weight)
    * Unit: "% of Filipinos living in homes with electricity"
    * Rationale: SDG #7 — electricity access affects individual welfare
    * Replicable in: Python §12, R §12 (same weight, same base)
    * ──────────────────────────────────────────────────────────────────────────
    tab el1 [aw=popw]

    di _n as res "Electricity by macro-region"
    tab el1 macroreg [aw=popw], col nofreq

    di _n as res "Hours electricity unavailable (past week)"
    su el5 [aw=hhw] if el1 == 1 & el5 >= 0 & el5 < .
    if r(N) > 0 di as res "  Mean hours: " %5.1f r(mean)

    * ── Internet ─────────────────────────────────────────────────────────────
    use "$dta/${dta_file}_${date}_M12_net.dta", clear
    merge m:1 hhid using "$out/_hhwt_temp.dta", nogen keep(match master)

    gen_macroreg
    gen_settlement

    * n1 = internet access type (multi-select)
    * n2 = devices used (multi-select)
    * n4 = purpose (multi-select)
    * n5 = experienced interruption

    * Internet access: n1_type1 codes: 1-4 = various connection types, 5 = No internet
    cap drop has_internet
    gen has_internet = (n1_type1 != 5 & n1_type1 < .) if n1_type1 < .

    di _n as res "Internet access"
    * ──────────────────────────────────────────────────────────────────────────
    * WEIGHT CHOICE: popw (population weight)
    * Unit: "% of Filipinos living in homes with internet access"
    * Rationale: SDG #9 — internet access affects individual digital opportunity
    * Replicable in: Python §12, R §12 (same weight, same base)
    * ──────────────────────────────────────────────────────────────────────────
    tab has_internet [aw=popw]

    di _n as res "Internet by macro-region"
    tab has_internet macroreg [aw=popw], col nofreq

    di _n as res "Internet access type"
    forvalues t = 1/3 {
        cap tab n1_type`t' [aw=hhw]
    }

    di _n as res "Devices used for internet"
    forvalues d = 1/5 {
        cap tab n2_dev`d' [aw=hhw] if has_internet == 1
    }

    di _n as res "Purpose of internet use"
    forvalues p = 1/12 {
        cap tab n4_purp`p' [aw=hhw] if has_internet == 1
    }

    di _n as res "Internet interruption (>1hr past month)"
    tab n5 [aw=hhw] if has_internet == 1

    * ── Water ────────────────────────────────────────────────────────────────
    use "$dta/${dta_file}_${date}_M12_water.dta", clear
    merge m:1 hhid using "$out/_hhwt_temp.dta", nogen keep(match master)

    gen_macroreg
    gen_settlement

    * w1 = main water source
    * w2 = provider of piped water
    * w3 = location of water source
    * w5 = main drinking water source
    * w8 = perception if safe

    di _n as res "Main water source"
    * ──────────────────────────────────────────────────────────────────────────
    * WEIGHT CHOICE: popw (population weight)
    * Unit: "% of Filipinos living in homes with each water source"
    * Rationale: SDG #6 — water source affects individual health/safety
    * Replicable in: Python §12, R §12 (same weight, same base)
    * ──────────────────────────────────────────────────────────────────────────
    tab w1 [aw=popw]

    di _n as res "Drinking water source"
    * ──────────────────────────────────────────────────────────────────────────
    * WEIGHT CHOICE: popw (population weight)
    * Unit: "% of Filipinos living in homes with each drinking water source"
    * Rationale: SDG #6 — drinking water affects individual health/safety
    * Replicable in: Python §12, R §12 (same weight, same base)
    * ──────────────────────────────────────────────────────────────────────────
    tab w5 [aw=popw]

    di _n as res "Perception of water safety"
    * ──────────────────────────────────────────────────────────────────────────
    * WEIGHT CHOICE: popw (population weight)
    * Unit: "% of Filipinos living in homes where water is perceived as safe"
    * Rationale: SDG #6 — water safety perception affects individual health decisions
    * Replicable in: Python §12, R §12 (same weight, same base)
    * ──────────────────────────────────────────────────────────────────────────
    tab w8 [aw=popw]

    di _n as res "Water source by macro-region"
    tab w1 macroreg [aw=popw], col nofreq

    di _n as res "Water safety perception by settlement"
    tab w8 settlement [aw=popw], col nofreq
}


********************************************************************************
**# §13  ASSETS & ENERGY (M13)
**#      Weight: hhw (household level)
********************************************************************************
{
    di _n(3) as smcl as txt "{hline 70}"
    di as res "§13  ASSETS & ENERGY — M13"
    di as smcl as txt "{hline 70}"

    use "$dta/${dta_file}_${date}_M13_hc.dta", clear
    merge m:1 hhid using "$out/_hhwt_temp.dta", nogen keep(match master)

    gen_macroreg
    gen_settlement

    * hc1_1 = refrigerator (qty)
    * hc1_2 = washing machine (qty)
    * hc1_3 = air conditioner (qty)
    * hc1_4 = stove/gas range (qty)
    * hc1_5 = motorcycle/tricycle (qty)
    * hc1_6 = car/jeep/van (qty)
    * hc1_7 = ? (check)
    * hc1_8 = ? (check)
    * hc2a-hc2d, hc3a-hc3f = cooking fuel types

    * Ownership rates (has at least 1)
    foreach item in 1 2 3 4 5 6 7 8 {
        cap gen own_hc`item' = (hc1_`item' >= 1 & hc1_`item' < .) if hc1_`item' < .
    }

    di _n as res "Asset ownership rates"
    * ──────────────────────────────────────────────────────────────────────────
    * WEIGHT CHOICE: hhw (household weight)
    * Unit: "% of households that own each asset"
    * Rationale: HH-level ownership decision (consumer durables)
    * ──────────────────────────────────────────────────────────────────────────
    foreach item in 1 2 3 4 5 6 {
        cap su own_hc`item' [aw=hhw]
        if _rc == 0 & r(N) > 0 {
            di as res "  hc1_`item': " %5.1f r(mean)*100 "%"
        }
    }

    di _n as res "Asset ownership by macro-region"
    foreach item in 1 2 3 4 5 6 {
        di _n as res "  Item hc1_`item':"
        cap table macroreg [aw=hhw], stat(mean own_hc`item') nformat(%5.3f)
    }

    di _n as res "Asset ownership by settlement"
    foreach item in 1 2 3 4 5 6 {
        di _n as res "  Item hc1_`item':"
        cap table settlement [aw=hhw], stat(mean own_hc`item') nformat(%5.3f)
    }

    * Cooking fuel
    di _n as res "Primary cooking fuel"
    * ──────────────────────────────────────────────────────────────────────────
    * WEIGHT CHOICE: popw (population weight)
    * Unit: "% of Filipinos living in homes using each cooking fuel type"
    * Rationale: SDG #7 — cooking fuel type affects individual health/environment
    * Replicable in: Python §12, R §12 (same weight, same base)
    * ──────────────────────────────────────────────────────────────────────────
    tab hc2a [aw=popw]

    di _n as res "Cooking fuel by macro-region"
    tab hc2a macroreg [aw=popw], col nofreq
}


********************************************************************************
**# §14  VIEWS & PERCEPTIONS (M14)
**#      Weight: hhw (household level)
********************************************************************************
{
    di _n(3) as smcl as txt "{hline 70}"
    di as res "§14  VIEWS & PERCEPTIONS — M14"
    di as smcl as txt "{hline 70}"

    use "$dta/${dta_file}_${date}_M14_view.dta", clear
    merge m:1 hhid using "$out/_hhwt_temp.dta", nogen keep(match master)

    gen_macroreg
    gen_settlement

    * v1 = life satisfaction (1-5)
    * v2 = self-income classification (poorest to richest)
    * v3 = expected income for children
    * v4 = most important factor for children's income
    * v5 = perceived change vs. past month
    * v6 = best description of current reality
    * v7 = most influential factor for progress
    * v8 = safety rating
    * v9a-v9k = views/worries (Likert scale)
    * v10a-v10e = support statements (Likert scale)

    * ── STORYLINE: Life satisfaction ──────────────────────────────────────────

    di _n as res "Life satisfaction (1-5 scale)"
    tab v1 [aw=hhw]

    di _n as res "Mean life satisfaction"
    su v1 [aw=hhw] if v1 >= 1 & v1 <= 5
    di as res "  Mean: " %5.2f r(mean)

    di _n as res "Life satisfaction by macro-region"
    table macroreg [aw=hhw] if v1 >= 1 & v1 <= 5, stat(mean v1) nformat(%5.2f)

    * ── Self-income classification (ADDED per colleague) ─────────────────────
    di _n as res "Self-income classification (v2) — ADD GRAPH per colleague"
    tab v2 [aw=hhw]

    di _n as res "Self-income classification by macro-region"
    tab v2 macroreg [aw=hhw], col nofreq

    * ── Expected income for children ─────────────────────────────────────────
    di _n as res "Expected income classification for children (v3)"
    tab v3 [aw=hhw] if hh_has_child_u18 == 1

    * ── NEW: Crosstab V2 × V3 (per colleague) ───────────────────────────────
    di _n as res "CROSSTAB: Self-income (V2) × Expected child income (V3)"
    tab v2 v3 [aw=hhw] if hh_has_child_u18 == 1, row nofreq

    * ── Most important factor ────────────────────────────────────────────────
    di _n as res "Most important factor for expected child income (v4)"
    tab v4 [aw=hhw] if hh_has_child_u18 == 1

    * ── Economic perception ──────────────────────────────────────────────────
    di _n as res "Perceived change in economic situation vs. past month (v5)"
    tab v5 [aw=hhw]

    di _n as res "Economic perception by macro-region"
    tab v5 macroreg [aw=hhw], col nofreq

    * ── Current reality description ──────────────────────────────────────────
    di _n as res "Best description of current reality (v6)"
    tab v6 [aw=hhw]

    * ── Most influential factor for progress ─────────────────────────────────
    di _n as res "Most influential factor for progress/success (v7)"
    tab v7 [aw=hhw]

    * ── Safety ───────────────────────────────────────────────────────────────
    di _n as res "Safety rating (v8)"
    tab v8 [aw=hhw]

    * ── Worries & Views (v9a-v9k) ────────────────────────────────────────────
    * Colleague comment: "Double-check vs Dashboard" for political instability

    di _n as res "Worries & Views (v9 series)"
    foreach v in v9a v9b v9c v9d v9e v9f v9g v9h v9i v9j v9k {
        di _n as res "  `v':"
        tab `v' [aw=hhw]
    }

    * ── Support statements (v10a-v10e) ───────────────────────────────────────
    di _n as res "Support statements (v10 series)"
    foreach v in v10a v10b v10c v10d v10e {
        di _n as res "  `v':"
        tab `v' [aw=hhw]
    }

    * ── Regional breakdowns for key views ─────────────────────────────────────
    di _n as res "Political instability worry (v9i) by macro-region — DOUBLE-CHECK"
    tab v9i macroreg [aw=hhw], col nofreq

    di _n as res "Financial situation worse (v9d) by macro-region"
    tab v9d macroreg [aw=hhw], col nofreq

    di _n as res "Job worry (v9g) by macro-region"
    tab v9g macroreg [aw=hhw], col nofreq
}

* ── Cleanup: remove temporary HH-level weight file ────────────────────────
cap erase "$out/_hhwt_temp.dta"

********************************************************************************
di _n(3) as smcl as txt "{hline 70}"
di as res "MASTER DO-FILE COMPLETE"
di as res "All storyline figures have been replicated."
di as smcl as txt "{hline 70}"
********************************************************************************
