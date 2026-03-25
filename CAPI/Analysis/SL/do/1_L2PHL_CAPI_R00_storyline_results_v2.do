********************************************************************************
* L2Phl CAPI Baseline — Storyline Results Export to Markdown (v2)
* Produces: storyline_results_stata.md
*
* v2: narrow employment definition for storyline match
*
* This do-file computes ALL key storyline statistics and writes them to
* a structured Markdown file. The Python and R replication scripts produce
* identically structured .md files for cross-validation.
*
* KEY CHANGE IN V2:
*   Employment rate computed with NARROW definition (a1==1 only) to match
*   storyline charts and text. Broad definition (ILO: a1|a2) still computed
*   for reference but not used in storyline output rows.
*
* Author: Avralt-Od Purevjav
* Created: Mar 24, 2026
* Updated: Mar 25, 2026 — v2 narrow employment + written contracts
*
* OUTPUT FORMAT (each line):
*   | indicator_id | label | value |
*
* All percentages rounded to 2 decimal places.
* All means rounded to nearest integer (PHP) or 2 decimals (rates/scores).
********************************************************************************

{
    clear all
    set more off
    set excelxlsxlargefile on
    set maxvar 10000

    loc user = "AP"

    if ("`user'"=="AP") ///
        glo wd "~/iDrive/GitHub/PHL/L2PHL/CAPI"
    if ("`user'"=="BB") ///
        glo wd "/Users/batmandakh/Dropbox/BB/WB/PHL/CAPI"
    if ("`user'"=="LD") ///
        glo wd "C:\Users\Liz Danganan\OneDrive - PSRC\3 MACROS & TEMPLATES\TIPON\TIPON\data"

    cd "$wd"

    glo LNG ENG
    glo R 00
    glo M 10
    glo D 15
    glo Y 2025
    glo dta_file l2phl
    glo date ${Y}${M}${D}

    glo ado "$wd/Round${R}/ado"
    glo dta "$wd/Round${R}/dta/$date"
    glo out "$wd/Analysis/SL"            // working dir (temp files)
    glo res "$wd/Analysis/SL/results"    // results output (.md, .txt)

    cap adopath - "$wd/Round${R}/ado/"
    adopath + "$wd/Round${R}/ado/"

    cap confirmdir "$res"
    if _rc ~= 0 mkdir "$res"
}

* ── Create HH-level weight file ───────────────────────────────────────────
use "$ado/final_weights.dta", clear
bys hhid: keep if _n == 1
keep hhid hhw popw region urban hhsize
save "$out/_hhwt_temp.dta", replace

* ── Macro-region generator ──────────────────────────────────────────────────
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

* ── Initialize Markdown output ──────────────────────────────────────────────
cap file close md
file open md using "$res/storyline_results_stata.md", write replace

file write md "# L2Phl Storyline Results — Stata (v2)" _n
file write md "Generated: `c(current_date)' `c(current_time)'" _n
file write md "" _n
file write md "| ID | Label | Value |" _n
file write md "|:---|:------|------:|" _n

* ── Helper program: write one result line ───────────────────────────────────
cap program drop wmd
program define wmd
    * Writes one row using globals: wid, wlb, wvl
    file write md "| ${wid} | ${wlb} | ${wvl} |" _n
end


