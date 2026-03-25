 	* L2PHL CAPI Baseline, Oct 2025
	* Survey To Go 2 Raw . 
	* created by Avralt-Od Purevjav
	* date: Oct 26, 2025
	
	* last modified by: Avraa
	* date: Mar 19, 2026

	
	
	{
	clear all 
	set more off
	set excelxlsxlargefile on
//     set processors 6 //8
	set maxvar 10000
	
	loc  user = "AP" //AP or BB or LD 	

	if ( "`user'"=="AP" )  ///
		glo wd "~/Library/CloudStorage/GoogleDrive-avraltod@gmail.com/My Drive/L2Phl/CAPI"
	if ( "`user'"=="BB" )  ///
		glo wd "/Users/batmandakh/Dropbox/BB/WB/PHL/CAPI"		
	if ( "`user'"=="LD" )  ///
		glo wd "C:\Users\Liz Danganan\OneDrive - PSRC\3 MACROS & TEMPLATES\TIPON\TIPON\data"		
		
	cd "$wd" //changing directory 
	

	glo LNG ENG 	
	glo R 00
	glo pR 00
	
	glo M 10
	glo D 15
	glo Y 2025
	
  	
	glo xlsx_file "TIPON 2025-N2470-Main Data 27Nov2025"
	glo call_file "TIPON 2025-n9166_Callsheet 18Oct2025"

// 	glo stata_file ""

	glo dta_file l2phl
	
	glo date ${Y}${M}${D}	
	glo date_filter "date <= mdy($M, $D, $Y)"
	
	cap adopath - "$wd/ado/"		
	// making sure are there defined commands
	foreach prog in kobo2stata _gwtmean extremes ///
		winsor2 povdeco apoverty ds3 ///
			clonevar confirmdir unique copydesc {
				cap which `prog'
					if _rc ssc install `prog' , replace all
	}
	adopath + "$wd/ado/"
	
		foreach dir in raw fix dta zzz {
			confirmdir "${wd}/`dir'/"
			if _rc ~= 0 {
				mkdir "${wd}/`dir'"
			}	
		}
		
		foreach dir in raw fix dta zzz {
			confirmdir "${wd}/`dir'/$date"
			if _rc ~= 0 {
				mkdir "${wd}/`dir'/$date"
			}			
		}

	glo ado "$wd/ado"
	glo raw "$wd/raw/$date"
	glo xls "$wd/xls"
	glo sav "$wd/sav"
	glo zzz "$wd/zzz/$date"
	glo call "$wd/call/$date"
	glo fix "$wd/fix/$date"
	glo tab "$wd/tab/$date"
	glo dta "$wd/dta/$date"
	glo aud "$wd/aud/$date"


// 	loc  zzzfiles : dir "${zzz}" files "*.dta"
	loc  rawfiles : dir "${raw}" files "*.dta"	
		foreach file in `zzzfiles' `rawfiles' {
				di 	"`file'" 						
			*shell rm -r $zzz/`file'
// 			cap erase "$zzz/`file'"
			cap erase "$raw/`file'"

			}
		
			
	* XLSX TO STATA : SUCCESSFUL 
*------------------------------------------------------------------------------*
	cap confirm file "${zzz}/data.dta" 
		if _rc ~= 0 {
		
/*
			import excel using "$xls/$xlsx_file.xlsx", describe 
			return list 
			foreach i of numlist 1/10 {
			qui import excel using "$xls/$xlsx_file.xlsx", describe 

				import excel using "$xls/$xflsx_file.xlsx" ///
					, sheet(`r(worksheet_`i')') cellrange(`r(range_`i')') ///
						first clear case(lower)
					
			su 		
			save "${zzz}/ws`i'.dta", replace 

			}
*/
			
			import excel using "$xls/$xlsx_file.xlsx" ///
				, sheet("Raw Data (Wide Version)") ///
					first clear case(lower) allstring
			
			dropmiss, obs force 

			replace d10a_6 = "" if hhid == "1004215004102050" & d10a_6 == "51"
			
			
//			drop if hhid == "1804502015079562"
//			drop if hhid == "0306910012047014"
//			drop if hhid == "0402120002055527"
//			drop if hhid == "1381701001022115"
//			drop if hhid == "1430300040023200"
//			drop if hhid == "0501732014072531"
//			drop if hhid == "1600314012115549"
//			drop if hhid == "0431200016063126"
			
			ren *, lower 
			
				ren hh_sn hhsn  	
				la var hhsn "HH serial number within PSGC"
					unique hhsn 
						as `r(N)' == `r(unique)' , r 
						destring hhsn, replace 
							format hhsn %03.0f 
							
				la var hhid "HHID baseline"
					unique hhid 
						as `r(N)' == `r(unique)' 

						g double hhid_num = real(hhid), a(hhid)
						
							ren hhid hhid_str
							ren hhid_num hhid
							format hhid %13.0f
						
						g hhid_len = strlen(hhid_str) , a(hhid_str)
						tab hhid_len 
					unique hhid 
						as `r(N)' == `r(unique)'
				ren interviewer_id ecode 	

				g double psgc_num = real(psgc), a(psgc)
					format psgc_num %010.0f
					unique psgc_num

				g psgc_len = strlen(psgc) , a(psgc)
				tab psgc_len 
				unique psgc 
					ren psgc psgc_str 
					ren psgc_num psgc 
				
			qui ds 	
			loc  all_vars `r(varlist)'
// 				di "`all_vars'"
			loc  exc_vars "hhid_str psgc_str"
// 				di "`exc_vars'"
			loc  fin_vars: list all_vars - exc_vars 
// 				di "`fin_vars'"
			quie destring `fin_vars', float replace 

				g date = date(z6, "MDY"), a(z6)
				cap drop z6  
				la var date "Date of Interview"
				format date %tdCCYY/NN/DD				
					order date, a(z5)
							
			
							
			quietly ds, has(type numeric)	
			//	format `r(varlist)' %9.0f
				//recast int `r(varlist)' 
			
			quietly ds , has(type string)
				foreach var of varlist `r(varlist)' {
					replace `var' = trim(itrim(proper(`var'))) 
					replace `var' = ustrupper(`var')	
				}
				
			quietly compress 
			save "$zzz/data.dta", replace
		}
	
	* XLSX TO STATA : NONRESPONSE
*------------------------------------------------------------------------------*
	cap confirm file "${zzz}/call.dta" 
		if _rc ~= 0 {

			import excel using "$xls/$call_file.xlsx" ///
				, sheet("Raw Data") ///
					first clear case(lower) allstring
			
			dropmiss, obs force 

			ren *, lower 
			
				ren hh_sn hhsn  	
				la var hhsn "HH serial number within PSGC"
					unique hhsn 
						as `r(N)' == `r(unique)' , r 
						destring hhsn, replace 
							format hhsn %03.0f 
							
				la var hhid "HHID baseline"
					unique hhid 
						as `r(N)' == `r(unique)' 

						g double hhid_num = real(hhid), a(hhid)
						
							ren hhid hhid_str
							ren hhid_num hhid
							format hhid %13.0f
						
						g hhid_len = strlen(hhid_str) , a(hhid_str)
						tab hhid_len 
					unique hhid 
						as `r(N)' == `r(unique)'
						
				ren interviewer_id ecode 	
				split ecode, g(e) parse(";")
				order e?, after(ecode)
				destring e1, replace 
					drop ecode 
						ren e1 ecode 
							cap drop e? 
							
				g double psgc_num = real(psgc), a(psgc)
					format psgc_num %010.0f
					unique psgc_num

				g psgc_len = strlen(psgc) , a(psgc)
				tab psgc_len 
				unique psgc 
					ren psgc psgc_str 
					ren psgc_num psgc 

			qui ds 	
			loc  all_vars `r(varlist)'
// 				di "`all_vars'"
			loc  exc_vars "hhid_str psgc_str"
// 				di "`exc_vars'"
			loc  fin_vars: list all_vars - exc_vars 
// 				di "`fin_vars'"
			quie destring `fin_vars', float replace 

				g temp = date(date, "DMY"), a(date)
				drop date
				ren temp date 
				la var date "Date of Interview"
				format date %tdCCYY/NN/DD				
							
			g temp = date(date_cb1, "DMY"), a(date_cb1)
				drop date_cb1
				ren temp date_cb1 
				la var date_cb1 "Date of Interview: Callback 1"
				format date_cb1 %tdCCYY/NN/DD
				
			tostring date_cb2 , replace force 	
			g temp = date(date_cb2, "DMY"), a(date_cb2)
				drop date_cb2
				ren temp date_cb2 
				la var date_cb2 "Date of Interview: Callback 1"
				format date_cb2 %tdCCYY/NN/DD
							
			quietly ds, has(type numeric)	
			//	format `r(varlist)' %9.0f
				//recast int `r(varlist)' 
			
			quietly ds , has(type string)
				foreach var of varlist `r(varlist)' {
					replace `var' = trim(itrim(proper(`var'))) 
					replace `var' = ustrupper(`var')	
				}

			quietly compress 
			save "$zzz/call.dta", replace
		}
	
	
	}

	
