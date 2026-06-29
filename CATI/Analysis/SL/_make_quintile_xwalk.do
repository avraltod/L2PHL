// =============================================================================
// Filename:      _make_quintile_xwalk.do
// Author:        Avralt-Od Purevjav
// Last Modified: Avraa
// Date:          2026-06-29
// =============================================================================
// One-time: re-key the baseline welfare quintile from the long PSGC hhid to the
// stage id (stg_id), which equals the CATI panel hhid. Output keyed by stg_id so
// the CATI masters can merge on hhid directly.

	clear all
	set more off
	version 18
	loc ow = c(os)
	if "`ow'" == "Windows"  glo root "D:/iDrive/GitHub/PHL/L2PHL"
	else                    glo root "/Users/avraa/iDrive/GitHub/PHL/L2PHL"
	glo QX  "$root/CAPI/Analysis/SL/data"
	glo PP  "$root/CAPI/Round00/dta/20251015/l2phl_20251015_M00_passport.dta"
	glo OUT "$root/CATI/Analysis/SL/data"
	cap mkdir "$OUT"

	* baseline quintile (long PSGC hhid) -> attach stg_id from the passport
	use hhid welfare_m5_q5 using "$QX/_quintiles_temp.dta", clear
	merge 1:1 hhid using "$PP", keep(match) keepusing(stg_id) nogen
	assert !missing(stg_id)
	drop hhid
	rename stg_id hhid                          // re-key to stg_id (= CATI hhid)
	drop if missing(hhid)
	isid hhid
	label var welfare_m5_q5 "Baseline welfare quintile (M5, 1=poorest)"
	save "$OUT/_quintiles_stgid.dta", replace
	di as result "wrote $OUT/_quintiles_stgid.dta (N=" _N ")"