********************************************************************************
**# §1  ROSTER (M01)
********************************************************************************
{
    use "$dta/${dta_file}_${date}_M01_roster.dta", clear
    merge m:1 hhid fmid using "$ado/final_weights.dta", ///
        keepusing(indw hhw popw region urban hhsize) nogen keep(match)
    gen_macroreg

    file write md "" _n
    file write md "## §1 Roster (M01)" _n
    file write md "" _n

    * ── Sample size ──────────────────────────────────────────────────────────
    count
    glo wid "R01_N"
    glo wlb "Total household members (unweighted N)"
    glo wvl "`r(N)'"
    wmd

    * ── Weighted population ──────────────────────────────────────────────────
    su indw
    local wpop = r(sum)
    glo wid "R01_POP"
    glo wlb "Weighted population (sum of indw)"
    glo wvl = string(`wpop', "%15.0f")
    wmd

    * ── Under 20 share ───────────────────────────────────────────────────────
    gen under20 = (age < 20) if age < .
    su under20 [aw=indw]
    glo wid "R01_UNDER20"
    glo wlb "% under 20"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    drop under20

    * ── Median age: total, male, female ──────────────────────────────────────
    _pctile age [pw=indw], p(50)
    glo wid "R01_MEDIAN_AGE"
    glo wlb "Median age (total)"
    glo wvl = string(r(r1), "%8.1f")
    wmd

    _pctile age [pw=indw] if gender == 1, p(50)
    glo wid "R01_MEDIAN_AGE_M"
    glo wlb "Median age (male)"
    glo wvl = string(r(r1), "%8.1f")
    wmd

    _pctile age [pw=indw] if gender == 2, p(50)
    glo wid "R01_MEDIAN_AGE_F"
    glo wlb "Median age (female)"
    glo wvl = string(r(r1), "%8.1f")
    wmd

    * ── Gender split ─────────────────────────────────────────────────────────
    gen male = (gender == 1) if gender < .
    su male [aw=indw]
    glo wid "R01_PCT_MALE"
    glo wlb "% male"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd

    local pf = (1 - r(mean)) * 100
    glo wid "R01_PCT_FEMALE"
    glo wlb "% female"
    glo wvl = string(`pf', "%8.2f")
    wmd
    drop male

    * ── Age groups (original 10-year bands) ──────────────────────────────────
    gen age_grp = .
    replace age_grp = 1 if age < 10
    replace age_grp = 2 if age >= 10 & age <= 19
    replace age_grp = 3 if age >= 20 & age <= 29
    replace age_grp = 4 if age >= 30 & age <= 39
    replace age_grp = 5 if age >= 40 & age <= 49
    replace age_grp = 6 if age >= 50 & age <= 59
    replace age_grp = 7 if age >= 60 & age <= 69
    replace age_grp = 8 if age >= 70 & age < .

    local agrlbl `" "<10" "10-19" "20-29" "30-39" "40-49" "50-59" "60-69" "70+" "'
    forvalues g = 1/8 {
        gen tag = (age_grp == `g') if age_grp < .
        su tag [aw=indw]
        local lbl: word `g' of `agrlbl'
        glo wid "R01_AGEGRP_`g'"
        glo wlb "% age `lbl'"
        glo wvl = string(r(mean)*100, "%8.2f")
        wmd
        drop tag
    }
    drop age_grp

    * ── Age groups (NEW: <15, 15-17, 18-45, 46-59, 60+) ─────────────────────
    gen age_grp_new = .
    replace age_grp_new = 1 if age < 15
    replace age_grp_new = 2 if age >= 15 & age <= 17
    replace age_grp_new = 3 if age >= 18 & age <= 45
    replace age_grp_new = 4 if age >= 46 & age <= 59
    replace age_grp_new = 5 if age >= 60 & age < .

    local newlbl `" "<15" "15-17" "18-45" "46-59" "60+" "'
    forvalues g = 1/5 {
        gen tag = (age_grp_new == `g') if age_grp_new < .
        su tag [aw=indw]
        local lbl: word `g' of `newlbl'
        glo wid "R01_AGEGRP_NEW_`g'"
        glo wlb "% age `lbl' (new)"
        glo wvl = string(r(mean)*100, "%8.2f")
        wmd
        drop tag
    }
    drop age_grp_new

    * ── Under-10 by macro-region ─────────────────────────────────────────────
    gen under10 = (age < 10) if age < .
    forvalues m = 1/4 {
        su under10 [aw=indw] if macroreg == `m'
        local lbl: label (macroreg) `m'
        glo wid "R01_UNDER10_MR`m'"
        glo wlb "% under 10 — `lbl'"
        glo wvl = string(r(mean)*100, "%8.2f")
        wmd
    }
    drop under10

    * ── Relationship to HH head ──────────────────────────────────────────────
    * Top categories
    foreach val in 1 2 3 6 {
        gen tag = (relationship == `val') if relationship < .
        su tag [aw=indw]
        local lbl: label (relationship) `val'
        glo wid "R01_REL_`val'"
        glo wlb "% relationship: `lbl'"
        glo wvl = string(r(mean)*100, "%8.2f")
        wmd
        drop tag
    }

    * ── Marital status ───────────────────────────────────────────────────────
    * Single
    gen single = (marital_status == 1) if marital_status < .
    su single [aw=indw]
    glo wid "R01_SINGLE"
    glo wlb "% single/unmarried"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    drop single

    * Widowed by sex
    gen widowed = (marital_status == 4) if marital_status < .
    su widowed [aw=indw] if gender == 2
    glo wid "R01_WIDOWED_F"
    glo wlb "% widowed (female)"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    su widowed [aw=indw] if gender == 1
    glo wid "R01_WIDOWED_M"
    glo wlb "% widowed (male)"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    drop widowed

    * ── Disability ───────────────────────────────────────────────────────────
    gen disabled = (member_disability == 1)
    su disabled [aw=indw]
    glo wid "R01_DISABILITY"
    glo wlb "% with disability"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd

    su disabled [aw=indw] if gender == 1
    glo wid "R01_DISABILITY_M"
    glo wlb "% with disability (male)"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd

    su disabled [aw=indw] if gender == 2
    glo wid "R01_DISABILITY_F"
    glo wlb "% with disability (female)"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd

    * PWD ID (among disabled)
    gen has_pwdid = (inci_pwdid == 1) if member_disability == 1 & inci_pwdid < .
    su has_pwdid [aw=indw]
    glo wid "R01_PWDID"
    glo wlb "% PWDs with ID card"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd

    local nopwd = (1 - r(mean)) * 100
    glo wid "R01_PWDID_NO"
    glo wlb "% PWDs without ID card"
    glo wvl = string(`nopwd', "%8.2f")
    wmd

    forvalues m = 1/4 {
        su has_pwdid [aw=indw] if macroreg == `m'
        local lbl: label (macroreg) `m'
        glo wid "R01_PWDID_MR`m'"
        glo wlb "% PWDs with ID — `lbl'"
        glo wvl = string(r(mean)*100, "%8.2f")
        wmd
    }
    drop disabled has_pwdid
}