********************************************************************************
**# (M0) HOUSEHOLD PASSPORT
********************************************************************************
	{
	use "$zzz/data.dta", clear 
		keep hhid_str-selected_pr z7b z7c *_duration 
		dropmiss hhid, obs force
		
	cap drop d1 d3 d4 	
		
	la lang ENG, copy new
	
	
/*
	capture program drop _mkclean
	program define _mkclean
		// usage: _mkclean srcvar tgtvar
		args src tgt
		// convert to string only if numeric
		capture confirm numeric variable `src'
		if !_rc {
			tostring `src', replace force format(%20.0g)
		}
		// trim, remove spaces, turn a lone "." into empty
		capture drop `tgt'
		gen str200 `tgt' = strtrim(`src')
		replace `tgt' = subinstr(`tgt'," ","",.)
		replace `tgt' = "" if `tgt' == "."
		// pad with semicolons for exact ;code; matching
		replace `tgt' = ";" + `tgt' + ";"
	end		
	
*/

	capture program drop _mkclean
	program define _mkclean
		// usage: _mkclean srcvar tgtvar
		// goal: normalize multi-select codes into ";code1;code2;...;"
		// handles separators " ", ",", ":", ";"

		args src tgt

		// 1. If source is numeric (single code), convert to string
		capture confirm numeric variable `src'
		if !_rc {
			tostring `src', replace force format(%20.0g)
		}

		// 2. Start clean target as trimmed string
		capture drop `tgt'
		gen str200 `tgt' = strtrim(`src')

		// 3. Treat lone "." as missing
		replace `tgt' = "" if `tgt' == "."

		// 4. Normalize all possible separators to a single semicolon
		//    - commas -> ";"
		//    - colons -> ";"
		//    - spaces  -> ";"
		//    - multiple semicolons ";;" -> ";"
		replace `tgt' = subinstr(`tgt', ",",  ";", .)
		replace `tgt' = subinstr(`tgt', ":",  ";", .)
		// Turn ANY run of whitespace into semicolons.
		// We'll first collapse multiple spaces to single space, then convert space to ";"
		// (Stata doesn't have regex in replace without plugins, so do a two-step)
		// Step 4a: squeeze multiple spaces
		quietly while strpos(`tgt', "  ")>0 {
			replace `tgt' = subinstr(`tgt', "  ", " ", .)
		}
		// Step 4b: single spaces -> ";"
		replace `tgt' = subinstr(`tgt', " ",  ";", .)

		// 5. Remove any accidental leading/trailing semicolons/spaces leftover
		replace `tgt' = subinstr(`tgt', ";;", ";", .)
		quietly while strpos(`tgt', ";;")>0 {
			replace `tgt' = subinstr(`tgt', ";;", ";", .)
		}
		replace `tgt' = subinstr(`tgt', "; ;", ";", .)

		// 6. Strip leading/trailing ";" if they exist so we can re-pad consistently
		// (We'll do this by trimming manually.)
		// leading ";"
		replace `tgt' = substr(`tgt', 2, .) if substr(`tgt',1,1)==";"
		// trailing ";"
		replace `tgt' = substr(`tgt', 1, length(`tgt')-1) if substr(`tgt',-1,1)==";"

		// 7. Final pad with semicolons for exact matching pattern ;code;
		replace `tgt' = ";" + `tgt' + ";" if `tgt' != ""

	end

		
	ren z1 region 
	la var region "Region"
	la def REG ///
		1 "I Ilocos" ///
		2 "II Cagayan Valley" ///
		3 "III Central Luzon " ///
		4 "IV-A Calabarzon " ///
		5 "V Bicol" ///
		6 "VI Western Visayas" ///
		7 "VII Central Visayas" ///
		8 "VIII Eastern Visayas " ///
		9 "IX Zamboanga Peninsula " ///
		10 "X Northern Mindanao " ///
		11 "XI Davao Region" ///
		12 "XII SOCCSKSARGEN" ///
		13 "NCR " ///
		14 "CAR" ///
		16 "XIII Caraga" ///
		17 "IV-B MIMAROPA" ///
		18 "NIR Negros Island Region" ///
		19 "BARMM " ///		
		, replace 
	la val region REG 
	
	ren z2 province 
	la var province "Province"
		qui run "$ado/province.do"
	la val province PROV 
		
	ren z3 city 
	la var city "City/Municipality"
		qui run "$ado/city.do"
	la val city CITY 
	
	ren z4 barangay 
	la var barangay "Barangay"
		qui run "$ado/barangay.do"
	la val barangay BRN 
	
	ren z5 locale 
	la var locale  "Settlement Type"
	la def loc  ///
		1 "Urban" ///
		2 "Rural" ///
		, replace 
	la val locale  loc  
	
	cap ren z6 date 
	cap la var date "Date of Interview"
	cap format date %tdCCYY/NN/DD

	replace z7a = upper(z7a)
	replace z7a = strtrim(itrim(z7a))
	replace z7a = ustrregexra(z7a, "\s*(AM|PM)$", " $1")   // adds space if missing, trims extras
	
	g double t = clock(z7a, "hms"), a(z7a)
	format t %tcHH:MM:SS	
	g time_start = dhms(date, hh(t), mm(t), ss(t)) , a(date)
	la var time_start "Time of Interview"
	format time_start %tcCCYY/NN/DD_HH:MM:SS
		drop z7a t
		
	g double t = clock(z7b, "hm"), a(z7b)
	replace t = clock(z7b, "hms") if missing(t)
	format t %tcHH:MM:SS
	g time_end = dhms(date, hh(t), mm(t), ss(t)) , a(time_start)
	la var time_end "Time of Interview"
	format time_end %tcCCYY/NN/DD_HH:MM:SS
		drop z7b t
		
	ren z8 visit 
	la var visit "Visit number"
	la def VSTNUM ///
		1 "1st attempt" ///
		2 "2nd attempt" ///
		3 "3rd attempt" ///
		, replace
	la val visit VSTNUM
	
	ren z9 agreement 
	la var agreement "Introduction and privacy notice"
	la def AGR ///
		1 "I agree" ///
		2 "No, I do not agree" ///
		, replace 
	la val agreement AGR 
	
	cap ren z10 lang 
	cap la var lang "Survey language" 
	cap la def LNG ///
		1 "English" ///
		2 "Filipino" ///
		3 "Cebuano" ///
		4 "Hiligaynon" ///
		5 "Waray" ///	
		, replace 
	cap la val lang LNG 
	
	ren z12a longitude 
	la var longitude "GPS-Longitude"
	ren z12b latitude 
	la var latitude "GPS-Latitude"
	
	ren z13 nhhs 
	la var nhhs "Number of households in housing unit"
	
	ren z15 hhmember 
	la var hhmember "Household member confirmation"
	la def CNF ///
		1 "Yes" ///
		2 "Not available" ///
		3 "No" ///
		98 "Refused" ///
		, replace 
	la val hhmember CNF 
	
	ren z_duration dur_passport 
	la var dur_passport "Duration of the passport"
	
	ren z7c tot_duration 
	la var tot_duration "Interview duration (min)"

	la lang ${LNG}
	compress 	
	save "$raw/${dta_file}_${date}_M00_passport.dta", replace	
	
	}

	unique hhid  if agreement == 1
		as `r(unique)' == `r(N)'
		tab date agreement , m nol 
				
********************************************************************************
**# (M0) HOUSEHOLD PASSPORT: NONRESPONSE
********************************************************************************
	{
	use "$zzz/call.dta", clear 
		dropmiss hhid, obs force
		
	la lang ENG, copy new

	la var region "Region"
	la def REG ///
		1 "I Ilocos" ///
		2 "II Cagayan Valley" ///
		3 "III Central Luzon " ///
		4 "IV-A Calabarzon " ///
		5 "V Bicol" ///
		6 "VI Western Visayas" ///
		7 "VII Central Visayas" ///
		8 "VIII Eastern Visayas " ///
		9 "IX Zamboanga Peninsula " ///
		10 "X Northern Mindanao " ///
		11 "XI Davao Region" ///
		12 "XII SOCCSKSARGEN" ///
		13 "NCR " ///
		14 "CAR" ///
		16 "XIII Caraga" ///
		17 "IV-B MIMAROPA" ///
		18 "NIR Negros Island Region" ///
		19 "BARMM " ///		
		, replace 
	la val region REG 
	
	la var locale  "Settlement Type"
	la def loc  ///
		1 "Urban" ///
		2 "Rural" ///
		, replace 
	la val locale  loc  
	
	cap la var date "Date of Interview"
	cap format date %tdCCYY/NN/DD

	ren rem1 status 
	la var status "Initial visit remarks"
	la def STATUS ///
		1 "Completed" ///
		2 "Skip" ///
		3 "For Callback" ///
		5 "No Reply" ///
		6 "No Adult HH Member/ Maid Only/ Boarders Only/ Visitor Only" ///
		7 "Gate/ Door loc ked" ///
		8 "Outright Refusal" ///
		9 "With Visible Sari-sari Store" ///
		10 "Not allowed enter gate/ compound" ///
		11 "Vacant lot" ///
		12 "Rice field/ Farm" ///
		13 "Abandoned house" ///
		14 "House under construction" ///
		15 "Commercial establishment" ///
		16 "SEC not qualified, looking for" ///
		17 "Terminate" ///
		18 "PR Refused" ///
		19 "PR not available" ///
		20 "Refused during the middle of the interview" ///	
		, replace 
	la val status STATUS 

	ren gps_lo longitude 
	la var longitude "GPS-Longitude"
	ren gps_la latitude 
	la var latitude "GPS-Latitude"
	
	destring rem_cb1, replace
	destring rem_cb2, replace
	la val rem_cb1 rem_cb2 STATUS 
	
	

	la lang ${LNG}
	compress 	
	save "$raw/${dta_file}_${date}_M00_attempts.dta", replace	
	
	}

********************************************************************************
**# (D) HOUSEHOLD ROSTER
********************************************************************************
	{
	use "$zzz/data.dta", clear 

		keep hhid* d* date
		cap drop dw* 
		
	loc  var ""
	foreach v in d5a1 d6 d8  d9  ///
		d10a d10b d10c d10d d10e d10f d12 d12a ///
		d13 d13a d14 d18 d19 d20 d24 {
		foreach i of numlist 1/25 {
		
			cap ren `v'`i' `v'_`i'
		}
		loc  var "`var' `v'_"
	
	}  	
	di "`var'"
		
	ds d10b_* , has(type numeric)
	loc  num  `r(varlist)'
	if "`num'" != "" {
		tostring `num', replace format(%18.0g)
	}	
	tostring d18_* d10c_* d10d_* d10e_* d10f_* d24_*, force replace 
	reshape long  d5a1_ d6_ d8_ d9_ d10a_ d10b_ d10c_ d10d_ d10e_ d10f_ d12_ d12a_ d13_ d13a_ d14_ d18_ d19_ d20_ d24_ ///
		, i(hhid) j(fmid)  

	su `var'
	destring d10b_, replace 	
	dropmiss d5a1_ d6_ d8_ d9_ d10a_ d10b_ d12_ d12a_ d13_ d13a_ d14_, obs force  
	
	ren *_ * 
		
	la lang ENG, copy new 
	
	ren d1 agreement 
	la var agreement "Introduction and privacy notice"
	la def AGR ///
		1 "I agree" ///
		2 "No, I do not agree" ///
		, replace 
	la val agreement AGR 
	
	ren d3 lang 
	la var lang "Survey language" 
	la def LNG ///
		1 "English" ///
		2 "Filipino" ///
		3 "Cebuano" ///
		4 "Hiligaynon" ///
		5 "Waray" ///	
		, replace 
	la val lang LNG 	

	ren d4 hhsize 
	la var hhsize "Household size"
		bys hhid (fmid): g N = _N 
		as N == hhsize , r 
			drop N 
			
	ren d5a1 hh_member_status
	la def MEM_STATUS ///
		1 "Permanent" ///
		2 "Overseas" ///
		3 "City/Province" ///
		4 "Others" ///
		, replace 
	
	la val hh_member_status MEM_STATUS
			
	ren d6 relationship
	la var relationship "Relationship to the household head"
	la def REL ///
		1 "Head" ///
		2 "Wife/Spouse" ///
		3 "Son/daughter" ///
		4 "Brother/sister" ///
		5 "Son-in-law/daughter-in-law" ///
		6 "Grandson/granddaughter" ///
		7 "Father/Mother" ///
		8 "Other Relative" ///
		9 "Boarder" ///
		10 "Domestic helper" ///
		11 "Non-relative" ///
		, replace 
	la val relationship REL 
	
	ren d7_1 migrant_int
	la var migrant_int "Incidence of Having Other HH Members - Has moved out of the household in the past 5 years and currently living overseas"
	la def YN ///
		1 "Yes" ///
		2 "No" ///
		, replace 
	la val migrant_int YN 
	
	ren d7_2 migrant_dom  
	la var migrant_dom "Incidence of Having Other HH Members - Has moved out of the household in the past 5 years and currently living overseas - Has moved out of the household in the past 5 years and currently living in another city/province"
	la val migrant_dom YN 
	
	ren d7_3 migrant_other 
	la var migrant_other "Incidence of Having Other HH Members - Anyone else?"
	la val migrant_other YN 
	
	ren d8 gender 
	la var gender "Gender of HH members"
	la def SEX ///
		1 "Male" ///
		2 "Female" ///
		, replace 
	la val gender SEX 
	
	ren d9 age 
	la var age "Age of HH Members"

	ren d10a pob_province 
	cap la var pob_province "Place of Birth - Province"
		qui run "$ado/province"
	cap la val pob_province PROV
	
	cap ren d10b pob_city 
	cap la var pob_city "Place of Birth - City/Municipality"
		cap qui run "$ado/city.do"
	cap la val pob_city CITY
	
	destring d10c d10d d10e d10f, replace
	
	cap ren d10c pob_country
	cap la var pob_country "Place of Birth - Country"
		cap qui run "$ado/country.do"
	cap la val pob_country COUNTRY
	
	cap ren d10d pob_other_country
	cap la var pob_other_country "Place of Birth - Other Country"
		cap qui run "$ado/country.do"
	cap la val pob_other_country COUNTRY
	
	cap ren d10e pob_other_country_prov
	cap la var pob_other_country_prov "Place of Birth - Other Country - Province"
		qui run "$ado/province"
	cap la val pob_other_country_prov PROV
	
	cap ren d10f pob_other_country_city
	cap la var pob_other_country_city "Place of Birth - Other Country - City"
		cap qui run "$ado/city.do"
	cap la val pob_other_country_city CITY
	
	ren d11 por_5yo
	la var por_5yo "Place of Residence 5 Years Ago"
	la def POR ///
		1 "Same place" ///
		2 "Other" ///
		, replace 
	la val por_5yo POR 
	
	ren d11a_1 por_5yo_province 
	la var por_5yo_province "Place of Residence 5 Years Ago - Province"
	la val por_5yo_province PROV

	ren d11a_2 por_5yo_city 
	la var por_5yo_city "Place of Residence 5 Years Ago - City/Municipality"
	cap la val por_5yo_city CITY
		
	ren d12 weight
	la var weight "Weight"
	la def WGT ///
		1"Weight in kilos" ///
		2 "Not present/available" ///
		98 "Refused" ///
		, replace 
	la val weight WGT 
	
	ren d12a weight_kg 
	la var weight_kg "Weight in kilos"
	
	ren d13 height 
	la var height "Height"
	la def HGT ///
		1 "Height in cm" ///
		2 "Not present/available" ///
		98 "Refused" ///
		, replace 
	la val height HGT 
	
	ren d13a height_cm 
	la var height_cm "Height in cm"
	
	ren d14 marital_status 
	la var marital_status "Marital status"
	la def MARR ///
		1 "Single or unmarried" ///
		2 "Married" ///
		3 "Common-law/Live-in" ///
		4 "Widowed" ///
		5 "Divorced" ///
		6 "Separated" ///
		7 "Annulled" ///
		8 "Not reported" ///
		, replace 
	la val marital_status MARR 
	
	ren d15 language_primary
	la var language_primary "Primary language spoken at home"
	la def PLNG ///
		1 "Bikol/Bicol" ///
		2 "Bisaya/Binisaya" ///
		3 "Cebuano" ///
		4 "English" ///
		5 "Hiligaynon/Ilonggo" ///
		6 "Ilocano" ///
		7 "Kapampangan" ///
		8 "Maguindanao" ///
		9 "Pangasinan/Panggalato" ///
		10 "Tagalog" ///
		11 "Waray" ///
		96 "Others" ///
		, replace 
	la val language_primary PLNG 
	
	ren d16 inci_disability
	la var inci_disability "Incidence of Having A HH Member With Disability"
	la val inci_disability YN 
	
	
	drop d17
	gen d17 = 1 if d19 != .
	order d17, b(d18)
	ren d17 member_disability
	la var member_disability "Member With Disability"
	
	
	//FIX D18
	
	replace d18 = "1 2 3" if d18 == "1;2;3"
	replace d18 = "2 3 4" if d18 == "2;3;4"
	replace d18 = "1 2" if d18 == "1;2"
	replace d18 = "2 4" if d18 == "2;4"
	replace d18 = "3 4" if d18 == "3;4"
	
	///
	
    _mkclean d18 d18_txt
    order d18_txt, a(d18)
    drop d18

    la var d18_txt "Type of Disability"
    note  d18_txt : Type of Disability

    #delimit ;
    glo D18OPT `"
		"Visual Disability"
		"Perforated eardrum"
		"Intellectual learning/Mental/Psychosocial Disability"
		"Speech and Language Impairment"
		"Cancer"
		"Rare Disease"
		"Amputated leg"
		"Difficulty walking"
		"Hydrocephalus"
		"Hypertension"
		"Ventricular Septal Defect"
		"Genetic condition"
		"Leg disability"
		"Scoliosis"
		"Physical disability"
		"Mild stroke/ stroke"
		"Polio"
		"Heart condition"
		"Arm injury"
		"Arthritis"
		"Dizziness"
		"Austism Spectrum Disorder"
		"Finger fracture"
		"Dislocated bone"
		"Cerebral Palsy"
		"Diabetic"
		"Epilepsy"
		"Hand amputation"
		"Hand injury"
		"Paralyzed"
		"Chronic kidney disease"
		"Nerve damage"
		"Cleft lip"
		"Missing teeth"
		"Arm/hand impairment"
		"Broken leg"
		"Had surgey"
		"Asthma"
		"Systemic Lupus Erythematosus"
		"Tendinopathy"
		"Limp"
		"Difficulty standing"
    "';
    #delimit cr
	
    loc D18codes "1 2 3 4 5 6 16 17 21 22 23 24 47 26 27 28 30 32 33 34 37 38 39 43 44 45 46 49 52 53 55 56 57 58 59 60 61 62 63 66 67 68"
    loc j = 0
    foreach c of loc D18codes {
        loc ++j
        loc w : word `j' of $D18OPT
        cap drop d18_`c'
        g byte d18_`c' = (strpos(d18_txt, ";`c';")>0) if d18_txt!=""
        la var d18_`c' "Disability: `w'"
        note  d18_`c' : Disability — `w'
        replace d18_`c' = . if d18_`c'==0
    }
    order d18_*, b(d19)
	
	ren d18_* disability_type_*
	
	ren d19 cause_disability
	la var cause_disability "Cause of Disability"
	la def CSDSB ///
		1 "In-born" ///
		2 "Illness" ///
		3 "Accident" ///
		4 "Old age" ///
		97 "Prefer not to say" ///
		96 "Others" ///
		, replace 
	la val cause_disability CSDSB 
	
	ren d20 inci_pwdid
	la var inci_pwdid "Incidence of Having PWD ID"
	la val inci_pwdid YN 

	ren d23 inci_remit
	la var inci_remit "Remittance"
	la def REMITYN ///
		1 "Yes, from other cities within the Philippines" ///
		2 "Yes, from other countries" ///
		3 "Yes, from within the Philippines and other countries" ///
		4 "No" ///
		, replace 
	la val inci_remit REMITYN 	
	
	cap ren d24 bday_under_5yo
	cap la var bday_under_5yo "Birthdate - under 5yo"

	
	la lang ${LNG}
	compress 	
	save "$raw/${dta_file}_${date}_M01_roster.dta", replace

	}
	
	
********************************************************************************
**# (ED) EDUCATION  
********************************************************************************
	{
	use "$zzz/data.dta", clear 
		keep hhid* d6* ed1_1-ed_duration date

	foreach l in a b c d e f g h i j {
		cap ren ed5*`l' ed5`l'* 
		cap ren ed10*`l' ed10`l'*
	}
	
	
	
	/// DESTRING 
	
	destring ed11_*, force replace


	loc  var ""
	foreach v in ed1 ed2 ed3 ed4 ///
		ed5a ed5b ed5c ed5d ed5e ed5f ed5g ed5h ed5i  ///
		ed6 ed7 ed8 ed9 ///
		ed10a ed10b ed10c ed10d ed10e ed10f ed10g ed10h ed10i ed10j {
		foreach i of numlist 1/25 {
		
			cap ren `v'`i' `v'_`i'
		}
		loc  var "`var' `v'_"
	
	}  	
	di "`var'"

	foreach v in d6_ ed11 ed12 {
		foreach i of numlist 1/25 {
		
			cap ren `v'`i' `v'_`i'
		}
		loc  var "`var' `v'_"
	
	}  	
	di "`var'"

	tostring ed4_* ed9_* ed8_* d6_*, replace 
	
	reshape long `var' ///
		, i(hhid) j(fmid)  
		
// 	dropmiss `var', obs force 	
	ren *_ *
	ren *_ *
	destring d6, replace
 	dropmiss d6, obs force 
///	dropmiss ed1 ed2 ed3 ed5? ed6 ed7 ed8 ed10? ed11 ed12 , obs force 	

	
	la lang ENG, copy new 

	la var ed1 "Who in your household is currently attending school, including early childcare centers & adult learning?"
	note ed1 : Who in your household is currently attending school, including early childcare centers & adult learning?
	la def YN 1 "Yes" 2 "No", replace
	la val ed1 YN

	la var ed2 "Is the school/institution public, private, or home-schooled?"
	note ed2 : Ask if ED1==Yes
	la def EDU_TYPE 1 "Yes, public" 2 "Yes, private" 3 "Yes, home-schooled", replace
	la val ed2 EDU_TYPE

	la var ed3 "What grade or year is [NAME] currently attending?"
	note ed3 : Ask if ED1==Yes
	la def EDU_YEAR ///
		1 "Daycare/ Nursery" 2 "Kindergarten" 3 "Grade 1" 4 "Grade 2" 5 "Grade 3" ///
		6 "Grade 4" 7 "Grade 5" 8 "Grade 6" 9 "Grade 7" 10 "Grade 8" ///
		11 "Grade 9" 12 "Grade 10" 13 "Grade 11" 14 "Grade 12" ///
		15 "Pre-school" 16 "Grade 1" 17 "Grade 2" 18 "Grade 3" 19 "Grade 4" 20 "Grade 5" 21 "Grade 6" ///
		23 "1st year" 24 "2nd year" 25 "3rd year" 26 "4th year" /// 
		28 "Elementary" 29 "High School" 30 "Elementary" 31 "High School" ///
		32 "Post-secondary, non-college programs undergraduate" ///
		33 "Post-secondary, non-college programs graduate" ///
		34 "TVET undergraduate" 35 "TVET graduate" 36 "1st year" 37 "2nd year" ///
		38 "3rd year" 39 "4th year" 40 "5th year" 41 "6th year" 46 "Some college" ///
		42 "Master's Degree undergraduate" ///
		44 "Doctorate degree undergraduate", replace
	la val ed3 EDU_YEAR

	cap conf string variable ed4
	if _rc {
		tostring ed4, replace force format(%20.0g)
	}
	replace ed4 = strtrim(ed4)

	
/*
	capture program drop _mkclean
	program define _mkclean
		// usage: _mkclean srcvar tgtvar
		args src tgt
		// convert to string only if numeric
		capture confirm numeric variable `src'
		if !_rc {
			tostring `src', replace force format(%20.0g)
		}
		// trim, remove spaces, turn a lone "." into empty
		capture drop `tgt'
		gen str200 `tgt' = strtrim(`src')
		replace `tgt' = subinstr(`tgt'," ","",.)
		replace `tgt' = "" if `tgt' == "."
		// pad with semicolons for exact ;code; matching
		replace `tgt' = ";" + `tgt' + ";"
	end	
*/

	capture program drop _mkclean
	program define _mkclean
		// usage: _mkclean srcvar tgtvar
		// goal: normalize multi-select codes into ";code1;code2;...;"
		// handles separators " ", ",", ":", ";"

		args src tgt

		// 1. If source is numeric (single code), convert to string
		capture confirm numeric variable `src'
		if !_rc {
			tostring `src', replace force format(%20.0g)
		}

		// 2. Start clean target as trimmed string
		capture drop `tgt'
		gen str200 `tgt' = strtrim(`src')

		// 3. Treat lone "." as missing
		replace `tgt' = "" if `tgt' == "."

		// 4. Normalize all possible separators to a single semicolon
		//    - commas -> ";"
		//    - colons -> ";"
		//    - spaces  -> ";"
		//    - multiple semicolons ";;" -> ";"
		replace `tgt' = subinstr(`tgt', ",",  ";", .)
		replace `tgt' = subinstr(`tgt', ":",  ";", .)
		// Turn ANY run of whitespace into semicolons.
		// We'll first collapse multiple spaces to single space, then convert space to ";"
		// (Stata doesn't have regex in replace without plugins, so do a two-step)
		// Step 4a: squeeze multiple spaces
		quietly while strpos(`tgt', "  ")>0 {
			replace `tgt' = subinstr(`tgt', "  ", " ", .)
		}
		// Step 4b: single spaces -> ";"
		replace `tgt' = subinstr(`tgt', " ",  ";", .)

		// 5. Remove any accidental leading/trailing semicolons/spaces leftover
		replace `tgt' = subinstr(`tgt', ";;", ";", .)
		quietly while strpos(`tgt', ";;")>0 {
			replace `tgt' = subinstr(`tgt', ";;", ";", .)
		}
		replace `tgt' = subinstr(`tgt', "; ;", ";", .)

		// 6. Strip leading/trailing ";" if they exist so we can re-pad consistently
		// (We'll do this by trimming manually.)
		// leading ";"
		replace `tgt' = substr(`tgt', 2, .) if substr(`tgt',1,1)==";"
		// trailing ";"
		replace `tgt' = substr(`tgt', 1, length(`tgt')-1) if substr(`tgt',-1,1)==";"

		// 7. Final pad with semicolons for exact matching pattern ;code;
		replace `tgt' = ";" + `tgt' + ";" if `tgt' != ""

	end

		
	
	_mkclean ed4 ed4_txt
	order ed4_txt, a(ed3)
	drop ed4

	la var ed4_txt "Reasons for not currently attending school (multi-select; codes)"
	note ed4_txt : Multi-select; stored as codes ;1;6;7;

	#delimit ;
	glo ED4OPT `"
		"Difficulty of getting to school"
		"Illness/disability"
		"Pregnancy"
		"Marriage"
		"High cost of education / Financial concern"
		"Employment"
		"Finished schooling / post-secondary / college"
		"Looking for work"
		"Lack of personal interest"
		"Too young to go to school"
		"Bullying"
		"Family matters"
		"School is pointless"
		"Wasn't learning"
		"Other (specify)"
		"Took a break"
		"Late enrollment"
		"Incomplete requirements"
		"Shift in interest"
		"Did not pass"
		"Temporary pause"
		"Child is afraid to study"
		"Relocation"
		"No slots available"
		"Peer influence"
		"Afraid to socialize"
		"Teacher advised to stop"		
	"';
	#delimit cr

	loc  j = 0
	foreach c of numlist 1/14 96 22 23 24 26 27 28 29 30 31 32 35 36 {
		loc  ++j
		loc  w : word `j' of $ED4OPT
		cap drop ed4_`c'
		g byte ed4_`c' = (strpos(ed4_txt, ";`c';")>0) if ed4_txt!=""
		la var ed4_`c' "Reason: `w'"
		note ed4_`c' : Reason: `w'
		replace ed4_`c' = . if ed4_`c'==0
	}
	order ed4_* , b(ed5a)
	

	la var ed5a "School fees and tuition"
	note  ed5a : Amount spent on [NAME]'s education last AY — School fees and tuition
	la var ed5b "School uniforms and footwear (just for pupils)"
	note  ed5b : Amount spent on [NAME]'s education last AY — Uniforms & footwear
	la var ed5c "Textbooks and other instruction materials"
	note  ed5c : Amount spent on [NAME]'s education last AY — Textbooks & materials
	la var ed5d "Educational supplies (pens, notebooks, etc.)"
	note  ed5d : Amount spent on [NAME]'s education last AY — Supplies
	la var ed5e "Meals and/or lodging"
	note  ed5e : Amount spent on [NAME]'s education last AY — Meals/lodging
	la var ed5f "Building repair, purchase of educational equipment and other similar expenses"
	note  ed5f : Amount spent on [NAME]'s education last AY — Repairs/equipment
	la var ed5g "Gifts to teachers and administrators"
	note  ed5g : Amount spent on [NAME]'s education last AY — Gifts
	la var ed5h "Transportation expenses"
	note  ed5h : Amount spent on [NAME]'s education last AY — Transport
	la var ed5i "Other expenses (do not include tutoring expenses)"
	note  ed5i : Amount spent on [NAME]'s education last AY — Other (exclude tutoring)

	la var ed6 "Received private tutoring during the last 3 months?"
	la def TUT_INC 1 "Yes" 2 "No"
	la val ed6 TUT_INC

	la var ed7 "Amount spent on private tutoring (last 3 months)"	
	note ed7 : Amount spent on tutoring (numeric; asked if ed6==1)
	
	
	cap conf string variable ed8
	if _rc {
		tostring ed8, replace force format(%20.0g)
	}
	replace ed8 = strtrim(ed8)

	_mkclean ed8 ed8_txt
	order ed8_txt, a(ed7)
	drop ed8
	la var ed8_txt "Who tutored (multiple choice)"
	note ed8_txt : Multi-select; stored as codes ;1;2;3;4;
	
	#delimit ;
	glo ED8OPT `"
		"Own teacher"
		"Other teacher at school"
		"Other teacher elsewhere"
		"Not a teacher"
	"';
	#delimit cr

	loc  j = 0
	foreach c of numlist 1/4 {
		loc  ++j
		loc  w : word `j' of $ED8OPT
		cap drop ed8_`c'
		g byte ed8_`c' = (strpos(ed8_txt, ";`c';")>0) if ed8_txt!=""
		la var ed8_`c' "Provider: `w'"
		note ed8_`c' : Provider: `w'
		replace ed8_`c' = . if ed8_`c'==0
	}
	
	
	cap conf string variable ed9
	if _rc {
		tostring ed9, replace force format(%20.0g)
	}
	replace ed9 = strtrim(ed9)

	_mkclean ed9 ed9_txt
	order ed9_txt, a(ed8_txt)
	drop ed9
	la var ed9_txt "Transport to school (multiple choice)"
	note ed9_txt : Transport to school (multi-select string; asked if ed1==1 & ed2 in {1,2,3}
	
	#delimit ;
	glo ED9OPT `"
		"By foot"
		"Used own vehicle (specify)"
		"Van"
		"Bicycle"
		"Motorcycle/Tricycle"
		"Jeepney/Bus"
		"Car/Taxi"
		"Boat"
		"Airplane"
		"Horse or water buffalo "
		"Others (specify)"
		"Train"
		"Truck"
		"Company service"
		"Sports Utility Vehicle/ SUV"
		"Pick Up Truck"
		"Government service"
		"Tractor"
		"Work from Home"
		"Refused to answer"
		"Don't know"	
	"';
	#delimit cr

	loc  j = 0
	foreach c of numlist 1 2 15 3 4 5 6 7 8 9 96 43 44 45 49 50 51 52 97 98 99 {
		loc  ++j
		loc  w : word `j' of $ED9OPT
		cap drop ed9_`c'
		g byte ed9_`c' = (strpos(ed9_txt, ";`c';")>0) if ed9_txt!=""
		la var ed9_`c' "Transport: `w'"
		note ed9_`c' : Mode of transport — `w'
		replace ed9_`c' = . if ed9_`c'==0
	}

	loc  suffixes "a b c d e f g h i j"
	loc  codes    "1 2 3 4 5 6 7 8 9 96"

	loc  i = 1
	foreach s of loc suffixes {
		loc  c : word `i' of `codes'
		cap ren  ed10`s' ed10_`c'
		loc  ++i
	}

	#delimit ;
	glo ED10OPT `"
		"By foot (minutes)"
		"Used own vehicle (minutes)"
		"Bicycle (minutes)"
		"Motorcycle/Tricycle (minutes)"
		"Jeepney/Bus (minutes)"
		"Car/Taxi (minutes)"
		"Boat (minutes)"
		"Airplane (minutes)"
		"Horse or water buffalo (minutes)"
		"Other (specify) (minutes)"	
	"';
	#delimit cr

	loc  j = 0
	foreach c of loc codes {
		loc  ++j
		loc  w : word `j' of $ED10OPT
		la var ed10_`c' "Usual travel time: `w'"
		note   ed10_`c' : Usual travel time for mode — `w'
	}

	la var ed11 "Dominant language used for teaching"
	la def LANG_INST ///
		1 "Bikol/Bicol" ///
		2 "Bisaya/Binisaya" ///
		3 "Cebuano" ///
		4 "English" ///
		5 "Hiligaynon/Ilonggo" ///
		6 "Ilocano" ///
		7 "Kapampangan" ///
		8 "Maguindanao" ///
		9 "Pangasinan/Panggalato" ///
		10 "Tagalog" ///
		11 "Waray" ///
		96 "Others" ///
		99 "Don't know", replace
	la val ed11 LANG_INST
	
	la var ed12 "Highest educational attainment of [HH MEMBER]"
	la def EDU_HIGH ///
		1 "Daycare/Nursery" 2 "Kindergarten" 3 "Grade 1" 4 "Grade 2" 5 "Grade 3" ///
		6 "Grade 4" 7 "Grade 5" 8 "Grade 6" 9 "Grade 7" 10 "Grade 8" ///
		11 "Grade 9" 12 "Grade 10" 13 "Grade 11" 14 "Grade 12" ///
		15 "Pre-school (old curriculum)" 16 "Grade 1 (old)" 17 "Grade 2 (old)" ///
		18 "Grade 3 (old)" 19 "Grade 4 (old)" 20 "Grade 5 (old)" 21 "Grade 6 (old)" ///
		22 "Elementary graduate" 23 "HS 1st year" 24 "HS 2nd year" 25 "HS 3rd year" ///
		26 "HS 4th year" 27 "HS graduate" 28 "ALS Elementary" 29 "ALS High School" ///
		30 "Special needs Elementary" 31 "Special needs High School" ///
		34 "TVET undergraduate" 35 "TVET graduate" 46 "Some college" 47 "Completed college" ///
		43 "Master's degree completed" 45 "Doctorate degree completed" 77 "No schooling", replace
	la val ed12 EDU_HIGH
	
	la var ed13 "Father's highest educational attainment"
	la def EDU_PARENT ///
		1 "None/illiterate" 2 "Primary only" 3 "Some secondary" ///
		4 "Completed high school" 5 "Some college" 6 "Completed college or higher" ///
	   99 "Don't know", replace
	la val ed13 EDU_PARENT

	la var ed14 "Mother's highest educational attainment"
	la val ed14 EDU_PARENT

	order ed*, a(fmid) seq 
	
	
		
		

	la lang ${LNG}
	compress 	
	save "$raw/${dta_file}_${date}_M02_edu.dta", replace
	

	}
		

		
		
		
		
