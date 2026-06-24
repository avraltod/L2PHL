//Analyze HF data of L2PHL
//created by Avralt-Od Purevjav
//modified on Jan 19, 2026
	
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
			glo root "~/Library/CloudStorage/GoogleDrive-avraltod@gmail.com/My Drive/L2PHL"
		
// 		loc ow = c(os)
// 		di "`ow'"
// 		if ( "`ow'"=="Windows" )  ///
// 			glo root "C:\Users\wb463427\OneDrive - WBG\ECAPOV\L2Ss\L2Ukr\CATI"
// 		if ( "`ow'"=="MacOSX" )  ///
// 			glo root "~/iDrive/Dropbox/WB/L2Ukr/CATI"
		
		glo hf "$root/CATI/Analysis/HF"
// 		glo baseline "$root/Analysis/Baseline"
// 		glo weight "$root/Analysis/Weights"
// 		glo out "$root/Analysis/Reporting"
// 		glo pool "$root/Pool"


// 		cd "$out"

		glo date 20260118	// change date each time you run the code
		glo LNG ENG  //change language of the data set: ENG RUS UKR 
		glo RDATES "20260112 20260106 $date "

	//Locals
		
		glo R=3  // change it in each round
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
					cap erase ${hf}/R`r'/`file'	
			}		
			
			//moving the files into input folder 		
			local dtafiles : dir "$root/CATI/Round`r'/dta/`d'" files "*.dta"
			foreach file in `dtafiles' {
				di 	"`file'" 
				cap erase ${hf}/R`r'/`file'	
					copy  "$root/CATI/Round`r'/dta/`d'/`file'" ///
						"${hf}/R`r'/`file'", replace
			}
			
		}
		
	//Open baseline weight file
		use "$hf/R00/weights.dta", clear
			
			tab region [iw = popw]
			tab region [iw = hhw]
// 			keep hhid hhw popw

		bys stratum (psu hhid): egen stratum_pop = total(popw)
		bys stratum (psu hhid): egen stratum_nhh = total(hhw)

			
		tempfile bwgt
		save `bwgt'
		
	//Open baseline roster
		use "$hf/R00/l2phl_20251127_M01_roster.dta", clear
		
		isid hhid fmid 
		
		bys hhid (fmid): g N = _N 
			assert hhsize == N , r 
				drop hhsize 
					ren N hhsize 
		
			bysort hhid (fmid): keep if _n == _N 
			
			keep hhid hhsize 
			isid hhid 

		tempfile hhsize
		save `hhsize'
		
	//Household Data
		//Create base information file for merge 
		use "$hf/R00/l2phl_20251127_M00_passport.dta", clear
		
			merge 1:1 hhid using `hhsize', assert(3) nogen 
				order hhsize, a(hhid)
	
			merge 1:1 hhid using `bwgt', assert(3) nogen 
			
			
			tab region, g(region_)
			tab stratum, g(stratum_)
// 			keep hhid stg_id locale hhsize region region_* stratum stratum_* 			
		
			tempfile base 
			save `base'	
			
			
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
			
			append using "$hf/R`R'/l2ph_`d'_M00_passport.dta", force 
				replace round = `r' if round == .
		}
		
		
		gen stg_id = hhid 
		
		cap drop region
		cap drop province 
		cap drop city
		cap drop barangay 
		cap drop locale
		
		merge m:1 stg_id ///
			using "$hf/R00/l2phl_20251127_M00_passport.dta", ///
				assert(2 3) keep(3) nogen ///
					keepusing(psgc_str region province city barangay locale)
			
			order psgc_str region province city barangay locale, b(hhid)
		
		
		
		merge m:1 stg_id ///
			using `base', ///
				keep(3) keepusing(region_* hhw popw stratum* psu ) nogen
		
		tempfile hf
		save `hf'
		
		
	//weight balancing 	
		//open baseline
		use `base'
			g base = 1 
		
		//Add HF data
		append using `hf'
		
		g rural = (locale == 2)
		
		g treat = .
		replace treat = 1  if base == 1
			
		g ad_weight = .
		
		forvalues i = 1/$R {
			replace treat = 0 if round ==`i'
