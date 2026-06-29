// =============================================================================
// Filename:      l2phl_storyline_series.do
// Author:        Avralt-Od Purevjav
// Last Modified: Avraa
// Date:          2026-06-29
// =============================================================================
// L2Phl CATI storyline — emit R1–R8 chart series (overall + by breakdown) to
// sl_series.json for the topic pages. Slice 1: food insecurity + any shock.

	clear all
	set more off
	set excelxlsxlargefile on
	cap set processors 4                         // MP only — harmless on SE/IC
	version 18

	* --- OS-detection / project root ---
	loc ow = c(os)
	if "`ow'" == "Windows"  glo root "D:/iDrive/GitHub/PHL/L2PHL"
	else                    glo root "/Users/avraa/iDrive/GitHub/PHL/L2PHL"   // MacOSX / Unix
	glo wd  "$root/CATI/Analysis/SL"
	glo HF  "$root/CATI/Analysis/HF"            // pooled HF masters
	glo QXI "$wd/data/_quintiles_stgid.dta"     // baseline welfare quintile re-keyed to stg_id
	cd "$wd"

	* --- date stamp ---
	glo YY = substr(c(current_date),8,4)
	glo MM = substr(c(current_date),4,3)
	glo DD = substr(c(current_date),1,2)
	glo date "${YY}${MM}${DD}"

	* --- emitter primitives + the series helper ---
	include "$wd/_stat_emit.do"
	include "$wd/_series_emit.do"

	stat_open "$wd/sl_series.json"

	***************************************************************************
	**# 1. Food security (FIES, M08) — mod_sev on the 5 core items, all rounds
	***************************************************************************
	use "$HF/l2phl_M08_food_nonfood.dta", clear
	* recode FIES items 1(yes)→1, 2(no)→0 (missing if not asked)
	foreach v of varlist f08_a f08_b f08_c f08_d f08_e {
		gen byte `v'_b = (`v'==1) if inlist(`v',1,2)
	}
	egen fies_score = rowtotal(f08_a_b f08_b_b f08_c_b f08_d_b f08_e_b)
	egen _nm = rownonmiss(f08_a_b f08_b_b f08_c_b f08_d_b f08_e_b)
	gen byte mod_sev = (fies_score >= 3) if _nm > 0        // moderate-to-severe; drop not-asked
	svyset psu [pweight=hhw], strata(stratum)
	do "$wd/_breakdowns.do"
	series_emit food_insecurity mod_sev, round(round) ///
		label("Moderate-to-severe food insecurity") unit("pct") ///
		quintile(inc_q) region(reg4) urbrur(urbrur)

	***************************************************************************
	**# 2. Shocks (M03) — any shock reported (sh1==1), all rounds
	***************************************************************************
	use "$HF/l2phl_M03_shock.dta", clear
	gen byte any_shock = (sh1==1) if inlist(sh1,1,2)
	svyset psu [pweight=hhw], strata(stratum)
	do "$wd/_breakdowns.do"
	series_emit any_shock any_shock, round(round) ///
		label("Households reporting any shock") unit("pct") ///
		quintile(inc_q) region(reg4) urbrur(urbrur)

	***************************************************************************
	**# 3. Digital finance (M06) — mobile-money & formal-bank account, R5–R8
	***************************************************************************
	use "$HF/l2phl_M06_finance.dta", clear
	gen byte mobile_money = (f18==1) if inlist(f18,1,2)        // has mobile-money account
	gen byte bank_account = (f17==1) if inlist(f17,1,2)        // has formal bank account
	svyset psu [pweight=hhw], strata(stratum)
	do "$wd/_breakdowns.do"
	series_emit mobile_money mobile_money, round(round) ///
		label("Has a mobile-money account") unit("pct") ///
		quintile(inc_q) region(reg4) urbrur(urbrur)
	series_emit bank_account bank_account, round(round) ///
		label("Has a formal bank account") unit("pct") ///
		quintile(inc_q) region(reg4) urbrur(urbrur)

	***************************************************************************
	**# 4. Work without security (M04) — no written contract, R1–R8 (indw)
	***************************************************************************
	use "$HF/l2phl_M04_employment.dta", clear
	gen byte no_contract = (a16==3) if inlist(a16,1,2,3)      // 3 = no written contract (among asked)
	svyset psu [pweight=indw], strata(stratum)
	do "$wd/_breakdowns.do"
	series_emit no_contract no_contract, round(round) ///
		label("Workers with no written contract") unit("pct") ///
		quintile(inc_q) region(reg4) urbrur(urbrur)

	stat_close
	di as result "storyline series written: $wd/sl_series.json"