********************************************************************************
**# (A) EMPLOYMENT — with notes on every variable
********************************************************************************
{
    use "$zzz/data.dta", clear
    keep hhid* a1_1-a_duration date

    * Standardize suffix letters on multi-part items before reshape
    foreach l in a b c d {
        cap ren a13*`l' a13`l'*
        cap ren a15*`l' a15`l'*
    }
	
	
	/// DESTRING
	
	destring a3_*, force replace
	
	
    * If instrument used verified-text columns for occupation
    cap ren a4_*_ver a4_txt_*

    * Build long list for reshape
    loc var ""
    foreach v in a1 a2 a3 a4 a4_txt a5 a6 a7 a8 a9 a10 a11 ///
                 a13 a15 a16 a17 a18 a19 a20 a21 a22 a23 {
        foreach i of numlist 1/25 {
            cap ren `v'`i' `v'_`i'
        }
        loc var "`var' `v'_"
    }
    di "`var'"

    * Convert to string for multi-select/text prior to reshape
    tostring a19_* a21_* a4_txt_* , replace force

    * Reshape to long (per-member)
    reshape long `var', i(hhid) j(fmid)

    * Clean names, drop fully empty obs for this module
    ren *_ *
    dropmiss a?, obs force

    * Language layer
    la lang ENG, copy new

    * -------------------------------
    * A1 Worked >=1 hour past week
    * -------------------------------
    la var a1 "Did [NAME] do any work for at least one hour, including work from home or telecommuting, during the past week?"
    note  a1 : Work activity indicator in the last 7 days (1=Yes, 2=No).
    cap la drop YN
    la def YN 1 "Yes" 2 "No", replace
    la val a1 YN

    * -------------------------------
    * A2 Had job/business (even if did not work)
    * -------------------------------
    la var a2 "Although [NAME] did not work, did [NAME] have a job or business during the past week?"
    note  a2 : Job attachment indicator in the last 7 days (1=Yes, 2=No).
    cap la drop JOB_INC
    la def JOB_INC 1 "Yes" 2 "No", replace
    la val a2 JOB_INC

    * -------------------------------
    * A3 Main reason for not working/searching
    * -------------------------------
    la var a3 "What is the main reason why [you/NAME] did not try to find a paid job or start a business in the past week?"
    note  a3 : Single choice; main reason for not working or searching.
    cap la drop REASON_NOWORK
    la def REASON_NOWORK ///
        1 "Applied/searched, waiting" ///
        2 "Awaiting recall" ///
        3 "Waiting for season to start" ///
        4 "Will start new job soon" ///
        5 "Tired of looking / no jobs" ///
        6 "No jobs match skills" ///
        7 "Too young/old" ///
        8 "In studies/training" ///
        9 "Family responsibilities" ///
        10 "Agri/fishing family use" ///
        11 "Disability/illness" ///
        12 "Retired/other income" ///
		21 "Operations of my job stopped" ///
		24	"Lack of Financial Capacity" ///
		33	"Lazy" ///
		34	"Being bullied" ///
		36	"Serving in the barangay" ///
		38	"Still lacking requirements" ///
		39	"Too much rain" /// 
		40	"Focused on religious duties or obligations" ///
		43	"In prison" ///
        96 "Other (specify)", replace
    la val a3 REASON_NOWORK

    * -------------------------------
    * A4 Primary occupation (coded) + text
    * -------------------------------
    la var a4 "What was [NAME]'s primary occupation during the past week?"
    note  a4 : Occupation code (ISCO or national). See occupation.do for coding.
    quietly run "$ado/occupation.do"
    la val a4 PRI_OCC
    la var a4_txt "Primary occupation (verbatim text)"
    note  a4_txt : Verbatim response used for occupation coding.

    * -------------------------------
    * A5 Industry/sector
    * -------------------------------
    la var a5 "In what kind of industry did [NAME] work during the past week?"
    note  a5 : Industry/sector classification; single choice.
    cap la drop INDUSTRY
    la def INDUSTRY ///
        1  "Agriculture/Forestry/Fishing" ///
        2  "Wholesale/retail trade; repair" ///
        3  "Accommodation/food service" ///
        4  "Admin/support services" ///
		5  "Professional, Scientific and Technical Activities" ///
		6	"Education" ///
		7	"Water Supply; Sewerage, Waste Management and Remediation Activities" ///
		8	"Other Service Activities" ///
		9	"Construction" ///
		10	"Transportation and Storage" ///
		12	"Arts, Entertainment and Recreation" ///
		18	"Real Estate Activities" ///
		19	"Manufacturing" ///
		20	"Information and Communication" ///
		23	"Financial and Insurance Activities" ///
		26	"Public Administration and Defense; Compulsory Social Security" ///
		27	"Mining and Quarrying" ///
		37	"Human Health and Social Work Activities" ///
		56	"Administrative and Support Service Activities" ///
		65	"Private company" ///
		66	"Personal services" ///		
        96 "Other (specify)", replace
    la val a5 INDUSTRY

    * -------------------------------
    * A6 Class of worker
    * -------------------------------
    la var a6 "What was the class of worker of [NAME] during the past six months?"
    note  a6 : Employment status in main job; single choice.
    cap la drop CLASS_WORK
    la def CLASS_WORK ///
        1 "Private household" ///
        2 "Private establishment" ///
        3 "Government" ///
        4 "Self-employed, no employee" ///
        5 "Employer in business/farm" ///
        6 "Worked with pay in family business/farm" ///
        7 "Unpaid in family business/farm" ///
        9 "None", replace
    la val a6 CLASS_WORK

    * -------------------------------
    * A7 Subsistence orientation (agri/fishing)
    * -------------------------------
    la var a7 "Are the (farming, animal, fishing) products that [NAME] works on intended…?"
    note  a7 : Output orientation of activity; single choice.
    cap la drop SUBSISTENCE
    la def SUBSISTENCE ///
        1 "Only for sale" ///
        2 "Mainly for sale" ///
        3 "Mainly for family use" ///
        4 "Only for family use" ///
        97 "Cannot say", replace
    la val a7 SUBSISTENCE

    * -------------------------------
    * A8 Gig work
    * -------------------------------
    la var a8 "Is [NAME]'s work a gig work? (short-term, freelance, temp jobs, often via platforms)"
    note  a8 : Gig/temporary/platform-style work identification.
    cap la drop GIGWORK
    la def GIGWORK 1 "Yes" 2 "No" 99 "Don't know", replace
    la val a8 GIGWORK

    * -------------------------------
    * A9 Digital platform type
    * -------------------------------
    la var a9 "What is the digital platform of [NAME]'s work?"
    note  a9 : Platform modality (web-based vs loc ation-based).
    cap la drop DIGIPLATFORM
    la def DIGIPLATFORM 1 "Online web-based" 2 "loc ation-based" -99 "Don't know", replace
    la val a9 DIGIPLATFORM

    * -------------------------------
    * A10 Usual days worked (numeric)
    * -------------------------------
    la var a10 "How many days does [NAME] usually work in a week?"
    note  a10 : Numeric days per week; non-negative.

    * -------------------------------
    * A11 Usual hours worked (numeric)
    * -------------------------------
    la var a11 "How many hours does [NAME] usually work in a week, even for an hour?"
    note  a11 : Numeric weekly hours; non-negative.

    * -------------------------------
    * A12 Lost job in past 30 days
    * -------------------------------
    la var a12 "Has any member of your household lost their job or stopped working in the past 30 days?"
    note  a12 : Household job loss incidence in last 30 days; single choice.
    cap la drop JOBLOSS
    la def JOBLOSS 1 "Yes" 2 "No", replace
    la val a12 JOBLOSS

    * -------------------------------
    * A13 Who lost job (roster selection)
    * -------------------------------
    la var a13 "Who lost their job or otherwise stopped working over the past 30 days?"
	la val a13 JOBLESS
    note  a13 : Roster selection of member(s) who lost job in last 30 days.

    * -------------------------------
    * A14 Looking for job in past 30 days
    * -------------------------------
    la var a14 "Is any member of your household currently looking for a job in the PAST 30 DAYS?"
    note  a14 : Job search status in last 30 days; single choice.
    cap la drop JOBSEARCH
    la def JOBSEARCH ///
        1 "Yes, looking for a new job" ///
        2 "Yes, looking for more work" ///
        3 "No", replace
    la val a14 JOBSEARCH

    * -------------------------------
    * A15 Who is looking for more work (roster selection)
    * -------------------------------
    la var a15 "Who is currently looking for more work?"
	la val a15 JOBLESS
    note  a15 : Roster selection for members seeking more work.

    * -------------------------------
    * A16 Contract type
    * -------------------------------
    la var a16 "Do you/NAME have a written contract for the work or is it an oral agreement?"
    note  a16 : Employment contract type; single choice.
    cap la drop CONTRACT
    la def CONTRACT 1 "Written" 2 "Verbal" 3 "No contract" 99 "Don't know", replace
    la val a16 CONTRACT

    * -------------------------------
    * A17 Contract duration
    * -------------------------------
    la var a17 "How long is your/NAME's current contract or agreement?"
    note  a17 : Contract duration category; single choice.
    cap la drop CONTRACT_DUR
    la def CONTRACT_DUR ///
        1 "<1 month" ///
        2 "1–<6 months" ///
        3 "6–<12 months" ///
        4 "≥1 year" ///
        5 "No duration" ///
        99 "Don't know", replace
    la val a17 CONTRACT_DUR

    * -------------------------------
    * A18 Employer contributions
    * -------------------------------
    la var a18 "Does [NAME]'s employer pay contributions to Pension/Unemployment Insurance?"
    note  a18 : Employer social contributions; single choice.
    cap la drop CONTRIB
    la def CONTRIB 1 "Yes" 2 "No" 99 "Don't know", replace
    la val a18 CONTRIB

    * -------------------------------
    * A19 Employment benefits (multi-select string -> *_txt + dummies)
    * -------------------------------
    cap conf string variable a19
    if _rc tostring a19, replace force format(%20.0g)
    replace a19 = strtrim(a19)

    _mkclean a19 a19_txt
    order a19_txt, a(a19)
    drop a19

    la var a19_txt "Which employment benefits does [NAME] have access to? (multi-select; codes)"
    note  a19_txt : Multiple answers allowed; codes like ;1;3;5; stored in a19_txt.

    #delimit ;
    glo A19OPT `"
		"Workplace pension plan"
		"Paid leave (vacation/annual, sick, maternity/paternity)"
		"SSS/GSIS"
		"PhilHealth"
		"Private health insurance/HMO"
		"Do not use this codes, (STG codes for others) for recode"
		"Life Plan"
		"Pag-ibig"
		"Incentives"
		"Tips"
		"Crop insurance"
		"Senior Citizen benefit"
		"Local government project"
		"None of the above"
    "';
    #delimit cr

    loc A19codes "1 2 3 4 5 96 11 12 13 15 17 18 19 7"
    loc j = 0
    foreach c of loc A19codes {
        loc ++j
        loc w : word `j' of $A19OPT
        cap drop a19_`c'
        g byte a19_`c' = (strpos(a19_txt, ";`c';")>0) if a19_txt!=""
        la var a19_`c' "Employment benefit: `w'"
        note  a19_`c' : Selected employment benefit — `w'
        replace a19_`c' = . if a19_`c'==0
    }
    order a19_*, b(a20)

    * -------------------------------
    * A20 For whom did [NAME] work
    * -------------------------------
    la var a20 "For whom did [NAME] work?"
    note  a20 : Client/ownership structure for self-employment.
    cap la drop FORWHOM
    la def FORWHOM 1 "Single client" 2 "Multiple clients" 3 "Subcontracting company/person" ///
                   4 "Agency/broker/intermediary" 5 "Website/app matching", replace
    la val a20 FORWHOM

    * -------------------------------
    * A21 Mode of transport to work (multi-select string)
    * -------------------------------
    cap conf string variable a21
    if _rc tostring a21, replace force format(%20.0g)
    replace a21 = strtrim(a21)

    _mkclean a21 a21_txt
    order a21_txt, a(a21)
    drop a21

    la var a21_txt "What mode of transport does [NAME] usually use to and from work? (multi-select; codes)"
    note  a21_txt : Multiple answers allowed; codes like ;1;5;96; stored in a21_txt.

    #delimit ;
    glo A21OPT `"
		"By foot"
		"Used own vehicle (specify)"
		"Van"
		"Bicycle"
		"Motorcycle/Tricycle"
		"Jeepney/Bus"
		"Car/Taxi"
		"Boat"
		"Airplane"
		"Horse or water buffalo "
		"Others (specify)"
		"Train"
		"Truck"
		"Company service"
		"Sports Utility Vehicle/ SUV"
		"Pick Up Truck"
		"Government service"
		"Tractor"
		"Work from Home"
		"Refused to answer"
		"Don't know"
    "';
    #delimit cr

    loc A21codes "1 2 15 3 4 5 6 7 8 9 96 43 44 45 49 50 51 52 97 98 99"
    loc j = 0
    foreach c of loc A21codes {
        loc ++j
        loc w : word `j' of $A21OPT
        cap drop a21_`c'
        g byte a21_`c' = (strpos(a21_txt, ";`c';")>0) if a21_txt!=""
        la var a21_`c' "Mode of transport: `w'"
        note  a21_`c' : Selected transport mode — `w'
        replace a21_`c' = . if a21_`c'==0
    }
    order a21_*, b(a22)

    * -------------------------------
    * A22 Travel time to work (minutes; numeric)
    * -------------------------------
    la var a22 "How long does it take [NAME] to travel to the workplace from home? (minutes)"
    note  a22 : Numeric travel time in minutes (non-negative; outliers to be reviewed).
    cap confirm numeric variable a22
    if _rc {
        replace a22 = strtrim(a22)
        destring a22, replace ignore(" ,.;")
    }
	la def NEGATE -99 "Don't know", replace
    la val a22 NEGATE

    * -------------------------------
    * A23 Transport cost (numeric)
    * -------------------------------
    la var a23 "How much does [NAME] usually pay for transport to and from work?"
    note  a23 : Numeric usual transport expenditure (period as specified in questionnaire).
    cap confirm numeric variable a23
    if _rc {
        replace a23 = strtrim(a23)
        destring a23, replace ignore(" ,.;")
    }
	la val a23 NEGATE

    * Ordering helpers
    order a*, a(fmid) seq

    la lang ${LNG}
    compress
    save "$raw/${dta_file}_${date}_M03_emp.dta", replace
}

