// =============================================================================
// Filename:      _breakdowns.do
// Author:        Avralt-Od Purevjav
// Last Modified: Avraa
// Date:          2026-06-29
// =============================================================================
// Build storyline breakdown vars on the dataset in memory (needs hhid, region,
// urban): inc_q (baseline welfare quintile, merged), reg4 (macro-region), urbrur.
// inc_q merges on hhid == stg_id via _quintiles_stgid.dta (built by
// _make_quintile_xwalk.do); $QXI must point at that file.

	version 18

	* --- urban / rural (master coding 1=urban, 2=rural) ---
	cap drop urbrur
	gen byte urbrur = urban
	label define urbrur_lbl 1 "Urban" 2 "Rural", replace
	label values urbrur urbrur_lbl

	* --- macro-region (1=NCR 2=Luzon 3=Visayas 4=Mindanao; see stata-conventions) ---
	cap drop reg4
	gen byte reg4 = .
	replace reg4 = 1 if inrange(region,101,105)                 // NCR districts
	replace reg4 = 2 if inlist(region,1,2,3,4,5,14,17)          // Luzon ex-NCR (+CAR, MIMAROPA)
	replace reg4 = 3 if inlist(region,6,7,8,18)                 // Visayas (+NIR)
	replace reg4 = 4 if inlist(region,9,10,11,12,16,19)         // Mindanao (+Caraga, BARMM)
	label define reg4_lbl 1 "NCR" 2 "Luzon" 3 "Visayas" 4 "Mindanao", replace
	label values reg4 reg4_lbl
	assert !missing(reg4)                                       // every region code mapped

	* --- baseline welfare quintile (merge on hhid; graceful if crosswalk absent) ---
	glo HAS_INCQ = 0
	cap confirm file "$QXI"
	if _rc == 0 {
		merge m:1 hhid using "$QXI", ///
			keep(master match) keepusing(welfare_m5_q5) nogen
		cap drop inc_q
		gen byte inc_q = welfare_m5_q5
		label define incq_lbl 1 "Q1 (poorest)" 2 "Q2" 3 "Q3" 4 "Q4" 5 "Q5 (richest)", replace
		label values inc_q incq_lbl
		qui count if !missing(inc_q)
		if r(N) > 0 glo HAS_INCQ = 1
		di as result "breakdowns: inc_q matched for `r(N)' rows (HAS_INCQ=$HAS_INCQ)"
	}
	else {
		cap drop inc_q
		gen byte inc_q = .
		di as error "breakdowns: $QXI not found — inc_q skipped"
	}