********************************************************************************
**# §2  EDUCATION (M02)
********************************************************************************
{
    use "$dta/${dta_file}_${date}_M02_edu.dta", clear
    merge m:1 hhid fmid using "$ado/final_weights.dta", ///
        keepusing(indw hhw popw region urban hhsize) nogen keep(match)
    gen_macroreg

    file write md "" _n
    file write md "## §2 Education (M02)" _n
    file write md "" _n

    * ── Attendance 5-24 ──────────────────────────────────────────────────────
    gen attending = (ed1 == 1) if ed1 < . & age >= 5 & age <= 24
    su attending [aw=indw]
    glo wid "E02_ATTEND_5_24"
    glo wlb "% attending school (5-24)"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd

    * By sex
    su attending [aw=indw] if gender == 1
    glo wid "E02_ATTEND_M"
    glo wlb "% attending (male, 5-24)"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    su attending [aw=indw] if gender == 2
    glo wid "E02_ATTEND_F"
    glo wlb "% attending (female, 5-24)"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd

    * By age band
    foreach lb in "6 11" "12 15" "16 17" "18 19" "20 24" {
        local lo: word 1 of `lb'
        local hi: word 2 of `lb'
        gen tag = (ed1 == 1) if ed1 < . & age >= `lo' & age <= `hi'
        su tag [aw=indw]
        glo wid "E02_ATTEND_`lo'_`hi'"
        glo wlb "% attending (`lo'-`hi')"
        glo wvl = string(r(mean)*100, "%8.2f")
        wmd
        drop tag
    }
    drop attending

    * By macro-region
    gen attending = (ed1 == 1) if ed1 < . & age >= 5 & age <= 24
    forvalues m = 1/4 {
        su attending [aw=indw] if macroreg == `m'
        local lbl: label (macroreg) `m'
        glo wid "E02_ATTEND_MR`m'"
        glo wlb "% attending (5-24) — `lbl'"
        glo wvl = string(r(mean)*100, "%8.2f")
        wmd
    }
    drop attending

    * ── School type ──────────────────────────────────────────────────────────
    * Public = 1, Private = 2, Home-schooled = 3 (check coding)
    gen public_sch = (ed2 == 1) if ed1 == 1 & ed2 < .
    su public_sch [aw=indw]
    glo wid "E02_PUBLIC"
    glo wlb "% public school (among attending)"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd

    * Private by macro-region
    gen private_sch = (ed2 == 2) if ed1 == 1 & ed2 < .
    forvalues m = 1/4 {
        su private_sch [aw=indw] if macroreg == `m'
        local lbl: label (macroreg) `m'
        glo wid "E02_PRIVATE_MR`m'"
        glo wlb "% private school — `lbl'"
        glo wvl = string(r(mean)*100, "%8.2f")
        wmd
    }
    drop public_sch private_sch

    * ── Education expenditure ────────────────────────────────────────────────
    cap drop ed_total_exp
    egen ed_total_exp = rowtotal(ed5a ed5b ed5c ed5d ed5e ed5f ed5g ed5h ed5i) ///
        if ed1 == 1

    su ed_total_exp [aw=indw] if ed_total_exp > 0 & ed_total_exp < .
    glo wid "E02_MEAN_EXP"
    glo wlb "Mean annual education expenditure (PHP)"
    glo wvl = string(r(mean), "%10.0f")
    wmd

    * By settlement
    su ed_total_exp [aw=indw] if ed_total_exp > 0 & urban == 1
    glo wid "E02_MEAN_EXP_URB"
    glo wlb "Mean education exp — Urban"
    glo wvl = string(r(mean), "%10.0f")
    wmd
    su ed_total_exp [aw=indw] if ed_total_exp > 0 & urban == 2
    glo wid "E02_MEAN_EXP_RUR"
    glo wlb "Mean education exp — Rural"
    glo wvl = string(r(mean), "%10.0f")
    wmd

    * Individual expenditure items (among spenders)
    local items "ed5a ed5b ed5c ed5d ed5e ed5f ed5g ed5h ed5i"
    local names `" "Tuition/fees" "Textbooks" "Uniforms" "Transport" "Meals/lodging" "Internet" "Supplies" "Contributions" "Other" "'
    local i = 1
    foreach v of local items {
        local nm: word `i' of `names'
        su `v' [aw=indw] if ed1 == 1 & `v' > 0 & `v' < .
        if r(N) > 0 {
            glo wid "E02_EXP_`v'"
            glo wlb "Mean `nm' expenditure (PHP)"
            glo wvl = string(r(mean), "%10.0f")
            wmd
        }
        local ++i
    }
}