********************************************************************************
**# (IA) INCOME — Regular & Seasonal Wages (IA1–IA7)  
********************************************************************************
{
    use "$zzz/data.dta", clear
    keep hhid* ia* d* date
	cap drop dw*

	loc  var ""
	foreach v in ia2 ia3a ia3b ia3c ia3d ia3e ia3f ia3ab ia3cf ///
		ia5 ia6a ia6b ia6c ia6d ia6e ia6f ia6ab ia6cf ///
		ia7 d5a1 d6 d8  d9  ///
		d10a d10b d12 d12a ///
		d13 d13a d14 d18 d19 d20 {
		foreach i of numlist 1/25 {
		
			cap ren `v'`i' `v'_`i'
		}
		loc  var "`var' `v'_"
	
	}  	
	di "`var'"
	
	tostring d18_*, force replace 
	reshape long `var' ///
		, i(hhid) j(fmid)  
		
	dropmiss d5a1_ d6_ d8_ d9_ d10a_ d10b_ d12_ d12a_ d13_ d13a_ d14_, obs force 	
	cap drop d*
	
	ren *_ * 

    la lang ENG, copy new

    * -------------------------------
    * IA1 Incidence of regular income
    * -------------------------------
    la var ia1 "During the past 6 months, did you/any HH member receive regular income in cash/in-kind (incl. allowances, bonuses, housing, food, grocery, clothing, medical)?"
    note  ia1 : Ask all; period auto-scripted by interview date.
    la def YN 1 "Yes" 2 "No", replace
    la val ia1 YN

    * -------------------------------
    * IA2 HH member receives regular income (per-member Yes/No)
    * -------------------------------
    la var ia2 "Does [HH MEMBER] receive regular income (past 6 months)?"
    note  ia2 : Per-member single choice (1=Yes, 2=No); asked if IA1==1.
    la def INC_REGULAR_MEMBER 1 "Yes" 2 "No", replace
    la val ia2 INC_REGULAR_MEMBER

    * -------------------------------
    * IA3 Regular earnings (components; numeric)
    * -------------------------------
    la var ia3a  "Regular basic salaries & wages (cash)"
    la var ia3b  "Regular other earnings (bonus/commission/gratuities/honoraria) (cash)"
    la var ia3c  "Regular basic salaries & wages (in-kind)"
    la var ia3d  "Regular housing (in-kind)"
    la var ia3e  "Regular food (in-kind)"
    la var ia3f  "Regular other goods/services (transport/education/clothing/medical…) (in-kind)"
    la var ia3ab "Total cash earnings (regular)"
    la var ia3cf "Total in-kind (regular)"

    * -------------------------------
    * IA4 Incidence of seasonal/occasional income
    * -------------------------------
    la var ia4 "During the past 6 months, did you/any HH member receive seasonal/occasional income (cash or in-kind)?"
    note  ia4 : Typically asked if IA1==2.
    la val ia4 YN

    * -------------------------------
    * IA5 Member receives seasonal/occasional income (per-member Yes/No)
    * -------------------------------
    la var ia5 "Does [HH MEMBER] receive seasonal/occasional income?"
    note  ia5 : Per-member single choice (1=Yes, 2=No); asked if IA4==1.
    la val ia5 YN

    * -------------------------------
    * IA6 Seasonal/occasional earnings (components; numeric)
    * -------------------------------
    la var ia6a  "Seasonal/occasional basic salaries & wages (cash)"
    la var ia6b  "Seasonal/occasional other earnings (bonus/commission/gratuities/honoraria) (cash)"
    la var ia6c  "Seasonal/occasional basic salaries & wages (in-kind)"
    la var ia6d  "Seasonal/occasional housing (in-kind)"
    la var ia6e  "Seasonal/occasional food (in-kind)"
    la var ia6f  "Seasonal/occasional other goods & services (transport/education/clothing/medical…) (in-kind)"
    la var ia6ab "Total cash earnings (seasonal/occasional)"
    la var ia6cf "Total in-kind (seasonal/occasional)"

    * -------------------------------
    * IA7 Gig work income (subset of IA3+IA6; numeric, may be unknown)
    * -------------------------------
    la var ia7 "Of [NAME]'s total earnings (IA3 + IA6), how much is from gig work?"
    note  ia7 : Numeric; -99 = Don't know (per instrument).
    la def INC_GIG -99 "Don't know", replace
    la val ia7 INC_GIG

    la lang ${LNG}
    compress
    save "$raw/${dta_file}_${date}_M04_inc1.dta", replace
}


********************************************************************************
**# (IB/IC/ID/IE) INCOME_2 — Non-wage / Transfers / Rentals / Benefits / Other
********************************************************************************
{
    use "$zzz/data.dta", clear
    keep hhid* ib* ic* id* ie* i_duration date

    la lang ENG, copy new
    la def INC2_YN 1 "Yes" 2 "No", replace

    * ================================================================
    * B. NET SHARE of crops/fishing/livestock from other households
    * ================================================================
    * IB1 — incidence (Yes/No), items 1..9
    cap la var ib1_1 "During past 6 months: Net share — RICE (1=Yes,2=No)"
    cap la var ib1_2 "During past 6 months: Net share — CORN (1=Yes,2=No)"
    cap la var ib1_3 "During past 6 months: Net share — OTHER CEREALS (1=Yes,2=No)"
    cap la var ib1_4 "During past 6 months: Net share — FRUIT (1=Yes,2=No)"
    cap la var ib1_5 "During past 6 months: Net share — VEGETABLES (1=Yes,2=No)"
    cap la var ib1_6 "During past 6 months: Net share — FISHING & AQUACULTURE (1=Yes,2=No)"
    cap la var ib1_7 "During past 6 months: Net share — LIVESTOCK & POULTRY (1=Yes,2=No)"
    cap la var ib1_8 "During past 6 months: Net share — LIVESTOCK & POULTRY PRODUCTS (1=Yes,2=No)"
    cap la var ib1_9 "During past 6 months: Net share — OTHERS (specify) (1=Yes,2=No)"
    cap la val ib1_? INC2_YN

	cap la var ib2_1 "Received Amount in Pesos - RICE"
	cap la var ib2_2 "Received Amount in Pesos - CORN"
	cap la var ib2_3 "Received Amount in Pesos - OTHER CEREALS"
	cap la var ib2_4 "Received Amount in Pesos - FRUIT"
	cap la var ib2_5 "Received Amount in Pesos - VEGETABLES"
	cap la var ib2_6 "Received Amount in Pesos - FISHING & AQUACULTURE "
	cap la var ib2_7 "Received Amount in Pesos - LIVESTOCK & POULTRY"
	cap la var ib2_8 "Received Amount in Pesos - LIVESTOCK & POULTRY PRODUCTS"
	cap la var ib2_9 "Received Amount in Pesos - OTHERS"
	

    * ================================================================
    * C. OTHER SOURCES OF INCOME
    * C1. From abroad (ic1_1..ic1_3) + A/B aliases
    * ================================================================
    cap la var ic1_1 "Past 6 months: Cash from family members who are OCW/working abroad (gross)"
    cap la var ic1a  "Past 6 months: Cash from family members who are OCW/working abroad (gross)"
    cap la var ic1_2 "Past 6 months: In-kind gifts/support from OFW/others abroad (gross)"
    cap la var ic1b  "Past 6 months: In-kind gifts/support from OFW/others abroad (gross)"
    cap la var ic1_3 "Past 6 months: Cash gifts/support/relief from abroad (non-family/organizations/governments)"
    cap la var ic1c  "Past 6 months: Cash gifts/support/relief from abroad (non-family/organizations/governments)"

    * ================================================================
    * C2. Domestic transfers: incidence, sources (multi), amounts
    * ================================================================
    la var ic3 "During past 6 months: Any gift/support/assistance/relief from a source in the Philippines?"
    la val ic3 INC2_YN

    * Sources (multi-select); keep original name ic4; add cleaned txt + dummies
    cap conf string variable ic4
    if _rc tostring ic4, replace force format(%20.0g)
    replace ic4 = strtrim(ic4)

    _mkclean ic4 ic4_txt
    order ic4_txt, a(ic4)
    drop ic4
    la var ic4_txt "Domestic support source(s) (multi-select; codes)"

    * Labels by code (1..12, 13=Other)
    loc S4_1  "Family member who would otherwise be part of this household"
    loc S4_2  "Other relatives or friends"
    loc S4_3  "Government institutions"
    loc S4_4  "Regular or Modified CCT/Pantawid/4Ps"
    loc S4_5  "Assistance to Individuals in Crisis Situation (AICS)"
    loc S4_6  "Ayuda para sa Kapos ang Kita Program (AKAP)"
    loc S4_7  "Programs supporting rice or other agriculture"
    loc S4_8  "Walang Gutom 2027: Philippine Food Stamp"
    loc S4_9  "Scholarships / financial assistance for schooling"
    loc S4_10 "Unemployment insurance"
    loc S4_11 "Other social programs (senior pension, medical assistance, microenterprise, solo parent subsidy)"
    loc S4_12 "Private institutions (Churches, NGOs)"
	loc S4_15 "Political parties"
	loc S4_23 "Government candidates"
    loc S4_96 "Other (specify)"

    foreach k in 1 2 3 4 5 6 7 8 9 10 11 12 15 23 96{
        cap drop ic4_`k'
        g byte ic4_`k' = (strpos(ic4_txt, ";`k';")>0) if ic4_txt!=""
        replace ic4_`k' = . if ic4_`k'==0
        loc L = "`S4_`k''"
        cap la var ic4_`k' "Domestic support source: `L'"
    }
	
	order ic4_1-ic4_12 ic4_15 ic4_23 ic4_96, a(ic4_txt)
	
	
	/// IN PESOS
	
	la var ic5_1 "Received Amount in Pesos: Family member who would otherwise be part of this household"
	la var ic5_2 "Received Amount in Pesos: Other relatives or friends"
	la var ic5_3 "Received Amount in Pesos: Government institutions"
	la var ic5_4 "Received Amount in Pesos: Regular or Modified CCT/Pantawid/4Ps"
	la var ic5_5 "Received Amount in Pesos: Assistance to Individuals in Crisis Situation (AICS)"
	la var ic5_6 "Received Amount in Pesos: Ayuda para sa Kapos ang Kita Program (AKAP)"
	la var ic5_7 "Received Amount in Pesos: Programs supporting rice or other agriculture"
	la var ic5_8 "Received Amount in Pesos: Walang Gutom 2027: Philippine Food Stamp"
	la var ic5_9 "Received Amount in Pesos: Scholarships / financial assistance for schooling"
	la var ic5_10 "Received Amount in Pesos: Unemployment insurance"
	la var ic5_11 "Received Amount in Pesos: Other social programs"
	la var ic5_12 "Received Amount in Pesos: Private institutions (Churches, NGOs)"
	la var ic5_13 "Received Amount in Pesos: Other"
	

    * ================================================================
    * C3. Rentals (non-agri): incidence & amounts
    * ================================================================
    la var ic6 "During past 6 months: Any rentals received (non-agri land/buildings/spaces/other properties)?"
    la val ic6 INC2_YN

    cap la var ic7_1 "Rental income received in CASH (past 6 months)"
    cap la var ic7a  "Rental income received in CASH (past 6 months)"
    cap la var ic7_2 "Rental income received IN KIND (past 6 months)"
    cap la var ic7b  "Rental income received IN KIND (past 6 months)"

    * ================================================================
    * C4. Pension / Social Security / Other benefits
    * ================================================================
    la var ic8a "Past 6 months: Pension (monthly)—GSIS/SSS/abroad (1=Yes,2=No)"
    la var ic8b "Past 6 months: Social security benefits (1=Yes,2=No)"
    la var ic8c "Past 6 months: Other (employee compensation, retirement payout) (1=Yes,2=No)"
    la val ic8a INC2_YN
    la val ic8b INC2_YN
    la val ic8c INC2_YN

    * Amounts (ic9a/b/c and ic9_1.._3 aliases)
    cap la var ic9a  "Amount received in cash: PENSION (past 6 months)"
    cap la var ic9_1 "Amount received in cash: PENSION (past 6 months)"
    cap la var ic9b  "Amount received in cash: SOCIAL SECURITY BENEFITS (past 6 months)"
    cap la var ic9_2 "Amount received in cash: SOCIAL SECURITY BENEFITS (past 6 months)"
    cap la var ic9c  "Amount received in cash: OTHER (employee compensation, retirement payout) (past 6 months)"
    cap la var ic9_3 "Amount received in cash: OTHER (employee compensation, retirement payout) (past 6 months)"

    * ================================================================
    * D. OTHER income (interest/dividends/sales/winnings…)
    * ================================================================
    la var id1 "During past 6 months: Any OTHER income (interest, dividends, property sale profits, winnings, etc.)?"
    la val id1 INC2_YN

    cap la var id2_1 "OTHER income received in CASH (past 6 months)"
    cap la var id2a  "OTHER income received in CASH (past 6 months)"
    cap la var id2_2 "OTHER income received IN KIND (past 6 months)"
    cap la var id2b  "OTHER income received IN KIND (past 6 months)"

    * ================================================================
    * E. FAMILY SUSTENANCE activities (incidence + amounts)
    * ================================================================
    la var ie1a "Produced mainly for home consumption — Fishing/gathering shells/snail/seaweeds/corals (past 6 months)"
    la var ie1b "Produced mainly for home consumption — Logging/gathering forest products (e.g., firewood)"
    la var ie1c "Produced mainly for home consumption — Hunting and trapping"
    la var ie1d "Produced mainly for home consumption — Farming/gardening"
    la var ie1e "Produced mainly for home consumption — Raising livestock and poultry"
    la val ie1? INC2_YN
    la val ie1b INC2_YN
    la val ie1c INC2_YN
    la val ie1d INC2_YN
    la val ie1e INC2_YN

    la var ie2a "Total net receipts (past 6 months): Fishing/gathering shells/snail/seaweeds/corals"
    la var ie2b "Total net receipts (past 6 months): Logging/gathering forest products (e.g., firewood)"
    la var ie2c "Total net receipts (past 6 months): Hunting and trapping"
    la var ie2d "Total net receipts (past 6 months): Farming/gardening"
    la var ie2e "Total net receipts (past 6 months): Raising livestock and poultry"

    order ie1a ie2a ie1b ie2b ie1c ie2c ie1d ie2d ie1e ie2e, after(id2b)

    la lang ${LNG}
    compress
    save "$raw/${dta_file}_${date}_M04_inc2.dta", replace
}


********************************************************************************
**# (F) BANKING / FINANCE — F1–F12  
********************************************************************************
{
    use "$zzz/data.dta", clear
    keep hhid* f1-f12 f_duration date
    dropmiss hhid, obs force

    la lang ENG, copy new

    la def YN 1 "Yes" 2 "No", replace
    la def YNR 1 "Yes" 2 "No" 98 "Refused to answer", replace
    la def YNRD 1 "Yes" 2 "No" 98 "Refused to answer" 99 "Don't know", replace

    * -------------------------------
    * F1 Deposit in bank account
    * -------------------------------
    la var f1 "Has anyone in your household received or deposited money into a formal bank account over the PAST 30 DAYS?"
    note  f1 : Ask all; categorical single choice
    la val f1 YNR 

    * -------------------------------
    * F2 Deposit in mobile banking / e-wallet
    * -------------------------------
    la var f2 "Has anyone in your household received or deposited money into Mobile Money service or an electronic wallet service over the PAST 30 DAYS?"
    note  f2 : Ask all; categorical single choice
    la val f2 YNR

    * -------------------------------
    * F3 Incidence of saving (P30D)
    * -------------------------------
    la var f3 "Given your financial commitments, were you able to save some money for the future over the PAST 30 DAYS?"
    note  f3 : Ask all; categorical single choice
    la val f3 YNR

    * -------------------------------
    * F4 Member of a savings group
    * -------------------------------
    la var f4 "Are you or any member of your household a member of a savings group/paluwagan?"
    note  f4 : Ask all; categorical single choice
    la val f4 YNR

    * -------------------------------
    * F5 Has credit/debit card
    * -------------------------------
    la var f5 "Does anyone in your household have a credit/debit card?"
    note  f5 : Ask all; categorical single choice
    la val f5 YNR

    * -------------------------------
    * F6 Emergency expense capacity (PHP 300,000)
    * -------------------------------
    la var f6 "Could your household currently pay an emergency expense of PhP300,000, using cash, savings, or other resources on-hand?"
    note  f6 : Ask all; categorical single choice
    la val f6 YNR

    * -------------------------------
    * F7 Applied for a loan (gate for F8–F10)
    * -------------------------------
    la var f7 "Did you or any other member of your household apply or try to take on credit or a loan in the past 30 days?"
    note  f7 : Ask all; gate question
    la val f7 YNRD

    * -------------------------------
    * F8 Purpose of loan (MULTIPLE CHOICE; keep string)
    * -------------------------------
    cap conf irm string variable f8
    if _rc {
        tostring f8, replace force format(%20.0g)
    }
    replace f8 = strtrim(f8)

    _mkclean f8 f8_txt
    order f8_txt, a(f8)
    drop f8

    la var f8_txt "For what purpose was the loan taken? (multi-select; codes)"
    note  f8_txt : Ask if F7==1; codes stored as ;1;…; (largest loan context)

    #delimit ;
    glo F8OPT `"
		"Housing"
		"Car/transportation"
		"Food"
		"Other consumption"
		"Business"
		"Education"
		"Health"
		"Savings"
		"Gadgets"
		"Utilities"
		"Allowance"
		"Farming / agriculture"
		"Insurance"
		"To pay for another loan"
		"Unexpected bills"
		"Don't know"
		"Others"
    "';
    #delimit cr

    * Codes as per your prior frame: 1 2 3 4 5 6 7 96 99
    loc F8codes "1 2 3 4 5 6 7 11 16 17 18 20 21 24 25 99 96"
    loc j = 0
    foreach c of loc F8codes {
        loc ++j
        loc w : word `j' of $F8OPT
        cap drop f8_`c'
        g byte f8_`c' = (strpos(f8_txt, ";`c';")>0) if f8_txt!=""
        la var f8_`c' "Loan purpose: `w'"
        note  f8_`c' : Loan purpose — `w'
        replace f8_`c' = . if f8_`c'==0
    }

    * -------------------------------
    * F9 Where applied for the (largest) loan (SINGLE CHOICE)
    * -------------------------------
    la var f9 "To which institution or person did you or any other member of your household apply for the largest loan or credit?"
    note  f9 : Ask if F7==1; single choice
    la def FIN_LOANSRC ///
        1 "Formal financial institution" ///
        2 "Private individuals" ///
        3 "Mobile/online digital services" ///
        4 "Government program" ///
        5 "Informal lender (5-6)" ///
        96 "Others" ///
        99 "Don't know", replace
    la val f9 FIN_LOANSRC

    * -------------------------------
    * F10 Loan approved (SINGLE CHOICE)
    * -------------------------------
    la var f10 "Was the loan approved?"
    note  f10 : Ask if F7==1; single choice
    la val f10 YNRD 


    * -------------------------------
    * F11 Has other loans outstanding (SINGLE CHOICE)
    * -------------------------------
    la var f11 "Do you or any other member of your household have any other loan or credit that still needs to be repaid?"
    note  f11 : Ask all; single choice
    la val f11 YNRD


    * -------------------------------
    * F12 Who to approach in severe financial difficulty (SINGLE CHOICE)
    * -------------------------------
    la var f12 "Who would you turn to first if you were in a situation of severe financial (cash) difficulty?"
    note  f12 : Ask all; single choice
    la def FIN_HELP ///
        1 "Family" ///
        2 "Friends" ///
        3 "Religious leader" ///
        4 "Formal financial institution" ///
        5 "Mobile/online digital services" ///
        6 "Government program" ///
        7 "Informal lender (5-6)" ///
		11 "Boyfriend" ///
        96 "Other (specify)", replace
    la val f12 FIN_HELP

	order f*, seq a(hhid)
 
    la lang ${LNG}
    compress
    save "$raw/${dta_file}_${date}_M05_fin.dta", replace
}

