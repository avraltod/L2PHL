// ============================================================================
// Filename:       l2phl_weight_diagnostics@AP@20260702.do
// Author:         Avralt-Od Purevjav
// Last Modified:  Avraa
// Date:           2026-07-02
// ----------------------------------------------------------------------------
// L2PHL survey weights - performance & diagnostics for the technical note.
// Reads CAPI baseline final_weights + CATI pooled per-round masters; computes
// distribution, DEFF_w, ESS/Kish-ESS, calibration residuals, calibration
// effect, and CATI round trajectory + attrition composition. Writes one
// results workbook (one sheet per table).
// ============================================================================

	version 18
	clear all
	set more off
	set excelxlsxlargefile on

	loc ow = c(os)
	if "`ow'"=="MacOSX" | "`ow'"=="Unix" 	glo wd "/Users/avraa/iDrive/GitHub/PHL/L2PHL"
	if "`ow'"=="Windows" 					glo wd "D:/iDrive/GitHub/PHL/L2PHL"
	cd "$wd"

	glo hf  "$wd/CATI/Analysis/HF"
	glo out "$wd/CATI/Analysis/do/output"
	cap mkdir "$out"
	glo xlsx "$out/weight_diagnostics_results.xlsx"

	qui foreach prog in putexcel {
		cap which `prog'
		if _rc ssc install `prog', replace all
	}

**# Reusable diagnostic program
cap program drop wdiag
program define wdiag, rclass
	syntax varname [if]
	marksample touse
	qui summ `varlist' if `touse', detail
	scalar _N_=r(N)
	scalar _mn=r(mean)
	scalar _med=r(p50)
	scalar _mi=r(min)
	scalar _ma=r(max)
	scalar _sd=r(sd)
	scalar _cv=_sd/_mn
	scalar _deff=1+_cv^2
	scalar _ess=_N_/_deff
	qui {
		tempvar w w2
		gen double `w'  = `varlist' if `touse'
		gen double `w2' = `varlist'^2 if `touse'
		summ `w', meanonly
		scalar _sw=r(sum)
		summ `w2', meanonly
		scalar _sw2=r(sum)
	}
	scalar _kish=(_sw^2)/_sw2
	return scalar N=_N_
	return scalar mean=_mn
	return scalar median=_med
	return scalar min=_mi
	return scalar max=_ma
	return scalar cv=_cv
	return scalar ratio=_ma/_mi
	return scalar deff=_deff
	return scalar ess=_ess
	return scalar kish=_kish
end

// helper: pull the 10 wdiag returns into locals N mn med mi ma cv rat df ess kish
cap program drop _grab
program define _grab
	c_local N   = r(N)
	c_local mn  = r(mean)
	c_local med = r(median)
	c_local mi  = r(min)
	c_local ma  = r(max)
	c_local cv  = r(cv)
	c_local rat = r(ratio)
	c_local df  = r(deff)
	c_local ess = r(ess)
	c_local kish= r(kish)
end

**# Table 1: capi_dist -- CAPI weight distribution
	use "$hf/R00/final_weights.dta", clear
	isid hhid fmid
	di as txt "CAPI final_weights loaded: " _N " person rows"

	putexcel set "$xlsx", sheet("capi_dist") replace
	putexcel A1="weight" B1="N" C1="mean" D1="median" E1="min" ///
			 F1="max" G1="CV" H1="max_min" I1="DEFFw" J1="ESS" K1="KishESS"

	loc row = 2
	// indw over all persons; popw/hhw over HH-tagged rows only
	foreach spec in indw popw hhw {
		if "`spec'"=="indw" 	wdiag indw
		else 					wdiag `spec' if tag_hh
		_grab
		putexcel A`row'="`spec'" B`row'=`N' C`row'=`mn' D`row'=`med' ///
				 E`row'=`mi' F`row'=`ma' G`row'=`cv' H`row'=`rat' ///
				 I`row'=`df' J`row'=`ess' K`row'=`kish'
		loc ++row
	}
	di as res "capi_dist written."

**# Table 2: capi_calib -- calibration residuals vs census, by stratum
	use "$hf/R00/final_weights.dta", clear
	preserve
		gen double _hhw_hhtag = hhw*tag_hh
		collapse (sum) sum_indw=indw sum_hhw=_hhw_hhtag ///
				 (mean) pop_census_s hh_census_s, by(stratum)
		gen double resid_pop = sum_indw - pop_census_s
		gen double resid_hh  = sum_hhw  - hh_census_s
		order stratum sum_indw pop_census_s resid_pop sum_hhw hh_census_s resid_hh

		// self-checks: weights must reconcile to census at the stratum level
		assert abs(resid_pop) < 1 + 0.001*pop_census_s
		assert abs(resid_hh)  < 1 + 0.001*hh_census_s
		di as res "capi_calib asserts PASSED for all " _N " strata."

		gen double _apop = abs(resid_pop)
		gen double _ahh  = abs(resid_hh)
		summ _apop, meanonly
		di as txt "max |resid_pop| = " r(max)
		summ _ahh, meanonly
		di as txt "max |resid_hh|  = " r(max)
		drop _apop _ahh

		export excel stratum sum_indw pop_census_s resid_pop sum_hhw ///
			hh_census_s resid_hh using "$xlsx", ///
			sheet("capi_calib") sheetreplace firstrow(variables)
	restore
	di as res "capi_calib written."