********************************************************************************
**# §3  EMPLOYMENT (M03) — Base: 15+ population
**# v2: Uses NARROW employment definition (a1==1 only) for storyline match
********************************************************************************
{
    use "$dta/${dta_file}_${date}_M03_emp.dta", clear
    merge m:1 hhid fmid using "$ado/final_weights.dta", ///
        keepusing(indw hhw popw region urban hhsize age gender) nogen keep(match)
    gen_macroreg

    file write md "" _n
    file write md "## §3 Employment (M03)" _n
    file write md "" _n

    count if age >= 15
    glo wid "A03_BASE_15PLUS"
    glo wlb "Working-age base 15+ (unweighted N)"
    glo wvl "`r(N)'"
    wmd

    * Broad definition (ILO): a1==1 | a2==1 (for reference)
    gen employed_broad = (a1 == 1 | a2 == 1) if age >= 15 & age < .

    * NARROW definition (storyline match): a1==1 only
    gen employed_narrow = (a1 == 1) if age >= 15 & age < .

    * Employment rate BROAD (ILO reference)
    su employed_broad [aw=indw] if age >= 15
    glo wid "A03_EMP_RATE_BROAD"
    glo wlb "Employment rate — broad (a1|a2, 15+, ILO reference)"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd

    * Employment rate NARROW (storyline match) → Storyline: ~45%
    su employed_narrow [aw=indw] if age >= 15
    glo wid "A03_EMP_RATE"
    glo wlb "Employment rate — narrow (a1 only, 15+)"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd

    * By sex (narrow) → Storyline: M 59%, F 30%
    su employed_narrow [aw=indw] if age >= 15 & gender == 1
    glo wid "A03_EMP_RATE_M"
    glo wlb "Employment rate (male)"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    su employed_narrow [aw=indw] if age >= 15 & gender == 2
    glo wid "A03_EMP_RATE_F"
    glo wlb "Employment rate (female)"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd

    * By age group (narrow)
    foreach lb in "15 24" "25 34" "35 44" "45 54" "55 64" {
        local lo: word 1 of `lb'
        local hi: word 2 of `lb'
        su employed_narrow [aw=indw] if age >= `lo' & age <= `hi'
        glo wid "A03_EMP_`lo'_`hi'"
        glo wlb "Employment rate (`lo'-`hi')"
        glo wvl = string(r(mean)*100, "%8.2f")
        wmd
    }

    * By macro-region (narrow) → Storyline: NCR 46%, Luzon 48%, Visayas 41%, Mindanao 41%
    forvalues m = 1/4 {
        su employed_narrow [aw=indw] if age >= 15 & macroreg == `m'
        local lbl: label (macroreg) `m'
        glo wid "A03_EMP_MR`m'"
        glo wlb "Employment rate — `lbl'"
        glo wvl = string(r(mean)*100, "%8.2f")
        wmd
    }

    * ── Contracts ────────────────────────────────────────────────────────────
    * a16: 1=Written, 2=Verbal, 3=No contract, 99=Don't know
    * No formal contract
    gen no_contract = (a16 == 3) if employed_narrow == 1 & a16 < .  // Include DK(99) in denominator → 71.7% → Storyline 72%
    su no_contract [aw=indw]
    glo wid "A03_NO_CONTRACT"
    glo wlb "% no contract (a16==3, among narrow-employed)"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    drop no_contract

    * Written contract → Storyline: 18%
    gen written_contract = (a16 == 1) if employed_narrow == 1 & a16 < .  // Include DK(99) in denominator → 17.8% → Storyline 18%
    su written_contract [aw=indw]
    glo wid "A03_WRITTEN_CONTRACT"
    glo wlb "% written contract (a16==1, among narrow-employed)"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    drop written_contract

    * ── Hours worked ─────────────────────────────────────────────────────────
    * a11: "How many hours does [NAME] usually work in a week?" → Storyline: 32 hours
    su a11 [aw=indw] if employed_narrow == 1 & a11 > 0 & a11 <= 168
    glo wid "A03_MEAN_HOURS"
    glo wlb "Mean hours worked/week (narrow-employed)"
    glo wvl = string(r(mean), "%8.1f")
    wmd

    * ── Job loss ─────────────────────────────────────────────────────────────
    gen jobloss = (a12 == 1) if age >= 15 & a12 < .
    su jobloss [aw=indw]
    glo wid "A03_JOBLOSS"
    glo wlb "% HH member lost job past 30d"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    drop jobloss employed_broad employed_narrow
}