********************************************************************************
**# (M) MIGRATION — M1–M10  
********************************************************************************
{
    use "$zzz/data.dta", clear
    keep hhid* m1_1-m_duration date

    foreach l in a b c {
        cap ren m8a*`l' m8a`l'*
        cap ren m8b*`l' m8b`l'*
        cap ren m8c*`l' m8c`l'*
        cap ren m8d*`l' m8d'*
        cap ren m10*`l' m10`l'*
    }

    loc var ""
    foreach v in m1 m2 m3 m4 m5 m7 m8 m8a m8b m8c m9 m10 m10b m10c {
        forvalues i = 1/25 {
            cap ren `v'`i' `v'_`i'
        }
        loc var "`var' `v'_"
    }
    di "`var'"

    tostring m8_* m10_*, replace force
    reshape long `var', i(hhid) j(fmid)

    ren *_ *
	dropmiss m1 m2 m3 m5 m7 m8a m8b m8c m9 m10b m10c, obs force 	

    la lang ENG, copy new

    * -------------------------------
    * M1 Ever experienced migration
    * -------------------------------
    la var m1 "Did [NAME] ever move and reside continuously for 3+ months in a different city/province/country than current?"
    note  m1 : Single choice — lifetime migration experience
    la def MIG_EVER ///
        1 "Yes, within the Philippines" ///
        2 "Yes, abroad" ///
        3 "Yes, both within the Philippines and abroad" ///
        4 "No", replace
    la val m1 MIG_EVER

    g byte m1_migrant = inlist(m1,1,2,3) if !missing(m1)
    la var m1_migrant "Tag from M1 (1–3 = migrant, 4 = non-migrant)"
    la def MIG_TAG 0 "NON-MIGRANT" 1 "MIGRANT", replace
    la val m1_migrant MIG_TAG

    * -------------------------------
    * M2 OFW status
    * -------------------------------
    la var m2 "Was/Is [NAME] an OFW?"
    note  m2 : Current/last 12 months vs earlier vs never
    la def MIG_OFW ///
        1 "Yes, currently / within last 12 months" ///
        2 "Yes, prior to the last 12 months" ///
        3 "No", replace
    la val m2 MIG_OFW

    * -------------------------------
    * M3 Returned OFW — sought work locally
    * -------------------------------
    la var m3 "If returned OFW: Did [NAME] look for work here?"
    note  m3 : Ask if M2==1 or 2
    la def MIG_RETSEEK ///
        1 "Yes, found work" ///
        2 "Yes, did not find work" ///
        3 "No, did not look for work", replace
    la val m3 MIG_RETSEEK

    * -------------------------------
    * M4 Country of destination
    * -------------------------------
    la var m4 "To which country did [NAME] go?"
    note  m4 : Country code or free text
		cap qui run "$ado/migratecountry.do"
	cap la val m4 MIGRATE_COUNTRY

    * -------------------------------
    * M5 Main reason for moving
    * -------------------------------
    la var m5 "What is [NAME]'s main reason for moving?"
    note  m5 : Single choice
    la def MIG_REASON ///
        1  "Schooling" ///
        2  "Employment/Job change/Relocation" ///
        3  "Family business succession" ///
        4  "Finish contract" ///
        5  "Retirement" ///
        6  "Housing-related reasons" ///
        7  "Living environment" ///
        8  "Commuting-related reasons" ///
        9  "To live with parents" ///
        10 "To join spouse/partner" ///
        11 "To live with children" ///
        12 "Marriage" ///
        13 "Divorce/Annulment/Separation" ///
        14 "Health-related reasons" ///
        15 "Conflict or violence" ///
        96 "Others", replace
    la val m5 MIG_REASON

    * -------------------------------
    * M6 Any HH member 15+ considering migration
    * -------------------------------
    la var m6 "Is any HH member age 15+ considering migrating within the next year?"
    note  m6 : Ask all; gate for M7/M8
    la def MIG_CONSIDER 1 "Yes" 2 "No", replace
    la val m6 MIG_CONSIDER

    * -------------------------------
    * M7 [NAME] considering migration
    * -------------------------------
    la var m7 "Is [NAME] considering migration?"
    note  m7 : Ask if M6==1; per-member single choice
    la val m7 MIG_CONSIDER

    * -------------------------------
    * M8 Where likely to migrate
    * -------------------------------
    la var m8 "Likely destination level (country/province/city)"
    note  m8 : Optional classifier
	destring m8 m10, replace force
	la def LIKELY_DEST ///
		1 "Country" ///
		2 "Province" ///
		3 "City/Municipality" ///
		4 "Undecided" ///
		, replace
	la val m8 LIKELY_DEST
	
    la var m8a "Destination country"
	cap qui run "$ado/migratecountry.do"
	cap la val m8a MIGRATE_COUNTRY
    la var m8b "Destination province"
    qui run "$ado/province.do"
    la val m8b PROV
    la var m8c "Destination city/municipality"
    qui run "$ado/city.do"
    la val m8c CITY

    * -------------------------------
    * M9 Internal displacement reason
    * -------------------------------
    la var m9 "In the past 12 months, did [NAME] move here due to any of the following?"
    note  m9 : Single choice — internal displacement reason
    la def MIG_DISPLACE ///
        1 "No" ///
        2 "Yes, natural calamities" ///
        3 "Yes, man-made disaster/event" ///
        4 "Yes, conflict or violence" ///
        5 "Yes, relocation due to other reasons", replace
    la val m9 MIG_DISPLACE

    * -------------------------------
    * M10 Previous area (origin)
    * -------------------------------
    la var m10 "Previous area (overall)"
	la def PREV_AREA ///
		2 "Province" ///
		3 "City/Municipality" ///
		, replace
	la val m10 PREV_AREA
    la var m10b "Previous area — Province"
    la val m10b PROV
    la var m10c "Previous area — City/Municipality"
    la val m10c CITY


    la lang ${LNG}
    compress
    save "$raw/${dta_file}_${date}_M06_mig.dta", replace
}

********************************************************************************
**# (H) HEALTH — H2–H17  
********************************************************************************
{
    use "$zzz/data.dta", clear
    keep hhid* h2-h_duration date

    * If per-member items exist (H17), normalize and reshape
    loc var ""
    foreach v in h17 {
        forvalues i = 1/25 {
            cap ren `v'`i' `v'_`i'
        }
        loc var "`var' `v'_"
    }
    di "`var'"

    * Reshape only if H17_* present
    cap reshape long `var', i(hhid) j(fmid)
    ren *_ *

    dropmiss h17, obs force

    la lang ENG, copy new

    * -------------------------------
    * H2 Needed but did not get care
    * -------------------------------
    la var h2 "In the last 30 days, has it been necessary for any member of your HH to get health care services but did not?"
    la def HLT_UNMET ///
        1 "Yes, inpatient" ///
        2 "Yes, outpatient" ///
        3 "Yes, both inpatient and outpatient" ///
        4 "No" ///
        98 "Refused", replace
    la val h2 HLT_UNMET

    * -------------------------------
    * H2A Able to get health care services
    * -------------------------------
    la var h2a "Whether was able to get health care services"
    la def HLT_ABLE_CARE ///
        1 "Yes" ///
        2 "No" ///
        98 "Don't want to answer / Refused", replace
    la val h2a HLT_ABLE_CARE

    * -------------------------------
    * H3 Reason for being unable to get care
    * -------------------------------
    la var h3 "What was the main reason you or a member of your household were not able to get health care service?"
    la def HLT_UNMETRSN ///
		1 "Lack of money / Cannot afford" ///
		2 "No medical personnel available" ///
		3 "Turned away because facility was full" ///
		4 "Limited/ No transportation " ///
		5 "Restriction to go outside" ///
		6 "Afraid" ///
		95 "None" ///
		11 "Medical services not yet needed" ///
		13 "Not able to avail" ///
		16 "No health programs / services available" ///
		18 "Mild illness only" ///
		19 "Health care providers choose who to help" ///
		22 "Not qualified" ///
		28 "Facility is too far away" ///
		29 "Cannot comply to requirements" ///
		32 "Lack of services provided" ///
		33 "Still waiting for schedule" ///
		39 "Limited knowledge on availing health care services" ///
		46 "Used alternative medicine instead" ///
		47 "Chose another health care provider" ///
		52 "Too busy" ///
		96 "Others" ///
		99 "Don't know" ///
		,
    la val h3 HLT_UNMETRSN

    * -------------------------------
    * H4 Most frequent facility visited
    * -------------------------------
    la var h4 "What type of facility/health care provider was most often visited for consultation/advice/care/treatment?"
    la def HLT_FAC ///
        1 "Barangay Health Station" ///
        2 "Rural Health Unit (RHU)/Health Center" ///
        3 "Private Clinic" ///
        4 "Public Hospital" ///
        5 "Private Hospital" ///
        96 "Others" ///
        99 "Don't know", replace
    la val h4 HLT_FAC

    * -------------------------------
    * H5 Mode(s) of transport to facility (MULTI)
    * -------------------------------
    la var h5 "Modes of transport used to reach health facility"
    cap conf string variable h5
    if _rc { 
		tostring h5, replace force format(%20.0g) 
		}
    replace h5 = strtrim(h5)

    _mkclean h5 h5_txt
    order h5_txt, a(h5)
    drop h5

    #delimit ;
    glo H5OPT `"
		"By foot"
		"Used own vehicle (specify)"
		"Van"
		"Bicycle"
		"Motorcycle/Tricycle"
		"Jeepney/Bus"
		"Car/Taxi"
		"Boat"
		"Airplane"
		"Horse or water buffalo "
		"Others (specify)"
		"Train"
		"Truck"
		"Company service"
		"Sports Utility Vehicle/ SUV"
		"Pick Up Truck"
		"Government service"
		"Tractor"
		"Work from Home"
		"Refused to answer"
		"Don't know"
    "';
    #delimit cr

    loc j = 0
    foreach c of numlist 1 2 15 3 4 5 6 7 8 9 96 43 44 45 49 50 51 52 97 98 99 {
        loc ++j
        loc w : word `j' of $H5OPT
        cap drop h5_`c'
        g byte h5_`c' = (strpos(h5_txt, ";`c';")>0) if h5_txt!=""
        la var h5_`c' "Transport to health facility: `w'"
        replace h5_`c' = . if h5_`c'==0
    }
    order h5_*, b(h6)

    * -------------------------------
    * H6 Travel time to facility (minutes)
    * -------------------------------
    la var h6 "How long does it usually take to get to the health care facility? (minutes)"

    * -------------------------------
    * H7 Transport cost to facility
    * -------------------------------
    la var h7 "How much is usually spent on transportation to and from the health care facility?"

    * -------------------------------
    * H8 OOP for consultation (cat) + H8a amount
    * -------------------------------
    la var h8 "Did you or any member of your household pay out-of-pocket for consultation? If yes, how much, or whether in kind."
    la def HLT_OOPCONS ///
        1 "Yes, in cash (specify amount)" ///
        2 "Yes, in kind (specify amount)" ///
        3 "No", replace
    la val h8 HLT_OOPCONS

    la var h8a "Amount paid out-of-pocket for consultation (PHP)"

    * -------------------------------
    * H9 Prescribed services (a/b/c)
    * -------------------------------
    la def YN 1 "Yes" 2 "No", replace
    la var h9a "Was [NAME] prescribed medicines/vaccines for treating illness?"
    la var h9b "Was [NAME] prescribed diagnostic services (e.g., x-ray, blood chemistry)?"
    la var h9c "Was [NAME] prescribed other services (dental, etc.)?"
    la val h9? YN

    * -------------------------------
    * H10 Able to obtain prescribed services (a/b/c)
    * -------------------------------
    la var h10a "Able to buy/get prescribed: Medicines/Vaccines?"
    la var h10b "Able to buy/get prescribed: Diagnostic services?"
    la var h10c "Able to buy/get prescribed: Other services (dental)?"
    la val h10? YN

    * -------------------------------
    * H11a Amounts paid for prescribed services (PHP)
    * -------------------------------
    la var h11aa "Amount paid for prescribed: Medicines/Vaccines (PHP; allowed 0–500,000)"
    la var h11ab "Amount paid for prescribed: Diagnostic services (PHP; allowed 0–500,000)"
    la var h11ac "Amount paid for prescribed: Other services (dental) (PHP; allowed 0–500,000)"

    * -------------------------------
    * H11b Who paid for prescribed services (MULTI) — meds / diag / other
    * -------------------------------
    #delimit ;
    glo H11bOPT `"
        "Immediate family member"
        "Relative/friend support"
        "PhilHealth"
        "PCSO"
        "Private insurance (HMO)"
        "Government program (MAIP, Malasakit, etc.)"
        "Other insurance (SSS, GSIS)"
        "Politician"
        "LGU"
        "Own Money"
		"Health care center"
		"From a loan"
		"Involved party in the accident"
		"None, free service"
		"Others"		
    "';
    #delimit cr

    * --- H11b(a): MEDS/VACCINES
    cap conf string variable h11ba
    if _rc { 
		tostring h11ba, replace force format(%20.0g) 
		}
    replace h11ba = strtrim(h11ba)
    _mkclean h11ba h11ba_txt
    order h11ba_txt, a(h11ba)

    loc j = 0
    foreach c of numlist 1/9 11 16 18 23 24 96 {
        loc ++j
        loc w : word `j' of $H11bOPT
        cap drop h11ba_`c'
        g byte h11ba_`c' = (strpos(h11ba_txt, ";`c';")>0) if h11ba_txt!=""
        la var h11ba_`c' "Payer (MEDS): `w'"
        replace h11ba_`c' = . if h11ba_`c'==0
    }

    * --- H11b(b): DIAGNOSTICS
    cap conf string variable h11bb
    if _rc { 
		tostring h11bb, replace force format(%20.0g) 
		}
    replace h11bb = strtrim(h11bb)
    _mkclean h11bb h11bb_txt
    order h11bb_txt, a(h11bb)

    loc j = 0
    foreach c of local H11bcodes {
        loc ++j
        loc w : word `j' of $H11bOPT
        cap drop h11bb_`c'
        g byte h11bb_`c' = (strpos(h11bb_txt, ";`c';")>0) if h11bb_txt!=""
        la var h11bb_`c' "Payer (DIAG): `w'"
        replace h11bb_`c' = . if h11bb_`c'==0
    }

    * --- H11b(c): OTHER SERVICES
    cap conf string variable h11bc
    if _rc { 
		tostring h11bc, replace force format(%20.0g) 
		}
    replace h11bc = strtrim(h11bc)
    _mkclean h11bc h11bc_txt
    order h11bc_txt, a(h11bc)

    loc j = 0
    foreach c of local H11bcodes {
        loc ++j
        loc w : word `j' of $H11bOPT
        cap drop h11bc_`c'
        g byte h11bc_`c' = (strpos(h11bc_txt, ";`c';")>0) if h11bc_txt!=""
        la var h11bc_`c' "Payer (OTHER): `w'"
        replace h11bc_`c' = . if h11bc_`c'==0
    }

    * -------------------------------
    * H12 Incidence of hospitalization (past 3 months)
    * -------------------------------
    la var h12 "During the past 3 months, has any household member been hospitalized overnight?"
    la val h12 YN

    * -------------------------------
    * H13 Type of hospital
    * -------------------------------
    la var h13 "What type of hospital was the member hospitalized in?"
    la def HLT_HOSPTYPE ///
        1 "Public Hospital" ///
        2 "Private Hospital" ///
        96 "Others" ///
        99 "Don't know", replace
    la val h13 HLT_HOSPTYPE

    * -------------------------------
    * H14 Total hospital bill
    * -------------------------------
    la var h14 "How much was the total hospital bill?"

    * -------------------------------
    * H15 Out-of-pocket hospital bill
    * -------------------------------
    la var h15 "How much was paid out-of-pocket for the hospital bill?"

    * -------------------------------
    * H16 Who paid the rest of the hospital bill (MULTI)
    * -------------------------------
    la var h16 "Who paid for the rest of the hospital bill?"
    cap conf string variable h16
    if _rc { 
		tostring h16, replace force format(%20.0g) 
		}
    replace h16 = strtrim(h16)

    _mkclean h16 h16_txt
    order h16_txt, a(h16)
    drop h16

    #delimit ;
    glo H16OPT `"
        "Immediate family member"
        "Relative/friend support"
        "PhilHealth"
        "PCSO"
        "Private insurance (HMO)"
        "Government program (MAIP, Malasakit, etc.)"
        "Other insurance (SSS, GSIS)"
        "Politician"
        "LGU"
		"Own Money"
		"Health care center"
		"From a loan"
		"Involved party in the accident"
		"None, free service"
		"Others"	
    "';
    #delimit cr

    loc H16codes "1 2 3 4 5 6 7 8 9 11 16 18 23 24 96"
    loc j = 0
    foreach c of numlist 1/9 11 16 18 23 24 96 {
        loc ++j
        loc w : word `j' of $H16OPT
        cap drop h16_`c'
        g byte h16_`c' = (strpos(h16_txt, ";`c';")>0) if h16_txt!=""
        la var h16_`c' "Payer of hospital bill: `w'"
        replace h16_`c' = . if h16_`c'==0
    }

    * -------------------------------
    * H17 PhilHealth membership
    * -------------------------------
    la var h17 "Is [HH MEMBER] a member/dependent/beneficiary of PhilHealth?"
    la def HLT_PHIL ///
        1 "PhilHealth - Paying Member" ///
        2 "PhilHealth - Non-Paying Member" ///
        3 "No" ///
		4 "Yes, PhilHealth - Dependent of Paying Member" ///
		5 "Yes, PhilHealth - Dependent of Non-Paying Member", replace
    la val h17 HLT_PHIL

	order hhid fmid 
	order h*, seq a(fmid)

    la lang ${LNG}
    compress
    save "$raw/${dta_file}_${date}_M07_med.dta", replace
}



********************************************************************************
**# (FO) FOOD — FO1–FO7
********************************************************************************
{
    use "$zzz/data.dta", clear
    keep hhid* fo1-fo7 fo_duration date
    dropmiss hhid, obs force

    la lang ENG, copy new

    * -------------------------------
    * FO1 Where purchase most food
    * -------------------------------
    la var fo1 "Over the past month, where did you buy most of the food for your household?"
    la def FOOD_SRC ///
        1 "Wet market" ///
        2 "Large supermarket/Hypermarket" ///
        3 "Supermarket/Grocery" ///
        4 "Convenience store" ///
        5 "Sari-sari store" ///
        6 "Ambulant peddlers" ///
        7 "Open stalls in shopping centers, malls, markets" ///
        8 "Online platforms (Lazada, Shopee, etc.)" ///
        96 "Others" ///
        99 "Don't know", replace
    la val fo1 FOOD_SRC

    * -------------------------------
    * FO2 Frequency of purchasing food from FO1
    * -------------------------------
    la var fo2 "How often does your household buy food from [FO1]?"
    la def FOOD_SRCFREQ ///
        1 "Once a week" ///
        2 "More than once a week" ///
        3 "Twice a month" ///
        4 "Thrice a month" ///
        5 "Less often than once a month" ///
        99 "Don't know", replace
    la val fo2 FOOD_SRCFREQ

    * -------------------------------
    * FO3 Mode(s) of transport to food source (MULTI)
    * -------------------------------
    la var fo3 "What modes of transport are used to reach [FO1] from home?"
    cap conf string variable fo3
    if _rc { 
		tostring fo3, replace force format(%20.0g) 
		}
    replace fo3 = strtrim(fo3)

    _mkclean fo3 fo3_txt
    order fo3_txt, a(fo3)
    drop fo3

    #delimit ;
    glo FO3OPT `"
		"By foot"
		"Used own vehicle (specify)"
		"Van"
		"Bicycle"
		"Motorcycle/Tricycle"
		"Jeepney/Bus"
		"Car/Taxi"
		"Boat"
		"Airplane"
		"Horse or water buffalo "
		"Others (specify)"
		"Train"
		"Truck"
		"Company service"
		"Sports Utility Vehicle/ SUV"
		"Pick Up Truck"
		"Government service"
		"Tractor"
		"Work from Home"
		"Refused to answer"
		"Don't know"	
    "';
    #delimit cr

    loc j = 0
    foreach c of numlist 1 2 15 3 4 5 6 7 8 9 96 43 44 45 49 50 51 52 97 98 99 {
        loc ++j
        loc w : word `j' of $FO3OPT
        cap drop fo3_`c'
        g byte fo3_`c' = (strpos(fo3_txt, ";`c';")>0) if fo3_txt!=""
        la var fo3_`c' "Transport to food source: `w'"
        replace fo3_`c' = . if fo3_`c'==0
    }

    * -------------------------------
    * FO4 Travel time to closest market (minutes)
    * -------------------------------
    la var fo4 "How long does it take to travel from here to the closest wet market or supermarket? (minutes)"

    * -------------------------------
    * FO5 Usual transport cost to/from market
    * -------------------------------
    la var fo5 "How much do you or any member of your household usually pay for transport to and from the closest wet market or supermarket?"
    la def FOOD_COST -99 "Don't know", replace
    la val fo5 FOOD_COST

    * -------------------------------
    * FO6 Incidence of receiving receipt (food)
    * -------------------------------
    la var fo6 "When shopping at [FO1], do you typically receive a receipt?"
    la def FOOD_RECEIPT 1 "Yes" 2 "No", replace
    la val fo6 FOOD_RECEIPT

    * -------------------------------
    * FO7 Usual mode of payment (food)
    * -------------------------------
    la var fo7 "What is your usual mode of payment in [FO1]?"
    la def FOOD_PAY ///
        1 "Cash" ///
        2 "Card (Credit/Debit)" ///
        3 "Digital payment (GCash, Maya, QR code)" ///
        96 "Others", replace
    la val fo7 FOOD_PAY

	order fo*, seq a(hhid)

    la lang ${LNG}
    compress
    save "$raw/${dta_file}_${date}_M08_food.dta", replace
}

