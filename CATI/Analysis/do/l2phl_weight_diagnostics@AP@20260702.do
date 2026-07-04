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

	* (no external ssc deps -- putexcel/export excel are Stata built-ins)

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

	// FIXED baseline income quintile: one row per hhid, xtile, merge back.
	// pcinc_imp_mean is the baseline panel per-capita income (constant per
	// hhid across rounds), so taking the first observed round is intentional
	// and quintile membership is fixed across the panel.
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

**# Table 7: attr_retention -- panel retention by round (R1 cohort)
	use "$hf/l2phl_cati_household.dta", clear

	// R1 cohort = set of hhids present at round 1
	preserve
		keep if round==1
		keep hhid
		duplicates drop
		gen byte in_r1 = 1
		tempfile r1set
		save "`r1set'"
	restore
	merge m:1 hhid using "`r1set'", keep(master match) nogen
	replace in_r1 = 0 if missing(in_r1)

	qui count if round==1
	scalar _n_r1 = r(N)          // 1239 baseline denominator

	putexcel set "$xlsx", sheet("attr_retention") modify
	putexcel A1="round" B1="n_present" C1="n_r1cohort_present" ///
			 D1="pct_r1_retained" E1="n_new_since_r1"

	loc row = 2
	forval rd = 1/8 {
		qui count if round==`rd'
		loc np = r(N)
		qui count if round==`rd' & in_r1==1
		loc nr1 = r(N)
		loc pct = 100*`nr1'/_n_r1
		loc nnew = `np' - `nr1'
		putexcel A`row'=`rd' B`row'=`np' C`row'=`nr1' ///
				 D`row'=`pct' E`row'=`nnew'
		loc ++row
	}
	di as res "attr_retention written."

**# Table 8: attr_bias -- stayers vs attriters, R1 baseline characteristics
	// stayer = R1-cohort HH also present at R8; attriter = R1 HH not in R8.
	// All characteristics measured at R1.

	// significance/verdict helper
	cap program drop _sigv
	program define _sigv
		args p
		loc sig "ns"
		if `p'<.10 loc sig "*"
		if `p'<.05 loc sig "**"
		if `p'<.01 loc sig "***"
		c_local sig  "`sig'"
		c_local verd = cond(`p'<.05,"differs","similar")
	end

	// R8 set (stayer membership)
	use "$hf/l2phl_cati_household.dta", clear
	keep if round==8
	keep hhid
	duplicates drop
	gen byte in_r8 = 1
	tempfile r8set
	save "`r8set'"

	// head sex at R1 (roster fmid==1; gender 1=male, 2=female)
	use "$hf/l2phl_M01_roster.dta", clear
	keep if fmid==1 & round==1
	gen byte head_female = (gender==2) if !missing(gender)
	keep hhid head_female
	tempfile hf1
	save "`hf1'"

	// employment at R1: HH-level "any working respondent" (isfmid==1, a1==1).
	// isfmid==1 is multi-row per HH, so aggregate to a per-HH binary; defined
	// only for HHs with >=1 non-missing a1.
	use "$hf/l2phl_M04_employment.dta", clear
	keep if isfmid==1 & round==1
	gen byte _wk = (a1==1) if !missing(a1)
	collapse (max) emp_any=_wk (count) n_a1=_wk, by(hhid)
	replace emp_any = . if n_a1==0
	keep hhid emp_any
	tempfile emp1
	save "`emp1'"

	// R1 HH analysis file
	use "$hf/l2phl_cati_household.dta", clear
	keep if round==1
	isid hhid

	// urban recode to 0/1 (rural=0, urban=1) if coded 1/2
	qui summ urban
	if r(min)==1 & r(max)==2 	replace urban = 2 - urban

	// FIES moderate-or-severe at R1: count of affirmative (==1) among f08_a-e
	gen byte fies_score  = (f08_a==1)+(f08_b==1)+(f08_c==1)+(f08_d==1)+(f08_e==1)
	gen byte fies_modsev = (fies_score>=3)

	// fixed baseline income quintile (pcinc_imp_mean constant per hhid)
	xtile incq = pcinc_imp_mean [pweight=hhw], nq(5)

	// stayer flag
	merge m:1 hhid using "`r8set'", keep(master match) nogen
	replace in_r8 = 0 if missing(in_r8)
	gen byte stayer = in_r8

	// merge head sex + employment
	merge 1:1 hhid using "`hf1'",  keep(master match) nogen
	merge 1:1 hhid using "`emp1'", keep(master match) nogen

	qui count if stayer==1
	di as txt "stayers (R1&R8) = " r(N)
	qui count if stayer==0
	di as txt "attriters (R1 only) = " r(N)

	putexcel set "$xlsx", sheet("attr_bias") modify
	putexcel A1="characteristic" B1="stayer" C1="attriter" D1="difference" ///
			 E1="test" F1="stat" G1="p_value" H1="sig" I1="verdict"

	loc row = 2
	loc anydiff = 0

	// ---- binary characteristics: % in each group, chi2 test ----
	// name  variable
	foreach pair in "urban urban" "head_female head_female" ///
					"employed emp_any" "fies_modsev fies_modsev" {
		gettoken cname pair : pair
		gettoken cvar  pair : pair
		cap {
			qui summ `cvar' if stayer==1
			loc s = r(mean)*100
			qui summ `cvar' if stayer==0
			loc a = r(mean)*100
			loc d = `s' - `a'
			qui tab `cvar' stayer, chi2
			loc st = r(chi2)
			loc p  = r(p)
		}
		if _rc | missing(`p') {
			putexcel A`row'="`cname'" E`row'="chi2" I`row'="n/a"
		}
		else {
			_sigv `p'
			if `p'<.05 loc anydiff = 1
			putexcel A`row'="`cname'" B`row'=`s' C`row'=`a' D`row'=`d' ///
					 E`row'="chi2" F`row'=`st' G`row'=`p' H`row'="`sig'" ///
					 I`row'="`verd'"
		}
		loc ++row
	}

	// ---- continuous characteristics: means, t-test ----
	// name  variable
	foreach pair in "hhsize hhsize" "inc_quintile incq" {
		gettoken cname pair : pair
		gettoken cvar  pair : pair
		cap {
			qui ttest `cvar', by(stayer)
			loc a  = r(mu_1)          // stayer==0 (attriter)
			loc s  = r(mu_2)          // stayer==1 (stayer)
			loc d  = `s' - `a'
			loc st = r(t)
			loc p  = r(p)
		}
		if _rc | missing(`p') {
			putexcel A`row'="`cname'" E`row'="ttest" I`row'="n/a"
		}
		else {
			_sigv `p'
			if `p'<.05 loc anydiff = 1
			putexcel A`row'="`cname'" B`row'=`s' C`row'=`a' D`row'=`d' ///
					 E`row'="ttest" F`row'=`st' G`row'=`p' H`row'="`sig'" ///
					 I`row'="`verd'"
		}
		loc ++row
	}

	// ---- geographic composition: chi2 across strata ----
	// region is ~99.5% missing in the CATI household file, so stratum (1-39,
	// complete) -- which embeds region -- is used as the geographic composition
	// variable. Cells hold the count of distinct strata per group.
	cap {
		qui tab stratum stayer, chi2
		loc st = r(chi2)
		loc p  = r(p)
		qui levelsof stratum if stayer==1, local(_ls)
		loc ns : word count `_ls'
		qui levelsof stratum if stayer==0, local(_la)
		loc na : word count `_la'
	}
	if _rc | missing(`p') {
		putexcel A`row'="region(via stratum)" E`row'="chi2" I`row'="n/a"
	}
	else {
		_sigv `p'
		if `p'<.05 loc anydiff = 1
		putexcel A`row'="region(via stratum)" B`row'="`ns' strata" ///
				 C`row'="`na' strata" E`row'="chi2" F`row'=`st' ///
				 G`row'=`p' H`row'="`sig'" I`row'="`verd'"
	}
	loc ++row

	// ---- overall verdict ----
	loc overall = cond(`anydiff'==1,"BIASED","OK")
	putexcel A`row'="OVERALL" I`row'="`overall'"
	di as res "attr_bias written (anydiff=`anydiff')."

	di as res _n "ALL TABLES WRITTEN: $xlsx"