********************************************************************************
**# §4  INCOME (M04)
**# NOTE: Storyline focuses on income SOURCES only, not mean earnings
********************************************************************************
{
    file write md "" _n
    file write md "## §4 Income (M04)" _n
    file write md "" _n

    * Individual level
    use "$dta/${dta_file}_${date}_M04_inc1.dta", clear
    merge m:1 hhid fmid using "$ado/final_weights.dta", ///
        keepusing(indw hhw popw region urban hhsize) nogen keep(match)
    gen_macroreg

    * Regular income
    gen has_regular = (ia1 == 1) if ia1 < .
    su has_regular [aw=indw]
    glo wid "I04_REGULAR_INC"
    glo wlb "% with regular income (past 6mo)"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    drop has_regular

    * Mean 6-month cash earnings (reference only; storyline focuses on sources)
    su ia3ab [aw=indw] if ia3ab > 0 & ia3ab < .
    glo wid "I04_MEAN_CASH_6MO"
    glo wlb "Mean 6-month cash earnings (PHP, reference only)"
    glo wvl = string(r(mean), "%10.0f")
    wmd

    * By macro-region
    forvalues m = 1/4 {
        su ia3ab [aw=indw] if ia3ab > 0 & ia3ab < . & macroreg == `m'
        local lbl: label (macroreg) `m'
        glo wid "I04_CASH_MR`m'"
        glo wlb "Mean cash earnings — `lbl'"
        glo wvl = string(r(mean), "%10.0f")
        wmd
    }

    * By settlement
    su ia3ab [aw=indw] if ia3ab > 0 & ia3ab < . & urban == 1
    glo wid "I04_CASH_URB"
    glo wlb "Mean cash earnings — Urban"
    glo wvl = string(r(mean), "%10.0f")
    wmd
    su ia3ab [aw=indw] if ia3ab > 0 & ia3ab < . & urban == 2
    glo wid "I04_CASH_RUR"
    glo wlb "Mean cash earnings — Rural"
    glo wvl = string(r(mean), "%10.0f")
    wmd

    * HH level
    use "$dta/${dta_file}_${date}_M04_inc2.dta", clear
    merge m:1 hhid using "$out/_hhwt_temp.dta", nogen keep(match master)
    gen_macroreg

    * OFW remittances — ic1_1 asked only if HH has OFW member; not missing = has OFW
    gen has_ofw = (ic1_1 < .)  // has OFW member = ic1_1 not missing → 8.72% → Storyline 9%
    su has_ofw [aw=hhw]
    glo wid "I04_OFW_PCT"
    glo wlb "% HHs with OFW member"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    drop has_ofw

    su ic1_1 [aw=hhw] if ic1_1 > 0 & ic1_1 < .
    glo wid "I04_OFW_MEAN"
    glo wlb "Mean OFW remittance (PHP, 6mo)"
    glo wvl = string(r(mean), "%10.0f")
    wmd

    * Domestic support
    gen has_domestic = (ic3 == 1) if ic3 < .
    su has_domestic [aw=hhw]
    glo wid "I04_DOMESTIC_PCT"
    glo wlb "% HHs receiving domestic support"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    drop has_domestic

    * Pension
    gen has_pension = (ic8a == 1) if ic8a < .
    su has_pension [aw=hhw]
    glo wid "I04_PENSION_PCT"
    glo wlb "% HHs receiving pension"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    drop has_pension

    * 4Ps
    gen has_4ps = (id1 == 1) if id1 < .
    su has_4ps [aw=hhw]
    glo wid "I04_4PS_PCT"
    glo wlb "% HHs receiving 4Ps"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    drop has_4ps
}


********************************************************************************
**# §5  FINANCE (M05)
********************************************************************************
{
    use "$dta/${dta_file}_${date}_M05_fin.dta", clear
    merge m:1 hhid using "$out/_hhwt_temp.dta", nogen keep(match master)
    gen_macroreg

    file write md "" _n
    file write md "## §5 Finance (M05)" _n
    file write md "" _n

    count
    glo wid "F05_N"
    glo wlb "Finance base (unweighted N HHs)"
    glo wvl "`r(N)'"
    wmd

    * Each indicator: f1-f7 (yes=1)
    local fvars "f1 f2 f3 f4 f5 f6 f7"
    local flbls `" "Formal bank account" "Mobile money" "Managed to save" "Paluwagan" "Credit/debit card" "Can cover 300k emergency" "Applied for loan" "'
    local i = 1
    foreach v of local fvars {
        local nm: word `i' of `flbls'
        gen tag = (`v' == 1) if `v' < .
        su tag [aw=hhw]
        glo wid "F05_`v'"
        glo wlb "% `nm'"
        glo wvl = string(r(mean)*100, "%8.2f")
        wmd
        drop tag
        local ++i
    }

    * Mobile money by macro-region
    gen mm = (f2 == 1) if f2 < .
    forvalues m = 1/4 {
        su mm [aw=hhw] if macroreg == `m'
        local lbl: label (macroreg) `m'
        glo wid "F05_MM_MR`m'"
        glo wlb "% mobile money — `lbl'"
        glo wvl = string(r(mean)*100, "%8.2f")
        wmd
    }
    drop mm

    * Savings by settlement
    gen saves = (f3 == 1) if f3 < .
    su saves [aw=hhw] if urban == 1
    glo wid "F05_SAVE_URB"
    glo wlb "% saves — Urban"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    su saves [aw=hhw] if urban == 2
    glo wid "F05_SAVE_RUR"
    glo wlb "% saves — Rural"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    drop saves
}