********************************************************************************
**# (NF) NON-FOOD — NF1–NF3  
********************************************************************************
{
    use "$zzz/data.dta", clear
    keep hhid* nf1-nf_duration date
    dropmiss hhid, obs force

    la lang ENG, copy new

    * -------------------------------
    * NF1 Where purchase non-food items (MULTI)
    * -------------------------------
    la var nf1 "Over the past month, where did you usually buy non-food items such as clothing, furniture, etc."
    cap conf string variable nf1
    if _rc { 
		tostring nf1, replace force format(%20.0g) 
		}
    replace nf1 = strtrim(nf1)

    _mkclean nf1 nf1_txt
    order nf1_txt, a(nf1)
    drop nf1
	
    #delimit ;
    glo NF1OPT `"
		"Market"
		"Large supermarket/ Hypermarket"
		"Supermarket/Grocery"
		"Convenience store"
		"Sari-sari store"
		"Ambulant peddlers"
		"Open stalls in shopping centers, malls, and markets"
		"Department stores"
		"Appliance centers"
		"Online platforms" 
		"Ukay-ukay"
		"From family members"
		"Warehouse / wholesale stores"
		"From relief assistance"
		"None"
		"Others"
    "';
    #delimit cr
	
    loc j = 0
    foreach c of numlist 1 2 3 4 5 6 7 8 9 10 12 16 17 18 99 96  {
        loc ++j
        loc w : word `j' of $NF1OPT
        cap drop nf1_`c'
        g byte nf1_`c' = (strpos(nf1_txt, ";`c';")>0) if nf1_txt!=""
        la var nf1_`c' "Non-food source: `w'"
        replace nf1_`c' = . if nf1_`c'==0
    }
    order nf1_*, after(hhid)

    * -------------------------------
    * NF2 Receipt for non-food (by source)
    * -------------------------------
    la def YN 1 "Yes" 2 "No", replace
	
	ren nf2_11 nf2_96
	ren nf3_11 nf3_96
	
	loc j = 0 
    foreach c of numlist 1 2 3 4 5 6 7 8 9 10 {
		loc ++j 
        loc w : word `j' of $NF1OPT
        la var nf2_`c' "Receipt received when shopping at: `w'"
        la val nf2_`c' YN
    }
	
	la var nf2_96 "Receipt received when shopping at: Others"
	la val nf2_96 YN
	
    * -------------------------------
    * NF3 Mode of payment for non-food (by source)
    * -------------------------------
    la def NF_PAY ///
        1 "Cash" ///
        2 "Card (Credit/Debit)" ///
        3 "Digital payment (GCash, Maya, QR code)" ///
        96 "Others", replace
		
	loc j = 0 	
    foreach c of numlist 1 2 3 4 5 6 7 8 9 10  {
		loc ++j 
        loc w : word `j' of $NF1OPT
        la var nf3_`c' "Usual mode of payment when shopping at: `w'"
        la val nf3_`c' NF_PAY
    }
	
	la var nf3_96 "Usual mode of payment when shopping at: Others"
	la val nf3_96 NF_PAY
	
	
	
 
	order nf* , seq a(hhid)
	
	
    la lang ${LNG}
    compress
    save "$raw/${dta_file}_${date}_M08_nf.dta", replace
}


********************************************************************************
**# (SSB) SWEETENED SUGARY BEVERAGES — SSB1–SSB3
********************************************************************************
{
    use "$zzz/data.dta", clear
    keep hhid* d* ssb1-ssb_duration date
	cap drop dw*

    * If individual items (ssb2/ssb3) are wide by member, normalize & reshape
    loc var ""
    foreach v in ssb2 ssb3 d5a1 d6 d8  d9  ///
		d10a d10b d12 d12a ///
		d13 d13a d14 d18 d19 d20 {
        forvalues i = 1/25 {
            cap ren `v'`i' `v'_`i'
        }
        loc var "`var' `v'_"
    }
    di "`var'"
	
	tostring d18_*, force replace
    cap reshape long `var', i(hhid) j(fmid)
    dropmiss ssb2 ssb3 d5a1_ d6_ d8_ d9_ d10a_ d10b_ d12_ d12a_ d13_ d13a_ d14_, obs force
	ren *_ *
	cap drop d*

    la lang ENG, copy new

    * -------------------------------
    * SSB1 Incidence of consuming SSB (HH-level)
    * -------------------------------
    la var ssb1 "Do you or any member of your family consume sweetened sugary beverages?"
    la def YN 1 "Yes" 2 "No", replace
    la val ssb1 YN

    * -------------------------------
    * SSB2 HH member consumes SSB (individual-level)
    * -------------------------------
    la var ssb2 "Does [HH MEMBER] consume sweetened sugary beverages?"
    la val ssb2 YN

    * -------------------------------
    * SSB3 Total SSB consumed in a week (individual-level)
    * -------------------------------
    la var ssb3 "How many single-serve sweetened sugary beverages does [NAME] consume in a week?"

	order ssb*, seq a(hhid)
	
    la lang ${LNG}
    compress
    save "$raw/${dta_file}_${date}_M08_ssb.dta", replace
}


********************************************************************************
**# (NH) NATURAL HAZARD    
********************************************************************************
	{
	
	use "$zzz/data.dta", clear 
		keep hhid* nh1a-nh_duration date
	dropmiss hhid, obs force 
		
		
	foreach l in a b c d e f g h i j {
		foreach i of numlist 1/4 6/11 {
			ren nh`i'`l' nh`i'_`l'
		}
		
	}
	
	foreach l in a b c d e f g h i j {
		foreach i of numlist 1/7 {
		
			ren nh5`l'_`i' nh5_`i'_`l'
		}
		
	}
	
	loc j = 0 
	foreach l in a b c d e f g h i j {
	loc ++j 
		ren nh*_`l' nh*_`j'
		
	}
	
	loc var  ""
	foreach k of numlist 1/11 {
	
		if `k' ~= 5 {
		loc var "`var' nh`k'_"

		}
		if `k' == 5 {
		foreach h of numlist 1/7 {
			loc var "`var' nh5_`h'_"
		}
		}
	
	
	} 
	di "`var'"
	
	tostring nh* , replace force 
	
 	reshape long `var', i(hhid) j(hazard)
	
	ren nh*_ nh* 
	destring _all, replace 
	
	la lang ENG, copy new 
	
    la var hazard "Hazard type (A–J mapped to 1–10)"
    la def HAZARD ///
        1  "Typhoon" ///
        2  "Drought/El Niño" ///
        3  "Flood/La Niña" ///
        4  "Earthquake" ///
        5  "Tsunami" ///
        6  "Landslide" ///
        7  "Volcanic eruption" ///
        8  "Extreme heat" ///
        9  "Pest infestation/crop diseases" ///
        10 "Livestock diseases/ASF/Avian flu", replace
    la val hazard HAZARD

    la var nh1  "Experienced this hazard in the past 3 years?"
	la def YN 1 "Yes" 2 "No", replace 
	la val nh1 YN 
    la var nh2  "Received an early warning prior to this hazard?"
	la val nh2 YN 
	
    la var nh3 "Damages/impact caused by this hazard (multi; codes)"
    cap conf string variable nh3
    if _rc { 
		tostring nh3, replace usedisplayformat 
			}
    replace nh3 = strtrim(nh3)
    _mkclean nh3 nh3_txt
    order nh3_txt, a(nh3)

    #delimit ;
    glo NH3OPT `"
		"Travel distruptions/time"
		"Childrens' school closure/interruption"
		"Damage to house"
		"Damage to other personal property"
		"Job disruption/reduced income earnings"
		"Health of a family member"
		"Death"
		"Others"
		"Disruption of Basic Utilities"
		"Negative environmental impact"
		"Damage to public property"
		"Price Inflation"
		"Negative agricultural impact"
		"Negative impact emotionally / mentally"
		"Panic buying"
		"Lack of / no source of food"
		"None"
    "';
    #delimit cr

    loc j = 0
    foreach c of numlist 1 2 3 4 5 6 7 96 8 69 11 26 58 66 71 79 95 {
        loc ++j
        loc w : word `j' of $NH3OPT
        cap drop nh3_`c'
        g byte nh3_`c' = (strpos(nh3_txt, ";`c';")>0) if nh3_txt!=""
        la var nh3_`c' "Impact: `w'"
        la val nh3_`c' YN 
        replace nh3_`c' = . if nh3_`c'==0
    }
    order nh3_*, b(nh4)

    * ---- NH4 Assistance sources (multi)
    la var nh4 "From whom assistance was received for this hazard (multi; codes)"
    cap conf string variable nh4
    if _rc { 
		tostring nh4, replace usedisplayformat 
		}
    replace nh4 = strtrim(nh4)
    _mkclean nh4 nh4_txt
    order nh4_txt, a(nh4)

    #delimit ;
    glo NH4OPT `"
        "Family member (would otherwise be part of HH)"
        "Other relatives or friends"
        "Local government"
        "National government"
        "Gov't (unknown level)"
        "Private institutions (Churches/NGOs)"
		"Neighbors"
        "No did not receive assistance"
		"Others"
    "';
    #delimit cr

    loc j = 0
    foreach c of numlist 1/6 11 99 96 {
        loc ++j
        loc w : word `j' of $NH4OPT
        cap drop nh4_`c'
        g byte nh4_`c' = (strpos(nh4_txt, ";`c';")>0) if nh4_txt!=""
        la var nh4_`c' "Assistance source: `w'"
        la val nh4_`c' YN
        replace nh4_`c' = . if nh4_`c'==0
    }
    order nh4_*, b(nh5_1)
	
	
  * ---- NH5 Type of assistance (based on source and natural hazard) (multi)
    la var nh4 "From whom assistance was received for this hazard (multi; codes)"
    cap conf string variable nh4
    if _rc { 
		tostring nh4, replace usedisplayformat 
		}
    replace nh4 = strtrim(nh4)
    _mkclean nh4 nh4_txt
    order nh4_txt, a(nh4)

    #delimit ;
    glo NH4OPT `"
        "Family member (would otherwise be part of HH)"
        "Other relatives or friends"
        "Local government"
        "National government"
        "Gov't (unknown level)"
        "Private institutions (Churches/NGOs)"
		"Neighbors"
        "No did not receive assistance"
		"Others"
    "';
    #delimit cr

    loc j = 0
    foreach c of numlist 1/6 11 99 96 {
        loc ++j
        loc w : word `j' of $NH4OPT
        cap drop nh4_`c'
        g byte nh4_`c' = (strpos(nh4_txt, ";`c';")>0) if nh4_txt!=""
        la var nh4_`c' "Assistance source: `w'"
        la val nh4_`c' YN
        replace nh4_`c' = . if nh4_`c'==0
    }
    order nh4_*, b(nh5_1)	
	
	
		
	* ---- NH5 Type of assistance received (multi; codes) by source (nh5_1 ... nh5_7)

	#delimit ;
	glo NH5TYPE `"
		"Food Packs"
		"Cash"
		"Relief Goods"
		"Fertilizer"
		"Insecticide"
		"Clothing"
		"Kitchen utensils"
		"Health and Safety Suppliles"
		"Seedlings/ Seeds"
		"Road clearing"
	"';

	glo NH5SRC `"
		"Family member (would otherwise be part of HH)"
		"Other relatives or friends"
		"Local government"
		"National government"
		"Gov't (unknown level)"
		"Private institutions (Churches/NGOs)"
		"Neighbors"
		"No did not receive assistance"
		"Others"
	"';
	#delimit cr

	* You said you have nh5_1 to nh5_7 (7 sources). We'll label them using the first 7 source labels above.
	forvalues s = 1/7 {

		local src : word `s' of $NH5SRC
		la var nh5_`s' "Type of assistance (source: `src') (multi; codes)"

		* ensure string + clean
		cap conf string variable nh5_`s'
		if _rc {
			tostring nh5_`s', replace usedisplayformat
		}
		replace nh5_`s' = strtrim(nh5_`s')
		_mkclean nh5_`s' nh5_`s'_txt
		order nh5_`s'_txt, a(nh5_`s')

		* add boundary semicolons so code matching is safe
		gen strL nh5_`s'_b = ";" + nh5_`s'_txt + ";" if nh5_`s'_txt != ""

		local j = 0
		foreach c of numlist 1/10 {
			local ++j
			local typ : word `j' of $NH5TYPE

			cap drop nh5_`s'_`c'
			gen byte nh5_`s'_`c' = .   // default missing

			* match both "4" and "04" styles for 1-9
			if `c' < 10 {
				replace nh5_`s'_`c' = ///
					(strpos(nh5_`s'_b, ";`c';")>0 | strpos(nh5_`s'_b, ";0`c';")>0) ///
					if nh5_`s'_b != ""
			}
			else {
				replace nh5_`s'_`c' = (strpos(nh5_`s'_b, ";10;")>0) if nh5_`s'_b != ""
			}

			la var nh5_`s'_`c' "Assistance type from `src': `typ'"
			la val nh5_`s'_`c' YN
			replace nh5_`s'_`c' = . if nh5_`s'_`c'==0
		}

		drop nh5_`s'_b
		order nh5_`s'_*, a(nh5_`s')
	}
	
	
    la var nh6  "Typically receive warnings for this hazard?"
	la val nh6 YN 
	
    la var nh7 "Channels used to receive warnings for this hazard (multi; codes)"
    cap conf string variable nh7
    if _rc { 
		tostring nh7, replace usedisplayformat 
		}
    replace nh7 = strtrim(nh7)
    _mkclean nh7 nh7_txt
    order nh7_txt, a(nh7)

    #delimit ;
    glo NH7OPT `"
        "TV"
        "Radio"
        "In-person: LGU/barangay"
        "SMS"
        "Website"
        "Cell broadcast / Emergency alert"
        "Sirens / Loudspeakers"
        "Social media"
        "Newspapers / Printed"
		"Word of Mouth (e.g., Friends, Relatives)"
		"Weather Forecast Services"
        "Other (specify)"
    "';
    #delimit cr

    loc j = 0
    foreach c of numlist 1/9 21 23 96 {
        loc ++j
        loc w : word `j' of $NH7OPT
        cap drop nh7_`c'
        g byte nh7_`c' = (strpos(nh7_txt, ";`c';")>0) if nh7_txt!=""
        la var nh7_`c' "Warning channel: `w'"
        la val nh7_`c' YN
        replace nh7_`c' = . if nh7_`c'==0
    }
    order nh7_*, b(nh8)

    la var nh8  "Understood the warning message for this hazard?"
	la val nh8 YN 
    la var nh9  "Warning gave guidance on actions to take for this hazard?"
	la val nh9 YN 
	
    la var nh10 "Actions taken upon receiving alert for this hazard (multi; codes)"
    cap conf string variable nh10
    if _rc { 
		tostring nh10, replace usedisplayformat 
		}
    replace nh10 = strtrim(nh10)
    _mkclean nh10 nh10_txt
    order nh10_txt, a(nh10)

    #delimit ;
    glo NH10OPT `"
		"Evacuated to a safe place"
		"Reinforced the structure of the house"
		"Avoiding risky activities (e.g., avoiding travel to hazardous areas, ceasing work or outdoor activities)"
		"Stocked up on food"
		"Sheltering in place (staying indoors or moving to a safe part of the house)"
		"Secure property and assets (move valuables, etc.)"
		"Stockpiling and preparing supplies"
		"Assisting others, including communicating with other family and community members)"
		"Stored enough water"
		"Drinking plenty of water"
		"Prepared medicines"
		"Rarely goes outside"
		"Bought insect repellent spray"
		"Sprayed pesticide to protect crops"
		"Regularly cleans pigpen"
		"Goes under the table"
		"Gives vitamins"
		"Avoids feeding meat to prevent infection"
		"Took shelter under a tree"
		"Be cautious"
		"Preparing a first aid kit"
		"Praying"
		"Bathing"
		"Going to a cold place"
		"Avoid visiting sick animals"
		"Be careful not to catch illness"
		"Open the windows"
		"Kept animals away from crowd"
		"Postponed planting"
		"Cleaned the chicken coop"
		"Sprayed medicine on crops"
		"Vaccination of pets/ livestock"
		"Bring an umbrella"
		"Conserve water"
		"Got infected for protection"
		"Charged cellphones"
		"Put a mosquito net over the pig"
		"kept watch"
		"Dug water pathways"
		"Tied down the roof "
		"Disinfected"
		"Went to the barangay hall"
		"Buried dead livestock "
		"Giving medicine to livestock"
		"Removed obstructing tree branches"
		"Temporarily stopped raising animals"
		"Planted early to avoid El Niño"
		"Pigs were confiscated by the Department of Agriculture"
		"Did not do anything"
		"Others"
    "';
    #delimit cr

    loc j = 0
    foreach c of numlist 1 2 3 4 5 6 7 8 11 12 13 14 15 16 17 18 20 21 22 23 24 25 26 27 28 29 30 31 32 33 35 39 40 43 44 45 49 51 54 56 57 58 60 61 62 63 64 65 99 96 {
        loc ++j
        loc w : word `j' of $NH10OPT
        cap drop nh10_`c'
        g byte nh10_`c' = (strpos(nh10_txt, ";`c';")>0) if nh10_txt!=""
        la var nh10_`c' "Action: `w'"
        la val nh10_`c' YN
        replace nh10_`c' = . if nh10_`c'==0
    }
    order nh10_*, b(nh11)
	
    la var nh11 "Warning received with sufficient time to act?"
    la val nh11 YN

  
	la var nh12 "Awareness of hazard maps (municipality/city/town/barangay)"
	la val nh12 YN

	la var nh13 "Source of awareness of hazard maps (multi-select; codes)"
	cap conf string variable nh13
	if _rc { 
		tostring nh13, replace force format(%20.0g) 
		}
	replace nh13 = strtrim(nh13)

	_mkclean nh13 nh13_txt
	order nh13_txt, a(nh13)

	#delimit ;
	glo NH13OPT `"
		"National officials"
		"Local officials"
		"Family & friends"
		"School"
		"PHIVOLCS"
		"UP NOAH"
		"Facebook"
		"TikTok"
		"YouTube"
		"Barangay Hall"
		"Red Cross"
		"PAG-ASA ( Philippine Atmospheric, Geophysical and Astronomical Services Administration)"
		"Company"
		"MDRRMC (Municipal Disaster Risk Reduction and Management Council)"
		"TV"
		"Google"
		"Radio"
		"Zoom Earth"
		"Roadside Signage"
		"Municipal Office"
		"Others"
	"';
	#delimit cr

	loc j = 0
	foreach c of numlist 1 2 3 4 5 6 8 9 10 11 12 13 14 15 16 17 18 19 20 21 96 {
		loc ++j
		loc w : word `j' of $NH13OPT
		cap drop nh13_`c'
		g byte nh13_`c' = (strpos(nh13_txt, ";`c';")>0) if nh13_txt!=""
		la var nh13_`c' "Source of hazard map awareness: `w'"
		la val nh13_`c' YN 
		replace nh13_`c' = . if nh13_`c'==0
	}
	order nh13_*, after(nh12)
	
	
	order hhid hazard 
	order nh*, seq a(hazard)
		
	la lang ${LNG}
	compress 	
	save "$raw/${dta_file}_${date}_M09_nh.dta", replace
	

	}


********************************************************************************
**# (DW) DWELLING — DW1–DW15 
********************************************************************************
{
    use "$zzz/data.dta", clear
    keep hhid* dw14-dw_duration date
	
	destring dw8b, force replace
	
    dropmiss hhid, obs force
	
    la lang ENG, copy new

    * -------------------------------
    * DW1 — Type of building/house
    * -------------------------------
    la var dw1 "Type of building/house"
    la def DWL_TYPE ///
        1 "Single house" ///
        2 "Duplex" ///
        3 "Apartment/accessorial/row house" ///
        4 "Condominium/condotel" ///
        5 "Other multi-unit residential" ///
        6 "Commercial/industrial/agricultural" ///
        7 "Institutional living quarter (e.g., hotel, hospital, convent, jail)" ///
        9 "None", replace
    la val dw1 DWL_TYPE

    * -------------------------------
    * DW2 — Construction materials of the roof
    * -------------------------------
    la var dw2 "Construction materials of the roof"
    la def DWL_ROOF ///
        1 "Metal roofing sheets (e.g., GI, copper, aluminum, stainless steel)" ///
        2 "Concrete/clay/slate tile" ///
        3 "Half galvanized iron and half concrete" ///
        4 "Wood/bamboo" ///
        5 "Sod/Thatch (e.g., cogon, nipa, anahaw)" ///
        6 "Asbestos" ///
        7 "Makeshift/salvaged/improvised materials" ///
        96 "Others", replace
    la val dw2 DWL_ROOF

    * -------------------------------
    * DW3 — Construction materials of the outer wall
    * -------------------------------
    la var dw3 "Construction materials of outer wall"
    la def DWL_WALL ///
        1 "Concrete/Brick/Stone" ///
        2 "Metal roofing sheets (e.g., GI, copper, aluminum, stainless steel)" ///
        3 "Half concrete/brickstone and half wood" ///
        4 "Glass" ///
        5 "Wood/bamboo" ///
        6 "Sawali/Cogon/Nipa" ///
        7 "Asbestos" ///
        8 "Makeshift/salvaged/improvised materials" ///
        9 "Fiber cement board (e.g., HardieFlex)" ///
        96 "Others", replace
    la val dw3 DWL_WALL

    * -------------------------------
    * DW4 — Number of bedrooms (numeric)
    * -------------------------------
    la var dw4 "How many bedrooms does your housing unit have?"

    * -------------------------------
    * DW5 — Tenure status of the housing unit/lot
    * -------------------------------
    la var dw5 "What is the tenure status of the housing unit and lot occupied by this household? Is it…?"
    la def DWL_TENURE ///
        1 "Own or owner-like possession of the house and lot" ///
        2 "Own house, rent lot" ///
        3 "Own house, rent-free lot with consent of owner" ///
        4 "Own house, rent-free lot without consent of owner" ///
        5 "Rent house/room, including lot" ///
        6 "Rent-free house and lot with consent of owner" ///
        7 "Rent-free house and lot without consent of owner" ///
		11 "Sariling Bahay na may pahintulot ng gobyerno" ///
        96 "Others (specify)", replace
    la val dw5 DWL_TENURE

    * -------------------------------
    * DW6 / DW6a — Interior paint (status + year)
    * -------------------------------
    la var dw6  "Interior last painted: status (1=Year specified, 2=No paint, -99=Don't know)"
    la def DWL_PAINTSTAT ///
        1 "Year specified" ///
        2 "No paint" ///
       99 "Don't know", replace
    la val dw6 DWL_PAINTSTAT

    la var dw6a "Interior last painted (YEAR), if DW6==1"

    * -------------------------------
    * DW7 — Interior paint color (coded)
    * -------------------------------
    la var dw7 "Interior paint color (most common)"
    la def PAINT_COLOR ///
    	1 "White" ///
		2 "Beige" ///
		3 "Dirty White" ///
		4 "Yellow" ///
		5 "Peach" ///
		6 "Mint Green" ///
		7 "Dark Grey" ///
		8 "White and Biege" ///
		9 "Blue" ///
		10 "Yellow Green" ///
		11 "Pink" ///
		12 "Violet" ///
		13 "Ivory" ///
		14 "Green" ///
		15 "Skyblue" ///
		16 "Orange" ///
		23 "Light Green" ///
		24 "Off White" ///
		27 "Cream" ///
		26 "Light Blue" ///
		28 "Gray" ///
		29 "Caramel" ///
		21 "Sky Blue" ///
		31 "Gold" ///
		35 "Cremy White" ///
		36 "Baby Blue" ///
		25 "Brown" ///
		19 "Blue" ///
		37 "Dark Green" ///
		18 "Dark Maroon" ///
		38 "Red" ///
		39 "Creamy White" ///
		40 "Creamy Dark Green" ///
		20 "Apple Green" ///
		22 "Light Yellow" ///
		30 "Light pink" ///
		57 "Teal Green" ///
		32 "Navy Blue" ///
		33 "Vanilla" ///
		34 "Light Violet" ///
		58 "Mocha Brown" ///
		59 "Flesh" ///
		60 "Maroon" ///
		61 "Light Brown" ///
		62 "Yellow Orange" ///
		63 "Ash Gray" ///
		41 "Blue Green" ///
		42 "Mint Blue" ///
		43 "Baby Pink" ///
		44 "Dark Blue" ///
		45 "Chocolate Brown" ///
		46 "Sun yellow" ///
		47 "Pearl White" ///
		48 "Coffee" ///
		49 "Silver Gray" ///
		50 "Dark Pink" ///
		51 "Mint" ///
		52 "Aqua Blue" ///
		53 "Salmon" ///
		54 "Purple" ///
		55 "Yellow Polish" ///
		56 "Light Gray" ///
		, replace	
    la val dw7 PAINT_COLOR

    * -------------------------------
    * DW8 / DW8a / DW8b — Exterior paint (status + year + color)
    * -------------------------------
    la var dw8  "Exterior last painted: status (1=Year specified, 2=No paint, 99=Don't know)"
    la val dw8 DWL_PAINTSTAT
    la var dw8a "Exterior last painted (YEAR), if DW8==1"
    la var dw8b "Exterior paint color (most common)"
    la val dw8b PAINT_COLOR

    * -------------------------------
    * DW9 / DW10 — Peeling/chipping paint (inside/outside)
    * -------------------------------
    la def YN 1 "Yes" 2 "No", replace
    la var dw9  "Are there any areas of peeling or chipping paint inside the home?"
    la val dw9 YN
    la var dw10 "Are there any areas of peeling or chipping paint outside the home?"
    la val dw10 YN

    * -------------------------------
    * DW11a / DW11b — Agreement statements on lead
    * -------------------------------
    la def AGREE 1 "Agree" 2 "Disagree" 99 "Don't know", replace
    la var dw11a "I am well informed about the health dangers of lead-based paint"
    la val dw11a AGREE
    la var dw11b "The presence of lead in paint is a serious public health issue for Philippines"
    la val dw11b AGREE

    * -------------------------------
    * DW12 / DW12a — Last repairs/remodeling (status + year)
    * -------------------------------
    la var dw12  "Repairs/remodeling last conducted: status (1=Year specified, -99=Don't know)"
    la def DWL_REPAIRSTAT 1 "Year specified" 99 "Don't know", replace
    la val dw12 DWL_REPAIRSTAT
    la var dw12a "Repairs/remodeling last conducted (YEAR), if DW12==1"

    * -------------------------------
    * DW13 — Type of metallic cookware most frequently used
    * -------------------------------
    la var dw13 "What type of metallic cookware is most frequently used in the household (frying pans, pots, etc.)?"
    la def DWL_COOKWARE ///
        1 "Aluminum" ///
        2 "Stainless steel" ///
        3 "Non-sticky" ///
        4 "Other", replace
    la val dw13 DWL_COOKWARE

    * -------------------------------
    * DW14 — Neighborhood (observer rating)
    * -------------------------------
    la var dw14 "Neighborhood"
    la def DW_NEIGH ///
        1 "Located generally in slum district interior or rural houses" ///
        2 "Mostly similar-size houses with occasional large houses" ///
        3 "Mixed neighborhood with larger/smaller houses" ///
        4 "Mixed neighborhood, predominantly larger houses" ///
        5 "Exclusive/expensive neighborhood; townhouses/condos; if mixed, house has a fence", replace
    la val dw14 DW_NEIGH

    * -------------------------------
    * DW15 — Indoor quality of house (observer rating)
    * -------------------------------
    la var dw15 "Indoor quality of house"
    la def DW_INDOOR ///
        1 "Unpainted and dilapidated" ///
        2 "Generally unpainted and badly in need of repair" ///
        3 "Painted but needs a new coat and some repairs" ///
        4 "Well-painted, may need minor repairs" ///
        5 "Well-painted; not in need of repair" ///
        6 "N/A", replace
    la val dw15 DW_INDOOR


	order dw*, seq a(hhid)

    la lang ${LNG}
    compress
    save "$raw/${dta_file}_${date}_M10_dwell.dta", replace
}	