**# Table 3: capi_caleffect -- calibration effect (design vs final)
	use "$hf/R00/final_weights.dta", clear
	putexcel set "$xlsx", sheet("capi_caleffect") modify
	putexcel A1="weight" B1="stage" C1="CV" D1="DEFFw" E1="ESS"

	loc row = 2
	foreach w in indw popw hhw {
		if "`w'"=="indw" 	loc cond ""
		else 				loc cond "if tag_hh"
		foreach stage in design final {
			if "`stage'"=="design" 	loc wv "`w'_design"
			else 					loc wv "`w'"
			wdiag `wv' `cond'
			_grab
			putexcel A`row'="`w'" B`row'="`stage'" C`row'=`cv' D`row'=`df' E`row'=`ess'
			loc ++row
		}
	}
	di as res "capi_caleffect written."

**# Table 4: cati_indw -- CATI indw by round (person-level)
	use "$hf/l2phl_cati_individual.dta", clear
	assert !missing(indw)
	putexcel set "$xlsx", sheet("cati_indw") modify
	putexcel A1="round" B1="N" C1="CV" D1="DEFFw" E1="ESS" F1="KishESS" G1="sum_indw"

	loc row = 2
	forval rd = 1/8 {
		qui count if round==`rd'
		if r(N)==0 continue
		wdiag indw if round==`rd'
		_grab
		qui summ indw if round==`rd', meanonly
		loc sw = r(sum)
		putexcel A`row'=`rd' B`row'=`N' C`row'=`cv' D`row'=`df' ///
				 E`row'=`ess' F`row'=`kish' G`row'=`sw'
		loc ++row
	}
	di as res "cati_indw written."

**# Table 5: cati_hhw -- CATI hhw & popw by round (HH-level)
	use "$hf/l2phl_cati_household.dta", clear
	assert !missing(hhw)
	putexcel set "$xlsx", sheet("cati_hhw") modify
	putexcel A1="round" B1="N_hh" C1="CV_hhw" D1="DEFFw_hhw" ///
			 E1="ESS_hhw" F1="CV_popw" G1="ESS_popw"

	loc row = 2
	forval rd = 1/8 {
		qui count if round==`rd'
		if r(N)==0 continue
		wdiag hhw if round==`rd'
		loc nhh  = r(N)
		loc cvh  = r(cv)
		loc dfh  = r(deff)
		loc essh = r(ess)
		wdiag popw if round==`rd'
		loc cvp  = r(cv)
		loc essp = r(ess)
		putexcel A`row'=`rd' B`row'=`nhh' C`row'=`cvh' D`row'=`dfh' ///
				 E`row'=`essh' F`row'=`cvp' G`row'=`essp'
		loc ++row
	}
	di as res "cati_hhw written."

**# Table 6: cati_attrition -- CATI weighted composition by round
	use "$hf/l2phl_cati_household.dta", clear

	// urban recode to 0/1 (rural=0, urban=1) if coded 1/2
	qui summ urban
	if r(min)==1 & r(max)==2 {
		replace urban = 2 - urban   // 1->1 (urban), 2->0 (rural)
	}

	// FIXED baseline income quintile: one row per hhid, xtile, merge back
	preserve
		bys hhid (round): keep if _n==1
		xtile incq = pcinc_imp_mean [pweight=hhw], nq(5)
		keep hhid incq
		tempfile qfile
		save "`qfile'"
	restore
	merge m:1 hhid using "`qfile'", assert(match) nogen

	gen byte _q1 = (incq==1)
	gen byte _q5 = (incq==5)

	di as txt "NOTE: region-level composition intentionally deferred pending region-code cleanup (BARMM sub-strata 101-105)."

	putexcel set "$xlsx", sheet("cati_attrition") modify
	putexcel A1="round" B1="n_hh" C1="urban_share" D1="q1_share" E1="q5_share"

	loc row = 2
	forval rd = 1/8 {
		qui count if round==`rd'
		if r(N)==0 continue
		loc nhh = r(N)
		qui summ urban [aw=hhw] if round==`rd'
		loc ush = r(mean)
		qui summ _q1 [aw=hhw] if round==`rd'
		loc q1 = r(mean)
		qui summ _q5 [aw=hhw] if round==`rd'
		loc q5 = r(mean)
		putexcel A`row'=`rd' B`row'=`nhh' C`row'=`ush' D`row'=`q1' E`row'=`q5'
		loc ++row
	}
	di as res "cati_attrition written."

	di as res _n "ALL TABLES WRITTEN: $xlsx"