********************************************************************************
**# §6  MIGRATION (M06)
********************************************************************************
{
    use "$dta/${dta_file}_${date}_M06_mig.dta", clear
    merge m:1 hhid fmid using "$ado/final_weights.dta", ///
        keepusing(indw hhw popw region urban hhsize) nogen keep(match)
    gen_macroreg

    file write md "" _n
    file write md "## §6 Migration (M06)" _n
    file write md "" _n

    * m6: "Is any HH member 15+ considering migrating?" (HH-level, 1=Yes, 2=No)
    * m6==1 [aw=hhw]: ~2.28% → Storyline 2%
    preserve
    bys hhid: keep if _n == 1
    gen considering = (m6 == 1) if m6 < .
    su considering [aw=hhw]
    glo wid "M06_CONSIDERING"
    glo wlb "% HHs with migration intent (m6)"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd

    forvalues m = 1/4 {
        su considering [aw=hhw] if macroreg == `m'
        local lbl: label (macroreg) `m'
        glo wid "M06_MIG_MR`m'"
        glo wlb "% HHs with migration intent — `lbl'"
        glo wvl = string(r(mean)*100, "%8.2f")
        wmd
    }
    drop considering
    restore

    * m7: individual migration intent — asked in HHs where m6==1 (n≈207)
    * m7==1 among ALL 15+ = ~0.92% (population share)
    * m7==1 among those asked = ~35.6% (conditional, within m6==1 HHs)
    gen considering15 = (m7 == 1) if age >= 15
    replace considering15 = 0 if considering15 == . & age >= 15
    su considering15 [aw=indw]
    glo wid "M06_MIG_INTENT_15PLUS"
    glo wlb "% of 15+ considering migration (m7, population share)"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    drop considering15

    gen mig_intent = (m7 == 1) if m7 < .
    su mig_intent [aw=indw]
    glo wid "M06_MIG_INTENT_COND"
    glo wlb "% considering migration (conditional, among m6==1 HH members)"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    drop mig_intent

    * m9: displacement in past 12 months (individual, 13+): 1=No, 2-5=Yes
    use "$dta/${dta_file}_${date}_M06_mig.dta", clear
    merge m:1 hhid fmid using "$ado/final_weights.dta", ///
        keepusing(indw hhw popw region urban hhsize) nogen keep(match)
    gen_macroreg
    gen displaced = (m9 != 1) if m9 < . & age >= 13
    su displaced [aw=indw]
    glo wid "M06_DISPLACED"
    glo wlb "% displaced in past 12mo (13+)"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    drop displaced
}


********************************************************************************
**# §7  HEALTH (M07)
********************************************************************************
{
    use "$dta/${dta_file}_${date}_M07_med.dta", clear
    merge m:1 hhid fmid using "$ado/final_weights.dta", ///
        keepusing(indw hhw popw region urban hhsize) nogen keep(match)
    gen_macroreg

    file write md "" _n
    file write md "## §7 Health (M07)" _n
    file write md "" _n

    * Needed health care (codes 1-3)
    gen needed = inlist(h2, 1, 2, 3) if h2 < .
    su needed [aw=indw]
    glo wid "H07_NEEDED"
    glo wlb "% needed health care (past 30d)"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd

    * Able to access (CORRECTED: among codes 1-3 only)
    gen able = (h2a == 1) if inlist(h2, 1, 2, 3) & h2a < .
    su able [aw=indw]
    glo wid "H07_ABLE"
    glo wlb "% able to get care (among those needing)"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    drop needed able

    * OOP — h8: 1=Yes cash, 2=Yes in kind, 3=No → Storyline: 54%
    gen oop = inlist(h8, 1, 2) if inlist(h2, 1, 2, 3) & h2a == 1 & h8 < .
    su oop [aw=indw]
    glo wid "H07_OOP"
    glo wlb "% paid OOP (among those accessing care)"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    drop oop

    * PhilHealth — h17: 1=Paying, 2=Non-paying, 3=No, 4=Dep paying, 5=Dep non-paying → Storyline: 46%
    gen ph = inlist(h17, 1, 2, 4, 5) if h17 < .
    su ph [aw=indw]
    glo wid "H07_PHILHEALTH"
    glo wlb "% PhilHealth member"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd

    forvalues m = 1/4 {
        su ph [aw=indw] if macroreg == `m'
        local lbl: label (macroreg) `m'
        glo wid "H07_PH_MR`m'"
        glo wlb "% PhilHealth — `lbl'"
        glo wvl = string(r(mean)*100, "%8.2f")
        wmd
    }
    drop ph

    * Hospitalisation — h14 is total hospital cost (not h13 which is hospital type)
    gen hosp = (h12 == 1) if h12 < .
    su hosp [aw=indw]
    glo wid "H07_HOSP"
    glo wlb "% hospitalised (past 12mo)"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    drop hosp

    su h14 [aw=indw] if h12 == 1 & h14 > 0 & h14 < .
    if r(N) > 0 {
        glo wid "H07_HOSP_BILL"
        glo wlb "Mean hospital bill (PHP)"
        glo wvl = string(r(mean), "%10.0f")
        wmd
    }
}