********************************************************************************
** (S) SANITATION — S1–S8 
********************************************************************************
{
    use "$zzz/data.dta", clear
    keep hhid* s1-s_duration date
    dropmiss hhid, obs force

    la lang ENG, copy new

    * -------------------------------
    * S1 — Toilet facility
    * -------------------------------
    la var s1 "What kind of toilet facility do you have in the house?"
    note  s1 : Household's primary toilet facility (single choice)
    la def SN_TOILET ///
        1 "Water-sealed, sewer septic tank, used exclusively by household" ///
        2 "Water-sealed, sewer septic tank, shared with other household" ///
        3 "Water-sealed, other depository, used exclusively by household" ///
        4 "Water-sealed, other depository, shared with other household" ///
        5 "Closed pit" ///
        6 "Open pit" ///
        7 "Others (pail system and others)" ///
        9 "None", replace
    la val s1 SN_TOILET

    * -------------------------------
    * S2 — Location of toilet facility
    * -------------------------------
    la var s2 "Where is this toilet facility located?"
    note  s2 : Location of the facility (single choice)
    la def SN_TLOC 1 "In own dwelling" 2 "In own yard/plot" 3 "Elsewhere", replace
    la val s2 SN_TLOC

    * -------------------------------
    * S3 — Share toilet facility (Yes/No)
    * -------------------------------
    la var s3 "Do you share this facility with others who are not members of your household?"
    note  s3 : Sharing status with non-household members (single choice)
    la def YN 1 "Yes" 2 "No", replace
    la val s3 YN

    * -------------------------------
    * S4 — Manner of disposing solid waste (past 7 days)
    * -------------------------------
    la var s4 "In the past 7 days, how did your household dispose of most of its solid waste?"
    note  s4 : Main disposal method during last 7 days (single choice)
    la def SN_WDISP ///
        1  "Collected by public/private service" ///
        2  "Dumped in open dump" ///
        3  "Burned openly or in pit" ///
        4  "Buried" ///
        96 "Others" ///
        99 "Don't know" ///
        9  "No waste", replace
    la val s4 SN_WDISP

    * -------------------------------
    * S5 — Segregating solid waste (MULTI)
    * -------------------------------
    la var s5 "Do you separate your waste into the following categories before disposal? (multi-select)"
    note  s5 : Multiple selections allowed; categories captured in s5_txt and dummies s5_*
    cap conf string variable s5
    if _rc { 
		tostring s5, replace force format(%20.0g) 
		}
    replace s5 = strtrim(s5)

    _mkclean s5 s5_txt
    order s5_txt, a(s5)
    note  s5_txt : Cleaned codes for S5 in ;code; format (e.g., ;1;3;)

    #delimit ;
    glo S5OPT `"
        "Organic (food/yard)"
        "Recyclables (plastic, paper, metal, glass)"
        "Hazardous (batteries, chemicals)"
        "Medical waste"
        "None"
    "';
    #delimit cr

    loc j = 0
    foreach k of numlist 1/5 {
        loc ++j
        loc w : word `j' of $S5OPT
        cap drop s5_`k'
        g byte s5_`k' = (strpos(s5_txt, ";`k';")>0) if s5_txt!=""
        la var s5_`k' "Segregate category: `w'"
        note  s5_`k' : Dummy = 1 if `w' selected; 0→. for cleanliness
        replace s5_`k' = . if s5_`k'==0
    }
    order s5_*, b(s6)

    * -------------------------------
    * S6 — Frequency of segregating waste
    * -------------------------------
    la var s6 "How often do you separate waste?"
    note  s6 : Self-reported frequency (single choice)
    la def SN_FREQ 1 "Never" 2 "Rarely" 3 "Sometimes" 4 "Often" 5 "Always", replace
    la val s6 SN_FREQ

    * -------------------------------
    * S7 — Paying for waste collection (with amount if Yes)
    * -------------------------------
    la var s7 "In the past 30 days, did your household pay for any waste collection or disposal service?"
    note  s7 : Gate for S7a amount (single choice)
    la def SN_PAYCOL 1 "Yes (specify total amount)" 2 "No", replace
    la val s7 SN_PAYCOL

    la var s7a "Total amount paid for waste collection/disposal in the past 30 days (if s7==1)"
    note  s7a : Monetary amount in local currency; numeric, non-negative

    * -------------------------------
    * S8 — Satisfaction with waste disposal services
    * -------------------------------
    la var s8 "How satisfied are you with your current waste disposal services?"
    note  s8 : Satisfaction scale (single choice)
    la def SN_SAT 1 "Very dissatisfied" 2 "Dissatisfied" 3 "Satisfied" 4 "Very satisfied", replace
    la val s8 SN_SAT

	order s*, seq a(hhid)

    la lang ${LNG}
    compress
    save "$raw/${dta_file}_${date}_M11_san.dta", replace
}
	
********************************************************************************
** (W) WATER — W1–W8 
********************************************************************************
{
    use "$zzz/data.dta", clear
    keep hhid* w1-w8 w_duration date
    destring w1-w8 w_duration date, replace
    dropmiss hhid, obs force
	tostring hhid_str, replace

    la lang ENG, copy new

    * -------------------------------
    * W1 — Main source of water supply
    * -------------------------------
    la var w1 "What is your main source of water supply?"
    note  w1 : Main household water source (single choice)
    la def WAT_SOURCE ///
        1  "Piped into dwelling" ///
        2  "Piped to yard/lot" ///
        3  "Piped to neighbor" ///
        4  "Public tap/Stand pipe" ///
        5  "Tubed well/Borehole" ///
        6  "Protected well" ///
        7  "Unprotected well" ///
        8  "Protected spring" ///
        9  "Unprotected spring" ///
        10 "Rainwater" ///
        11 "Tanker-truck" ///
        12 "Cart with small tank" ///
        13 "Water refilling station" ///
        14 "Surface water (river, dam, lake, pond, stream, canal, irrigation channel)" ///
        15 "Bottled water" ///
        16 "Sachet water" ///
		21 "Tubig sa galon" ///
        96 "Others (specify)", replace
    la val w1 WAT_SOURCE

    * -------------------------------
    * W2 — Time to reach water source (minutes; special codes)
    * -------------------------------
    la var w2 "How long does it take to go there, get water, and come back? (minutes)"
    note  w2 : 0 = members do not collect; 99 = Don't know; positive = minutes
    la def WAT_TIMEFLAG 0 "Members do not collect" 99 "Don't know", replace
    la val w2 WAT_TIMEFLAG

    * -------------------------------
    * W3 — Provider of water supply
    * -------------------------------
    la var w3 "Who provided the main source of your water supply?"
    note  w3 : Provider type (single choice)
    la def WAT_PROVIDER 1 "Government (public, LGU)" 2 "Private" 3 "No water system" 99 "Don't know", replace
    la val w3 WAT_PROVIDER

    * -------------------------------
    * W4 — Location of main water source
    * -------------------------------
    la var w4 "Where is the main source of water supply located?"
    note  w4 : Location of main source (single choice)
    la def WAT_LOC 1 "In own yard/plot" 2 "Elsewhere", replace
    la val w4 WAT_LOC

    * -------------------------------
    * W5 — Main source of drinking water
    * -------------------------------
    la var w5 "What is the main source of drinking water used by members of your family?"
    note  w5 : Drinking water source (single choice; reuse WAT_SOURCE)
    la val w5 WAT_SOURCE

    * -------------------------------
    * W6 — Water treatment incidence
    * -------------------------------
    la var w6 "Do you do anything to the water to make it safer to drink?"
    note  w6 : Treatment gate (single choice)
    la def WAT_TREATYN 1 "Yes" 2 "No" 99 "Don't know", replace
    la val w6 WAT_TREATYN

    * -------------------------------
    * W7 — What do you do to make water safer? (MULTI)
    * -------------------------------
    la var w7 "What do you usually do to make the water safer to drink? (multi-select)"
    note  w7 : Multiple selections allowed; codes stored in w7_txt and expanded to dummies
    cap conf string variable w7
    if _rc { 
		tostring w7, replace force format(%20.0g) 
		}
    replace w7 = strtrim(w7)

    _mkclean w7 w7_txt
    order w7_txt, a(w7)
    drop w7
    note  w7_txt : Cleaned ;code; representation (e.g., ;1;4;96;)

    #delimit ;
    glo W7OPT `"
        "Boiled it"
        "Add bleach/chlorine"
        "Strain it through a cloth"
        "Use water filter (ceramic, sand, composite, etc.)"
        "Solar disinfection"
        "Let it stand and settle"
        "Don't know"
        "Others"
    "';
    #delimit cr
    loc W7codes "1 2 3 4 5 6 99 96"

    loc j = 0
    foreach k of local W7codes {
        loc ++j
        loc w : word `j' of $W7OPT
        cap drop w7_`k'
        g byte w7_`k' = (strpos(w7_txt, ";`k';")>0) if w7_txt!=""
        la var w7_`k' "Water treatment method: `w'"
        note  w7_`k' : Dummy =1 if `w' selected; 0→. for cleanliness
        replace w7_`k' = . if w7_`k'==0
    }
    order w7_*, b(w8)

    * -------------------------------
    * W8 — Safety rating of drinking water
    * -------------------------------
    la var w8 "How would you rate the safety of your drinking water from contaminants?"
    note  w8 : Perceived safety (single choice)
    la def WAT_SAFETY 1 "Very unsafe" 2 "Mostly unsafe" 3 "Mostly safe" 4 "Very safe", replace
    la val w8 WAT_SAFETY
	
	order w* , seq a(hhid)

    la lang ${LNG}
    compress
    save "$raw/${dta_file}_${date}_M12_water.dta", replace
}

********************************************************************************
** (EL) ELECTRICITY — EL1–EL5 
********************************************************************************
{
    use "$zzz/data.dta", clear
    keep hhid* el1-el_duration date
    dropmiss hhid, obs force

    la lang ENG, copy new

    * EL1 — Availability of electricity
    la var el1 "Is electricity available in this dwelling?"
    note  el1 : Availability status (single choice)
    la def YN 1 "Yes" 2 "No", replace
    la val el1 YN

    * EL2 — Ownership of electric connection
    la var el2 "Is this your own connection or shared?"
    note  el2 : Ownership/shared status (single choice)
    la def ELEC_CONNOWN 1 "Own connection" 2 "Shared connection", replace
    la val el2 ELEC_CONNOWN

    * EL3 — Source of electricity
    la var el3 "What is the main source of electricity?"
    note  el3 : Source type (single choice)
    la def ELEC_SOURCE 1 "Local electric grid/provider" 2 "Solar" 3 "Charging batteries from neighbor" 4 "Generator" 96 "Others", replace
    la val el3 ELEC_SOURCE

    * EL4 — Provider of electricity
    la var el4 "Who provided the main source of electricity in your house?"
    note  el4 : Provider type (single choice)
    la def ELEC_PROVIDER 1 "Government (public, LGU)" 2 "Private" 3 "No electric system" 99 "Don't know", replace
    la val el4 ELEC_PROVIDER

    * EL5 — Hours of electricity outage in the past week (numeric)
    la var el5 "How many hours was electricity unavailable in your house in the past week? (0 if none)"
    note  el5 : Numeric hours; non-negative; 0 if no outage

	order el* , seq a(hhid)
	
    la lang ${LNG}
    compress
    save "$raw/${dta_file}_${date}_M12_elec.dta", replace
}

********************************************************************************
** (N) INTERNET — N1–N6 
********************************************************************************
{
    use "$zzz/data.dta", clear
    keep hhid* n1-n_duration date
    dropmiss hhid, obs force

    la lang ENG, copy new

    * N1 — Types of internet connection at home (MULTI)
    la var n1 "Does your household have access to internet at your home? (multi-select)"
    note  n1 : Multiple selections; codes stored in n1_txt and expanded to dummies
    cap conf string variable n1
    if _rc { 
		tostring n1, replace force format(%20.0g) 
		}
    replace n1 = strtrim(n1)

    _mkclean n1 n1_txt
    order n1_txt, a(n1)
    drop n1
    note  n1_txt : Cleaned ;code; representation for N1

    #delimit ;
    glo N1OPT `"
        "Yes, Fixed (wired) broadband network"
        "Yes, Fixed (wireless) broadband network"
        "Yes, Satellite broadband network"
        "Yes, Mobile broadband network"
        "No"
    "';
    #delimit cr

    loc j = 0
    foreach k of numlist 1/5 {
        loc ++j
        loc w : word `j' of $N1OPT
        cap drop n1_`k'
        g byte n1_`k' = (strpos(n1_txt, ";`k';")>0) if n1_txt!=""
        la var n1_`k' "Internet at home: `w'"
        note  n1_`k' : Dummy =1 if `w' selected; 0→. for cleanliness
        replace n1_`k' = . if n1_`k'==0
    }
    order n1_*, b(n2)

    * N2 — Devices used to access internet (MULTI)
    la var n2 "What devices/gadgets do household members use to access the internet? (multi-select)"
    note  n2 : Multiple selections; codes in n2_txt and dummies n2_*
    cap conf string variable n2
    if _rc { 
		tostring n2, replace force format(%20.0g) 
		}
    replace n2 = strtrim(n2)

    _mkclean n2 n2_txt
    order n2_txt, a(n2)
    drop n2

    #delimit ;
    glo N2OPT `"
        "Personal Computer (PC) / Desktop"
        "Laptop"
        "Tablet"
        "Smartphone"
        "Smart TV/Monitor"
		"Piso Net (coin-operated internet kiosk)"
		"Basic Phone (non-smartphone with limited internet capability)"
        "Others"
    "';
    #delimit cr

    loc j = 0
    foreach k of numlist 1/5 11 12 96 {
        loc ++j
        loc w : word `j' of $N2OPT
        cap drop n2_`k'
        g byte n2_`k' = (strpos(n2_txt, ";`k';")>0) if n2_txt!=""
        la var n2_`k' "Internet access device: `w'"
        note  n2_`k' : Dummy =1 if `w' selected; 0→. for cleanliness
        replace n2_`k' = . if n2_`k'==0
    }
    order n2_*, b(n3)

    * N3 — Type of internet subscription at home (MULTI)
    la var n3 "What type of Internet connection does your household have? (multi-select)"
    note  n3 : Multiple selections; codes in n3_txt and dummies n3_*
    cap conf string variable n3
    if _rc { 
		tostring n3, replace force format(%20.0g) 
		}
    replace n3 = strtrim(n3)

    _mkclean n3 n3_txt
    order n3_txt, a(n3)
    drop n3

    #delimit ;
    glo N3OPT `"
        "Prepaid"
        "Postpaid / Billed monthly by a provider"
		"Connecting to neighbor's WiFi"
        "Others"
    "';
    #delimit cr

    loc j = 0
    foreach k of numlist 1/2 12 96 {
        loc ++j
        loc w : word `j' of $N3OPT
        cap drop n3_`k'
        g byte n3_`k' = (strpos(n3_txt, ";`k';")>0) if n3_txt!=""
        la var n3_`k' "Internet subscription type: `w'"
        note  n3_`k' : Dummy =1 if `w' selected; 0→. for cleanliness
        replace n3_`k' = . if n3_`k'==0
    }
    order n3_*, b(n4)

    * N4 — Main purposes for internet use (MULTI)
    la var n4 "What are the main purposes for internet use? (multi-select)"
    note  n4 : Multiple selections; codes in n4_txt and dummies n4_*
    cap conf string variable n4
    if _rc { 
		tostring n4, replace force format(%20.0g) 
		}
    replace n4 = strtrim(n4)

    _mkclean n4 n4_txt
    order n4_txt, a(n4)
    drop n4

    #delimit ;
    glo N4OPT `"
        "Communication/social networking"
        "Payments/banking"
        "Search for information/news/current events"
        "Online shopping"
        "Online education"
        "Non-gig work"
        "Gig work"
        "Telehealth/medicine"
        "Use government services"
        "Access government information"
        "Search for jobs"
        "Entertainment/gaming"
    "';
    #delimit cr

    loc j = 0
    foreach k of numlist 1/12 {
        loc ++j
        loc w : word `j' of $N4OPT
        cap drop n4_`k'
        g byte n4_`k' = (strpos(n4_txt, ";`k';")>0) if n4_txt!=""
        la var n4_`k' "Internet purpose: `w'"
        note  n4_`k' : Dummy =1 if `w' selected; 0→. for cleanliness
        replace n4_`k' = . if n4_`k'==0
    }
    order n4_*, b(n5)

    * N5 — Internet interruption > 1 hour in past month
    la var n5 "Did you experience internet interruption of more than an hour in the past month?"
    note  n5 : Service reliability indicator (single choice)
    la def NET_YN 1 "Yes" 2 "No", replace
    la val n5 NET_YN

    * N6 — Where access internet outside home (MULTI)
    la var n6 "Where do you access internet outside of your home? (multi-select)"
    note  n6 : Multiple selections; codes in n6_txt and dummies n6_*
    cap conf string variable n6
    if _rc { 
		tostring n6, replace force format(%20.0g) 
		}
    replace n6 = strtrim(n6)

    _mkclean n6 n6_txt
    order n6_txt, a(n6)
    drop n6

    #delimit ;
    glo N6OPT `"
        "Piso wifi"
        "Hotspots from government offices"
        "Hotspots from private establishments (malls, cafes, etc.)"
        "School / Office"
        "Neighbors / Other households"
        "Mobile broadband network / Mobile data"
        "None"
    "';
    #delimit cr

    loc j = 0
    foreach k of numlist 1/7 {
        loc ++j
        loc w : word `j' of $N6OPT
        cap drop n6_`k'
        g byte n6_`k' = (strpos(n6_txt, ";`k';")>0) if n6_txt!=""
        la var n6_`k' "Access internet outside home: `w'"
        note  n6_`k' : Dummy =1 if `w' selected; 0→. for cleanliness
        replace n6_`k' = . if n6_`k'==0
    }

	order n*, seq a(hhid)
	
    la lang ${LNG}
    compress
    save "$raw/${dta_file}_${date}_M12_net.dta", replace
}

********************************************************************************
** (HC) DURABLES 
********************************************************************************
{
    use "$zzz/data.dta", clear
    keep hhid* hc1* hc2* hc3* hc_duration date
    dropmiss hhid, obs force

    la lang ENG, copy new

    * ================================================================
    * HC1 — ASSETS: numeric counts per item (0 if none)
    * We keep BOTH lettered (hc1a…hc1h) and underscore (hc1_1…hc1_8) forms.
    * ================================================================
    note  hc1_1 : Refrigerator/Freezer (alternate column)
    cap la var hc1_1 "How many does the household own? Refrigerator/Freezer"

    note  hc1_2 : Washing Machine (alternate column)
    cap la var hc1_2 "How many does the household own? Washing Machine"

    note  hc1_3 : Air conditioner (alternate column)
    cap la var hc1_3 "How many does the household own? Air conditioner"

    note  hc1_4 : Stove with oven / gas range (alternate column)
    cap la var hc1_4 "How many does the household own? Stove with oven/gas range"

    note  hc1_5 : Motorcycle/Tricycle (alternate column)
    cap la var hc1_5 "How many does the household own? Motorcycle/Tricycle"

    note  hc1_6 : Car/jeep/van (alternate column)
    cap la var hc1_6 "How many does the household own? Car, jeep, van"

    note  hc1_7 : Personal computer (alternate column)
    cap la var hc1_7 "How many does the household own? Personal computer (desktop, laptop, notebook, netbook, others)"

    note  hc1_8 : Motorized boat/banca (alternate column)
    cap la var hc1_8 "How many does the household own? Motorized boat/banca"

    * ================================================================
    * Common Yes/No value label (reuse across HC2 & HC3)
    * ================================================================
    la def DUR_YN 1 "Yes" 2 "No", replace

    * ================================================================
    * HC2 — Household service expenses (each item 1=Yes, 2=No)
    * ================================================================
    la var hc2a "In the last 6 months, did your household pay for services of a Maid?"
    note  hc2a : Domestic service expense indicator — Maid (1=Yes,2=No)
    la val hc2a DUR_YN

    la var hc2b "In the last 6 months, did your household pay for services of a Cook?"
    note  hc2b : Domestic service expense indicator — Cook (1=Yes,2=No)
    la val hc2b DUR_YN

    la var hc2c "In the last 6 months, did your household pay for services of a Driver?"
    note  hc2c : Domestic service expense indicator — Driver (1=Yes,2=No)
    la val hc2c DUR_YN

    la var hc2d "In the last 6 months, did your household pay for other domestic services (launderer, child care, caregiver, gardener, etc.)?"
    note  hc2d : Domestic service expense indicator — Other (1=Yes,2=No)
    la val hc2d DUR_YN

    * ================================================================
    * HC3 — Energy items used for cooking (each 1=Yes, 2=No)
    * We also label underscore variants if present.
    * ================================================================
    la var hc3a "Used for cooking: Electricity for cooking"
    note  hc3a : Cooking energy — Electricity (1=Yes,2=No)
    la val hc3a DUR_YN

    la var hc3b "Used for cooking: LPG"
    note  hc3b : Cooking energy — LPG (1=Yes,2=No)
    la val hc3b DUR_YN

    la var hc3c "Used for cooking: Kerosene"
    note  hc3c : Cooking energy — Kerosene (1=Yes,2=No)
    la val hc3c DUR_YN

    la var hc3d "Used for cooking: Fuelwood"
    note  hc3d : Cooking energy — Fuelwood (1=Yes,2=No)
    la val hc3d DUR_YN

    la var hc3e "Used for cooking: Charcoal"
    note  hc3e : Cooking energy — Charcoal (1=Yes,2=No)
    la val hc3e DUR_YN

    la var hc3f "Used for cooking: Other fuels (biomass residues, etc.)"
    note  hc3f : Cooking energy — Other fuels (1=Yes,2=No)
    la val hc3f DUR_YN

	order hc*, seq a(hhid)

    la lang ${LNG}
    compress
    save "$raw/${dta_file}_${date}_M13_hc.dta", replace
}