// 			ebalance treat ///
// /* hhsize */ /* g1pc */ region_1 region_2 region_3 region_4 region_5 ///
// 					region_6 region_7 region_8 region_9 region_10 region_11 ///
// 					region_12 region_13 region_14 region_15 region_16 region_18 ///
// 				rural ///
// 					, gen(weight`i')
					
					
			ebalance treat ///
						hhsize region_* , gen(weight`i')
					
				replace treat = . if round ==`i'
				replace ad_weight = weight`i' if weight`i' !=.
				
// 			cap drop stratum_pop`i'	
// 			bys round stratum (psu hhid): egen stratum_pop`i' = total(popw)	if round == `i'
// 			replace adj_popw = stratum_pop / stratum_pop`i' if round == `i'
			
			}
		
		drop if base ==1

		replace popw = popw*ad_weight
		
		su popw , d 		
		winsor2 popw, replace cuts(1 99) by(round)
		
		hist popw if round == 3
		
		bys round stratum (psu hhid): egen stratum_pop_rnd = total(popw)
		g adj_popw = stratum_pop / stratum_pop_rnd 
		
		replace popw = popw * adj_popw 
		
		table (stratum) (round) [iw = popw]			
		
// 		foreach i of numlist 1/$R {
// 			tab region 	[iw = popw] if round == `i' 		
// 			replace popw = popw * (112609308 / (`r(N)' ) ) ///
// 				if round == `i'
// 			tab region 	[iw = popw] if round == `i'
// 		}		
		
		cap drop hhw  
		g hhw = popw / hhsize
		
		bys round stratum (psu hhid): egen stratum_nhh_rnd = total(hhw)
		g adj_hhw = stratum_nhh / stratum_nhh_rnd 
		
		replace hhw = hhw * adj_hhw 

		table (stratum) (round) [iw = hhw]	
		
		
// 		foreach i of numlist 1/$R {
// 			tab region 	[iw = hhw] if round == `i' 		
// 			replace hhw = hhw * (26393906 / (`r(N)' ) ) ///
// 				if round == `i'
// 			tab region 	[iw = hhw] if round == `i'
// 		}	

		
	
/*
		xtile quint = gallT [aw=popw] , nq(5)
		xtile decile = gallT [aw=popw], nq(10)
		g b40 = 0
		replace b40 = 1 if decile<5
		g t60 = 0
		replace t60 =1 if b40==0
		tab quint [aw=popw], g(quint)
*/		
		
		/// KEEPING 
		
		keep round hhid popw hhw subm_date subm_time hhsize stg_id region locale ///
			region_* psgc_str province city barangay ad_weight weight* urban adj* stratum* 
		
		
		/// ORDERING
		
		order round, first
		sort round
		
		order province city barangay urban popw hhw subm_*, after(hhid)
		
		
		tempfile base
		save `base'
		save "$hf/l2phl_cati_base@${rnd}.dta", replace
		
	//date 
	use `hf', clear 
			gunique hhid round 
				as `r(N)' == `r(unique)'
				
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

			cap drop qofd 
			g qofd =qofd(date)
				format qofd %tq_CCYY_!Qq
			
			keep hhid date year qofd quarter mofd month round
			
	tempfile date 
	save `date', replace 
		save "${hf}/date.dta", replace
		

	//Merging rounds
	foreach ss in 	M00_passport ///
					M01_roster ///
					M02_education ///
					M03_shock ///
					M04_employment ///
					M05_income ///
					M06_finance ///
					M07_health ///
					M08_food_nonfood ///
					M09_views ///
					{		
		clear all 
		cap drop rnd 
		g rnd = .
			
		foreach r of numlist 1/$R {
			loc r : di %02.0f `r'
			
			di "`ss'-`r'"
			
			local dt: word `r' of $RDATES
			cap append using  "${hf}/R`r'/l2ph_`dt'_`ss'.dta" , force 
			
			replace rnd = `r' if rnd == .
				tab rnd
		}
		
			
	save "${hf}/l2phl_`ss'.dta", replace

	}
	
	
	 	 
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
	
	
	
	
	
	
	
	

		
			
			