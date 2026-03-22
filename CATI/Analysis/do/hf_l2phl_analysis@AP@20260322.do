//Analyze HF data of L2PHL
//created by Avralt-Od Purevjav
//modified on Mar 22, 2026
// Changes vs @20260320: added Section 4 – module cleanup & reorder.
//   Each pooled M00–M09 file is stripped of admin/processing variables
//   and its columns are put in questionnaire order so the panel structure
//   is consistent across modules and rounds.

	//Preamble
		clear all
		set more off
		set excelxlsxlargefile on
// 		set processors 4 //8

	//Set file location
		*loc ws "Work" //Home //Server

		loc ow = c(os)
		di "`ow'"
		if ( "`ow'"=="Windows" )  ///
			glo root "C:\Users\wb463427\OneDrive - WBG\ECAPOV\L2Ss\L2Ukr\CATI"
		if ( "`ow'"=="MacOSX" )  ///
			glo root "~/iDrive/GitHub/PHL/L2PHL"   // updated: moved from Google Drive to GitHub folder

// 		-- Previous root paths (kept for reference) --
// 		if ( "`ow'"=="MacOSX" )  ///
// 			glo root "~/Library/CloudStorage/GoogleDrive-avraltod@gmail.com/My Drive/L2PHL"  // old: Google Drive
// 		if ( "`ow'"=="MacOSX" )  ///
// 			glo root "~/iDrive/Dropbox/WB/L2Ukr/CATI"  // old: Dropbox

		glo hf "$root/CATI/Analysis/HF"
// 		glo baseline "$root/Analysis/Baseline"
// 		glo weight "$root/Analysis/Weights"
// 		glo out "$root/Analysis/Reporting"
// 		glo pool "$root/Pool"


// 		cd "$out"

		glo date 20260319	// change date each time you run the code
		glo LNG ENG  //change language of the data set: ENG RUS UKR
		glo RDATES "20251125 20251228 20260128 20260228 $date "

	//Locals

		glo R=5  // change it in each round
		loc file l2phl_hf_result_${date}



	// =========================================================================
	// SECTION 1: Move round files into HF/R*/
	// =========================================================================

	//moving the files into input folder
		foreach r of numlist 1/$R {
			loc r : di %02.0f `r'
			di "`r'"
			loc d: word `r' of $RDATES

			//deleting files in the folder
			local dtafiles : dir "${hf}/R`r'" files "*.dta"
			foreach file in `dtafiles' {
				di 	"`file'"
					cap erase "${hf}/R`r'/`file'"
			}

			//moving the files into input folder
			local dtafiles : dir "$root/CATI/Round`r'/dta/`d'" files "*.dta"
			foreach file in `dtafiles' {
				di 	"`file'"
				cap erase "${hf}/R`r'/`file'"
					copy  "$root/CATI/Round`r'/dta/`d'/`file'" ///
						"${hf}/R`r'/`file'", replace
			}

		}

	// =========================================================================
	// SECTION 2: Build panel weights
	// =========================================================================

	//Open baseline weight file
		use "$hf/R00/final_weights.dta", clear
			merge m:1 hhid using "$hf/R00/l2phl_20251015_M00_passport.dta", ///
				assert(3) nogen keepusing(stg_id)

			tab region [iw = popw] if tag_hh
			tab region [iw = hhw] if tag_hh
			tab region [iw = indw]