********************************************************************************
** (V) PERCEPTIONS / VIEWS — V1–V10 
********************************************************************************
{
    use "$zzz/data.dta", clear
    keep hhid* v1-v10e v_duration date v2
    dropmiss hhid, obs force

    la lang ENG, copy new

    * -------------------------------
    * V1 — Overall life satisfaction (1..5)
    * -------------------------------
    la var v1 "On a scale from one to five, where 1 is not satisfied at all and 5 is completely satisfied, how satisfied with life are you, in general?"
    note  v1 : Life satisfaction ladder; single choice (1–5)
    la def VW_LIFESAT ///
        1 "Not satisfied at all" ///
        2 "Partly satisfied" ///
        3 "Satisfied" ///
        4 "More than Satisfied" ///
        5 "Completely satisfied", replace
    la val v1 VW_LIFESAT

    * -------------------------------
    * V2 — Self income classification (1..5)
    * -------------------------------
    la var v2 "Imagine the total population of Philippines is divided into 5 income groups from poorest to richest, each with the same number of people. In which of these income groups do you place your household?"
    note  v2 : Self-placement in income quintiles; single choice (1–5)
    la def VW_INCOMECLASS ///
        1 "Poorest group" ///
        2 "2nd poorest group" ///
        3 "Middle group" ///
        4 "2nd richest group" ///
        5 "Richest group", replace
    la val v2 VW_INCOMECLASS

    * -------------------------------
    * V3 — Expected income class of children (1..5)
    * -------------------------------
    la var v3 "If the current situation continues, which income group do you think your children or younger members of your family will belong to when they reach your age?"
    note  v3 : Expected intergenerational position; single choice (1–5)
    la val v3 VW_INCOMECLASS   // reuse

    * -------------------------------
    * V4 — Most important factor for expected children's income group
    * -------------------------------
    la var v4 "What is the most important factor influencing your answer earlier (expected income group of your children)?"
    note  v4 : Single most-important factor; single choice
    la def VW_CHILD_FACTOR ///
        1 "Education" ///
        2 "Income" ///
        3 "Access to influential individuals" ///
        4 "Race / Ethnicity" ///
        5 "Religion" ///
        6 "Gender", replace
    la val v4 VW_CHILD_FACTOR

    * -------------------------------
    * V5 — Household economic situation vs. last month (1..5)
    * -------------------------------
    la var v5 "Relative to last month, do you think the economic situation of your household has significantly improved, slightly improved, stayed the same, slightly worsened, or significantly worsened?"
    note  v5 : Retrospective monthly change; single choice (1–5)
    la def VW_ECONCHANGE ///
        1 "Significantly worsened" ///
        2 "Slightly worsened" ///
        3 "Stayed the same" ///
        4 "Slightly improved" ///
        5 "Significantly improved", replace
    la val v5 VW_ECONCHANGE

    * -------------------------------
    * V6 — Statement best describing current reality in the Philippines
    * -------------------------------
    la var v6 "In your opinion, which of the following statements best describes the current reality in the Philippines?"
    note  v6 : Mobility/effort belief; single choice
    la def VW_REALITY ///
        1 "It is easy for people to improve their economic situation even if they don't work hard" ///
        2 "It is easy for people to improve their economic situation if they are willing to work hard" ///
        3 "People find it difficult to improve their economic situation even if they work hard" ///
        4 "It is impossible for people to improve their economic situation even if they work hard" ///
        99 "Don't know/don't want to answer", replace
    la val v6 VW_REALITY

    * -------------------------------
    * V7 — Most influential factor for progress/success
    * -------------------------------
    la var v7 "What is the most important factor influencing progress/success in life?"
    note  v7 : Single most-important factor; single choice
    la def VW_SUCCESS_FACTOR ///
        1 "Rich family" ///
        2 "Highly educated parents" ///
        3 "Highly educated (individual)" ///
        4 "Hard work" ///
        5 "Using influential individuals" ///
        6 "Giving or receiving bribes" ///
        7 "Race / Ethnicity" ///
        8 "Religion" ///
        9 "Gender", replace
    la val v7 VW_SUCCESS_FACTOR

    * -------------------------------
    * V8 — Safety meter (walking alone at night)
    * -------------------------------
    la var v8 "How safe do you feel walking alone in your area (i.e., neighborhood or village) at night?"
    note  v8 : Perceived safety scale; single choice
    la def VW_SAFETY ///
        1 "Unsafe" ///
        2 "Somewhat unsafe" ///
        3 "Somewhat safe" ///
        4 "Safe" ///
        5 "I'm afraid to be alone" ///
        99 "Don't know", replace
    la val v8 VW_SAFETY

    * ================================================================
    * V9 — Agreement statements (a,b,c,d,e,f,g,h,i,j,l,k) — 1..5
    * Statement f additionally allows 6 = No children
    * ================================================================
    la def VW_AGREE5 ///
        1 "Strongly disagree" ///
        2 "Disagree" ///
        3 "Neither agree nor disagree" ///
        4 "Agree" ///
        5 "Strongly agree", replace

    la var v9a "Prices for the things I buy are rising too quickly"
    note  v9a : Agreement scale 1–5
    la val v9a VW_AGREE5

    la var v9b "Now is a good time to find a job where I live"
    note  v9b : Agreement scale 1–5
    la val v9b VW_AGREE5

    la var v9c "I am optimistic about the economic future of the country"
    note  v9c : Agreement scale 1–5
    la val v9c VW_AGREE5

    la var v9d "My family's financial situation is worse now than it was two years ago"
    note  v9d : Agreement scale 1–5
    la val v9d VW_AGREE5

    la var v9e "Citizens should have more say in important government decisions"
    note  v9e : Agreement scale 1–5
    la val v9e VW_AGREE5

    la var v9f "I am worried about being able to give my children a good education (give option for no children)"
    note  v9f : Agreement scale 1–5 with 6 = No children
    la def VW_AGREE5_F ///
        1 "Strongly disagree" ///
        2 "Disagree" ///
        3 "Neither agree nor disagree" ///
        4 "Agree" ///
        5 "Strongly agree" ///
        6 "No children", replace
    la val v9f VW_AGREE5_F

    la var v9g "I am worried about losing my job (or not finding a job)"
    note  v9g : Agreement scale 1–5
    la val v9g VW_AGREE5

    la var v9h "I am worried about losing my job due to AI or other advanced technology"
    note  v9h : Agreement scale 1–5
    la val v9h VW_AGREE5

    la var v9i "I am worried about political instability in my country"
    note  v9i : Agreement scale 1–5
    la val v9i VW_AGREE5

    la var v9j "Digital public services helped me save time or cost"
    note  v9j : Agreement scale 1–5
    la val v9j VW_AGREE5

//     cap la var v9l "<<placeholder for rice prices>>"
//     cap la val v9l VW_AGREE5
//     note v9l : Agreement scale 1–5 (placeholder)

    la var v9k "The taxes that I pay are being well spent on priorities to help the country"
    note  v9k : Agreement scale 1–5
    la val v9k VW_AGREE5

    * ================================================================
    * V10 — Support/Oppose statements (a..e) — 1..5
    * ================================================================
    la def VW_SUPPORT5 ///
        1 "Strongly oppose" ///
        2 "Somewhat oppose" ///
        3 "Neither support nor oppose" ///
        4 "Somewhat support" ///
        5 "Strongly support", replace

    la var v10a "The government directing the economy"
    note  v10a : Support scale 1–5
    la val v10a VW_SUPPORT5

    la var v10b "Imported goods from other countries should be strictly limited"
    note  v10b : Support scale 1–5
    la val v10b VW_SUPPORT5

    la var v10c "The government provides useful digital services"
    note  v10c : Support scale 1–5
    la val v10c VW_SUPPORT5

    la var v10d "Taxes should be increased to pay for better public services, like education and roads."
    note  v10d : Support scale 1–5
    la val v10d VW_SUPPORT5

    la var v10e "Using more green energy and increasing recycling in this country should be a top priority for the Government."
    note  v10e : Support scale 1–5
    la val v10e VW_SUPPORT5

    la lang ${LNG}
    compress
    save "$raw/${dta_file}_${date}_M14_view.dta", replace
}

*******************************************************************************
**# (X) NEXT       
********************************************************************************
	{
	use "$zzz/data.dta", clear 

		keep hhid* x1-x_duration date
		
	loc  var ""
	foreach v in   {
		foreach i of numlist 1/25 {
		
			cap ren `v'`i' `v'_`i'
		}
		loc  var "`var' `v'_"
	
	}  	
	di "`var'"
	
	dropmiss hhid, obs force

	la lang ENG, copy new 
	

	* ================================================================
	* MODULE NEXT (X1–X10)
	* Prefix: nxt_
	* ================================================================

	* ------------------------------------------------
	* X1 — WILLINGNESS TO JOIN FUTURE SURVEYS
	* ------------------------------------------------
	ren x1 nxt_followup_consent
	la var nxt_followup_consent "Are you willing to be contacted for future surveys?"
	la def NXT_CONSENT ///
		1 "I agree" ///
		2 "No, I do not agree" ///
		, replace
	la val nxt_followup_consent NXT_CONSENT


	* ------------------------------------------------
	* X2 — CONTACT DETAILS (ask if X1==1)
	* (Handle alternate raw names with cap ren)
	* ------------------------------------------------
	cap ren x2_landline nxt_contact_landline
	cap ren x2a        nxt_contact_landline
	cap la var nxt_contact_landline "Best number to reach you (Landline)"

	cap ren x2_mobile  nxt_contact_mobile
	cap ren x2b        nxt_contact_mobile
	cap la var nxt_contact_mobile "Best number to reach you (Mobile)"

	cap ren x2_email   nxt_contact_email
	cap ren x2c        nxt_contact_email
	cap la var nxt_contact_email "Email address"


	* ------------------------------------------------
	* X3 — BEST DAY(S) TO REACH (MULTIPLE)
	* ------------------------------------------------
	ren x3 nxt_contact_days
	la var nxt_contact_days "What day(s) of the week will be best to reach you? (multi-select source)"
	_mkclean nxt_contact_days nxt_contact_days_clean

	loc X3lab1 "Monday"
	loc X3lab2 "Tuesday"
	loc X3lab3 "Wednesday"
	loc X3lab4 "Thursday"
	loc X3lab5 "Friday"
	loc X3lab6 "Saturday"
	loc X3lab7 "Sunday"

	foreach k in 1 2 3 4 5 6 7 {
		cap drop nxt_contact_day_`k'
		g byte nxt_contact_day_`k' = (strpos(nxt_contact_days_clean, ";`k';") > 0) if nxt_contact_days_clean!=""
		replace nxt_contact_day_`k' = 0 if missing(nxt_contact_day_`k')
		loc L `"`X3lab`k''"'
		la var nxt_contact_day_`k' "Best day to reach: `L'"
	}
	order nxt_contact_day_*, after(nxt_contact_days)


	* ------------------------------------------------
	* X4 — BEST TIME(S) TO REACH (MULTIPLE)
	* ------------------------------------------------
	ren x4 nxt_contact_times
	la var nxt_contact_times "What time(s) of the day would be best to contact you? (multi-select source)"
	_mkclean nxt_contact_times nxt_contact_times_clean

	loc X4lab1 "Morning"
	loc X4lab2 "Afternoon"
	loc X4lab3 "Evening"

	foreach k in 1 2 3 {
		cap drop nxt_contact_time_`k'
		g byte nxt_contact_time_`k' = (strpos(nxt_contact_times_clean, ";`k';") > 0) if nxt_contact_times_clean!=""
		replace nxt_contact_time_`k' = 0 if missing(nxt_contact_time_`k')
		loc L `"`X4lab`k''"'
		la var nxt_contact_time_`k' "Best time to reach: `L'"
	}
	order nxt_contact_time_*, after(nxt_contact_times)


	* ------------------------------------------------
	* X5 — CONSENT FOR LEAD TESTING (ask if painted; per instrument)
	* ------------------------------------------------
	ren x5 nxt_lead_consent
	la var nxt_lead_consent "Are you willing to participate in lead testing (swab on interior wall paint)?"
	la def NXT_LEADCONSENT ///
		1 "Willing to participate" ///
		2 "Not willing to participate" ///
		, replace
	la val nxt_lead_consent NXT_LEADCONSENT

	* X5b — Lead testing result (if consented)
	cap ren x5b nxt_lead_result
	la var nxt_lead_result "Lead testing result (recorded by interviewer)"
	la def NXT_LEADRESULT ///
		1 "Positive" ///
		2 "Negative" ///
		, replace
	la val nxt_lead_result NXT_LEADRESULT

	* ------------------------------------------------
	* X7 — CALL STATUS (FOR INTERVIEWER)
	* ------------------------------------------------
	ren x7 nxt_call_status
	la var nxt_call_status "What is the result of the interview?"
	la def NXT_CALLSTATUS ///
		1  "Complete" ///
		2  "Partially complete, no more callback" ///
		3  "Partially complete, scheduled another call" ///
		4  "Not yet started, with scheduled callback" ///
		98 "Refused" ///
		95 "Nobody answering / Door loc k" ///
		99 "Don't know the household" ///
		, replace
	la val nxt_call_status NXT_CALLSTATUS


	* ------------------------------------------------
	* X8 — INTERVIEWER'S REMARKS (open-end)
	* ------------------------------------------------
	cap ren x8 nxt_interviewer_remarks
	cap la var nxt_interviewer_remarks "Interviewer remarks (open-end)"


	* ------------------------------------------------
	* X9 — ENUMERATOR RATING: APPROPRIATENESS
	* ------------------------------------------------
	ren x9 nxt_enum_rating_appropriate
	la var nxt_enum_rating_appropriate "How appropriate were the respondent's answers?"
	la def NXT_RATE5 ///
		1 "Very poor" ///
		2 "Not good" ///
		3 "Adequate" ///
		4 "Good" ///
		5 "Very good" ///
		, replace
	la val nxt_enum_rating_appropriate NXT_RATE5


	* ------------------------------------------------
	* X10 — ENUMERATOR RATING: SERIOUSNESS
	* ------------------------------------------------
	ren x10 nxt_enum_rating_serious
	la var nxt_enum_rating_serious "How serious were the respondent's answers?"
	* reuse NXT_RATE5
	la val nxt_enum_rating_serious NXT_RATE5

	la lang ${LNG}
	compress 	
	save "$raw/${dta_file}_${date}_M15_next.dta", replace
	

	}	
	
/*
********************************************************************************
** (X) NEXT — X1–X10 | household-level (same style as prior modules) + NOTES
** Conventions: la var / la def ..., replace / la val / cap / loc / #delimit.
** Keep original names (x1..x10). Use _mkclean for multi-select (X3, X4).
********************************************************************************
{
    use "$zzz/data.dta", clear
    keep hhid x1-x10 x2* x5b x_duration date
    dropmiss hhid, obs force

    la lang ENG, copy new

    * -------------------------------
    * X1 — Willingness to join future surveys
    * -------------------------------
    la var x1 "Are you willing to be contacted for future surveys?"
    note  x1 : Follow-up consent; single choice
    la def NXT_CONSENT 1 "I agree" 2 "No, I do not agree", replace
    la val x1 NXT_CONSENT

    * -------------------------------
    * X2 — Contact details (ask if X1==1). Label alternates if present.
    * -------------------------------
    cap la var x2_landline "Best number to reach you (Landline)"
    cap la var x2a        "Best number to reach you (Landline)"
    note x2_landline : Only if X1==1; free text (phone)
    note x2a        : Only if X1==1; free text (phone)

    cap la var x2_mobile  "Best number to reach you (Mobile)"
    cap la var x2b        "Best number to reach you (Mobile)"
    note x2_mobile : Only if X1==1; free text (mobile)
    note x2b       : Only if X1==1; free text (mobile)

    cap la var x2_email   "Email address"
    cap la var x2c        "Email address"
    note x2_email : Only if X1==1; free text (email)
    note x2c      : Only if X1==1; free text (email)

    * -------------------------------
    * X3 — Best day(s) to reach (MULTI)
    * -------------------------------
    la var x3 "What day(s) of the week will be best to reach you? (multi-select)"
    note  x3 : Multiple selections; cleaned into x3_txt + dummies x3_*
    cap conf string variable x3
    if _rc { tostring x3, replace force format(%20.0g) }
    replace x3 = strtrim(x3)

    _mkclean x3 x3_txt
    order x3_txt, a(x3)
    drop x3
    note  x3_txt : Cleaned ;code; representation (e.g., ;1;3;7;)

    #delimit ;
    glo X3OPT `"
        "Monday"
        "Tuesday"
        "Wednesday"
        "Thursday"
        "Friday"
        "Saturday"
        "Sunday"
    "';
    #delimit cr
    loc X3codes "1 2 3 4 5 6 7"

    loc j = 0
    foreach k of local X3codes {
        loc ++j
        loc w : word `j' of $X3OPT
        cap drop x3_`k'
        g byte x3_`k' = (strpos(x3_txt, ";`k';")>0) if x3_txt!=""
        la var x3_`k' "Best day to reach: `w'"
        note  x3_`k' : Dummy =1 if `w' selected; 0→. for cleanliness
        replace x3_`k' = . if x3_`k'==0
    }
    order x3_*, after(x3_txt)

    * -------------------------------
    * X4 — Best time(s) to reach (MULTI)
    * -------------------------------
    la var x4 "What time(s) of the day would be best to contact you? (multi-select)"
    note  x4 : Multiple selections; cleaned into x4_txt + dummies x4_*
    cap conf string variable x4
    if _rc { tostring x4, replace force format(%20.0g) }
    replace x4 = strtrim(x4)

    _mkclean x4 x4_txt
    order x4_txt, a(x4)
    drop x4
    note  x4_txt : Cleaned ;code; representation (e.g., ;1;3;)

    #delimit ;
    glo X4OPT `"
        "Morning"
        "Afternoon"
        "Evening"
    "';
    #delimit cr
    loc X4codes "1 2 3"

    loc j = 0
    foreach k of local X4codes {
        loc ++j
        loc w : word `j' of $X4OPT
        cap drop x4_`k'
        g byte x4_`k' = (strpos(x4_txt, ";`k';")>0) if x4_txt!=""
        la var x4_`k' "Best time to reach: `w'"
        note  x4_`k' : Dummy =1 if `w' selected; 0→. for cleanliness
        replace x4_`k' = . if x4_`k'==0
    }
    order x4_*, after(x4_txt)

    * -------------------------------
    * X5 — Consent for lead testing
    * -------------------------------
    la var x5 "Are you willing to participate in lead testing (swab on interior wall paint)?"
    note  x5 : Lead testing consent; single choice
    la def NXT_LEADCONSENT 1 "Willing to participate" 2 "Not willing to participate", replace
    la val x5 NXT_LEADCONSENT

    * X5b — Lead testing result (if consented)
    cap la var x5b "Lead testing result (recorded by interviewer)"
    la def NXT_LEADRESULT 1 "Positive" 2 "Negative", replace
    cap la val x5b NXT_LEADRESULT

    * -------------------------------
    * X7 — Call status (for interviewer)
    * -------------------------------
    la var x7 "What is the result of the interview?"
    note  x7 : Final call result; single choice
    la def NXT_CALLSTATUS ///
        1  "Complete" ///
        2  "Partially complete, no more callback" ///
        3  "Partially complete, scheduled another call" ///
        4  "Not yet started, with scheduled callback" ///
        98 "Refused" ///
        95 "Nobody answering / Door lock" ///
        99 "Don't know the household", replace
    la val x7 NXT_CALLSTATUS

    * -------------------------------
    * X8 — Interviewer remarks (open-end)
    * -------------------------------
    cap la var x8 "Interviewer remarks (open-end)"
    note x8 : Free text; interviewer observations or notes

    * -------------------------------
    * X9 — Enumerator rating: appropriateness
    * -------------------------------
    la var x9 "How appropriate were the respondent's answers?"
    note  x9 : Enumerator rating; single choice (1–5)
    la def NXT_RATE5 1 "Very poor" 2 "Not good" 3 "Adequate" 4 "Good" 5 "Very good", replace
    la val x9 NXT_RATE5

    * -------------------------------
    * X10 — Enumerator rating: seriousness
    * -------------------------------
    la var x10 "How serious were the respondent's answers?"
    note  x10 : Enumerator rating; single choice (1–5)
    la val x10 NXT_RATE5   // reuse

    * ---------- Short QC (non-destructive) ----------
    cap drop qc_x2_needed_when_consent
    gen byte qc_x2_needed_when_consent = (x1==1 & missing(x2_landline, x2a, x2_mobile, x2b, x2_email, x2c))
    la var  qc_x2_needed_when_consent  "QC: X1==Agree but all contact details are missing"

    la lang ${LNG}
    compress
    save "$raw/${dta_file}_${date}_M21_next.dta", replace
}
*/	
	