********************************************************************************
**# §8  FOOD (M08)
********************************************************************************
{
    file write md "" _n
    file write md "## §8 Food (M08)" _n
    file write md "" _n

    * Food — HH level
    use "$dta/${dta_file}_${date}_M08_food.dta", clear
    merge m:1 hhid using "$out/_hhwt_temp.dta", nogen keep(match master)
    gen_macroreg

    * Wet market share → Storyline: 74%
    gen wetmarket = (fo1 == 1) if fo1 < .
    su wetmarket [aw=hhw]
    glo wid "FO8_WETMARKET"
    glo wlb "% wet market as primary food source"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    drop wetmarket

    * SSB — individual level
    use "$dta/${dta_file}_${date}_M08_ssb.dta", clear
    merge m:1 hhid fmid using "$ado/final_weights.dta", ///
        keepusing(indw hhw popw region urban hhsize) nogen keep(match)

    gen ssb_yes = (ssb1 == 1) if ssb1 < .
    su ssb_yes [aw=indw]
    glo wid "FO8_SSB"
    glo wlb "% consumed SSB (past 30d)"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    drop ssb_yes

    su ssb3 [aw=indw] if ssb1 == 1 & ssb3 > 0 & ssb3 < .  // ssb3 = actual servings/day → ~7.15 → Storyline 6.9
    if r(N) > 0 {
        glo wid "FO8_SSB_SERVINGS"
        glo wlb "Mean SSB servings/day"
        glo wvl = string(r(mean), "%8.1f")
        wmd
    }
}


********************************************************************************
**# §9  HAZARDS (M09)
********************************************************************************
{
    use "$dta/${dta_file}_${date}_M09_nh.dta", clear
    merge m:1 hhid using "$out/_hhwt_temp.dta", nogen keep(match master)
    gen_macroreg

    file write md "" _n
    file write md "## §9 Hazards (M09)" _n
    file write md "" _n

    * Warning received (among affected) → Storyline: 55%
    gen warning = (nh2 == 1) if nh1 == 1 & nh2 < .
    su warning [aw=hhw]
    glo wid "NH9_WARNING"
    glo wlb "% received early warning (among affected)"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    drop warning

    * Assistance received (among affected) — nh4 is string (multi-select)
    * Not empty, not ".", not "99" means assistance received
    gen assist = (nh4 != "" & nh4 != "." & nh4 != "99") if nh1 == 1
    su assist [aw=hhw]
    glo wid "NH9_ASSIST"
    glo wlb "% received assistance (among affected)"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    drop assist
}


********************************************************************************
**# §10-11  DWELLING & SANITATION (M10, M11)
********************************************************************************
{
    file write md "" _n
    file write md "## §10-11 Dwelling & Sanitation (M10, M11)" _n
    file write md "" _n

    * Dwelling tenure
    use "$dta/${dta_file}_${date}_M10_dwell.dta", clear
    merge m:1 hhid using "$out/_hhwt_temp.dta", nogen keep(match master)

    count
    glo wid "DW10_N"
    glo wlb "Dwelling base (unweighted N HHs)"
    glo wvl "`r(N)'"
    wmd

    * Sanitation
    use "$dta/${dta_file}_${date}_M11_san.dta", clear
    merge m:1 hhid using "$out/_hhwt_temp.dta", nogen keep(match master)

    count
    glo wid "S11_N"
    glo wlb "Sanitation base (unweighted N HHs)"
    glo wvl "`r(N)'"
    wmd
}