// 			keep hhid hhw popw

		clonevar stratum_pop = pop_census_s
		clonevar stratum_nhh = hh_census_s

	foreach v of varlist indw popw hhw indw_design popw_design hhw_design {
		cap drop sd_w
		bys stratum age_grp gender: egen sd_w = sd(`v')
		replace sd_w = round(sd_w)
		di in red "					`v' by stratum age_grp gender"
		summ sd_w

		cap drop sd_w
		bys stratum: egen sd_w = sd(`v')
		replace sd_w = round(sd_w)
		di in red "					`v' by stratum "
		summ sd_w

		cap drop sd_w
		bys psu : egen sd_w = sd(`v')
		replace sd_w = round(sd_w)
		di in red "					`v' by psu "
		summ sd_w

		drop sd_w

	}

// 		bys stratum (psu hhid): egen stratum_pop = total(popw)
// 		bys stratum (psu hhid): egen stratum_nhh = total(hhw)

		isid hhid fmid
		isid stg_id fmid
			drop hhid
				ren stg_id hhid

		tempfile indw
		save `indw' , replace

			keep if tag_hh

		tempfile hhw
		save `hhw' , replace

		use `indw', clear

			cap drop sd_w
			bys stratum age_grp gender: egen sd_w = sd(indw)
			replace sd_w = round(sd_w)
			di in red "					`v' by stratum age_grp gender"
			summ sd_w

			bys stratum age_grp gender (hhid fmid): keep if _n == _N

			isid stratum age_grp gender

		tempfile cell
		save `cell', replace

	//Merge with baseline
		//refusal/unable to participate in round 1
		clear
			g round = .
		//appending all rounds
		foreach r of numlist 1/$R {
			loc R : di %02.0f `r'
				di "`r' and `R'"
					loc d: word `r' of $RDATES
						di "`d'"

			append using "$hf/R`R'/l2phl_`d'_M01_roster.dta", force
				replace round = `r' if round == .
		}

		keep round hhid fmid hhsize age gender isfmid

		* gender
		tab gender
		as gender ~= .

		* age group
		su age
		as age ~= .
		as age >= 0

		g age_grp = .
		replace age_grp = 1 if age >=0 & age <= 17
		replace age_grp = 2 if age >= 18 & age <= 45
		replace age_grp = 3 if age >= 46 & age < .
// 		replace age_grp = 4 if age >= 66 & age < .
		la def AGEGRP 1 "0-17" 2 "18-45" 3 "46+" , replace
		la val age_grp AGEGRP


			merge m:1 hhid using `hhw', ///
				assert(2 3) keep(3) nogen keepusing(stratum psu region urban) update

					table (stratum) (age_grp gender) (round)

			merge m:1 stratum age_grp gender using `cell' ///
				, assert(3) nogen keepusing(indw *census* pop_cell ) update

				ren indw indw_base

			table (stratum) (age_grp gender) (round), stat(sum indw_base) nototals

			merge m:1 stratum age_grp gender using `cell' ///
				, assert(3) nogen keepusing(indw *census* pop_cell ) update

				ren indw indw_base

			table (stratum) (age_grp gender) (round), stat(sum indw_base) nototals

			egen tag_cell = tag(round stratum gender age_grp)

			table (stratum) (age_grp gender) (round) if tag_cell , stat(sum pop_cell) nototals

			bys round stratum gender age_grp : egen tot_indw = sum(indw_base)

			g indw = indw_base * (pop_cell/tot_indw)
			la var indw "Individual weight (Individual-level data)"

			table (stratum) (age_grp gender) (round), stat(sum indw)

			table (stratum) (round), stat(sum indw)

			bys round hhid (fmid): egen popw = sum(indw)
			la var popw "Population weight (Household-level data)"

			bys round hhid (fmid): egen hhw = mean(indw)
			la var hhw "Household weight (Household-level data)"

			bys round psu (hhid fmid): egen ave_hhw = mean(hhw)
			la var ave_hhw "Smoothed Household weight (Household-level data)"

			replace hhw = ave_hhw
				drop ave_hhw

			cap drop tag_hh
			egen tag_hh = tag(hhid round)

			table (stratum) (round) if tag_hh, stat(sum hhw)

			bys round stratum (psu hhid fmid)  : egen tot_hhw_s = sum( hhw*tag_hh )
			replace hhw = hhw * (hh_census_s/tot_hhw_s)

			table (stratum) (round) if tag_hh , stat(sum hhw)

		preserve
			keep round hhid fmid age age_grp gender region urban stratum psu indw

			save "$hf/l2phl_cati_indw.dta", replace
		restore

			isid round hhid fmid
			bys round hhid (fmid): keep if _n == _N
			isid round hhid fmid

			keep round hhid fmid age age_grp gender region urban stratum psu popw hhw
			save "$hf/l2phl_cati_hhw.dta", replace


	// =========================================================================
	// SECTION 3: Pool rounds for each module
	// =========================================================================

	//Merging rounds — HH-level modules
	foreach ss in 	M00_passport ///
					M03_shock ///
					M06_finance ///
					M08_food_nonfood ///
					M09_views ///
					HH_Level_Data ///
					{
		clear all
		cap drop round
		g round = .

		foreach r of numlist 1/$R {
			loc r : di %02.0f `r'

			di "`ss'-`r'"

			local dt: word `r' of $RDATES
			cap append using  "${hf}/R`r'/l2phl_`dt'_`ss'.dta" , force

			replace round = `r' if round == .
				tab round
		}

		merge 1:1 round hhid using "$hf/l2phl_cati_hhw.dta" ///
			, assert(1 3) keep(3) nogen

	save "${hf}/l2phl_`ss'.dta", replace

	}

	//Merging rounds — Individual-level modules
	foreach ss in 	M01_roster ///
					M02_education ///
					M04_employment ///
					M05_income ///
					M07_health ///
					Roster_Level_Data ///
					{
		clear all
		cap drop round
		g round = .

		foreach r of numlist 1/$R {
			loc r : di %02.0f `r'

			di "`ss'-`r'"

			local dt: word `r' of $RDATES
			cap append using  "${hf}/R`r'/l2phl_`dt'_`ss'.dta" , force

			replace round = `r' if round == .
				tab round
		}

		merge 1:1 round hhid fmid using "$hf/l2phl_cati_indw.dta" ///
			, assert(1 2 3) keep(3) nogen

	save "${hf}/l2phl_`ss'.dta", replace

	}


	// =========================================================================
	// SECTION 4: Clean and reorder pooled module files
	// -------------------------------------------------------------------------
	// For each module:
	//   • drop admin/processing vars (dur_*, excess_int, computed totals, etc.)
	//   • drop duplicate geo/demographic vars that come from the weight merge
	//     but are redundant for HH-level modules (fmid, age, gender, age_grp)
	//   • enforce a consistent column order:
	//       HH-level  : hhid round | stratum psu region urban popw hhw | [Q vars]
	//       Ind-level : hhid round fmid | stratum psu region urban age age_grp gender indw | [Q vars]
	// Variable order within [Q vars] follows questionnaire section order.
	//
	// NOTE: hhw/indw files are still live here (erased in Section 5).
	// =========================================================================

	// ── M00 Passport ─────────────────────────────────────────────────────────
	// HH-level. fmid kept (= respondent ID). Province/city/barangay/locale kept
	// as questionnaire geographic descriptors alongside stratum/psu/region/urban.

	use "${hf}/l2phl_M00_passport.dta", clear

		// drop duration timers, system vars, round-tracking, and computed vars
		cap drop x15 dur_pp dur_rr dur_educ dur_sh dur_emp dur_inc dur_fin ///
		         dur_hlt dur_f_nf dur_vw dur_tot
		cap drop subm_date date_str subm_time time_str int_id round_lastint excess_int
		// drop person-level vars added by hhw merge (these belong in M01)
		cap drop age gender age_grp

		order hhid round stratum psu region urban popw hhw ///
		      call_attemp call_status1 correct_resp agreement ///
		      refusal_reason refusal_reason_oth interview_record ///
		      address_unchanged new_address_str province city barangay locale hhsize ///
		      survey_lang date_of_interview time_of_interview ///
		      start_date end_date start_time end_time call_result fmid sample

	compress
	save "${hf}/l2phl_M00_passport.dta", replace


	// ── M01 Roster ───────────────────────────────────────────────────────────
	// Individual-level. age/gender/hhsize come from the questionnaire itself
	// (not the weight merge), so they stay with the other questionnaire vars.
	// age_grp, stratum, psu, region, urban, indw come from the indw merge.

	use "${hf}/l2phl_M01_roster.dta", clear

		cap drop isfmid dur_rr trailer_tag excess_int

		order hhid round fmid stratum psu region urban age_grp indw ///
		      fmidpermanent hhsize age gender relationship ///
		      member_leftreason member_leftreason_oth member_leftreason_other ///
		      moved_in_reason moved_in_reason_oth ///
		      country_moved prov_moved city_moved ///
		      country_migrated_from province_migrated_from city_migrated_from

	compress
	save "${hf}/l2phl_M01_roster.dta", replace


	// ── M02 Education ────────────────────────────────────────────────────────
	// Individual-level. Variables were renamed in HF processing:
	//   ed1–ed14 (questionnaire) → ed15, ed16 (HF data).

	use "${hf}/l2phl_M02_education.dta", clear

		cap drop dur_educ isfmid dur_emp hhsize excess_int

		order hhid round fmid stratum psu region urban age age_grp gender indw ///
		      ed15 ed16 ed16_oth ed16_1 ed16_2

	compress
	save "${hf}/l2phl_M02_education.dta", replace


	// ── M03 Shocks ───────────────────────────────────────────────────────────
	// HH-level. Combines Natural Hazards (NH* / EL5 / N5) and Shocks (SH*).
	// nh14–nh17 variants are processing artefacts (not in questionnaire).

	use "${hf}/l2phl_M03_shock.dta", clear

		cap drop dur_sh nh14_1 nh15_1 nh16_1 nh17_1_1 nh14_2 nh17_1_2 shocks_end excess_int
		// drop person-level vars added by hhw merge
		cap drop fmid age gender age_grp

		order hhid round stratum psu region urban popw hhw ///
		      el5 n5 ///
		      nh2_1 nh2_2 nh3_1_1 nh3_1_2 nh3_2_1 nh3_3_1 nh3_4_1 ///
		      nh7_1_1 nh7_1_2 nh7_2_1 nh7_2_2 nh7_3_1 nh7_4_1 nh7_5_1 nh7_oth_1 ///
		      nh10_1_1 nh10_1_2 nh10_2_1 nh10_3_1 nh10_4_1 nh10_5_1 nh10_6_1 nh10_oth_1 ///
		      sh1 sh1b sh1b_1 sh1b_2 sh1b_3 sh1b_4 ///
		      sh2_1 sh2_1_1 sh2_1_2 sh2_1_3 sh2_1_4 sh2_1_5 sh2_1_6 ///
		             sh2_1_7 sh2_1_8 sh2_1_9 sh2_1_oth ///
		      sh2_2 sh2_2_1 sh2_2_2 sh2_2_3 sh2_2_4 sh2_2_5 sh2_2_oth ///
		      sh2_3 sh2_3_1 sh2_3_2 sh2_3_3 sh2_3_oth ///
		      sh2_4_1 sh3 sh4 n1 n3 n3_1

	compress
	save "${hf}/l2phl_M03_shock.dta", replace


	// ── M04 Employment ───────────────────────────────────────────────────────
	// Individual-level. a24–a27, a25_old* are legacy/recoded vars not in questionnaire.
	// isfmid kept as it flags the primary respondent in the HH.

	use "${hf}/l2phl_M04_employment.dta", clear

		cap drop a24 a27 a25 a25_olda6 a25_olda8a9 a25_olda10 a25_olda11 a26 ///
		         trailer_tag dur_emp emp_status excess_int

		order hhid round fmid stratum psu region urban age age_grp gender indw ///
		      isfmid ///
		      a1 a3 a3_oth a4 a4_oth a5 a5_oth a6 a7 a8 a9 a10 a11 ///
		      a16 a17 a18 ///
		      a19 a19_1 a19_2 a19_3 a19_4 a19_5 a19_oth ///
		      a20 a21 a21_1 a21_2 a21_3 a21_oth a21_own a22 a23

	compress
	save "${hf}/l2phl_M04_employment.dta", replace


	// ── M05 Income ───────────────────────────────────────────────────────────
	// Individual-level. Computed income totals (total_*_income, regular_cash_earnings)
	// are dropped — derive from questionnaire vars if needed.

	use "${hf}/l2phl_M05_income.dta", clear

		cap drop isfmid n_ia3 trailer_tag dur_inc excess_int ///
		         regular_cash_income regular_inkind_income total_regular_income ///
		         season_cash_income season_inkind_income total_season_income ///
		         total_income regular_cash_earnings

		order hhid round fmid stratum psu region urban age age_grp gender indw ///
		      ia2 ia3_a ia3_b ia3_c ia3_d ia3_e ia3_f ///
		      ia5 ia6_a ia6_b ia6_c ia6_d ia6_e ia6_f ia7

	compress
	save "${hf}/l2phl_M05_income.dta", replace


	// ── M06 Finance ──────────────────────────────────────────────────────────
	// HH-level. f13–f18 not in questionnaire (HF processing artefacts).
	// f4/f5/f11/f12 are in questionnaire but absent from HF data (not collected).

	use "${hf}/l2phl_M06_finance.dta", clear

		cap drop n_f13 f13_a f13_b f14 f15 f16 f17 f18 dur_fin excess_int
		// drop person-level vars added by hhw merge
		cap drop fmid age gender age_grp

		order hhid round stratum psu region urban popw hhw ///
		      f1 f2 f3 f6 f7 ///
		      f8 f8_1 f8_2 f8_3 f8_4 f8_5 f8_6 f8_7 f8_oth ///
		      f9 f9_oth f10

	compress
	save "${hf}/l2phl_M06_finance.dta", replace


	// ── M07 Health ───────────────────────────────────────────────────────────
	// Conceptually HH-level (one row per HH per round; fmid = respondent).
	// Currently pooled in the individual-level loop → carries indw not popw/hhw.
	// Fix: drop individual vars; merge back HH-level weights from hhw file.

	use "${hf}/l2phl_M07_health.dta", clear

		cap drop dur_hlt name excess_int age age_grp
		// swap individual weight for HH-level weights
		cap drop fmid indw
		merge m:1 round hhid using "${hf}/l2phl_cati_hhw.dta" ///
			, assert(1 3) keep(3) nogen keepusing(popw hhw)

		order hhid round stratum psu region urban popw hhw ///
		      h2 h2a h3 h3_oth h4 h4_oth h7 h8 h8_amt ///
		      h9_1 h9_2 h9_3 h9a h9b h9c ///
		      h10_1 h10_2 h10_3 ///
		      h11a_1 h11a_2 h11a_3 ///
		      h11b_1__1 h11b_1__2 h11b_1__3 h11b_1__oth ///
		      h11b_2__1 h11b_2__2 h11b_2__3 h11b_2__oth ///
		      h11b_3__1 h11b_3__2 h11b_3__3 h11b_3__oth ///
		      h17 h12 h13 h13_oth h14 h15 h16 h16_1 h16_2 h16_3 h16_4 h16_5 h16_oth

	compress
	save "${hf}/l2phl_M07_health.dta", replace


	// ── M08 Food & Non-Food ───────────────────────────────────────────────────
	// HH-level. f08_a–f08_e are HF-restructured versions of
	// fo*/nf*/ssb* questionnaire vars.

	use "${hf}/l2phl_M08_food_nonfood.dta", clear

		cap drop dur_f_nf excess_int
		cap drop fmid age gender age_grp

		order hhid round stratum psu region urban popw hhw ///
		      f08_a f08_b f08_c f08_d f08_e

	compress
	save "${hf}/l2phl_M08_food_nonfood.dta", replace


	// ── M09 Opinions & Views ─────────────────────────────────────────────────
	// HH-level. v11/v12 are processing artefacts not in questionnaire.
	// v9_d absent from HF data (skip logic — not collected).

	use "${hf}/l2phl_M09_views.dta", clear

		cap drop v11 v12 dur_vw excess_int
		cap drop fmid age gender age_grp

		order hhid round stratum psu region urban popw hhw ///
		      v1 v5 ///
		      v9_a v9_b v9_c v9_e v9_f v9_g v9_i v9_j v9_k v9_l v9_m

	compress
	save "${hf}/l2phl_M09_views.dta", replace


	// =========================================================================
	// SECTION 5: Build household- and individual-level master datasets
	// =========================================================================

	use "${hf}/l2phl_HH_Level_Data.dta", clear

			gunique hhid round
				as `r(N)' == `r(unique)'

			merge 1:1 round hhid using "$hf/l2phl_cati_hhw.dta" ///
				, assert(1 3) keep(3) nogen

			g date = subm_date
			replace date = date_of_interview if date == .
			replace date = 24050 if date == . & round == 1
			su *date*

			cap drop year
			g year = year(date)

			cap drop quarter
			g quarter = quarter(date)

			cap drop qofd
			g qofd =qofd(date)
				format qofd %tq_CCYY_!Qq

			cap drop month
			g month = month(date)

			cap drop mofd
			g mofd = mofd(date)
				format mofd %tm_CCYY!mNN

	save "${hf}/l2phl_cati_household.dta", replace

	use "${hf}/l2phl_Roster_Level_Data.dta", clear

			gunique hhid round fmid
				as `r(N)' == `r(unique)'

			merge 1:1 round hhid fmid using "$hf/l2phl_cati_indw.dta" ///
				, assert(1 3) keep(3) nogen

			merge m:1 round hhid using "${hf}/l2phl_cati_household.dta" ///
				, assert(1 3) keep(3) nogen keepusing(date year quarter qofd month mofd)

	save "${hf}/l2phl_cati_individual.dta", replace

		cap erase "${hf}/l2phl_Roster_Level_Data.dta"
		cap erase "${hf}/l2phl_HH_Level_Data.dta"
		cap erase "${hf}/l2phl_cati_indw.dta"
		cap erase "${hf}/l2phl_cati_hhw.dta"
