//Analyze HF data of L2PHL
//created by Avralt-Od Purevjav
//modified on Mar 19, 2026
	
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


	//Merging rounds
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
	
	//Merging rounds
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

		
/* 
	 	 
	* passport 
	use "${hf}/l2phl_M00_passport.dta", clear 
	
		drop call_* correct_resp agreement refusal_* interview_* *address*
		drop *_date *_time date_* time_* sample* old* fmid* backgound* intro x* 
		drop deviceid hhsize_wrong alternative* round_lastint n_z17 int_name 
		
		merge 1:1 hhid round using "$hf/l2phl_cati_base@${rnd}.dta" ///
			, assert(3 4 5) nogen update ///
				keepusing(hhw popw hhsize region province city barangay locale)
		
		cap drop date 
			merge m:1 hhid round using "${hf}/date.dta" ///
				, update assert(1 2 3 4 5) keep(3 4 5) ///
					keepusing(date year qofd quarter mofd month)	
				tab mofd _m 
				drop _merge 
					format date %tdCCYY/NN/DD
					format qofd %tqCCYY!Qq
					format mofd %tmCCYY!MNN
					
			order year quarter qofd month mofd , a(date)
			
			gunique hhid round 
				as `r(N)' == `r(unique)'
			gunique hhid mofd  
				as `r(N)' == `r(unique)'
				
	drop int_id survey_lang replacement d3 member_called resp_fmid koboid uuid sid 
	drop province city barangay 
	rename locale urban 
	
	assert rnd == round 
		drop rnd 
		
		la var hhid "L2PHL HHID"
		la var round "L2PHL CATI Round" 
		la var hhsize "Household size"
		la var region "Region"
		la var urban "Urban/Rural"
		la var popw "Population weight"
		la var hhw "Household weight"
		
		order date year quarter qofd month mofd round hhid hhsize region urban popw hhw 
		
		table (region) (round) [iw = popw]
		table (urban) (round) [iw = popw]

		table (region) (round) [iw = hhw]
		table (urban) (round) [iw = hhw]
	
	save "${hf}/l2phl_M00_passport.dta", replace 
	
	* roster 
	use "${hf}/l2phl_M01_roster.dta", clear 
	
		keep hhid fmid age gender relationship round 
			
		merge m:1 hhid round using "${hf}/l2phl_M00_passport.dta" ///
			, update keepusing(date year quarter qofd month mofd round region urban popw hhw) ///
				assert(2 3) keep(3) nogen 
				
			gunique hhid fmid round 
				as `r(N)' == `r(unique)'
			gunique hhid fmid mofd  
				as `r(N)' == `r(unique)'
				
		bys round hhid (fmid): g hhsize = _N 
		
	g  indw = popw / hhsize 
	
	table (round) (gender) [iw = indw] 
		drop hhw popw 
	compress 
	sort mofd hhid fmid 
	save "${hf}/l2phl_M01_roster.dta", replace 
	

	* education  
	use "${hf}/l2phl_M02_education.dta", clear 
	
		keep hhid fmid round ed*  
			
		merge 1:1 hhid fmid round using "${hf}/l2phl_M01_roster.dta" ///
			, update keepusing(date year quarter qofd month mofd round region urban indw age gender) ///
				assert(1 2 3) keep(1 2 3) nogen 
				
			gunique hhid fmid round 
				as `r(N)' == `r(unique)'
			gunique hhid fmid mofd  
				as `r(N)' == `r(unique)'
					
	table (round) (gender) [iw = indw] 

	compress 
	sort mofd hhid fmid 
	save "${hf}/l2phl_M02_education.dta", replace 

	* shocks 
	use "${hf}/l2phl_M03_shock.dta", clear 
	
		keep round hhid sh* el* n5 nh* 
		bys round hhid: g N = _N
		
		tab round N 
				drop N 
		bys round hhid: keep if _n == _N 

		merge 1:1 hhid round using "${hf}/l2phl_M00_passport.dta" ///
			, update keepusing(date year quarter qofd month mofd round region urban popw hhw) ///
				assert(2 3) keep(3) nogen 
				
		drop shocks_end 		

	compress 
	sort mofd hhid 
	save "${hf}/l2phl_M03_shock.dta", replace 
	
	
	* employment   
	use "${hf}/l2phl_M04_employment.dta", clear 
	
		keep hhid fmid round a*  
		drop age 
			
		merge 1:1 hhid fmid round using "${hf}/l2phl_M01_roster.dta" ///
			, update keepusing(date year quarter qofd month mofd round region urban indw age gender) ///
				assert(2 3) keep(2 3) nogen 
				
			gunique hhid fmid round 
				as `r(N)' == `r(unique)'
			gunique hhid fmid mofd  
				as `r(N)' == `r(unique)'
					
	table (round) (gender) [iw = indw] 

	compress 
	sort mofd hhid fmid 
	save "${hf}/l2phl_M04_employment.dta", replace 
	
	
	* income 
	use "${hf}/l2phl_M05_income.dta", clear 
	
		keep round hhid fmid *ia* *income 

		merge 1:1 hhid fmid round using "${hf}/l2phl_M01_roster.dta" ///
			, update keepusing(date year quarter qofd month mofd round region urban indw age gender) ///
				assert(2 3) keep(2 3) nogen 
				
			gunique hhid fmid round 
				as `r(N)' == `r(unique)'
			gunique hhid fmid mofd  
				as `r(N)' == `r(unique)'
				

	compress 
	sort mofd hhid fmid 
	save "${hf}/l2phl_M05_income.dta", replace 
	
	* finance 
	use "${hf}/l2phl_M06_finance.dta", clear 
	
		keep round hhid *f*
		
			gunique hhid round 
				as `r(N)' == `r(unique)'

		merge 1:1 hhid round using "${hf}/l2phl_M00_passport.dta" ///
			, update keepusing(date year quarter qofd month mofd round region urban popw hhw) ///
				assert(3) keep(3) nogen 
			
	compress 
	sort mofd hhid 
	save "${hf}/l2phl_M06_finance.dta", replace 
	
	* health 
	use "${hf}/l2phl_M07_health.dta", clear 
	
		keep round hhid *h*
	
			gunique hhid round 
				as `r(N)' == `r(unique)'

		merge 1:1 hhid round using "${hf}/l2phl_M00_passport.dta" ///
			, update keepusing(date year quarter qofd month mofd round region urban popw hhw) ///
				assert(3) keep(3) nogen 
			
	compress 
	sort mofd hhid 
	save "${hf}/l2phl_M07_health.dta", replace 
	
	* food nonfood  
	use "${hf}/l2phl_M08_food_nonfood.dta", clear 
	
		keep round hhid *f*
	
			gunique hhid round 
				as `r(N)' == `r(unique)'

		merge 1:1 hhid round using "${hf}/l2phl_M00_passport.dta" ///
			, update keepusing(date year quarter qofd month mofd round region urban popw hhw) ///
				assert(3) keep(3) nogen 
			
	compress 
	sort mofd hhid 
	save "${hf}/l2phl_M08_food_nonfood.dta", replace 
	
	
	* views  
	use "${hf}/l2phl_M09_views.dta", clear 
	
		keep round hhid *v*
		
			gunique hhid round 
				as `r(N)' == `r(unique)'

		merge 1:1 hhid round using "${hf}/l2phl_M00_passport.dta" ///
			, update keepusing(date year quarter qofd month mofd round region urban popw hhw) ///
				assert(3) keep(3) nogen 
			
	compress 
	sort mofd hhid 
	save "${hf}/l2phl_M09_views.dta", replace
	
	
	
	
	
	
	
	

		
			
			