********************************************************************************
**# §12  UTILITIES (M12)
********************************************************************************
{
    file write md "" _n
    file write md "## §12 Utilities (M12)" _n
    file write md "" _n

    * Electricity
    use "$dta/${dta_file}_${date}_M12_elec.dta", clear
    merge m:1 hhid using "$out/_hhwt_temp.dta", nogen keep(match master)
    gen_macroreg

    gen has_elec = (el1 == 1) if el1 < .
    su has_elec [aw=hhw]
    glo wid "U12_ELEC"
    glo wlb "% has electricity"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    drop has_elec

    * Internet
    use "$dta/${dta_file}_${date}_M12_net.dta", clear
    merge m:1 hhid using "$out/_hhwt_temp.dta", nogen keep(match master)
    gen_macroreg

    * n1_type1: 1=Fixed wired, 2=Fixed wireless, 3=Satellite, 4=Mobile, 5=No
    gen has_inet = (n1_type1 != 5 & n1_type1 < .) if n1_type1 < .
    su has_inet [aw=hhw]
    glo wid "U12_INTERNET"
    glo wlb "% has internet access"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    drop has_inet

    * Water
    use "$dta/${dta_file}_${date}_M12_water.dta", clear
    merge m:1 hhid using "$out/_hhwt_temp.dta", nogen keep(match master)
    gen_macroreg

    * Piped water = w1 == 1 ("Piped into dwelling" only) → 60.6% → Storyline 61%
    gen piped = (w1 == 1) if w1 < .
    su piped [aw=hhw]
    glo wid "U12_PIPED_WATER"
    glo wlb "% piped water"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    drop piped

    * Perception safe — w8: 1=Very unsafe, 2=Mostly unsafe, 3=Mostly safe, 4=Very safe
    gen safe = inlist(w8, 3, 4) if w8 < .
    su safe [aw=hhw]
    glo wid "U12_WATER_SAFE"
    glo wlb "% perceive water as safe"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    drop safe
}


********************************************************************************
**# §13  ASSETS (M13)
********************************************************************************
{
    use "$dta/${dta_file}_${date}_M13_hc.dta", clear
    merge m:1 hhid using "$out/_hhwt_temp.dta", nogen keep(match master)
    gen_macroreg

    file write md "" _n
    file write md "## §13 Assets (M13)" _n
    file write md "" _n

    local assets "hc1_1 hc1_2 hc1_3 hc1_4 hc1_5 hc1_6"
    local albl `" "Refrigerator" "Washing machine" "Air conditioner" "Stove/range" "Motorcycle" "Car/jeep/van" "'
    local i = 1
    foreach v of local assets {
        local nm: word `i' of `albl'
        gen own = (`v' >= 1 & `v' < .) if `v' < .
        su own [aw=hhw]
        glo wid "HC13_OWN_`i'"
        glo wlb "% owns `nm'"
        glo wvl = string(r(mean)*100, "%8.2f")
        wmd
        drop own
        local ++i
    }
}


********************************************************************************
**# §14  VIEWS (M14)
********************************************************************************
{
    use "$dta/${dta_file}_${date}_M14_view.dta", clear
    merge m:1 hhid using "$out/_hhwt_temp.dta", nogen keep(match master)
    gen_macroreg

    file write md "" _n
    file write md "## §14 Views (M14)" _n
    file write md "" _n

    * Life satisfaction mean → Storyline: 3.04/5
    su v1 [aw=hhw] if v1 >= 1 & v1 <= 5
    glo wid "V14_LIFESAT"
    glo wlb "Mean life satisfaction (1-5)"
    glo wvl = string(r(mean), "%8.2f")
    wmd

    * By macro-region
    forvalues m = 1/4 {
        su v1 [aw=hhw] if v1 >= 1 & v1 <= 5 & macroreg == `m'
        local lbl: label (macroreg) `m'
        glo wid "V14_LIFESAT_MR`m'"
        glo wlb "Mean life satisfaction — `lbl'"
        glo wvl = string(r(mean), "%8.2f")
        wmd
    }

    * Feel worse off (v5: significantly worsened or slightly worsened) → Storyline: 35%
    gen worse = inlist(v5, 4, 5) if v5 < .  // v5: 4=Somewhat worsened, 5=Significantly worsened → 34.7% → Storyline 35%
    su worse [aw=hhw]
    glo wid "V14_WORSE_OFF"
    glo wlb "% feel worse off vs last month"
    glo wvl = string(r(mean)*100, "%8.2f")
    wmd
    drop worse

    * V9 worries — output mean score for each v9 item
    foreach v in v9a v9b v9c v9d v9e v9f v9g v9h v9i v9j v9k {
        su `v' [aw=hhw] if `v' < .
        glo wid "V14_`v'"
        glo wlb "Mean `v' score"
        glo wvl = string(r(mean), "%8.2f")
        wmd
    }
}


********************************************************************************
* CLOSE MARKDOWN FILE
********************************************************************************

file write md "" _n
file write md "---" _n
file write md "End of results. Compare with Python and R outputs." _n
file close md

cap erase "$out/_hhwt_temp.dta"

di _n(2) as res "Results written to: $res/storyline_results_stata.md"
di as res "DONE."
