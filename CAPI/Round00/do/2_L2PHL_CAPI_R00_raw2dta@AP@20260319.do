* Data Cleaning of L2Phl 2025 Baseline
* Official Data 
* FROM RAW data TO CLEAN data set Before cleaning
* created by Avralt-Od Purevjav
* modified by Avraa 
* last updated:  Mar 19, 2026
	
	
	
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

	glo dta_file l2phl
	
	glo date ${Y}${M}${D}	
	glo date_filter "date <= mdy($M, $D, $Y)"
	
	cap adopath - "$wd\ado\"		
	// making sure are there defined commands
	foreach prog in kobo2stata _gwtmean extremes ///
		winsor2 povdeco apoverty ds3 ///
			clonevar confirmdir unique copydesc {
				cap which `prog'
					if _rc ssc install `prog' , replace all
	}
	adopath + "$wd\ado\"
	
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

}

	
********************************************************************************
**# (M0) HOUSEHOLD PASSPORT
********************************************************************************
    
{
    use "$raw/${dta_file}_${date}_M00_passport.dta", clear 
	
	
	la lang ${LNG} 
	
	//here correcting the mistakes 
		// replace var = correctvalue....  if var = wrongvalue hhid ==  & fmid 
	
	do "${wd}/fix/do/M00.do"
	
	*drop h z3 z4 z5 d1 d3 d4 interviewer_id psgcold
	

	save "$dta/${dta_file}_${date}_M00_passport.dta", replace
	
    glo mod M00

    confirmdir "${fix}/${mod}/"
        if _rc ~= 0 mkdir "${fix}/${mod}"
    glo sec "${wd}/fix/${date}/${mod}"
	
	export excel using  "${fix}/${mod}/${dta_file}_${date}_M00_passport.xlsx" ///
		, replace firstrow(var) nol 	
	

// Prefix labels with var name (nice for Excel firstrow(varl))
    foreach var of varlist _all {
        local varlab: variable label `var'
        la var `var' "`var': `varlab'"
    }

    // IDs shown in every export
    glo IDENT "hhid_str ecode psgc region province city barangay locale date visit agreement longitude latitude nhhs hhmember"

    // Module duration variables (from your list)
    local MODDURS dur_passport d_duration ed_duration a_duration i_duration f_duration ///
                  m_duration h_duration fo_duration nf_duration ssb_duration ///
                  nh_duration dw_duration s_duration w_duration el_duration ///
                  c_duration n_duration hc_duration v_duration x_duration

    // Build a TODAY guard only if date is numeric daily
    local TODAY = date(c(current_date),"DMY")
    local capcond ""
    capture confirm numeric variable date
    if !_rc local capcond "& date <= `TODAY'"

    // Counter for filenames
    local o = 0
    quietly count

    // ---------------- Base uniqueness (helpful) ----------------
  
    capture confirm variable hhid
    if !_rc {
        unique hhid
            as `r(N)' == `r(unique)' 
    }

    // ================== DURATION CHECKS ==================

    // 01) Any module duration <= 0
    tempvar __nonpos
    gen byte `__nonpos' = 0
    foreach v of local MODDURS {
        capture confirm numeric variable `v'
        if !_rc replace `__nonpos' = `__nonpos' | (`v' <= 0 & !missing(`v'))
    }
    glo filter    "if `__nonpos' == 1"
    glo namext    "any_module_duration_nonpositive"
    glo exportvars "`MODDURS'"
    local ++o
    if `o' < 10 local o="0`o'"
    count $filter `capcond'
    if `r(N)' > 0 {
        export excel ${IDENT} ${exportvars} $filter `capcond' using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", ///
            replace firstrow(varl) nol
    }

    // 02) Any module duration missing (useful to catch partials)
    tempvar __dmiss
    egen `__dmiss' = rowmiss(`MODDURS')
    glo filter    "if `__dmiss' > 0"
    glo namext    "any_module_duration_missing"
    glo exportvars "`MODDURS'"
    local ++o
    if `o' < 10 local o="0`o'"
    count $filter `capcond'
    if `r(N)' > 0 {
        export excel ${IDENT} ${exportvars} $filter `capcond' using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", ///
            replace firstrow(varl) nol
    }

    // (Optional but helpful) Outlier module durations: <0 or >60 minutes
    tempvar __out
    gen byte `__out' = 0
    foreach v of local MODDURS {
        capture confirm numeric variable `v'
        if !_rc replace `__out' = `__out' | ((`v' < 0 | `v' > 60) & !missing(`v'))
    }
    glo filter    "if `__out' == 1"
    glo namext    "duration_outliers_negative_to60min"
    glo exportvars "`MODDURS'"
    local ++o
    if `o' < 10 local o="0`o'"
    count $filter `capcond'
    if `r(N)' > 0 {
        export excel ${IDENT} ${exportvars} $filter `capcond' using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", ///
            replace firstrow(varl) nol
    }

    // ================== HH MEMBER CHECKS ==================

    // 03) hhmember outside [0,10]
    capture confirm numeric variable hhmember
    if !_rc {
        glo filter    "if hhmember < 0 | hhmember > 10"
        glo namext    "hhmember_out_of_range_0to10"
        glo exportvars "hhmember"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter `capcond'
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter `capcond' using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", ///
                replace firstrow(varl) nol
        }

        glo filter    "if missing(hhmember)"
        glo namext    "hhmember_missing"
        glo exportvars "hhmember"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter `capcond'
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter `capcond' using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", ///
                replace firstrow(varl) nol
        }
    }

    // ================== CORE "IMPORTANT" SANITY CHECKS ==================

    // 04) visit code ∈ {1,2,3}
    capture confirm numeric variable visit
    if !_rc {
        glo filter    "if !inlist(visit,1,2,3) & !missing(visit)"
        glo namext    "visit_badcode"
        glo exportvars "visit"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter `capcond'
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter `capcond' using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", ///
                replace firstrow(varl) nol
        }
    }

    // 05) agreement code ∈ {1,2}
    capture confirm numeric variable agreement
    if !_rc {
        glo filter    "if !inlist(agreement,1,2) & !missing(agreement)"
        glo namext    "agreement_badcode"
        glo exportvars "agreement"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter `capcond'
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter `capcond' using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", ///
                replace firstrow(varl) nol
        }
    }

    // 06) locale ∈ {1,2} (Urban/Rural)
    capture confirm numeric variable locale
    if !_rc {
        glo filter    "if !inlist(locale,1,2) & !missing(locale)"
        glo namext    "locale_badcode"
        glo exportvars "locale"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter `capcond'
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter `capcond' using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", ///
                replace firstrow(varl) nol
        }
    }

    // 07) language missing
    capture confirm numeric variable lang
    if !_rc {
        glo filter    "if missing(lang)"
        glo namext    "language_missing"
        glo exportvars "lang"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter `capcond'
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter `capcond' using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", ///
                replace firstrow(varl) nol
        }
    }

    // 08) GPS validity
    capture confirm numeric variable latitude
    local has_lat = !_rc
    capture confirm numeric variable longitude
    local has_lon = !_rc
    if `has_lat' & `has_lon' {
        glo filter    "if missing(latitude) | missing(longitude) | latitude<-90 | latitude>90 | longitude<-180 | longitude>180"
        glo namext    "gps_invalid_or_missing"
        glo exportvars "latitude longitude"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter `capcond'
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter `capcond' using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", ///
                replace firstrow(varl) nol
        }
    }

    // 09) Location hierarchy presence
    capture confirm variable province
    local has_prov = !_rc
    capture confirm variable city
    local has_city = !_rc
    capture confirm variable barangay
    local has_brg  = !_rc

    if `has_prov' {
        glo filter    "if missing(province)"
        glo namext    "province_missing"
        glo exportvars "province"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter `capcond'
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter `capcond' using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", ///
                replace firstrow(varl) nol
        }
    }
    if `has_prov' & `has_city' {
        glo filter    "if !missing(province) & missing(city)"
        glo namext    "city_missing"
        glo exportvars "province city"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter `capcond'
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter `capcond' using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", ///
                replace firstrow(varl) nol
        }
    }
    if `has_city' & `has_brg' {
        glo filter    "if !missing(city) & missing(barangay)"
        glo namext    "barangay_missing"
        glo exportvars "city barangay"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter `capcond'
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter `capcond' using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", ///
                replace firstrow(varl) nol
        }
    }

    // 10) Enumerator/PSGC presence
    capture confirm variable ecode
    if !_rc {
        glo filter    "if missing(ecode)"
        glo namext    "ecode_missing"
        glo exportvars "ecode"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter `capcond'
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter `capcond' using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", ///
                replace firstrow(varl) nol
        }
    }
    capture confirm variable psgc
    if !_rc {
        glo filter    "if missing(psgc)"
        glo namext    "psgc_missing"
        glo exportvars "psgc"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter `capcond'
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter `capcond' using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", ///
                replace firstrow(varl) nol
        }
    }
}


		
********************************************************************************
**# (D) HOUSEHOLD ROSTER
********************************************************************************
	{
	
	use "$raw/${dta_file}_${date}_M01_roster.dta", clear

	
	la lang ${LNG} 
	format hhid %16.0f

	drop if hhid == 1004215004102050 & fmid == 6
	
	save "$raw/${dta_file}_${date}_M01_roster.dta", replace
	
	use "$raw/${dta_file}_${date}_M01_roster.dta", clear

	
	la lang ${LNG} 
	
	//here correcting the mistakes 
		// replace var = correctvalue....  if var = wrongvalue hhid ==  & fmid 
	
	do "${wd}/fix/do/M01.do"
	
	
	/// MULTIPLE TO SINGLE ON 20251218 BY MANDAKH 
	
	******************************************************
	* A) Value label for Disability Types
	******************************************************

	la def DISABILITY_TYPE ///
		1  "Visual Disability" ///
		2  "Perforated eardrum" ///
		3  "Intellectual learning/Mental/Psychosocial Disability" ///
		4  "Speech and Language Impairment" ///
		5  "Cancer" ///
		6  "Rare Disease" ///
		16 "Amputated leg" ///
		17 "Difficulty walking" ///
		21 "Hydrocephalus" ///
		22 "Hypertension" ///
		23 "Ventricular Septal Defect" ///
		24 "Genetic condition" ///
		26 "Scoliosis" ///
		27 "Physical disability" ///
		28 "Mild stroke/ stroke" ///
		30 "Polio" ///
		32 "Heart condition" ///
		33 "Arm injury" ///
		34 "Arthritis" ///
		37 "Dizziness" ///
		38 "Austism Spectrum Disorder" ///
		39 "Finger fracture" ///
		43 "Dislocated bone" ///
		44 "Cerebral Palsy" ///
		45 "Diabetic" ///
		46 "Epilepsy" ///
		47 "Leg disability" ///
		49 "Hand amputation" ///
		52 "Hand injury" ///
		53 "Paralyzed" ///
		55 "Chronic kidney disease" ///
		56 "Nerve damage" ///
		57 "Cleft lip" ///
		58 "Missing teeth" ///
		59 "Arm/hand impairment" ///
		60 "Broken leg" ///
		61 "Had surgey" ///
		62 "Asthma" ///
		63 "Systemic Lupus Erythematosus" ///
		66 "Tendinopathy" ///
		67 "Limp" ///
		68 "Difficulty standing" ///
		, replace
		
	
	******************************************************
	* B) Build disability_type1 disability_type2 ...
	******************************************************

	* codes in the order you want to peel off
	local codes 1 2 3 4 5 6 16 17 21 22 23 24 26 27 28 30 32 33 34 37 ///
				38 39 43 44 45 46 47 49 52 53 55 56 57 58 59 60 61 62 ///
				63 66 67 68

	* count selections per person
	egen disability_ntypes = rowtotal( ///
		disability_type_1  disability_type_2  disability_type_3  disability_type_4  disability_type_5  disability_type_6 ///
		disability_type_16 disability_type_17 disability_type_21 disability_type_22 disability_type_23 disability_type_24 ///
		disability_type_26 disability_type_27 disability_type_28 disability_type_30 disability_type_32 disability_type_33 ///
		disability_type_34 disability_type_37 disability_type_38 disability_type_39 disability_type_43 disability_type_44 ///
		disability_type_45 disability_type_46 disability_type_47 disability_type_49 disability_type_52 disability_type_53 ///
		disability_type_55 disability_type_56 disability_type_57 disability_type_58 disability_type_59 disability_type_60 ///
		disability_type_61 disability_type_62 disability_type_63 disability_type_66 disability_type_67 disability_type_68 ///
	)
	quietly summarize disability_ntypes, meanonly
	local max = r(max)

	* make "remaining" copies
	foreach c of local codes {
		capture confirm variable disability_type_`c'
		if !_rc {
			gen byte disability_rem_`c' = disability_type_`c'
		}
	}

	* create disability_type1 ... disability_type`max'
	forvalues k = 1/`max' {
		gen disability_type`k' = .

		foreach c of local codes {
			capture confirm variable disability_rem_`c'
			if !_rc {
				replace disability_type`k' = `c' ///
					if disability_rem_`c' == 1 & missing(disability_type`k')
			}
		}

		* remove used code so it doesn't repeat
		foreach c of local codes {
			capture confirm variable disability_rem_`c'
			if !_rc {
				replace disability_rem_`c' = 0 if disability_type`k' == `c'
			}
		}

		label variable disability_type`k' "Disability type (`k')"
		label values  disability_type`k' DISABILITY_TYPE
	}

	drop disability_rem_*
	order disability_ntypes disability_type*, before(cause_disability)	
		
		
		
	
	/// DROPPING BINARY 
	
	drop disability_type_1 - disability_type_68
	
	

	save "$dta/${dta_file}_${date}_M01_roster.dta", replace
	
	
	
	
	
	
	
    glo mod M01	
	
    confirmdir "${fix}/${mod}/"
        if _rc ~= 0 mkdir "${fix}/${mod}"
    glo sec "${wd}/fix/${date}/${mod}"
	
	export excel using  "${fix}/${mod}/${dta_file}_${date}_M01_roster.xlsx" ///
		, replace firstrow(var) nol 	
	
	


	
	/// LOGIC CHECKS
	
// Prefix labels with var name (nicer Excel headers)
    foreach var of varlist _all {
        local varlab: variable label `var'
        la var `var' "`var': `varlab'"
    }

    // Always export these identifiers (edit if needed)
    glo IDENT "hhid_str fmid date relationship gender age lang hhsize hh_member_status"

    // ======= CONFIG =======
    local HHMEM_MIN = 0
    local HHMEM_MAX = 10
    local AGE_MIN   = 0
    local AGE_MAX   = 120

    // Duration present?
    local DUR_EXIST ""
    capture confirm variable d_duration
    if !_rc local DUR_EXIST "d_duration"

    // Date guard (only if date is numeric daily)
    local TODAY = date(c(current_date),"DMY")
    local capcond ""
    capture confirm numeric variable date
    if !_rc local capcond "& date <= `TODAY'"

    // File counter
    local o = 0

    // =============== BASE ID CHECKS (long data key) ===============
    // Unique household-member key (NO HHID dup check)
    capture noisily isid hhid fmid
    if _rc {
        duplicates tag hhid fmid, gen(__dup_hhf)
        glo filter    "if __dup_hhf>0"
        glo namext    "dup_hhid_fmid"
        glo exportvars "hhid fmid"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", replace firstrow(varl) nol
        }
    }

    // =============== 1) DURATION POSITIVITY (if present) ===============
    if "`DUR_EXIST'" != "" {
        glo filter    "if d_duration <= 0 & !missing(d_duration)"
        glo namext    "duration_nonpositive"
        glo exportvars "d_duration"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter `capcond'
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter `capcond' using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", replace firstrow(varl) nol
        }

        glo filter    "if missing(d_duration)"
        glo namext    "duration_missing"
        glo exportvars "d_duration"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter `capcond'
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter `capcond' using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", replace firstrow(varl) nol
        }

        // optional outliers <1 or >180 minutes
        glo filter    "if (d_duration < 1 | d_duration > 180) & !missing(d_duration)"
        glo namext    "duration_outliers_1to180"
        glo exportvars "d_duration"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter `capcond'
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter `capcond' using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", replace firstrow(varl) nol
        }
    }

    // =============== 2) HHSIZE vs. ROSTER COUNT (long) ===============
    bysort hhid: gen byte __one = 1
    egen __nmem   = total(__one), by(hhid)
    egen __hh_min = min(hhsize),  by(hhid)
    egen __hh_max = max(hhsize),  by(hhid)

    // hhsize inconsistent within HH
    glo filter    "if __hh_min != __hh_max"
    glo namext    "hhsize_inconsistent_within_hh"
    glo exportvars "__hh_min __hh_max __nmem"
    local ++o
    if `o' < 10 local o="0`o'"
    count $filter
    if `r(N)' > 0 {
        export excel ${IDENT} ${exportvars} $filter using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", replace firstrow(varl) nol
    }

    // roster count != stated hhsize (use max as stated hhsize)
    glo filter    "if __nmem != __hh_max"
    glo namext    "hhsize_ne_rostercount"
    glo exportvars "__nmem __hh_max"
    local ++o
    if `o' < 10 local o="0`o'"
    count $filter
    if `r(N)' > 0 {
        export excel ${IDENT} ${exportvars} $filter using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", replace firstrow(varl) nol
    }

    // =============== 3) HH MEMBER STATUS RANGE (0..10) ===============
    capture confirm numeric variable hh_member_status
    if !_rc {
        glo filter    "if hh_member_status < `HHMEM_MIN' | hh_member_status > `HHMEM_MAX'"
        glo namext    "hh_member_status_out_of_range_0to10"
        glo exportvars "hh_member_status"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", replace firstrow(varl) nol
        }

        glo filter    "if missing(hh_member_status)"
        glo namext    "hh_member_status_missing"
        glo exportvars "hh_member_status"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", replace firstrow(varl) nol
        }
    }

    // =============== 4) WITHIN-HH CONSISTENCY (long data) ===============
    // agreement uniform within household
    capture confirm numeric variable agreement
    if !_rc {
        by hhid: egen __agr_min = min(agreement)
        by hhid: egen __agr_max = max(agreement)
        glo filter    "if __agr_min != __agr_max"
        glo namext    "agreement_inconsistent_within_hh"
        glo exportvars "agreement __agr_min __agr_max"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter `capcond'
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter `capcond' using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", replace firstrow(varl) nol
        }
    }

    // date uniform within household (if numeric)
    capture confirm numeric variable date
    if !_rc {
        by hhid: egen __dt_min = min(date)
        by hhid: egen __dt_max = max(date)
        glo filter    "if __dt_min != __dt_max"
        glo namext    "date_inconsistent_within_hh"
        glo exportvars "date __dt_min __dt_max"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter `capcond'
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter `capcond' using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", replace firstrow(varl) nol
        }
    }

    // exactly ONE head (relationship==1) per household (if available)
    capture confirm numeric variable relationship
    if !_rc {
        by hhid: egen __nhead = total(relationship==1) 
        glo filter    "if __nhead==0"
        glo namext    "no_head_in_household"
        glo exportvars "__nhead relationship"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", replace firstrow(varl) nol
        }

        glo filter    "if __nhead>1"
        glo namext    "multiple_heads_in_household"
        glo exportvars "__nhead relationship"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", replace firstrow(varl) nol
        }
    }

    // =============== 5) CORE INDIVIDUAL CHECKS ===============
    // age range / missing
    capture confirm numeric variable age
    if !_rc {
        glo filter    "if age < `AGE_MIN' | age > `AGE_MAX'"
        glo namext    "age_out_of_range_0to120"
        glo exportvars "age"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", replace firstrow(varl) nol
        }

        glo filter    "if missing(age)"
        glo namext    "age_missing"
        glo exportvars "age"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", replace firstrow(varl) nol
        }
    }

    // gender strictly 1/2 + missing
    capture confirm numeric variable gender
    if !_rc {
        glo filter    "if !inlist(gender,1,2) & !missing(gender)"
        glo namext    "gender_badcode"
        glo exportvars "gender"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", replace firstrow(varl) nol
        }

        glo filter    "if missing(gender)"
        glo namext    "gender_missing"
        glo exportvars "gender"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", replace firstrow(varl) nol
        }
    }

    // =============== 6) HEIGHT AND WEIGHT (flags + age-specific plausibility) ===============
    // weight: 1 = yes (binary), measurement in weight_kg
    capture confirm numeric variable weight
    local has_wflag = !_rc
    capture confirm numeric variable weight_kg
    local has_wkg   = !_rc

    if `has_wflag' & `has_wkg' {
        glo filter    "if weight==1 & missing(weight_kg)"
        glo namext    "weight_yes_missing_measure"
        glo exportvars "weight weight_kg age"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", replace firstrow(varl) nol
        }

        glo filter    "if weight!=1 & !missing(weight_kg)"
        glo namext    "weight_no_but_measure_filled"
        glo exportvars "weight weight_kg"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", replace firstrow(varl) nol
        }

        // broad plausibility when age missing
        glo filter    "if weight==1 & missing(age) & (weight_kg<1 | weight_kg>350)"
        glo namext    "weight_plausibility_age_missing"
        glo exportvars "weight_kg age"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", replace firstrow(varl) nol
        }

        // age-banded plausibility
        glo filter    "if weight==1 & !missing(age) & ((age<1   & (weight_kg<1  | weight_kg>20))  | (inrange(age,1,4)  & (weight_kg<6  | weight_kg>25)) | (inrange(age,5,14) & (weight_kg<10 | weight_kg>80)) | (age>=15 & (weight_kg<25 | weight_kg>350)) )"
        glo namext    "weight_plausibility_by_age"
        glo exportvars "weight_kg age"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", replace firstrow(varl) nol
        }
    }

    // height: 1 = yes (), measurement in height_cm
    capture confirm numeric variable height
    local has_hflag = !_rc
    capture confirm numeric variable height_cm
    local has_hcm   = !_rc

    if `has_hflag' & `has_hcm' {
        glo filter    "if height==1 & missing(height_cm)"
        glo namext    "height_yes_missing_measure"
        glo exportvars "height height_cm age"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", replace firstrow(varl) nol
        }

        glo filter    "if height!=1 & !missing(height_cm)"
        glo namext    "height_no_but_measure_filled"
        glo exportvars "height height_cm"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", replace firstrow(varl) nol
        }

        // broad plausibility when age missing
        glo filter    "if height==1 & missing(age) & (height_cm<40 | height_cm>250)"
        glo namext    "height_plausibility_age_missing"
        glo exportvars "height_cm age"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", replace firstrow(varl) nol
        }

        // age-banded plausibility
        glo filter    "if height==1 & !missing(age) & ( (age<1   & (height_cm<40  | height_cm>100)) | (inrange(age,1,4)  & (height_cm<60  | height_cm>120)) | (inrange(age,5,14) & (height_cm<90  | height_cm>180)) | (age>=15 & (height_cm<120 | height_cm>250)) )"
        glo namext    "height_plausibility_by_age"
        glo exportvars "height_cm age"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", replace firstrow(varl) nol
        }
    }

    // =============== 7) POR @5 basic ===============
    capture confirm numeric variable por_5yo
    if !_rc {
        glo filter    "if age>=5 & missing(por_5yo)"
        glo namext    "por5yo_missing_age5plus"
        glo exportvars "age por_5yo por_5yo_province por_5yo_city"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", replace firstrow(varl) nol
        }
        tempvar __p5nm
        egen `__p5nm' = rownonmiss(por_5yo_province por_5yo_city), strok
        glo filter    "if age<5 & `__p5nm'>0"
        glo namext    "por5yo_fields_filled_under5"
        glo exportvars "age por_5yo_province por_5yo_city"
        local ++o
        if `o' < 10 local o="0`o'"
        count $filter
        if `r(N)' > 0 {
            export excel ${IDENT} ${exportvars} $filter using "${sec}/${LNG}_${mod}_`o'_${namext}.xlsx", replace firstrow(varl) nol
        }
    }
}



********************************************************************************
**# (ED) EDUCATION  — LOGIC CHECKS (renamed to match cleaned vars)
********************************************************************************
{

    use "$raw/${dta_file}_${date}_M02_edu.dta", clear
    
    merge 1:1 hhid fmid using "$raw/${dta_file}_${date}_M01_roster.dta" , ///
            assert(3) keep(3) keepusing(age gender) nogen
        
    order age gender, a(fmid)

    la lang ${LNG} 
    
    // optional hotfix hook
    do "${wd}/fix/do/M02.do"
	
	
	
	
	/// MULTIPLE TO SINGLE ON 20251218 BY MANDAKH 
	
	/// ED4
	
	******************************************************
	* A) Value label for ED4 reasons
	******************************************************
	
	la def ED4_REASON ///
		1 "Difficulty of getting to school" ///
		2 "Illness/disability" ///
		3 "Pregnancy" ///
		4 "Marriage" ///
		5 "High cost of education/ Financial concern" ///
		6 "Employment" ///
		7 "Finished schooling or finished post secondary/college" ///
		8 "Looking for work" ///
		9 "Lack of personal interest" ///
		10 "Too young to go to school" ///
		11 "Bullying" ///
		12 "Family matters" ///
		13 "School is pointless" ///
		14 "Wasn't learning" ///
		96 "Others" ///
		22 "Took a break" ///
		23 "Late enrollment" ///
		24 "Incomplete requirements" ///
		26 "Shift in interest" ///
		27 "Did not pass" ///
		28 "Temporary pause" ///
		29 "Child is afraid to study" ///
		30 "Relocation" ///
		31 "No slots available" ///
		32 "Peer influence" ///
		35 "Afraid to socialize" ///
		36 "Teacher advised to stop" ///
		, replace 
	

	******************************************************
	* B) Build ed4_reason1 ed4_reason2 ... (ranked reasons)
	******************************************************

	* list of ED4 codes in the order you want to fill reasons
	local codes 1 2 3 4 5 6 7 8 9 10 11 12 13 14 96 22 23 24 26 27 28 29 30 31 32 35 36

	* count selections per person (max determines how many reason vars to create)
	egen ed4_nreasons = rowtotal( ///
		ed4_1 ed4_2 ed4_3 ed4_4 ed4_5 ed4_6 ed4_7 ed4_8 ed4_9 ed4_10 ed4_11 ed4_12 ed4_13 ed4_14 ///
		ed4_96 ed4_22 ed4_23 ed4_24 ed4_26 ed4_27 ed4_28 ed4_29 ed4_30 ed4_31 ed4_32 ed4_35 ed4_36 ///
	)
	quietly summarize ed4_nreasons, meanonly
	local max = r(max)

	* make "remaining" copies so we can peel off one selected reason at a time
	foreach c of local codes {
		capture confirm variable ed4_`c'
		if !_rc {
			gen byte ed4_rem_`c' = ed4_`c'
		}
	}

	* create ed4_reason1 ... ed4_reason`max'
	forvalues k = 1/`max' {
		gen ed4_reason`k' = .

		foreach c of local codes {
			capture confirm variable ed4_rem_`c'
			if !_rc {
				replace ed4_reason`k' = `c' if ed4_rem_`c' == 1 & missing(ed4_reason`k')
			}
		}

		* remove the used reason so it doesn't repeat in the next column
		foreach c of local codes {
			capture confirm variable ed4_rem_`c'
			if !_rc {
				replace ed4_rem_`c' = 0 if ed4_reason`k' == `c'
			}
		}

		label variable ed4_reason`k' "Reason not attending school (reason `k')"
		label values  ed4_reason`k' ED4_REASON
	}

	drop ed4_rem_*
		
	
	order ed4_nreasons ed4_reason*, after(ed3)
	
	

	/// ED8 
	
	
	******************************************************
	* A) Value label for ED8 tutors
	******************************************************
	
	la def ED8_TUTOR ///
		1 "Own teacher" ///
		2 "Other teacher at school" ///
		3 "Other teacher elsewhere" ///
		4 "Not a teacher" ///
		, replace 
	

	******************************************************
	* B) Build ed8_tutor1 ed4_tutor2 ... 
	******************************************************

	* list of ED8 codes in the order you want to fill reasons
	local codes 1 2 3 4 

	* count selections per person (max determines how many reason vars to create)
	egen ed8_ntutors = rowtotal( ///
		ed8_1 ed8_2 ed8_3 ed8_4 ///
	)
	quietly summarize ed8_ntutors, meanonly
	local max = r(max)

	* make "remaining" copies so we can peel off one selected reason at a time
	foreach c of local codes {
		capture confirm variable ed8_`c'
		if !_rc {
			gen byte ed8_rem_`c' = ed8_`c'
		}
	}

	* create ed8_tutor1 ... ed8_tutor`max'
	forvalues k = 1/`max' {
		gen ed8_tutor`k' = .

		foreach c of local codes {
			capture confirm variable ed8_rem_`c'
			if !_rc {
				replace ed8_tutor`k' = `c' if ed8_rem_`c' == 1 & missing(ed8_tutor`k')
			}
		}

		* remove the used reason so it doesn't repeat in the next column
		foreach c of local codes {
			capture confirm variable ed8_rem_`c'
			if !_rc {
				replace ed8_rem_`c' = 0 if ed8_tutor`k' == `c'
			}
		}

		label variable ed8_tutor`k' "Tutoring (provider `k')"
		label values  ed8_tutor`k' ED8_TUTOR
	}

	drop ed8_rem_*
		
	
	order ed8_ntutors ed8_tutor*, after(ed7)	
	
	
	/// ED9 
	
	
	******************************************************
	* A) Value label for ED9 mode of transport
	******************************************************

	la def ED9_TRANS ///
		1  "By foot" ///
		2  "Used own vehicle (specify)" ///
		15 "Van" ///
		3  "Bicycle" ///
		4  "Motorcycle/Tricycle" ///
		5  "Jeepney/Bus" ///
		6  "Car/Taxi" ///
		7  "Boat" ///
		8  "Airplane" ///
		9  "Horse or water buffalo " ///
		96 "Others (specify)" ///
		43 "Train" ///
		44 "Truck" ///
		45 "Company service" ///
		49 "Sports Utility Vehicle/ SUV" ///
		50 "Pick Up Truck" ///
		51 "Government service" ///
		52 "Tractor" ///
		97 "Work from Home" ///
		98 "Refused to answer" ///
		99 "Don't know" ///
		, replace


	******************************************************
	* B) Build ed9_trans1 ed9_trans2 ...
	******************************************************

	* list of ED9 codes in the order you want to fill
	local codes 1 2 15 3 4 5 6 7 8 9 96 43 44 45 49 50 51 52 97 98 99

	* count selections per person
	egen ed9_ntrans = rowtotal( ///
		ed9_1  ed9_2  ed9_15 ed9_3  ed9_4  ///
		ed9_5  ed9_6  ed9_7  ed9_8  ed9_9  ///
		ed9_96 ed9_43 ed9_44 ed9_45 ed9_49 ///
		ed9_50 ed9_51 ed9_52 ed9_97 ed9_98 ///
		ed9_99 ///
	)
	quietly summarize ed9_ntrans, meanonly
	local max = r(max)

	* make "remaining" copies
	foreach c of local codes {
		capture confirm variable ed9_`c'
		if !_rc {
			gen byte ed9_rem_`c' = ed9_`c'
		}
	}

	* create ed9_trans1 ... ed9_trans`max'
	forvalues k = 1/`max' {
		gen ed9_trans`k' = .

		foreach c of local codes {
			capture confirm variable ed9_rem_`c'
			if !_rc {
				replace ed9_trans`k' = `c' if ed9_rem_`c' == 1 & missing(ed9_trans`k')
			}
		}

		* remove used code
		foreach c of local codes {
			capture confirm variable ed9_rem_`c'
			if !_rc {
				replace ed9_rem_`c' = 0 if ed9_trans`k' == `c'
			}
		}

		label variable ed9_trans`k' "Mode of transport (option `k')"
		label values  ed9_trans`k' ED9_TRANS
	}

	drop ed9_rem_*
	order ed9_ntrans ed9_trans*, after(ed8_txt)
	
	
	
	
	/// ED10 
	
	
	******************************************************
	* Build ed10_time1 ed10_time2 ...
	* (Travel time in minutes, corresponding to ED9)
	******************************************************

	* only the ED10 codes that exist
	local codes 1 2 3 4 5 6 7 8 9 96

	* count how many times are reported per person
	egen ed10_ntime = rowtotal( ///
		ed9_1 ed9_2 ed9_3 ed9_4 ed9_5 ///
		ed9_6 ed9_7 ed9_8 ed9_9 ed9_96 ///
	)
	quietly summarize ed10_ntime, meanonly
	local max = r(max)

	* make "remaining" copies
	foreach c of local codes {
		capture drop ed10_rem_`c'
		gen ed10_rem_`c' = ed10_`c'
	}

	forvalues k = 1/`max' {
		gen ed10_time`k' = .
		gen byte ed10_pickcode`k' = .

		foreach c of local codes {
			replace ed10_time`k'     = ed10_rem_`c' if !missing(ed10_rem_`c') & missing(ed10_time`k')
			replace ed10_pickcode`k' = `c'          if !missing(ed10_rem_`c') & missing(ed10_pickcode`k')
		}

		* clear ONLY the slot that was used (by code)
		foreach c of local codes {
			replace ed10_rem_`c' = . if ed10_pickcode`k' == `c'
		}

		label variable ed10_time`k' "Travel time (minutes, option `k')"
	}

	drop ed10_rem_* ed10_pickcode*
	order ed10_ntime ed10_time*, after(ed9_txt)
	
	
	/// DROPPING BINARY VARIABLES FROM MULTIPLE CHOICE
	
	drop ed4_1-ed4_96
	drop ed8_1-ed8_4 
	drop ed9_1-ed9_99 
	drop ed10_1-ed10_96
	

    save "$dta/${dta_file}_${date}_M02_edu.dta", replace
    
    glo mod M02    
    
    confirmdir "${fix}/${mod}/"
    if _rc ~= 0 mkdir "${fix}/${mod}"
    glo sec "${wd}/fix/${date}/${mod}"
    
    export excel using  "${fix}/${mod}/${dta_file}_${date}_M02_edu.xlsx", ///
        replace firstrow(var) nol  

    /// LOGIC CHECKS
    {

/*
MAPPING from original -> cleaned:
---------------------------------
Enrollment        : edu_enrolled      -> ed1
School type       : edu_public        -> ed2
Current grade     : edu_grade         -> ed3
Not-enroll reasons: not_enroll_reason_* -> ed4_* (dummies created from ed4_txt)
Education costs   : edu_cost_*        -> ed5a ... ed5i
Tutoring?         : tutoring_incidence-> ed6
Tutoring amount   : tutoring_amount   -> ed7
Travel times      : travel_time_*     -> ed10_1 ... ed10_9, ed10_96
Lang of instruction: lang_instruction -> ed11
Highest attainment : edu_highest      -> ed12
Notes:
- ed8_* (tutor provider) and ed9_* (transport modes) aren't validated here (lean version).
*/

    // Prefix labels with var name for clearer Excel headers
    foreach var of varlist _all {
        local vlab: variable label `var'
        la var `var' "`var': `vlab'"
    }

    // IDs included in each export
    glo IDENT "hhid_str fmid date age gender ed1 ed2 ed3 ed12"

    // Counter
    local o = 0
	
	// DROP _txt
	
	drop *_txt

    // ---------------- Keys (long data) ----------------
    capture noisily isid hhid fmid
    if _rc {
        duplicates tag hhid fmid, gen(__dup_hhf)
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if __dup_hhf
        if `r(N)'>0 export excel ${IDENT} hhid fmid if __dup_hhf using ///
            "${sec}/${LNG}_${mod}_`suf'_dup_hhid_fmid.xlsx", replace firstrow(varl) nol
        drop __dup_hhf
    }

    // ---------------- 1) Enrollment coding (ed1) ----------------
    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if !inlist(ed1,1,2) & !missing(ed1)
    if `r(N)'>0 export excel ${IDENT} ed1 if !inlist(ed1,1,2) & !missing(ed1) using ///
        "${sec}/${LNG}_${mod}_`suf'_enrolled_badcode.xlsx", replace firstrow(varl) nol

    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if missing(ed1)
    if `r(N)'>0 export excel ${IDENT} ed1 if missing(ed1) using ///
        "${sec}/${LNG}_${mod}_`suf'_enrolled_missing.xlsx", replace firstrow(varl) nol

    // ---------------- 2) ed2/ed3 gating ----------------
    // If enrolled (ed1==1): ed2 ∈ {1,2,3}; ed3 present
    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if ed1==1 & !inlist(ed2,1,2,3)
    if `r(N)'>0 export excel ${IDENT} ed1 ed2 if ed1==1 & !inlist(ed2,1,2,3) using ///
        "${sec}/${LNG}_${mod}_`suf'_public_missing_or_bad.xlsx", replace firstrow(varl) nol

    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if ed1==2 & !missing(ed2)
    if `r(N)'>0 export excel ${IDENT} ed1 ed2 if ed1==2 & !missing(ed2) using ///
        "${sec}/${LNG}_${mod}_`suf'_public_filled_when_not_enrolled.xlsx", replace firstrow(varl) nol

    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if ed1==1 & missing(ed3)
    if `r(N)'>0 export excel ${IDENT} ed1 ed3 if ed1==1 & missing(ed3) using ///
        "${sec}/${LNG}_${mod}_`suf'_grade_missing_when_enrolled.xlsx", replace firstrow(varl) nol

    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if ed1==2 & !missing(ed3)
    if `r(N)'>0 export excel ${IDENT} ed1 ed3 if ed1==2 & !missing(ed3) using ///
        "${sec}/${LNG}_${mod}_`suf'_grade_filled_when_not_enrolled.xlsx", replace firstrow(varl) nol

    // ---------------- 3) Reasons for not attending (ed4_*; age 3–24 & not enrolled) ----------------
    tempvar reastot
    capture unab R : ed4_*
    if !_rc {
        egen `reastot' = rowtotal(`R'), missing
    }
    else {
        gen byte `reastot' = 0
    }

    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if ed1==2 & inrange(age,3,24) & `reastot'==0
    if `r(N)'>0 export excel ${IDENT} age ed1 `reastot' if ed1==2 & inrange(age,3,24) & `reastot'==0 using ///
        "${sec}/${LNG}_${mod}_`suf'_no_reason_age3to24.xlsx", replace firstrow(varl) nol

    // ---------------- 4) Education costs ed5a–ed5i (>=0 or -99) & only when enrolled ----------------
    local COSTS
    foreach v in ed5a ed5b ed5c ed5d ed5e ed5f ed5g ed5h ed5i {
        capture confirm numeric variable `v'
        if !_rc local COSTS "`COSTS' `v'"
    }
    if "`COSTS'" != "" {
        tempvar negcost nonmiss
        gen byte `negcost' = 0
        foreach v of local COSTS {
            replace `negcost' = 1 if (`v' < 0 & `v' != -99) & !missing(`v')
        }
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if ed1==1 & `negcost'==1
        if `r(N)'>0 export excel ${IDENT} `COSTS' ed1 if ed1==1 & `negcost'==1 using ///
            "${sec}/${LNG}_${mod}_`suf'_costs_negative.xlsx", replace firstrow(varl) nol

        egen `nonmiss' = rownonmiss(`COSTS')
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if ed1==2 & `nonmiss'>0
        if `r(N)'>0 export excel ${IDENT} `COSTS' ed1 if ed1==2 & `nonmiss'>0 using ///
            "${sec}/${LNG}_${mod}_`suf'_costs_when_not_enrolled.xlsx", replace firstrow(varl) nol
    }

    // ---------------- 5) Tutoring (ed6–ed7) ----------------
    capture confirm numeric variable ed6
    if !_rc {
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if ed1==2 & !missing(ed6)
        if `r(N)'>0 export excel ${IDENT} ed6 ed1 if ed1==2 & !missing(ed6) using ///
            "${sec}/${LNG}_${mod}_`suf'_tutoring_when_not_enrolled.xlsx", replace firstrow(varl) nol

        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if ed1==1 & !inlist(ed6,1,2) & !missing(ed6)
        if `r(N)'>0 export excel ${IDENT} ed6 if ed1==1 & !inlist(ed6,1,2) & !missing(ed6) using ///
            "${sec}/${LNG}_${mod}_`suf'_tutoring_badcode.xlsx", replace firstrow(varl) nol

        capture confirm numeric variable ed7
        if !_rc {
            local o = `o' + 1
            local suf = string(`o', "%02.0f")
            count if ed6==1 & (missing(ed7) | (ed7<0 & ed7!=-99))
            if `r(N)'>0 export excel ${IDENT} ed6 ed7 if ed6==1 & (missing(ed7) | (ed7<0 & ed7!=-99)) using ///
                "${sec}/${LNG}_${mod}_`suf'_tutoring_amount_issue.xlsx", replace firstrow(varl) nol
        }
    }

    // ---------------- 6) Travel times (ed10_*) non-negative or -99; none if not enrolled ----------------
    local TTIMEVARS
    foreach v in ed10_1 ed10_2 ed10_3 ed10_4 ed10_5 ed10_6 ed10_7 ed10_8 ed10_9 ed10_96 {
        capture confirm numeric variable `v'
        if !_rc local TTIMEVARS "`TTIMEVARS' `v'"
    }
    if "`TTIMEVARS'" != "" {
        tempvar badtime tfilled
        gen byte `badtime' = 0
        foreach v of local TTIMEVARS {
            replace `badtime' = 1 if (`v' < 0 & `v' != -99) & !missing(`v')
        }
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if `badtime'==1
        if `r(N)'>0 export excel ${IDENT} `TTIMEVARS' if `badtime'==1 using ///
            "${sec}/${LNG}_${mod}_`suf'_travel_time_negative.xlsx", replace firstrow(varl) nol

        egen `tfilled' = rownonmiss(`TTIMEVARS')
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if ed1==2 & `tfilled'>0
        if `r(N)'>0 export excel ${IDENT} `TTIMEVARS' ed1 if ed1==2 & `tfilled'>0 using ///
            "${sec}/${LNG}_${mod}_`suf'_travel_time_when_not_enrolled.xlsx", replace firstrow(varl) nol
    }

    // ---------------- 7) Language of instruction (ed11) ----------------
    capture confirm variable ed11
    if !_rc {
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if ed1==1 & missing(ed11)
        if `r(N)'>0 export excel ${IDENT} ed11 ed1 if ed1==1 & missing(ed11) using ///
            "${sec}/${LNG}_${mod}_`suf'_lang_instruction_missing.xlsx", replace firstrow(varl) nol

        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if ed1==2 & !missing(ed11)
        if `r(N)'>0 export excel ${IDENT} ed11 ed1 if ed1==2 & !missing(ed11) using ///
            "${sec}/${LNG}_${mod}_`suf'_lang_instruction_when_not_enrolled.xlsx", replace firstrow(varl) nol
    }

    // ---------------- 8) Highest attainment (ed12) ----------------
    local ADULT_LEARN 28, 29, 30, 31
    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if ed1==2 & missing(ed12)
    if `r(N)'>0 export excel ${IDENT} ed1 ed12 if ed1==2 & missing(ed12) using ///
        "${sec}/${LNG}_${mod}_`suf'_highest_missing_when_not_enrolled.xlsx", replace firstrow(varl) nol

    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if ed1==1 & !inlist(ed3,`ADULT_LEARN') & !missing(ed12)
    if `r(N)'>0 export excel ${IDENT} ed1 ed3 ed12 if ed1==1 & !inlist(ed3,`ADULT_LEARN') & !missing(ed12) using ///
        "${sec}/${LNG}_${mod}_`suf'_highest_filled_when_enrolled.xlsx", replace firstrow(varl) nol

    // ---------------- 9) Coarse age vs current grade (lower bounds, using ed3) ----------------
    tempvar bad_ag
    gen byte `bad_ag' = 0
    replace `bad_ag' = 1 if ed1==1 & !missing(age,ed3) & ( ///
        (inrange(ed3,9,14)  & age<10) |   /// JHS/SHS
        (inrange(ed3,36,41) & age<14) |   /// College years
        (inrange(ed3,42,45) & age<18) )   /// Post-bacc

    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if `bad_ag'==1
    if `r(N)'>0 export excel ${IDENT} age ed3 ed1 if `bad_ag'==1 using ///
        "${sec}/${LNG}_${mod}_`suf'_age_vs_grade_lowbound.xlsx", replace firstrow(varl) nol

    }

}
	
	
	
		
********************************************************************************
**# (A) EMPLOYMENT  — LOGIC CHECKS (renamed to match new labels a1–a23)
********************************************************************************
{

    use "$raw/${dta_file}_${date}_M03_emp.dta", clear
    
    merge 1:1 hhid fmid using "$raw/${dta_file}_${date}_M01_roster.dta", /// 
        assert(3) keep(3) keepusing(age gender) nogen
        
    order age gender, a(fmid)

    la lang ${LNG} 
    
    // optional hotfix hook
    do "${wd}/fix/do/M03.do"
	
	
	
	
	
	
	// MULTIPLE TO SINGLE 
	
	
	******************************************************
	* a19: Employment benefits (select_multiple binaries)
	* Create ranked single-choice variables a19_ben1, a19_ben2, ...
	******************************************************

	* --- 1) Value label (code = suffix of a19_# binary) ---
	capture label drop a19_benefit_eng
	label define a19_benefit_eng ///
		1  "Workplace pension plan" ///
		2  "Paid leave (vacation/annual, sick, maternity/paternity)" ///
		3  "SSS/GSIS" ///
		4  "PhilHealth" ///
		5  "Private health insurance/HMO" ///
		7  "None of the above" ///
		11 "Life Plan" ///
		12 "Pag-ibig" ///
		13 "Incentives" ///
		15 "Tips" ///
		17 "Crop insurance" ///
		18 "Senior Citizen benefit" ///
		19 "Local government project" ///
		96 "Other (STG codes; recode)" ///
		, replace

	* (optional) label the parent question variable if you have it
	* label variable a19 "Employment benefits (multiple response)"

	* --- 2) Count selections and find max (how many ranked vars to create) ---
	egen a19_nbenefits = rowtotal(a19_1 a19_2 a19_3 a19_4 a19_5 a19_7 a19_11 a19_12 a19_13 a19_15 a19_17 a19_18 a19_19 a19_96)
	quietly summarize a19_nbenefits, meanonly
	local max = r(max)

	* --- 3) Peel off selected benefits into ranked single-choice variables ---
	local codes 1 2 3 4 5 11 12 13 15 17 18 19 96 7   // put 7 last if you want "None of the above" to come last

	foreach c of local codes {
		gen byte a19_rem_`c' = a19_`c'
	}

	forvalues k = 1/`max' {
		gen a19_ben`k' = .

		foreach c of local codes {
			replace a19_ben`k' = `c' if a19_rem_`c' == 1 & missing(a19_ben`k')
		}

		foreach c of local codes {
			replace a19_rem_`c' = 0 if a19_ben`k' == `c'
		}

		label variable a19_ben`k' "Employment benefit (rank `k')"
		label values  a19_ben`k' a19_benefit_eng
	}

	drop a19_rem_*
		
	
	drop a19_1 - a19_96
	order a19_ben* a19_nbenefits, after(a19_txt)
		
	
	
	
	
	/// A21 
	
		
	******************************************************
	* a21: Mode of transport (select_multiple binaries)
	* Create ranked single-choice variables a21_mode1, a21_mode2, ...
	******************************************************

	* --- 1) Value label (code = suffix of a21_# binary) ---
	capture label drop a21_mode_eng
	label define a21_mode_eng ///
		1  "By foot" ///
		2  "Used own vehicle (specify)" ///
		3  "Bicycle" ///
		4  "Motorcycle/Tricycle" ///
		5  "Jeepney/Bus" ///
		6  "Car/Taxi" ///
		7  "Boat" ///
		8  "Airplane" ///
		9  "Horse or water buffalo" ///
		15 "Van" ///
		43 "Train" ///
		44 "Truck" ///
		45 "Company service" ///
		49 "Sports Utility Vehicle (SUV)" ///
		50 "Pick Up Truck" ///
		51 "Government service" ///
		52 "Tractor" ///
		96 "Others (specify)" ///
		97 "Work from home" ///
		98 "Refused to answer" ///
		99 "Don't know" ///
		, replace

	* --- 2) Count selections and find max (how many ranked vars to create) ---
	egen a21_nmodes = rowtotal(a21_1 a21_2 a21_3 a21_4 a21_5 a21_6 a21_7 a21_8 a21_9 a21_15 a21_43 a21_44 a21_45 a21_49 a21_50 a21_51 a21_52 a21_96 a21_97 a21_98 a21_99)
	quietly summarize a21_nmodes, meanonly
	local max = r(max)

	* --- 3) Peel off selected modes into ranked single-choice variables ---
	local codes 1 2 3 4 5 6 7 8 9 15 43 44 45 49 50 51 52 96 97 98 99

	foreach c of local codes {
		gen byte a21_rem_`c' = a21_`c'
	}

	forvalues k = 1/`max' {
		gen a21_mode`k' = .

		foreach c of local codes {
			replace a21_mode`k' = `c' if a21_rem_`c' == 1 & missing(a21_mode`k')
		}

		foreach c of local codes {
			replace a21_rem_`c' = 0 if a21_mode`k' == `c'
		}

		label variable a21_mode`k' "Mode of transport (rank `k')"
		label values  a21_mode`k' a21_mode_eng
	}

	drop a21_rem_*
		
	drop a21_1-a21_99 
	
	order a21_mode* a21_nmodes, after(a21_txt) 
	
	///
	
	

    save "$dta/${dta_file}_${date}_M03_emp.dta", replace
    
    glo mod M03    
    
    confirmdir "${fix}/${mod}/"
    if _rc ~= 0 mkdir "${fix}/${mod}"
    glo sec "${wd}/fix/${date}/${mod}"
    
    export excel using  "${fix}/${mod}/${dta_file}_${date}_M03_emp.xlsx", ///
        replace firstrow(var) nol  

    /// LOGIC CHECKS
    {

/*
MAPPING from original -> new labels:
------------------------------------
emp_work           -> a1
emp_biz            -> a2
emp_notwork_reason -> a3
emp_occupation     -> a4
emp_sector         -> a5
emp_class          -> a6
emp_subsistence    -> a7
emp_gig            -> a8
emp_platform       -> a9
emp_days           -> a10
emp_hours          -> a11
emp_lostjob        -> a12
emp_lostjob_who    -> a13
emp_jobsearch      -> a14
emp_jobsearch_more -> a15
emp_contract       -> a16
emp_contract_dur   -> a17
emp_contrib        -> a18
emp_benefit_*      -> a19_* (1 2 3 4 5 96 7; 7 = None of the above)
emp_ownership      -> a20
emp_transport_*    -> a21_* (1..9 96 98 99)
emp_travel_time    -> a22
emp_trans_cost     -> a23
*/

    // Prefix labels with var name for clearer Excel headers
    foreach var of varlist _all {
        local vlab: variable label `var'
        la var `var' "`var': `vlab'"
    }

    
	// DROP _txt
	
	drop *_txt
	
	
	// IDs included in each export (tweak as needed)
    glo IDENT "hhid_str fmid date age gender a1 a2 a6 a5"
	
    // Counter
    local o = 0

    // ---------------- Keys (long data) ----------------
    capture noisily isid hhid fmid
    if _rc {
        duplicates tag hhid fmid, gen(__dup_hhf)
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if __dup_hhf
        if `r(N)'>0 export excel ${IDENT} hhid fmid if __dup_hhf using ///
            "${sec}/${LNG}_${mod}_`suf'_dup_hhid_fmid.xlsx", replace firstrow(varl) nol
        drop __dup_hhf
    }

    // ---------------- Helper: working indicator (A1==1 or A2==1) ----------------
    tempvar working
    gen byte `working' = (a1==1 | a2==1)

    // ---------------- A1 (worked >=1 hour) coding ----------------
    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if !inlist(a1,1,2) & !missing(a1)
    if `r(N)'>0 export excel ${IDENT} a1 if !inlist(a1,1,2) & !missing(a1) using ///
        "${sec}/${LNG}_${mod}_`suf'_A1_badcode.xlsx", replace firstrow(varl) nol

    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if missing(a1)
    if `r(N)'>0 export excel ${IDENT} a1 if missing(a1) using ///
        "${sec}/${LNG}_${mod}_`suf'_A1_missing.xlsx", replace firstrow(varl) nol

    // ---------------- A2 (had job/business) gating ----------------
    // If worked (A1=1) → A2 should be blank; If A1=2 → A2 must be 1/2 (not missing)
    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if a1==1 & !missing(a2)
    if `r(N)'>0 export excel ${IDENT} a1 a2 if a1==1 & !missing(a2) using ///
        "${sec}/${LNG}_${mod}_`suf'_A2_filled_when_A1_yes.xlsx", replace firstrow(varl) nol

    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if a1==2 & (missing(a2) | !inlist(a2,1,2))
    if `r(N)'>0 export excel ${IDENT} a1 a2 if a1==2 & (missing(a2) | !inlist(a2,1,2)) using ///
        "${sec}/${LNG}_${mod}_`suf'_A2_missing_or_bad_when_A1_no.xlsx", replace firstrow(varl) nol

    // ---------------- A3 (reason not working/searching) — ask if A1==2 & A2==2 ----------------
    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if a1==2 & a2==2 & (missing(a3) | !inlist(a3,1,2,3,4,5,6,7,8,9,10,11,12, 21, 24, 33, 34, 36, 38, 39, 40, 43, 96))
    if `r(N)'>0 export excel ${IDENT} a1 a2 a3 if a1==2 & a2==2 & (missing(a3) | !inlist(a3,1,2,3,4,5,6,7,8,9,10,11,12, 21, 24, 33, 34, 36, 38, 39, 40, 43, 96)) using ///
        "${sec}/${LNG}_${mod}_`suf'_A3_missing_or_bad_when_A1A2_no.xlsx", replace firstrow(varl) nol

    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if (a1==1 | a2==1) & !missing(a3)
    if `r(N)'>0 export excel ${IDENT} a1 a2 a3 if (a1==1 | a2==1) & !missing(a3) using ///
        "${sec}/${LNG}_${mod}_`suf'_A3_filled_when_not_required.xlsx", replace firstrow(varl) nol

		
    // ---------------- A14/A15 job search ----------------
    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if missing(a14) | !inlist(a14,1,2,3)
    if `r(N)'>0 export excel ${IDENT} a14 if missing(a14) | !inlist(a14,1,2,3) using ///
        "${sec}/${LNG}_${mod}_`suf'_A14_missing_or_badcode.xlsx", replace firstrow(varl) nol

    capture confirm variable a15
    if !_rc {
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if a14==2 & missing(a15)
        if `r(N)'>0 export excel ${IDENT} a14 a15 if a14==2 & missing(a15) using ///
            "${sec}/${LNG}_${mod}_`suf'_A15_missing_when_A14_2.xlsx", replace firstrow(varl) nol

        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if a14!=2 & !missing(a15)
        if `r(N)'>0 export excel ${IDENT} a14 a15 if a14!=2 & !missing(a15) using ///
            "${sec}/${LNG}_${mod}_`suf'_A15_filled_when_not_A14_2.xlsx", replace firstrow(varl) nol
    }

    // ---------------- A4/A5/A6 asked if working (A1=1 or A2=1) ----------------
    // A4 occupation non-missing; A5 sector valid; A6 class valid; if not working → blank
    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if `working'==1 & missing(a4)
    if `r(N)'>0 export excel ${IDENT} a4 `working' if `working'==1 & missing(a4) using ///
        "${sec}/${LNG}_${mod}_`suf'_A4_missing_when_working.xlsx", replace firstrow(varl) nol

    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if `working'==1 & (missing(a5) | !inlist(a5,1,2,3,4,19,96))
    if `r(N)'>0 export excel ${IDENT} a5 `working' if `working'==1 & (missing(a5) | !inlist(a5,1,2,3,4,19,96)) using ///
        "${sec}/${LNG}_${mod}_`suf'_A5_missing_or_bad_when_working.xlsx", replace firstrow(varl) nol

    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if `working'==1 & (missing(a6) | !inlist(a6,1,2,3,4,5,6,7,9))
    if `r(N)'>0 export excel ${IDENT} a6 `working' if `working'==1 & (missing(a6) | !inlist(a6,1,2,3,4,5,6,7,9)) using ///
        "${sec}/${LNG}_${mod}_`suf'_A6_missing_or_bad_when_working.xlsx", replace firstrow(varl) nol

    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if `working'==0 & !missing(a4, a5, a6)
    if `r(N)'>0 export excel ${IDENT} a4 a5 a6 `working' if `working'==0 & !missing(a4, a5, a6) using ///
        "${sec}/${LNG}_${mod}_`suf'_A4toA6_filled_when_not_working.xlsx", replace firstrow(varl) nol

    // ---------------- A7 subsistence (ask if a5==1 & a6 in 5/6/7) ----------------
    tempvar needA7
    gen byte `needA7' = (a5==1 & inlist(a6,5,6,7))
    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if `needA7'==1 & (missing(a7) | !inlist(a7,1,2,3,4,97))
    if `r(N)'>0 export excel ${IDENT} a5 a6 a7 if `needA7'==1 & (missing(a7) | !inlist(a7,1,2,3,4,97)) using ///
        "${sec}/${LNG}_${mod}_`suf'_A7_missing_or_bad_when_required.xlsx", replace firstrow(varl) nol

    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if `needA7'==0 & !missing(a7)
    if `r(N)'>0 export excel ${IDENT} a5 a6 a7 if `needA7'==0 & !missing(a7) using ///
        "${sec}/${LNG}_${mod}_`suf'_A7_filled_when_not_required.xlsx", replace firstrow(varl) nol

    // ---------------- A8/A9 gig/platform (ask if class in 2 or 4) ----------------
    tempvar needA8
    gen byte `needA8' = inlist(a6,2,4)

    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if `needA8'==1 & (missing(a8) | !inlist(a8,1,2,99))
    if `r(N)'>0 export excel ${IDENT} a6 a8 if `needA8'==1 & (missing(a8) | !inlist(a8,1,2,99)) using ///
        "${sec}/${LNG}_${mod}_`suf'_A8_missing_or_bad_when_required.xlsx", replace firstrow(varl) nol

    // A9 required if A8==1; else should be blank
    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if a8==1 & (missing(a9) | !inlist(a9,1,2,99))
    if `r(N)'>0 export excel ${IDENT} a8 a9 if a8==1 & (missing(a9) | !inlist(a9,1,2,99)) using ///
        "${sec}/${LNG}_${mod}_`suf'_A9_missing_or_bad_when_A8_yes.xlsx", replace firstrow(varl) nol

    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if inlist(a8,2,-99) & !missing(a9)
    if `r(N)'>0 export excel ${IDENT} a8 a9 if inlist(a8,2,-99) & !missing(a9) using ///
        "${sec}/${LNG}_${mod}_`suf'_A9_filled_when_A8_not_yes.xlsx", replace firstrow(varl) nol

    // ---------------- A10/A11 days & hours (ask if working) ----------------
    // A10: 0–7 days; A11: 0–168 hours
    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if `working'==1 & (missing(a10) | a10<0 | a10>7)
    if `r(N)'>0 export excel ${IDENT} a10 `working' if `working'==1 & (missing(a10) | a10<0 | a10>7) using ///
        "${sec}/${LNG}_${mod}_`suf'_A10_days_out_of_range.xlsx", replace firstrow(varl) nol

    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if `working'==1 & (missing(a11) | a11<0 | a11>168)
    if `r(N)'>0 export excel ${IDENT} a11 `working' if `working'==1 & (missing(a11) | a11<0 | a11>168) using ///
        "${sec}/${LNG}_${mod}_`suf'_A11_hours_out_of_range.xlsx", replace firstrow(varl) nol

    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if `working'==0 & !missing(a10, a11)
    if `r(N)'>0 export excel ${IDENT} a10 a11 `working' if `working'==0 & !missing(a10, a11) using ///
        "${sec}/${LNG}_${mod}_`suf'_A10A11_filled_when_not_working.xlsx", replace firstrow(varl) nol

    // ---------------- A12/A13 job loss (HH-level consistency + person-level sanity) ----------------

    // A12 must be coded 1/2
    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if missing(a12) | !inlist(a12,1,2)
    if `r(N)'>0 export excel ${IDENT} a12 if missing(a12) | !inlist(a12,1,2) using ///
        "${sec}/${LNG}_${mod}_`suf'_A12_missing_or_badcode.xlsx", replace firstrow(varl) nol

    // Build a13 selection indicator that works for numeric or string storage
    tempvar a13sel
    gen byte `a13sel' = .
    capture confirm numeric variable a13
    if !_rc {
        replace `a13sel' = (a13==1) if !missing(a13)
    }
    else {
        replace `a13sel' = (a13!="") if a13!=""
    }

    // HH-level rule: if anyone has a12==1, there must be >=1 selected in a13 within that HH
    tempvar hh_yesA12 hh_nA13 hh_badA13
    bysort hhid: egen `hh_yesA12' = max(a12==1)
    bysort hhid: egen `hh_nA13'  = total(`a13sel')
    gen byte `hh_badA13' = (`hh_yesA12'==1 & `hh_nA13'==0)

    // Export one row per failing household (first member row)
    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    bysort hhid: gen byte __first = (_n==1)
    count if `hh_badA13'==1 & __first
    if `r(N)'>0 export excel ${IDENT} a12 a13 `a13sel' `hh_yesA12' `hh_nA13' ///
        if `hh_badA13'==1 & __first using ///
        "${sec}/${LNG}_${mod}_`suf'_A13_no_member_tagged_when_A12_yes.xlsx", ///
        replace firstrow(varl) nol
    drop __first

    // Person-level sanity: if a12==2 for this person, a13 should be blank for this person
    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if a12==2 & `a13sel'==1
    if `r(N)'>0 export excel ${IDENT} a12 a13 if a12==2 & `a13sel'==1 using ///
        "${sec}/${LNG}_${mod}_`suf'_A13_filled_when_A12_no_personlevel.xlsx", replace firstrow(varl) nol


    // ---------------- A16/A17 contract & duration (ask if working) ----------------
    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if `working'==1 & (missing(a16) | !inlist(a16,1,2,3,99))
    if `r(N)'>0 export excel ${IDENT} a16 `working' if `working'==1 & (missing(a16) | !inlist(a16,1,2,3,99)) using ///
        "${sec}/${LNG}_${mod}_`suf'_A16_missing_or_bad_when_working.xlsx", replace firstrow(varl) nol

    // A17 required if contract is 1/2; else should be blank
    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if inlist(a16,1,2) & (missing(a17) | !inlist(a17,1,2,3,4,5,99))
    if `r(N)'>0 export excel ${IDENT} a16 a17 if inlist(a16,1,2) & (missing(a17) | !inlist(a17,1,2,3,4,5,99)) using ///
        "${sec}/${LNG}_${mod}_`suf'_A17_missing_or_bad_when_A16_yes.xlsx", replace firstrow(varl) nol

    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if inlist(a16,3,-99) & !missing(a17)
    if `r(N)'>0 export excel ${IDENT} a16 a17 if inlist(a16,3,-99) & !missing(a17) using ///
        "${sec}/${LNG}_${mod}_`suf'_A17_filled_when_A16_no_or_DK.xlsx", replace firstrow(varl) nol

    // ---------------- A18 employer contributions (ask if working) ----------------
    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if `working'==1 & (missing(a18) | !inlist(a18,1,2,99))
    if `r(N)'>0 export excel ${IDENT} a18 `working' if `working'==1 & (missing(a18) | !inlist(a18,1,2,99)) using ///
        "${sec}/${LNG}_${mod}_`suf'_A18_missing_or_bad_when_working.xlsx", replace firstrow(varl) nol

    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if `working'==0 & !missing(a18)
    if `r(N)'>0 export excel ${IDENT} a18 `working' if `working'==0 & !missing(a18) using ///
        "${sec}/${LNG}_${mod}_`suf'_A18_filled_when_not_working.xlsx", replace firstrow(varl) nol

 
	// ---------------- A19 benefits (robust, export only real positives) ----------------
    // Build list of existing, numeric a19_* dummies
    local BENNUM
    capture unab __a19s : a19_*
    if !_rc {
        foreach v of local __a19s {
            capture confirm numeric variable `v'
            if !_rc local BENNUM "`BENNUM' `v'"
        }
    }

    // Proceed only if we found at least one numeric benefit dummy
    if "`BENNUM'" != "" {
        tempvar nben ben_any
        // Rowtotal treats missing as zero with 'missing' option; gives 0 if all missing
        egen `nben' = rowtotal(`BENNUM'), missing

        // Boolean "any selected": handles 0/1 or . / 1 codings
        gen byte `ben_any' = 0
        foreach v of local BENNUM {
            replace `ben_any' = 1 if `v'==1
        }

        // Flag + export: not working but has ≥1 benefit selected
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if `working'==0 & `ben_any'==1
        if `r(N)'>0 {
            export excel ${IDENT} `BENNUM' `nben' `ben_any' `working' ///
                if `working'==0 & `ben_any'==1 using ///
                "${sec}/${LNG}_${mod}_`suf'_A19_benefits_when_not_working.xlsx", ///
                replace firstrow(varl) nol
        }
    }


    // ---------------- A20 for whom worked (ask if class==4 self-employed) ----------------
    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if a6==4 & (missing(a20) | !inlist(a20,1,2,3,4,5))
    if `r(N)'>0 export excel ${IDENT} a6 a20 if a6==4 & (missing(a20) | !inlist(a20,1,2,3,4,5)) using ///
        "${sec}/${LNG}_${mod}_`suf'_A20_missing_or_bad_when_self_employed.xlsx", replace firstrow(varl) nol

    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if a6!=4 & !missing(a20)
    if `r(N)'>0 export excel ${IDENT} a6 a20 if a6!=4 & !missing(a20) using ///
        "${sec}/${LNG}_${mod}_`suf'_A20_filled_when_not_self_employed.xlsx", replace firstrow(varl) nol

    // ---------------- A21 transport (robust, avoid exporting all-zeros) ----------------
    // Build list of existing, numeric transport dummies
    local TRANSNUM
    capture unab __a21s : a21_*
    if !_rc {
        foreach v of local __a21s {
            capture confirm numeric variable `v'
            if !_rc local TRANSNUM "`TRANSNUM' `v'"
        }
    }

    // Proceed only if we found at least one numeric transport dummy
    if "`TRANSNUM'" != "" {
        tempvar ntrans trans_any
        // Rowtotal across whatever dummies actually exist
        egen `ntrans' = rowtotal(`TRANSNUM'), missing

        // Boolean "any selected" — robust to 0/1 vs . /1 codings
        gen byte `trans_any' = 0
        foreach v of local TRANSNUM {
            replace `trans_any' = 1 if `v'==1
        }

        // (1) Working but picked no transport
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if `working'==1 & `trans_any'==0
        if `r(N)'>0 {
            export excel ${IDENT} `TRANSNUM' `ntrans' `trans_any' `working' ///
                if `working'==1 & `trans_any'==0 using ///
                "${sec}/${LNG}_${mod}_`suf'_A21_no_transport_when_working.xlsx", ///
                replace firstrow(varl) nol
        }

        // (2) Not working but has transport selected
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if `working'==0 & `trans_any'==1
        if `r(N)'>0 {
            export excel ${IDENT} `TRANSNUM' `ntrans' `trans_any' `working' ///
                if `working'==0 & `trans_any'==1 using ///
                "${sec}/${LNG}_${mod}_`suf'_A21_transport_when_not_working.xlsx", ///
                replace firstrow(varl) nol
        }
    }


    // ---------------- A22 travel time (minutes) — ask if working ----------------
    // Valid: >=0 or -99 (DK)
    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if `working'==1 & (missing(a22) | (a22<0 & a22!=-99))
    if `r(N)'>0 export excel ${IDENT} a22 `working' if `working'==1 & (missing(a22) | (a22<0 & a22!=-99)) using ///
        "${sec}/${LNG}_${mod}_`suf'_A22_time_missing_or_negative.xlsx", replace firstrow(varl) nol

    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if `working'==0 & !missing(a22)
    if `r(N)'>0 export excel ${IDENT} a22 `working' if `working'==0 & !missing(a22) using ///
        "${sec}/${LNG}_${mod}_`suf'_A22_time_filled_when_not_working.xlsx", replace firstrow(varl) nol

    // ---------------- A23 transport cost — ask if working ----------------
    // Valid: >=0 or -99 (DK)
    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if `working'==1 & (missing(a23) | (a23<0 & a23!=-99))
    if `r(N)'>0 export excel ${IDENT} a23 `working' if `working'==1 & (missing(a23) | (a23<0 & a23!=-99)) using ///
        "${sec}/${LNG}_${mod}_`suf'_A23_cost_missing_or_negative.xlsx", replace firstrow(varl) nol

    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if `working'==0 & !missing(a23)
    if `r(N)'>0 export excel ${IDENT} a23 `working' if `working'==0 & !missing(a23) using ///
        "${sec}/${LNG}_${mod}_`suf'_A23_cost_filled_when_not_working.xlsx", replace firstrow(varl) nol

    }

}

	
********************************************************************************
**# (IA) INCOME  — LOGIC CHECKS (renamed to ia1–ia7)
********************************************************************************
{

    use "$raw/${dta_file}_${date}_M04_inc1.dta", clear
    
    merge 1:1 hhid fmid using "$raw/${dta_file}_${date}_M01_roster.dta", /// 
        assert(2 3) keep(3) keepusing(age gender) nogen
        
    order age gender, a(fmid)

    la lang ${LNG} 
    
    // optional hotfix hook
    do "${wd}/fix/do/M04_1.do"

    save "$dta/${dta_file}_${date}_M04_inc1.dta", replace
    
    glo mod M04_1    
    
    confirmdir "${fix}/${mod}/"
    if _rc ~= 0 mkdir "${fix}/${mod}"
    glo sec "${wd}/fix/${date}/${mod}"
    
    export excel using  "${fix}/${mod}/${dta_file}_${date}_M04_inc1.xlsx", ///
        replace firstrow(var) nol  

    /// LOGIC CHECKS
    {

/*
MAPPING from original -> new labels:
------------------------------------
inc_regular            -> ia1
inc_regular_member     -> ia2
inc_reg_cash_basic     -> ia3a
inc_reg_cash_other     -> ia3b
inc_reg_cash_total     -> ia3ab
inc_reg_inkind_basic   -> ia3c
inc_reg_inkind_housing -> ia3d
inc_reg_inkind_food    -> ia3e
inc_reg_inkind_other   -> ia3f
inc_reg_inkind_total   -> ia3cf

inc_seasonal           -> ia4
inc_seasonal_member    -> ia5
inc_seas_cash_basic    -> ia6a
inc_seas_cash_other    -> ia6b
inc_seas_cash_total    -> ia6ab
inc_seas_inkind_basic  -> ia6c
inc_seas_inkind_housing-> ia6d
inc_seas_inkind_food   -> ia6e
inc_seas_inkind_other  -> ia6f
inc_seas_inkind_total  -> ia6cf

inc_gig                -> ia7
*/

    // Prefix labels with var name (clearer Excel headers)
    foreach var of varlist _all {
        local vlab: variable label `var'
        la var `var' "`var': `vlab'"
    }

    // IDs to show on every export
    glo IDENT "hhid_str fmid age gender ia1 ia4 ia2 ia5 ia7"

    // Counter
    local o = 0

    // ---------------- Keys (long data) ----------------
    capture noisily isid hhid fmid
    if _rc {
        duplicates tag hhid fmid, gen(__dup_hhf)
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if __dup_hhf
        if `r(N)'>0 export excel ${IDENT} hhid fmid if __dup_hhf using ///
            "${sec}/${LNG}_${mod}_`suf'_dup_hhid_fmid.xlsx", replace firstrow(varl) nol
        drop __dup_hhf
    }

    // ---------------- 1) IA1 regular incidence (1/2, non-missing) ----------------
    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if missing(ia1) | !inlist(ia1,1,2)
    if `r(N)'>0 export excel ${IDENT} ia1 if missing(ia1) | !inlist(ia1,1,2) using ///
        "${sec}/${LNG}_${mod}_`suf'_IA1_missing_or_badcode.xlsx", replace firstrow(varl) nol

    // ---------------- 2) IA2 regular member gating ----------------
    // If ia1==1 → ia2 must be 1/2; If ia1==2 → ia2 should be blank
    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if ia1==1 & (missing(ia2) | !inlist(ia2,1,2))
    if `r(N)'>0 export excel ${IDENT} ia1 ia2 if ia1==1 & (missing(ia2) | !inlist(ia2,1,2)) using ///
        "${sec}/${LNG}_${mod}_`suf'_IA2_missing_or_bad_when_IA1_yes.xlsx", replace firstrow(varl) nol

    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if ia1==2 & !missing(ia2)
    if `r(N)'>0 export excel ${IDENT} ia1 ia2 if ia1==2 & !missing(ia2) using ///
        "${sec}/${LNG}_${mod}_`suf'_IA2_filled_when_IA1_no.xlsx", replace firstrow(varl) nol

    // ---------------- REGULAR amounts (IA3) — if ia2==1 ----------------
    local REGCASH "ia3a ia3b ia3ab"
    local REGINK  "ia3c ia3d ia3e ia3f ia3cf"

    // Basic validity: >=0 or -99 (DK) when ia2==1
    foreach v of local REGCASH {
        capture confirm numeric variable `v'
        if !_rc {
            local o = `o' + 1
            local suf = string(`o', "%02.0f")
            count if ia2==1 & !missing(`v') & (`v' < 0 & `v' != -99)
            if `r(N)'>0 export excel ${IDENT} ia2 `v' if ia2==1 & !missing(`v') & (`v' < 0 & `v' != -99) using ///
                "${sec}/${LNG}_${mod}_`suf'_IA3_regular_negatives.xlsx", replace firstrow(varl) nol
        }
    }
    foreach v of local REGINK {
        capture confirm numeric variable `v'
        if !_rc {
            local o = `o' + 1
            local suf = string(`o', "%02.0f")
            count if ia2==1 & !missing(`v') & (`v' < 0 & `v' != -99)
            if `r(N)'>0 export excel ${IDENT} ia2 `v' if ia2==1 & !missing(`v') & (`v' < 0 & `v' != -99) using ///
                "${sec}/${LNG}_${mod}_`suf'_IA3_regular_negatives.xlsx", replace firstrow(varl) nol
        }
    }

    // Totals consistency for regular (only if all components present & not -99)
    capture confirm numeric variable ia3a
    if !_rc capture confirm numeric variable ia3b
    if !_rc capture confirm numeric variable ia3ab
    if !_rc {
        tempvar _okR _sumR
        gen byte `_okR' = ia2==1 & !missing(ia3a,ia3b,ia3ab) & ia3a!=-99 & ia3b!=-99 & ia3ab!=-99
        gen double `_sumR' = ia3a + ia3b
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if `_okR'==1 & ia3ab != `_sumR'
        if `r(N)'>0 export excel ${IDENT} ia3a ia3b ia3ab if `_okR'==1 & ia3ab != `_sumR' using ///
            "${sec}/${LNG}_${mod}_`suf'_IA3_regular_cash_total_mismatch.xlsx", replace firstrow(varl) nol
    }
    capture confirm numeric variable ia3c
    if !_rc capture confirm numeric variable ia3d
    if !_rc capture confirm numeric variable ia3e
    if !_rc capture confirm numeric variable ia3f
    if !_rc capture confirm numeric variable ia3cf
    if !_rc {
        tempvar _okR2 _sumR2
        gen byte `_okR2' = ia2==1 & !missing(ia3c,ia3d,ia3e,ia3f,ia3cf) ///
                           & ia3c!=-99 & ia3d!=-99 & ia3e!=-99 & ia3f!=-99 & ia3cf!=-99
        gen double `_sumR2' = ia3c + ia3d + ia3e + ia3f
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if `_okR2'==1 & ia3cf != `_sumR2'
        if `r(N)'>0 export excel ${IDENT} ia3c ia3d ia3e ia3f ia3cf if `_okR2'==1 & ia3cf != `_sumR2' using ///
            "${sec}/${LNG}_${mod}_`suf'_IA3_regular_inkind_total_mismatch.xlsx", replace firstrow(varl) nol
    }

    // If ia2==2 → all IA3 items should be blank
    local ALLREG "ia3a ia3b ia3ab ia3c ia3d ia3e ia3f ia3cf"
    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    egen __reg_nonmiss = rownonmiss(`ALLREG')
    count if ia2==2 & __reg_nonmiss>0
    if `r(N)'>0 export excel ${IDENT} `ALLREG' ia2 if ia2==2 & __reg_nonmiss>0 using ///
        "${sec}/${LNG}_${mod}_`suf'_IA3_filled_when_member_no.xlsx", replace firstrow(varl) nol
    drop __reg_nonmiss

    // ---------------- 3) IA4 seasonal incidence (only asked if IA1==2) ----------------
    capture confirm numeric variable ia4
    if !_rc {
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if ia1==2 & (missing(ia4) | !inlist(ia4,1,2))
        if `r(N)'>0 export excel ${IDENT} ia1 ia4 if ia1==2 & (missing(ia4) | !inlist(ia4,1,2)) using ///
            "${sec}/${LNG}_${mod}_`suf'_IA4_missing_or_bad_when_IA1_no.xlsx", replace firstrow(varl) nol

        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if ia1==1 & !missing(ia4)
        if `r(N)'>0 export excel ${IDENT} ia1 ia4 if ia1==1 & !missing(ia4) using ///
            "${sec}/${LNG}_${mod}_`suf'_IA4_filled_when_IA1_yes.xlsx", replace firstrow(varl) nol
    }

    // ---------------- 4) IA5 seasonal member gating ----------------
    capture confirm numeric variable ia5
    if !_rc {
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if ia4==1 & (missing(ia5) | !inlist(ia5,1,2))
        if `r(N)'>0 export excel ${IDENT} ia4 ia5 if ia4==1 & (missing(ia5) | !inlist(ia5,1,2)) using ///
            "${sec}/${LNG}_${mod}_`suf'_IA5_missing_or_bad_when_IA4_yes.xlsx", replace firstrow(varl) nol

        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if (ia4!=1 | missing(ia4)) & !missing(ia5)
        if `r(N)'>0 export excel ${IDENT} ia4 ia5 if (ia4!=1 | missing(ia4)) & !missing(ia5) using ///
            "${sec}/${LNG}_${mod}_`suf'_IA5_filled_when_IA4_not_yes.xlsx", replace firstrow(varl) nol
    }

    // ---------------- SEASONAL amounts (IA6) — if ia5==1 ----------------
    local SEASCASH "ia6a ia6b ia6ab"
    local SEASINK  "ia6c ia6d ia6e ia6f ia6cf"

    foreach v of local SEASCASH {
        capture confirm numeric variable `v'
        if !_rc {
            local o = `o' + 1
            local suf = string(`o', "%02.0f")
            count if ia5==1 & !missing(`v') & (`v' < 0 & `v' != -99)
            if `r(N)'>0 export excel ${IDENT} ia5 `v' if ia5==1 & !missing(`v') & (`v' < 0 & `v' != -99) using ///
                "${sec}/${LNG}_${mod}_`suf'_IA6_seasonal_negatives.xlsx", replace firstrow(varl) nol
        }
    }
    foreach v of local SEASINK {
        capture confirm numeric variable `v'
        if !_rc {
            local o = `o' + 1
            local suf = string(`o', "%02.0f")
            count if ia5==1 & !missing(`v') & (`v' < 0 & `v' != -99)
            if `r(N)'>0 export excel ${IDENT} ia5 `v' if ia5==1 & !missing(`v') & (`v' < 0 & `v' != -99) using ///
                "${sec}/${LNG}_${mod}_`suf'_IA6_seasonal_negatives.xlsx", replace firstrow(varl) nol
        }
    }

    // Totals consistency for seasonal (only if all components present & not -99)
    capture confirm numeric variable ia6a
    if !_rc capture confirm numeric variable ia6b
    if !_rc capture confirm numeric variable ia6ab
    if !_rc {
        tempvar _okS _sumS
        gen byte `_okS' = ia5==1 & !missing(ia6a,ia6b,ia6ab) & ia6a!=-99 & ia6b!=-99 & ia6ab!=-99
        gen double `_sumS' = ia6a + ia6b
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if `_okS'==1 & ia6ab != `_sumS'
        if `r(N)'>0 export excel ${IDENT} ia6a ia6b ia6ab if `_okS'==1 & ia6ab != `_sumS' using ///
            "${sec}/${LNG}_${mod}_`suf'_IA6_seasonal_cash_total_mismatch.xlsx", replace firstrow(varl) nol
    }
    
	// --- Totals consistency for seasonal in-kind (ia6cf == ia6c+ia6d+ia6e+ia6f) ---
    capture confirm numeric variable ia6c
    if !_rc capture confirm numeric variable ia6d
    if !_rc capture confirm numeric variable ia6e
    if !_rc capture confirm numeric variable ia6f
    if !_rc capture confirm numeric variable ia6cf
    if !_rc {
        tempvar okS2 sumS2 has_all
        egen `has_all' = rownonmiss(ia6c ia6d ia6e ia6f ia6cf)
        gen byte `okS2' = (ia5==1 & `has_all'==5 ///
            & ia6c!=-99 & ia6d!=-99 & ia6e!=-99 & ia6f!=-99 & ia6cf!=-99)
        gen double `sumS2' = ia6c + ia6d + ia6e + ia6f

        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if `okS2'==1 & ia6cf != `sumS2'
        if `r(N)'>0 export excel ${IDENT} ia6c ia6d ia6e ia6f ia6cf ///
            if `okS2'==1 & ia6cf != `sumS2' using ///
            "${sec}/${LNG}_${mod}_`suf'_IA6_seasonal_inkind_total_mismatch.xlsx", ///
            replace firstrow(varl) nol

        drop `has_all'
    }


    // If ia5==2 → all IA6 items should be blank
    local ALLSEAS "ia6a ia6b ia6ab ia6c ia6d ia6e ia6f ia6cf"
    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    egen __seas_nonmiss = rownonmiss(`ALLSEAS')
    count if ia5==2 & __seas_nonmiss>0
    if `r(N)'>0 export excel ${IDENT} `ALLSEAS' ia5 if ia5==2 & __seas_nonmiss>0 using ///
        "${sec}/${LNG}_${mod}_`suf'_IA6_filled_when_member_no.xlsx", replace firstrow(varl) nol
    drop __seas_nonmiss

    // ---------------- 5) Cross-branch cleanliness ----------------
    // If ia1==1 (regular path), seasonal totals should not be filled
    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    egen __seastot_nonmiss = rownonmiss(ia6ab ia6cf)
    count if ia1==1 & __seastot_nonmiss>0
    if `r(N)'>0 export excel ${IDENT} ia6ab ia6cf if ia1==1 & __seastot_nonmiss>0 using ///
        "${sec}/${LNG}_${mod}_`suf'_seasonal_totals_filled_when_IA1_yes.xlsx", replace firstrow(varl) nol
    drop __seastot_nonmiss

    // If ia1==2 and ia4==2 (neither regular nor seasonal), no IA3/IA6 items should be filled
    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    egen __any_income = rownonmiss(`ALLREG' `ALLSEAS')
    count if ia1==2 & ia4==2 & __any_income>0
    if `r(N)'>0 export excel ${IDENT} `ALLREG' `ALLSEAS' ia1 ia4 if ia1==2 & ia4==2 & __any_income>0 using ///
        "${sec}/${LNG}_${mod}_`suf'_income_details_when_both_no.xlsx", replace firstrow(varl) nol
    drop __any_income

    // ---------------- 6) IA7 gig income ----------------
    // Rule: if a member has income (regular OR seasonal), ia7 must be >=0 or -99; 
    // and when totals known (not -99), ia7 should not exceed the relevant total.
    tempvar any_member_income total_used bad_gig
    gen byte `any_member_income' = (ia2==1 | ia5==1)

    // Total used depends on path (regular if ia1==1; else if ia4==1 seasonal)
    gen double `total_used' = .
    capture confirm numeric variable ia3ab
    capture confirm numeric variable ia3cf
    if !_rc replace `total_used' = ia3ab + ia3cf if ia1==1
    capture confirm numeric variable ia6ab
    capture confirm numeric variable ia6cf
    if !_rc replace `total_used' = ia6ab + ia6cf if ia1==2 & ia4==1

    // Basic validity: >=0 or -99 when member has income
    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if `any_member_income'==1 & !missing(ia7) & (ia7<0 & ia7!=-99)
    if `r(N)'>0 export excel ${IDENT} ia7 `any_member_income' if `any_member_income'==1 & !missing(ia7) & (ia7<0 & ia7!=-99) using ///
        "${sec}/${LNG}_${mod}_`suf'_IA7_gig_negative.xlsx", replace firstrow(varl) nol

    // If member has income and ia7, total_used are known & not -99, ia7 should not exceed total_used
    gen byte `bad_gig' = 0
    replace `bad_gig' = 1 if `any_member_income'==1 ///
        & !missing(ia7, `total_used') ///
        & ia7!=-99 & `total_used'!=-99 ///
        & ia7 > `total_used'

    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if `bad_gig'==1
    if `r(N)'>0 export excel ${IDENT} ia7 `total_used' if `bad_gig'==1 using ///
        "${sec}/${LNG}_${mod}_`suf'_IA7_gig_exceeds_total.xlsx", replace firstrow(varl) nol

    // If member has NO income → ia7 should be blank
    local o = `o' + 1
    local suf = string(`o', "%02.0f")
    count if `any_member_income'==0 & !missing(ia7)
    if `r(N)'>0 export excel ${IDENT} ia7 `any_member_income' if `any_member_income'==0 & !missing(ia7) using ///
        "${sec}/${LNG}_${mod}_`suf'_IA7_gig_filled_without_income.xlsx", replace firstrow(varl) nol

    // Clean temp flags
    drop `bad_gig'

    }

}
	
	
********************************************************************************
**# (IB/IC/ID/IE)  — LOGIC CHECKS (renamed to new labels)
********************************************************************************
{

    use "$raw/${dta_file}_${date}_M04_inc2.dta", clear

    la lang ${LNG} 

    // optional hotfix hook
    do "${wd}/fix/do/M04_2.do"
	
	
	/// MULTIPLE TO SINGLE 
	
	
	******************************************************
	* ib1: Agriculture sales share categories (during past 6 months)
	* ib1_# are coded 1=Yes, 2=No (INC2_YN)
	* Create ranked single-choice variables ib1_cat1, ib1_cat2, ...
	******************************************************

	* --- 1) Value label for categories (code = item number 1..9) ---
	capture label drop ib1_cat_eng
	label define ib1_cat_eng ///
		1 "Rice" ///
		2 "Corn" ///
		3 "Other cereals" ///
		4 "Fruit" ///
		5 "Vegetables" ///
		6 "Fishing & aquaculture" ///
		7 "Livestock & poultry" ///
		8 "Livestock & poultry products" ///
		9 "Others (specify)" ///
		, replace

	* --- 2) Build 0/1 indicators for YES (1) and count selections ---
	tempvar y1 y2 y3 y4 y5 y6 y7 y8 y9
	gen byte `y1' = (ib1_1==1)
	gen byte `y2' = (ib1_2==1)
	gen byte `y3' = (ib1_3==1)
	gen byte `y4' = (ib1_4==1)
	gen byte `y5' = (ib1_5==1)
	gen byte `y6' = (ib1_6==1)
	gen byte `y7' = (ib1_7==1)
	gen byte `y8' = (ib1_8==1)
	gen byte `y9' = (ib1_9==1)

	egen ib1_ncats = rowtotal(`y1' `y2' `y3' `y4' `y5' `y6' `y7' `y8' `y9')
	quietly summarize ib1_ncats, meanonly
	local max = r(max)

	* --- 3) Peel off selected categories into ranked single-choice variables ---
	local codes 1 2 3 4 5 6 7 8 9

	foreach c of local codes {
		gen byte ib1_rem_`c' = (ib1_`c'==1)
	}

	forvalues k = 1/`max' {
		gen ib1_cat`k' = .

		foreach c of local codes {
			replace ib1_cat`k' = `c' if ib1_rem_`c' == 1 & missing(ib1_cat`k')
		}

		foreach c of local codes {
			replace ib1_rem_`c' = 0 if ib1_cat`k' == `c'
		}

		label variable ib1_cat`k' "Agriculture sales category (past 6 months) (rank `k')"
		label values  ib1_cat`k' ib1_cat_eng
	}

	drop ib1_rem_* `y1' `y2' `y3' `y4' `y5' `y6' `y7' `y8' `y9'
	
	order ib1_*, before(ib2_1)
	
	******************************************************
	* ib2: Received amount in pesos
	* Create ib1_amt1, ib1_amt2, ... corresponding to ib1_cat#
	******************************************************

	* find how many ranked category vars exist
	ds ib1_cat*
	local catvars `r(varlist)'
	local ncat : word count `catvars'

	* create amount variables
	forvalues k = 1/`ncat' {
		gen ib1_amt`k' = .

		replace ib1_amt`k' = ib2_1 if ib1_cat`k' == 1
		replace ib1_amt`k' = ib2_2 if ib1_cat`k' == 2
		replace ib1_amt`k' = ib2_3 if ib1_cat`k' == 3
		replace ib1_amt`k' = ib2_4 if ib1_cat`k' == 4
		replace ib1_amt`k' = ib2_5 if ib1_cat`k' == 5
		replace ib1_amt`k' = ib2_6 if ib1_cat`k' == 6
		replace ib1_amt`k' = ib2_7 if ib1_cat`k' == 7
		replace ib1_amt`k' = ib2_8 if ib1_cat`k' == 8
		replace ib1_amt`k' = ib2_9 if ib1_cat`k' == 9

		label variable ib1_amt`k' ///
			"Received amount in pesos for agriculture sales category (rank `k')"
	}
		
	
	order ib1_amt*, after(ib1_cat6)
	
	
	/// IC4 
	
	
	******************************************************
	* ic4: Domestic support sources (select_multiple binaries)
	* Create ranked single-choice variables ic4_src1, ic4_src2, ...
	* (Excludes ic4_txt)
	******************************************************

	* --- 1) Value label (code = suffix of ic4_# binary) ---
	capture label drop ic4_source_eng
	label define ic4_source_eng ///
		1  "Family member who would otherwise be part of this house" ///
		2  "Other relatives or friends" ///
		3  "Government institutions" ///
		4  "Regular or Modified CCT/Pantawid/4Ps" ///
		5  "Assistance to Individuals in Crisis Situation (AICS)" ///
		6  "Ayuda para sa Kapos ang Kita Program (AKAP)" ///
		7  "Programs supporting rice or other agriculture" ///
		8  "Walang Gutom 2027: Philippine Food Stamp" ///
		9  "Scholarships / financial assistance for schooling" ///
		10 "Unemployment insurance" ///
		11 "Other social programs (senior pension, medical assistance, etc.)" ///
		12 "Private institutions (Churches, NGOs)" ///
		15 "Political parties" ///
		23 "Government candidates" ///
		96 "Other (specify)" ///
		, replace

	* --- 2) Count selections and find max (how many ranked vars to create) ---
	egen ic4_nsrc = rowtotal(ic4_1 ic4_2 ic4_3 ic4_4 ic4_5 ic4_6 ic4_7 ic4_8 ic4_9 ic4_10 ic4_11 ic4_12 ic4_15 ic4_23 ic4_96)
	quietly summarize ic4_nsrc, meanonly
	local max = r(max)

	* --- 3) Peel off selected sources into ranked single-choice variables ---
	local codes 1 2 3 4 5 6 7 8 9 10 11 12 15 23 96

	foreach c of local codes {
		gen byte ic4_rem_`c' = ic4_`c'
	}

	forvalues k = 1/`max' {
		gen ic4_src`k' = .

		foreach c of local codes {
			replace ic4_src`k' = `c' if ic4_rem_`c' == 1 & missing(ic4_src`k')
		}

		foreach c of local codes {
			replace ic4_rem_`c' = 0 if ic4_src`k' == `c'
		}

		label variable ic4_src`k' "Domestic support source (rank `k')"
		label values  ic4_src`k' ic4_source_eng
	}

	drop ic4_rem_*
		
	
	order ic4_nsrc ic4_src*, after(ic4_txt)
	
	
	
	/// IC5 
	
	
		
	******************************************************
	* ic5: Received amounts in pesos corresponding to ic4 sources
	* Create ranked amount variables ic5_1 ic5_2 ... (ranked)
	* based on ranked source variables ic4_src1 ic4_src2 ...
	*
	* Treat codes 15 and 23 as "Other" (same bucket as 96), i.e. map to ic5_13
	*
	* IMPORTANT: This creates NEW variables named ic5_# (ranked),
	* so rename original ic5_* first if you want to keep them.
	******************************************************

	* (optional but recommended) preserve original item-level amounts
	rename ic5_1  ic5_item1
	rename ic5_2  ic5_item2
	rename ic5_3  ic5_item3
	rename ic5_4  ic5_item4
	rename ic5_5  ic5_item5
	rename ic5_6  ic5_item6
	rename ic5_7  ic5_item7
	rename ic5_8  ic5_item8
	rename ic5_9  ic5_item9
	rename ic5_10 ic5_item10
	rename ic5_11 ic5_item11
	rename ic5_12 ic5_item12
	rename ic5_13 ic5_item13

	* how many ranked source variables exist
	ds ic4_src*
	local nsrc : word count `r(varlist)'

	forvalues k = 1/`nsrc' {
		gen ic5_`k' = .

		replace ic5_`k' = ic5_item1  if ic4_src`k' == 1
		replace ic5_`k' = ic5_item2  if ic4_src`k' == 2
		replace ic5_`k' = ic5_item3  if ic4_src`k' == 3
		replace ic5_`k' = ic5_item4  if ic4_src`k' == 4
		replace ic5_`k' = ic5_item5  if ic4_src`k' == 5
		replace ic5_`k' = ic5_item6  if ic4_src`k' == 6
		replace ic5_`k' = ic5_item7  if ic4_src`k' == 7
		replace ic5_`k' = ic5_item8  if ic4_src`k' == 8
		replace ic5_`k' = ic5_item9  if ic4_src`k' == 9
		replace ic5_`k' = ic5_item10 if ic4_src`k' == 10
		replace ic5_`k' = ic5_item11 if ic4_src`k' == 11
		replace ic5_`k' = ic5_item12 if ic4_src`k' == 12

		* Treat 15/23/96 as "Other"
		replace ic5_`k' = ic5_item13 if inlist(ic4_src`k', 15, 23, 96)

		label variable ic5_`k' "Received amount in pesos for domestic support source (rank `k')"
	}	
			
	
	order ic5_1-ic5_4, after(ic4_96)
	
	
	/// 
	
	drop ib1_1 - ib1_9 
	drop ib2_1-ib2_9
	drop ic4_1 - ic4_96
	drop ic5_item1 - ic5_item13
	

    save "$dta/${dta_file}_${date}_M04_inc2.dta", replace

    glo mod M04_2

    confirmdir "${fix}/${mod}/"
    if _rc ~= 0 mkdir "${fix}/${mod}"
    glo sec "${wd}/fix/${date}/${mod}"

    export excel using "${fix}/${mod}/${dta_file}_${date}_M04_inc2.xlsx", ///
        replace firstrow(var) nol

/*
    /// LOGIC CHECKS
    {

/*
SECTION MAP (new labels)
------------------------
B) Net share from other households
   - Incidence: ib1_1..ib1_9 (1=Yes,2=No)
   - Amounts:   prefer ib2_1..ib2_9; fallback to legacy inc2_share_<item>_amt
                where index→item is:
                1 rice, 2 corn, 3 cereals, 4 fruit, 5 veg,
                6 fishing, 7 livestock, 8 livestockprod, 9 other
C1) From abroad amounts: ic1_1/ic1a, ic1_2/ic1b, ic1_3/ic1c (non-negative)
C2) Domestic transfers:
    - Incidence: ic3 (1/2)
    - Sources (multi dummies): ic4_1..ic4_13
    - Amounts per source: prefer ic5_1..ic5_13; fallback inc2_domestic_amt_1.._13
C3) Rentals:
    - Incidence: ic6 (1/2)
    - Amounts: cash ic7_1/ic7a ; in-kind ic7_2/ic7b  (>=0 or -99)
C4) Benefits:
    - Y/N: ic8a ic8b ic8c (1/2)
    - Amounts: ic9a/ic9_1 ; ic9b/ic9_2 ; ic9c/ic9_3  (>=0 or -99)
D) Other income:
    - Incidence: id1 (1/2)
    - Amounts: cash id2_1/id2a ; in-kind id2_2/id2b  (>=0 or -99)
E) Family sustenance (HH-level):
    - Y/N:  ie1a..ie1e (1/2)
    - Amt:  ie2a..ie2e (>=0 or -99)
*/

    // Prefix labels with var name (nicer Excel headers with firstrow(varl))
    foreach v of varlist _all {
        local vl : variable label `v'
        la var `v' "`v': `vl'"
    }

    // IDs on every export (HH-level)
    glo IDENT "hhid_str date"

    // filename counter
    local o = 0

    // ---------------- Household uniqueness (HH-level) ----------------
    capture noisily isid hhid
    if _rc {
        duplicates tag hhid, gen(__dup_hh)
        count if __dup_hh
        if r(N) {
            local o = `o' + 1
            local suf = string(`o', "%02.0f")
            export excel ${IDENT} if __dup_hh using ///
                "${sec}/${LNG}_${mod}_`suf'_dup_hhid.xlsx", replace firstrow(varl) nol
        }
        cap drop __dup_hh
    }

	  // ============== B) NET SHARE from other households (IB1/IB2) ==============
	local SHARE_IDX   "1 2 3 4 5 6 7 8 9"
	local SHARE_NAMES "rice corn cereals fruit veg fishing livestock livestockprod other"

	local j = 0
	foreach i of local SHARE_IDX {
		local j = `j' + 1
		local item : word `j' of `SHARE_NAMES'

		// incidence var (may not exist for all items)
		local yn = ib1_`i'
		local okyn = 0
		capture confirm numeric variable `yn'
		if !_rc local okyn = 1

		// amount var: prefer ib2_#, else fallback to legacy name
		local amt ""
		local okamt = 0
		capture confirm numeric variable ib2_`i'
		if !_rc {
			local amt "ib2_`i'"
			local okamt = 1
		}
		if `okamt'==0 {
			capture confirm numeric variable inc2_share_`item'_amt
			if !_rc {
				local amt "inc2_share_`item'_amt"
				local okamt = 1
			}
		}

		// Only proceed if we actually have an amount var
		if `okamt' {
			// (1) Negative amount (no DK code in spec for IB2)
			count if !missing(`amt') & `amt' < 0
			if r(N) {
				local o = `o' + 1
				local suf = string(`o', "%02.0f")
				export excel ${IDENT} `yn' `amt' ///
					if !missing(`amt') & `amt' < 0 using ///
					"${sec}/${LNG}_${mod}_`suf'_IB2_`item'_negative.xlsx", replace firstrow(varl) nol
			}

			// (2) Gating ONLY if the incidence var exists
			if `okyn' {
				// Yes → amount required
				count if `yn'==1 & missing(`amt')
				if r(N) {
					local o = `o' + 1
					local suf = string(`o', "%02.0f")
					export excel ${IDENT} `yn' `amt' ///
						if `yn'==1 & missing(`amt') using ///
						"${sec}/${LNG}_${mod}_`suf'_IB2_`item'_yes_missing_amt.xlsx", replace firstrow(varl) nol
				}
				// No → amount must be blank
				count if `yn'==2 & !missing(`amt')
				if r(N) {
					local o = `o' + 1
					local suf = string(`o', "%02.0f")
					export excel ${IDENT} `yn' `amt' ///
						if `yn'==2 & !missing(`amt') using ///
						"${sec}/${LNG}_${mod}_`suf'_IB2_`item'_no_with_amt.xlsx", replace firstrow(varl) nol
				}
			}
		}
	}


    // ============== C1) FROM ABROAD amounts (IC1) ==============
    // Use whichever alias exists
    local ABR "ic1_1 ic1a ic1_2 ic1b ic1_3 ic1c"
    foreach v of local ABR {
        capture confirm numeric variable `v'
        if !_rc {
            count if !missing(`v') & `v' < 0
            if r(N) {
                local o = `o' + 1
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} `v' if !missing(`v') & `v' < 0 using ///
                    "${sec}/${LNG}_${mod}_`suf'_IC1_abroad_negative.xlsx", replace firstrow(varl) nol
            }
        }
    }

    // ============== C2) DOMESTIC TRANSFERS (IC3–IC5) ==============
    // ic3 validity
    capture confirm numeric variable ic3
    if !_rc {
        count if missing(ic3) | !inlist(ic3,1,2)
        if r(N) {
            local o = `o' + 1
            local suf = string(`o', "%02.0f")
            export excel ${IDENT} ic3 if missing(ic3) | !inlist(ic3,1,2) using ///
                "${sec}/${LNG}_${mod}_`suf'_IC3_support_bad_or_missing.xlsx", replace firstrow(varl) nol
        }

        // Gather existing ic4_1..ic4_13 dummies
        local SRC_DUMS
        foreach k in 1 2 3 4 5 6 7 8 9 10 11 12 96 {
            capture confirm numeric variable ic4_`k'
            if !_rc local SRC_DUMS "`SRC_DUMS' ic4_`k'"
        }
        if "`SRC_DUMS'" != "" {
            egen byte __nsrc = rowtotal(`SRC_DUMS')
            // ic3==1 → need ≥1 source
            count if ic3==1 & __nsrc==0
            if r(N) {
                local o = `o' + 1
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} ic3 `SRC_DUMS' if ic3==1 & __nsrc==0 using ///
                    "${sec}/${LNG}_${mod}_`suf'_IC4_support_yes_no_source.xlsx", replace firstrow(varl) nol
            }
            drop __nsrc
        }

        // Amounts per source: prefer ic5_k; fallback inc2_domestic_amt_k
        // Rules: amt >=0 or -99; ic3==2 → all blank; if source exists:
        //        source==0 & amt filled → flag ; source==1 & amt missing → flag
        foreach k in 1 2 3 4 5 6 7 8 9 10 11 12 96 {
            local AMT = ""
            capture confirm numeric variable ic5_`k'
            if !_rc local AMT "ic5_`k'"
            if "`AMT'"=="" {
                capture confirm numeric variable inc2_domestic_amt_`k'
                if !_rc local AMT "inc2_domestic_amt_`k'"
            }
            if "`AMT'" != "" {
                // negative (excluding -99)
                count if !missing(`AMT') & (`AMT' < 0 & `AMT' != -99)
                if r(N) {
                    local o = `o' + 1
                    local suf = string(`o', "%02.0f")
                    export excel ${IDENT} `AMT' if !missing(`AMT') & (`AMT' < 0 & `AMT' != -99) using ///
                        "${sec}/${LNG}_${mod}_`suf'_IC5_domestic_amt`k'_negative.xlsx", replace firstrow(varl) nol
                }
                // ic3==2 → amount should be blank
                count if ic3==2 & !missing(`AMT')
                if r(N) {
                    local o = `o' + 1
                    local suf = string(`o', "%02.0f")
                    export excel ${IDENT} ic3 `AMT' if ic3==2 & !missing(`AMT') using ///
                        "${sec}/${LNG}_${mod}_`suf'_IC5_amt_filled_when_ic3_no.xlsx", replace firstrow(varl) nol
                }
                // If matching source dummy exists, enforce alignment
                capture confirm numeric variable ic4_`k'
                if !_rc {
                    // amount but source==0
                    count if ic4_`k'==0 & !missing(`AMT')
                    if r(N) {
                        local o = `o' + 1
                        local suf = string(`o', "%02.0f")
                        export excel ${IDENT} ic4_`k' `AMT' if ic4_`k'==0 & !missing(`AMT') using ///
                            "${sec}/${LNG}_${mod}_`suf'_IC5_amt_without_source`k'.xlsx", replace firstrow(varl) nol
                    }
                    // source==1 but amount missing
                    count if ic4_`k'==1 & missing(`AMT')
                    if r(N) {
                        local o = `o' + 1
                        local suf = string(`o', "%02.0f")
                        export excel ${IDENT} ic4_`k' `AMT' if ic4_`k'==1 & missing(`AMT') using ///
                            "${sec}/${LNG}_${mod}_`suf'_IC5_source_yes_missing_amt`k'.xlsx", replace firstrow(varl) nol
                    }
                }
            }
        }
    }

    // ============== C3) RENTALS (IC6/IC7) ==============
    capture confirm numeric variable ic6
    if !_rc {
        // code validity
        count if missing(ic6) | !inlist(ic6,1,2)
        if r(N) {
            local o = `o' + 1
            local suf = string(`o', "%02.0f")
            export excel ${IDENT} ic6 if missing(ic6) | !inlist(ic6,1,2) using ///
                "${sec}/${LNG}_${mod}_`suf'_IC6_rental_bad_or_missing.xlsx", replace firstrow(varl) nol
        }

        // amounts: pick available aliases
        local RENTCASH ""
        capture confirm numeric variable ic7_1
        if !_rc local RENTCASH "ic7_1"
        if "`RENTCASH'"=="" {
            capture confirm numeric variable ic7a
            if !_rc local RENTCASH "ic7a"
        }
        local RENTINK ""
        capture confirm numeric variable ic7_2
        if !_rc local RENTINK "ic7_2"
        if "`RENTINK'"=="" {
            capture confirm numeric variable ic7b
            if !_rc local RENTINK "ic7b"
        }

        // negatives (except -99)
        foreach v in `RENTCASH' `RENTINK' {
            if "`v'" != "" {
                count if !missing(`v') & (`v' < 0 & `v' != -99)
                if r(N) {
                    local o = `o' + 1
                    local suf = string(`o', "%02.0f")
                    export excel ${IDENT} `v' if !missing(`v') & (`v' < 0 & `v' != -99) using ///
                        "${sec}/${LNG}_${mod}_`suf'_IC7_rental_negative.xlsx", replace firstrow(varl) nol
                }
            }
        }

        // gating: ic6==1 → need at least one amount; ic6==2 → both blank
        tempvar __rnm
        gen byte `__rnm' = 0
        if "`RENTCASH'" != "" replace `__rnm' = `__rnm' + !missing(`RENTCASH')
        if "`RENTINK'"  != "" replace `__rnm' = `__rnm' + !missing(`RENTINK')

        count if ic6==1 & `__rnm'==0
        if r(N) {
            local o = `o' + 1
            local suf = string(`o', "%02.0f")
            export excel ${IDENT} ic6 `RENTCASH' `RENTINK' if ic6==1 & `__rnm'==0 using ///
                "${sec}/${LNG}_${mod}_`suf'_IC7_rental_yes_no_amount.xlsx", replace firstrow(varl) nol
        }
        count if ic6==2 & `__rnm'>0
        if r(N) {
            local o = `o' + 1
            local suf = string(`o', "%02.0f")
            export excel ${IDENT} ic6 `RENTCASH' `RENTINK' if ic6==2 & `__rnm'>0 using ///
                "${sec}/${LNG}_${mod}_`suf'_IC7_rental_no_with_amount.xlsx", replace firstrow(varl) nol
        }
        drop `__rnm'
    }

	// ============== C4) BENEFITS (IC8/IC9) ==============
	// For each: YN must be 1/2; amount >=0 or -99; YN==1 → amount required; YN==2 → amount blank
	local BEN_YN   "ic8a ic8b ic8c"
	local BEN_AMTA "ic9a ic9b ic9c"
	local BEN_AMTB "ic9_1 ic9_2 ic9_3"

	local i = 0
	foreach yn of local BEN_YN {
		// pick amount alias
		local i = `i' + 1
		local a : word `i' of `BEN_AMTA'
		local b : word `i' of `BEN_AMTB'
		local amt ""
		capture confirm numeric variable `a'
		if !_rc local amt "`a'"
		if "`amt'"=="" {
			capture confirm numeric variable `b'
			if !_rc local amt "`b'"
		}

		// does the YN var exist?
		local okyn = 0
		capture confirm numeric variable `yn'
		if !_rc local okyn = 1

		// build ID columns safely (only include `yn' if it exists)
		local IDCOLS "${IDENT}"
		if `okyn' local IDCOLS "`IDCOLS' `yn'"

		// YN code validity (only if `yn' exists)
		if `okyn' {
			count if missing(`yn') | !inlist(`yn',1,2)
			if r(N) {
				local o = `o' + 1
				local suf = string(`o', "%02.0f")
				export excel ${IDENT} `yn' if missing(`yn') | !inlist(`yn',1,2) using ///
					"${sec}/${LNG}_${mod}_`suf'_IC8_`yn'_bad_or_missing.xlsx", replace firstrow(varl) nol
			}
		}

		// amount validity + gating
		if "`amt'" != "" {
			// negatives (except -99)
			count if !missing(`amt') & (`amt' < 0 & `amt' != -99)
			if r(N) {
				local o = `o' + 1
				local suf = string(`o', "%02.0f")
				export excel `IDCOLS' `amt' if !missing(`amt') & (`amt' < 0 & `amt' != -99) using ///
					"${sec}/${LNG}_${mod}_`suf'_IC9_`amt'_negative.xlsx", replace firstrow(varl) nol
			}

			// gating only if we have `yn'
			if `okyn' {
				// YN==1 → amount required
				count if `yn'==1 & missing(`amt')
				if r(N) {
					local o = `o' + 1
					local suf = string(`o', "%02.0f")
					export excel ${IDENT} `yn' `amt' if `yn'==1 & missing(`amt') using ///
						"${sec}/${LNG}_${mod}_`suf'_IC9_`amt'_missing_when_yes.xlsx", replace firstrow(varl) nol
				}
				// YN==2 → amount must be blank
				count if `yn'==2 & !missing(`amt')
				if r(N) {
					local o = `o' + 1
					local suf = string(`o', "%02.0f")
					export excel ${IDENT} `yn' `amt' if `yn'==2 & !missing(`amt') using ///
						"${sec}/${LNG}_${mod}_`suf'_IC9_`amt'_filled_when_no.xlsx", replace firstrow(varl) nol
				}
			}
		}
	}


    // ============== D) OTHER INCOME (ID1/ID2) ==============
    capture confirm numeric variable id1
    if !_rc {
        // code validity
        count if missing(id1) | !inlist(id1,1,2)
        if r(N) {
            local o = `o' + 1
            local suf = string(`o', "%02.0f")
            export excel ${IDENT} id1 if missing(id1) | !inlist(id1,1,2) using ///
                "${sec}/${LNG}_${mod}_`suf'_ID1_other_bad_or_missing.xlsx", replace firstrow(varl) nol
        }

        // choose amount aliases
        local OTHCASH ""
        capture confirm numeric variable id2_1
        if !_rc local OTHCASH "id2_1"
        if "`OTHCASH'"=="" {
            capture confirm numeric variable id2a
            if !_rc local OTHCASH "id2a"
        }
        local OTHING ""
        capture confirm numeric variable id2_2
        if !_rc local OTHING "id2_2"
        if "`OTHING'"=="" {
            capture confirm numeric variable id2b
            if !_rc local OTHING "id2b"
        }

        // gating by incidence: id1==1 need >=1 amount; id1==2 both blank
        tempvar __onm
        gen byte `__onm' = 0
        if "`OTHCASH'" != "" replace `__onm' = `__onm' + !missing(`OTHCASH')
        if "`OTHING'" != "" replace `__onm' = `__onm' + !missing(`OTHING')

        count if id1==1 & `__onm'==0
        if r(N) {
            local o = `o' + 1
            local suf = string(`o', "%02.0f")
            export excel ${IDENT} id1 `OTHCASH' `OTHING' if id1==1 & `__onm'==0 using ///
                "${sec}/${LNG}_${mod}_`suf'_ID2_other_yes_no_amount.xlsx", replace firstrow(varl) nol
        }
        count if id1==2 & `__onm'>0
        if r(N) {
            local o = `o' + 1
            local suf = string(`o', "%02.0f")
            export excel ${IDENT} id1 `OTHCASH' `OTHING' if id1==2 & `__onm'>0 using ///
                "${sec}/${LNG}_${mod}_`suf'_ID2_other_no_with_amount.xlsx", replace firstrow(varl) nol
        }

        // Negatives (except -99)
        foreach v in `OTHCASH' `OTHING' {
            if "`v'" != "" {
                count if !missing(`v') & (`v' < 0 & `v' != -99)
                if r(N) {
                    local o = `o' + 1
                    local suf = string(`o', "%02.0f")
                    export excel ${IDENT} `v' if !missing(`v') & (`v' < 0 & `v' != -99) using ///
                        "${sec}/${LNG}_${mod}_`suf'_ID2_other_negative.xlsx", replace firstrow(varl) nol
                }
            }
        }
        drop `__onm'
    }

    // ============== E) FAMILY SUSTENANCE (IE1/IE2) ==============
    // For each activity: if YN==1 → amount required (>=0 or -99); if YN==2 → amount blank
    local SUST "a b c d e"
    foreach s of local SUST {
        local yn  = ie1`s'
        local amt = ie2`s'

        capture confirm numeric variable `yn'
        capture confirm numeric variable `amt'
        if !_rc {
            // code validity
            count if missing(`yn') | !inlist(`yn',1,2)
            if r(N) {
                local o = `o' + 1
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} `yn' if missing(`yn') | !inlist(`yn',1,2) using ///
                    "${sec}/${LNG}_${mod}_`suf'_IE1_`s'_bad_or_missing.xlsx", replace firstrow(varl) nol
            }
            // negative amount (except -99)
            count if !missing(`amt') & (`amt' < 0 & `amt' != -99)
            if r(N) {
                local o = `o' + 1
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} `yn' `amt' if !missing(`amt') & (`amt' < 0 & `amt' != -99) using ///
                    "${sec}/${LNG}_${mod}_`suf'_IE2_`s'_negative.xlsx", replace firstrow(varl) nol
            }
            // YN==1 but missing amount
            count if `yn'==1 & missing(`amt')
            if r(N) {
                local o = `o' + 1
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} `yn' `amt' if `yn'==1 & missing(`amt') using ///
                    "${sec}/${LNG}_${mod}_`suf'_IE2_`s'_yes_missing_amt.xlsx", replace firstrow(varl) nol
            }
            // YN==2 but amount filled
            count if `yn'==2 & !missing(`amt')
            if r(N) {
                local o = `o' + 1
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} `yn' `amt' if `yn'==2 & !missing(`amt') using ///
                    "${sec}/${LNG}_${mod}_`suf'_IE2_`s'_no_with_amt.xlsx", replace firstrow(varl) nol
            }
        }
    }

    // ============== Optional: dynamic high-outlier screen across *_amt ==============
    // Treat -99 (DK) as missing; only flag when sample size is reasonable.
    capture unab _AMTS : *_amt
    if !_rc {
        foreach v of local _AMTS {
            capture confirm numeric variable `v'
            if !_rc {
                tempvar __x
                gen double `__x' = `v'
                replace `__x' = . if `__x'==-99
                quietly count if !missing(`__x') & `__x'>=0
                if r(N) >= 20 {
                    quietly summarize `__x', detail
                    local ub = max(r(p99)*1.5, r(p95)*2, r(p50)*20)
                    if missing(`ub') | `ub'<=0 local ub = 1e9
                    count if `__x' > `ub'
                    if r(N) {
                        local o = `o' + 1
                        local suf = string(`o', "%02.0f")
                        export excel ${IDENT} `v' if `__x' > `ub' using ///
                            "${sec}/${LNG}_${mod}_`suf'_outlier_hi_`v'.xlsx", replace firstrow(varl) nol
                    }
                }
                drop `__x'
            }
        }
    }

    }

}
*/

}
	
********************************************************************************
**# (F) BANKING / FINANCE — logic checks for M05_fin (new labels f1–f12)
********************************************************************************
{
    // -------- Load & setup --------
    use "$raw/${dta_file}_${date}_M05_fin.dta", clear
    la lang ${LNG}

    // (Optional) one-off fixes for banking module (if you keep such a file)
    do "${wd}/fix/do/M05.do"
	
	
	
	
	
	
	/// MULTI TO SINGLE 
	
	
	******************************************************
	* f8: Loan purpose (select_multiple binaries)
	* Create ranked single-choice variables f8_purp1, f8_purp2, ...
	******************************************************

	* --- 1) Value label (code = suffix of f8_# binary) ---
	capture label drop f8_purpose_eng
	label define f8_purpose_eng ///
		1  "Housing" ///
		2  "Car/transportation" ///
		3  "Food" ///
		4  "Other consumption" ///
		5  "Business" ///
		6  "Education" ///
		7  "Health" ///
		11 "Savings" ///
		16 "Gadgets" ///
		17 "Utilities" ///
		18 "Allowance" ///
		20 "Farming / agriculture" ///
		21 "Insurance" ///
		24 "To pay for another loan" ///
		25 "Unexpected bills" ///
		96 "Others" ///
		99 "Don't know" ///
		, replace

	* --- 2) Count selections and find max (how many ranked vars to create) ---
	egen f8_npurp = rowtotal(f8_1 f8_2 f8_3 f8_4 f8_5 f8_6 f8_7 f8_11 f8_16 f8_17 f8_18 f8_20 f8_21 f8_24 f8_25 f8_96 f8_99)
	quietly summarize f8_npurp, meanonly
	local max = r(max)

	* --- 3) Peel off selected purposes into ranked single-choice variables ---
	local codes 1 2 3 4 5 6 7 11 16 17 18 20 21 24 25 96 99

	foreach c of local codes {
		gen byte f8_rem_`c' = f8_`c'
	}

	forvalues k = 1/`max' {
		gen f8_purp`k' = .

		foreach c of local codes {
			replace f8_purp`k' = `c' if f8_rem_`c' == 1 & missing(f8_purp`k')
		}

		foreach c of local codes {
			replace f8_rem_`c' = 0 if f8_purp`k' == `c'
		}

		label variable f8_purp`k' "Loan purpose (rank `k')"
		label values  f8_purp`k' f8_purpose_eng
	}

	drop f8_rem_*
		
	order f8_npurp f8_purp*, after(f7) 	
		
	drop f8_1 - f8_99
	
	
	
	
	
	
	
	
	
    // Save a cleaned copy alongside
    save "$dta/${dta_file}_${date}_M05_fin.dta", replace

    // Module + output folders
    glo mod M05
    confirmdir "${fix}/${mod}/"
    if _rc ~= 0 mkdir "${fix}/${mod}"
    glo sec "${wd}/fix/${date}/${mod}"

    // Flat export for eyeballing
    export excel using "${fix}/${mod}/${dta_file}_${date}_M05_fin.xlsx", ///
        replace firstrow(var) nol


    /// ========================== LOGIC CHECKS ==========================
    {

        /*
        New labeling map:
          f1  bank deposits (1/2/98)
          f2  mobile/e-wallet deposits (1/2/98)
          f3  saved money (1/2/98)
          f4  savings group (1/2/98)
          f5  has card (1/2/98)
          f6  emergency expense capacity (1/2/98)
          f7  applied for a loan (1/2/98/99; accept ±98/±99)
          f8_* loan purpose dummies (1,2,3,4,5,6,7,96,99); f8_txt is cleaned string
          f9  where applied (1,2,3,4,5,96,99)
          f10 loan approved (1/2/98/99; accept ±98/±99)
          f11 other loans outstanding (1/2/98/99; accept ±98/±99)
          f12 who to approach in difficulty (1,2,3,4,5,6,7,96)
        */

        // Prefix labels with var name for clearer Excel headers
        foreach v of varlist _all {
            local vl : variable label `v'
            la var `v' "`v': `vl'"
        }

        // IDs in every export (HH-level)
        glo IDENT "hhid_str date"

        // File counter
        local o = 0

        // ---------------- Household uniqueness ----------------
        capture noisily isid hhid
        if _rc {
            duplicates tag hhid, gen(__dup_hh)
            count if __dup_hh
            if r(N) {
                local o = `o' + 1
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} if __dup_hh using ///
                    "${sec}/${LNG}_${mod}_`suf'_dup_hhid.xlsx", replace firstrow(varl) nol
            }
            drop __dup_hh
        }

        // ---------------- F1–F6: basic code validity (1/2/98) ----------------
        foreach v in f1 f2 f3 f4 f5 f6 {
            capture confirm numeric variable `v'
            if !_rc {
                count if missing(`v') | !inlist(`v',1,2,98)
                if r(N) {
                    local o = `o' + 1
                    local suf = string(`o', "%02.0f")
                    export excel ${IDENT} `v' if missing(`v') | !inlist(`v',1,2,98) ///
                        using "${sec}/${LNG}_${mod}_`suf'_`v'_bad_or_missing.xlsx", ///
                        replace firstrow(varl) nol
                }
            }
        }

        // ---------------- F7: applied for loan (1/2/98/99 or -98/-99) ----------------
        capture confirm numeric variable f7
        if !_rc {
            count if missing(f7) | !inlist(f7,1,2,98,99,-98,-99)
            if r(N) {
                local o = `o' + 1
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} f7 if missing(f7) | !inlist(f7,1,2,98,99,-98,-99) ///
                    using "${sec}/${LNG}_${mod}_`suf'_F7_apply_bad_or_missing.xlsx", ///
                    replace firstrow(varl) nol
            }
        }

        // ---------------- F8: loan purpose (multi) — gating & exclusivity ----------------
        // Build list of numeric dummy vars: f8_* (avoid string *specify* fields)
        local PURPOSE_DUMS
        capture ds f8_*, has(type numeric)
        if !_rc {
            local PURPOSE_DUMS `r(varlist)'

            // How many purposes chosen (treat missing as 0)
            egen byte __npurp = rowtotal(`PURPOSE_DUMS')

            // If applied==1 → need ≥1 purpose
            count if f7==1 & __npurp==0
            if r(N) {
                local o = `o' + 1
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} f7 `PURPOSE_DUMS' if f7==1 & __npurp==0 ///
                    using "${sec}/${LNG}_${mod}_`suf'_F8_apply_yes_no_purpose.xlsx", ///
                    replace firstrow(varl) nol
            }

            // If applied!=1 (2/98/99/missing) → purposes must be zero/blank
            count if f7!=1 & __npurp>0
            if r(N) {
                local o = `o' + 1
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} f7 `PURPOSE_DUMS' if f7!=1 & __npurp>0 ///
                    using "${sec}/${LNG}_${mod}_`suf'_F8_purpose_filled_when_not_applied.xlsx", ///
                    replace firstrow(varl) nol
            }

            // Exclusivity: if DK (code 99) is selected, it should be the ONLY selection
            capture confirm variable f8_99
            if !_rc {
                egen byte __npurp_all = rowtotal(`PURPOSE_DUMS')
                count if f8_99==1 & __npurp_all>1
                if r(N) {
                    local o = `o' + 1
                    local suf = string(`o', "%02.0f")
                    export excel ${IDENT} `PURPOSE_DUMS' if f8_99==1 & __npurp_all>1 ///
                        using "${sec}/${LNG}_${mod}_`suf'_F8_DK_not_exclusive.xlsx", ///
                        replace firstrow(varl) nol
                }
                drop __npurp_all
            }

            drop __npurp
        }

        // ---------------- F9: where applied — gate on f7==1 ----------------
        capture confirm numeric variable f9
        if !_rc {
            // If applied==1 → source present & valid (1–5,96,99)
            count if f7==1 & (missing(f9) | !inlist(f9,1,2,3,4,5,96,99))
            if r(N) {
                local o = `o' + 1
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} f7 f9 if f7==1 & (missing(f9) | !inlist(f9,1,2,3,4,5,96,99)) ///
                    using "${sec}/${LNG}_${mod}_`suf'_F9_source_missing_or_bad_when_applied.xlsx", ///
                    replace firstrow(varl) nol
            }
            // If applied!=1 → source should be blank
            count if f7!=1 & !missing(f9)
            if r(N) {
                local o = `o' + 1
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} f7 f9 if f7!=1 & !missing(f9) ///
                    using "${sec}/${LNG}_${mod}_`suf'_F9_source_filled_when_not_applied.xlsx", ///
                    replace firstrow(varl) nol
            }
        }

        // ---------------- F10: loan approved — gate on f7==1 ----------------
        capture confirm numeric variable f10
        if !_rc {
            // If applied==1 → approved present & valid (1/2/98/99 or -98/-99)
            count if f7==1 & (missing(f10) | !inlist(f10,1,2,98,99,-98,-99))
            if r(N) {
                local o = `o' + 1
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} f7 f10 if f7==1 & (missing(f10) | !inlist(f10,1,2,98,99,-98,-99)) ///
                    using "${sec}/${LNG}_${mod}_`suf'_F10_approved_missing_or_bad_when_applied.xlsx", ///
                    replace firstrow(varl) nol
            }
            // If applied!=1 → should be blank
            count if f7!=1 & !missing(f10)
            if r(N) {
                local o = `o' + 1
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} f7 f10 if f7!=1 & !missing(f10) ///
                    using "${sec}/${LNG}_${mod}_`suf'_F10_approved_filled_when_not_applied.xlsx", ///
                    replace firstrow(varl) nol
            }
        }

        // ---------------- F11: other loans outstanding (1/2/98/99 or -98/-99) ----------------
        capture confirm numeric variable f11
        if !_rc {
            count if missing(f11) | !inlist(f11,1,2,98,99,-98,-99)
            if r(N) {
                local o = `o' + 1
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} f11 if missing(f11) | !inlist(f11,1,2,98,99,-98,-99) ///
                    using "${sec}/${LNG}_${mod}_`suf'_F11_outstanding_bad_or_missing.xlsx", ///
                    replace firstrow(varl) nol
            }
        }

        // ---------------- F12: who to approach (valid codes) ----------------
        capture confirm numeric variable f12
        if !_rc {
            count if missing(f12) | !inlist(f12,1,2,3,4,5,6,7,96)
            if r(N) {
                local o = `o' + 1
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} f12 if missing(f12) | !inlist(f12,1,2,3,4,5,6,7,96) ///
                    using "${sec}/${LNG}_${mod}_`suf'_F12_help_bad_or_missing.xlsx", ///
                    replace firstrow(varl) nol
            }
        }

    } // end logic checks

} // end wrapper


	
********************************************************************************
**# (M) MIGRATION — logic checks for M06_mig (new labels m1–m10)
********************************************************************************
{
    // -------- Load & merge roster (for age/gender gating) --------
    use "$raw/${dta_file}_${date}_M06_mig.dta", clear

    merge 1:1 hhid fmid using "$raw/${dta_file}_${date}_M01_roster.dta", ///
        assert(2 3) keep(3) keepusing(age gender) nogen
    order age gender, a(fmid)

    la lang ${LNG}

    // One-off fixes (optional)
    do "${wd}/fix/do/M06.do"

    // Save cleaned copy
    save "$dta/${dta_file}_${date}_M06_mig.dta", replace

    // Module + output folders
    glo mod M06
    confirmdir "${fix}/${mod}/"
    if _rc ~= 0 mkdir "${fix}/${mod}"
    glo sec "${wd}/fix/${date}/${mod}"

    // Flat dump for quick inspection
    export excel using "${fix}/${mod}/${dta_file}_${date}_M06_mig.xlsx", ///
        replace firstrow(var) nol


    /// ========================== LOGIC CHECKS ==========================
    {

        /*
        New labeling map:
          m1  Ever experienced migration (1..4)
          m1_migrant  Tag: 1 if m1 in 1/2/3 else 0
          m2  OFW status (1..3)
          m3  Returned OFW — sought work (1..3) [ask if m2 in 1/2]
          m4  Destination country (free/numeric)
          m5  Main reason for moving (1..; includes 96 Other)
          m6  HH-level: any member 15+ considering migrating (1/2)
          m7  Member is considering migration (1/2) [ask if m6==1]
          m8a Destination country, m8b province, m8c city (ask if m7==1)
          m9  Internal displacement reason (1..5)
          m10b Previous province, m10c Previous city (ask if displaced)
        */

        // Prefix labels with var name for clearer Excel headers
        foreach v of varlist _all {
            local vl : variable label `v'
            la var `v' "`v': `vl'"
        }

        // IDs shown in every export
        glo IDENT "hhid_str fmid date age gender m1 m2 m3 m1_migrant m6 m7 m9"

        // Counter for export filenames
        local o = 0

        // ---------------- Keys (long data) ----------------
        capture noisily isid hhid fmid
        if _rc {
            duplicates tag hhid fmid, gen(__dup_hhf)
            count if __dup_hhf
            if r(N) {
                local o = `o' + 1
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} hhid fmid if __dup_hhf using ///
                    "${sec}/${LNG}_${mod}_`suf'_dup_hhid_fmid.xlsx", ///
                    replace firstrow(varl) nol
            }
            drop __dup_hhf
        }

        // Existence guards (some fields might be absent early on)
        capture confirm var m1
        local hasM1 = !_rc
        capture confirm var m2
        local hasM2 = !_rc
        capture confirm var m3
        local hasM3 = !_rc
        capture confirm var m1_migrant
        local hasTAG = !_rc
        capture confirm var m6
        local hasM6 = !_rc
        capture confirm var m7
        local hasM7 = !_rc
        capture confirm var m8a
        local hasC = !_rc
        capture confirm var m8b
        local hasP = !_rc
        capture confirm var m8c
        local hasT = !_rc
        capture confirm var m9
        local hasM9 = !_rc
        capture confirm var m10b
        local hasPP = !_rc
        capture confirm var m10c
        local hasPC = !_rc

        // ---------------- 1) Code validity ----------------
        if `hasM1' {
            count if !inlist(m1,1,2,3,4) & !missing(m1)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} m1 if !inlist(m1,1,2,3,4) & !missing(m1) ///
                    using "${sec}/${LNG}_${mod}_`suf'_badcode_m1_evermoved.xlsx", ///
                    replace firstrow(varl) nol
            }
        }
        if `hasM2' {
            count if !inlist(m2,1,2,3) & !missing(m2)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} m2 if !inlist(m2,1,2,3) & !missing(m2) ///
                    using "${sec}/${LNG}_${mod}_`suf'_badcode_m2_ofw.xlsx", ///
                    replace firstrow(varl) nol
            }
        }
        if `hasM3' {
            count if !inlist(m3,1,2,3) & !missing(m3)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} m3 if !inlist(m3,1,2,3) & !missing(m3) ///
                    using "${sec}/${LNG}_${mod}_`suf'_badcode_m3_returnseek.xlsx", ///
                    replace firstrow(varl) nol
            }
        }
        if `hasM9' {
            count if !inlist(m9,1,2,3,4,5) & !missing(m9)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} m9 if !inlist(m9,1,2,3,4,5) & !missing(m9) ///
                    using "${sec}/${LNG}_${mod}_`suf'_badcode_m9_displace.xlsx", ///
                    replace firstrow(varl) nol
            }
        }

        // ---------------- 2) Age gating (M1–M3 only for age≥15) ----------------
        capture confirm var age
        if !_rc {
            count if age<15 & ( (`hasM1' & !missing(m1)) | (`hasM2' & !missing(m2)) | (`hasM3' & !missing(m3)) )
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} age m1 m2 m3 if age<15 & ( (`hasM1' & !missing(m1)) | (`hasM2' & !missing(m2)) | (`hasM3' & !missing(m3)) ) ///
                    using "${sec}/${LNG}_${mod}_`suf'_filled_under15_m1m3.xlsx", ///
                    replace firstrow(varl) nol
            }
        }

        // ---------------- 3) Routing: M2 → M3 ----------------
        if `hasM2' & `hasM3' {
            // Need M3 if OFW {1,2}
            count if inlist(m2,1,2) & missing(m3)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} m2 m3 if inlist(m2,1,2) & missing(m3) ///
                    using "${sec}/${LNG}_${mod}_`suf'_routing_m2_need_m3.xlsx", ///
                    replace firstrow(varl) nol
            }
            // Should NOT have M3 if OFW==3
            count if m2==3 & !missing(m3)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} m2 m3 if m2==3 & !missing(m3) ///
                    using "${sec}/${LNG}_${mod}_`suf'_routing_m3_when_not_needed.xlsx", ///
                    replace firstrow(varl) nol
            }
        }

        // ---------------- 4) OFW implies ever-moved ≠ 4 (No) ----------------
        if `hasM1' & `hasM2' {
            count if inlist(m2,1,2) & m1==4
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} m2 m1 if inlist(m2,1,2) & m1==4 ///
                    using "${sec}/${LNG}_${mod}_`suf'_ofw_vs_evermoved.xlsx", ///
                    replace firstrow(varl) nol
            }
        }

        // ---------------- 5) Tag check: m1_migrant matches M1 ----------------
        if `hasM1' & `hasTAG' {
            tempvar _exp
            gen byte `_exp' = inlist(m1,1,2,3) if !missing(m1)
            count if !missing(m1_migrant, `_exp') & m1_migrant != `_exp'
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} m1_migrant m1 if !missing(m1_migrant, `_exp') & m1_migrant != `_exp' ///
                    using "${sec}/${LNG}_${mod}_`suf'_tag_migrant_mismatch.xlsx", ///
                    replace firstrow(varl) nol
            }
            drop `_exp'
        }

        // ---------------- 6) HH m6 vs member m7; m7 age≥15 ----------------
        // Household key
        local hhkey ""
        cap confirm var hhid
        if !_rc local hhkey "hhid"
        else {
            cap confirm var hhsn
            if !_rc local hhkey "hhsn"
        }

        if "`hhkey'" != "" {
            cap drop __elig __hh_m6 __hh_m7
            gen byte __elig = (age>=15) if !missing(age)
            replace __elig = 1 if missing(age) // don't block if age missing

            if `hasM6' bysort `hhkey': egen byte __hh_m6 = max(m6==1)
            else gen byte __hh_m6 = .

            if `hasM7' bysort `hhkey': egen byte __hh_m7 = max(m7==1 & __elig==1)
            else gen byte __hh_m7 = .

            // (a) m6==1 but no member m7==1
            preserve
                by `hhkey': keep if _n==1
                keep if __hh_m6==1 & __hh_m7==0
                if _N {
                    local ++o
                    local suf = string(`o', "%02.0f")
                    export excel ${IDENT} `hhkey' using ///
                        "${sec}/${LNG}_${mod}_`suf'_m6_yes_no_m7.xlsx", ///
                        replace firstrow(varl) nol
                }
            restore

            // (b) member m7==1 but HH m6!=1
            preserve
                by `hhkey': keep if _n==1
                keep if __hh_m7==1 & __hh_m6!=1
                if _N {
                    local ++o
                    local suf = string(`o', "%02.0f")
                    export excel `hhkey' using ///
                        "${sec}/${LNG}_${mod}_`suf'_m7_yes_m6_no.xlsx", ///
                        replace firstrow(varl) nol
                }
            restore

            cap drop __elig __hh_m6 __hh_m7
        }

        // m7 filled under age 15
        if `hasM7' {
            cap confirm var age
            if !_rc {
                count if age<15 & !missing(m7)
                if r(N) {
                    local ++o
                    local suf = string(`o', "%02.0f")
                    export excel ${IDENT} age m7 if age<15 & !missing(m7) ///
                        using "${sec}/${LNG}_${mod}_`suf'_m7_filled_under15.xlsx", ///
                        replace firstrow(varl) nol
                }
            }
        }

        // ---------------- 7) Destination fields vs m7 ----------------
        if `hasM7' & (`hasC' | `hasP' | `hasT') {
            // Need at least one of m8a/m8b/m8c when m7==1
            count if m7==1 & ///
                     ( (`hasC' & missing(m8a)) & (`hasP' & missing(m8b)) & (`hasT' & missing(m8c)) )
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} m7 m8a m8b m8c if m7==1 & ///
                    ( (`hasC' & missing(m8a)) & (`hasP' & missing(m8b)) & (`hasT' & missing(m8c)) ) ///
                    using "${sec}/${LNG}_${mod}_`suf'_m8_missing_when_needed.xlsx", ///
                    replace firstrow(varl) nol
            }

            // Destination filled when m7!=1
            count if (m7!=1 | missing(m7)) & ///
                     ( (`hasC' & !missing(m8a)) | (`hasP' & !missing(m8b)) | (`hasT' & !missing(m8c)) )
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} m7 m8a m8b m8c if (m7!=1 | missing(m7)) & ///
                    ( (`hasC' & !missing(m8a)) | (`hasP' & !missing(m8b)) | (`hasT' & !missing(m8c)) ) ///
                    using "${sec}/${LNG}_${mod}_`suf'_m8_filled_when_not_needed.xlsx", ///
                    replace firstrow(varl) nol
            }
        }

        // ---------------- 8) Displacement → previous area ----------------
        if `hasM9' & (`hasPP' | `hasPC') {
            // Displaced (2–5) → need m10b or m10c
            count if inlist(m9,2,3,4,5) & ///
                    ( (`hasPP' & missing(m10b)) & (`hasPC' & missing(m10c)) )
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} m9 m10b m10c if inlist(m9,2,3,4,5) & ///
                    ( (`hasPP' & missing(m10b)) & (`hasPC' & missing(m10c)) ) ///
                    using "${sec}/${LNG}_${mod}_`suf'_m10_missing_when_displaced.xlsx", ///
                    replace firstrow(varl) nol
            }

            // Not displaced (=1) → m10b/m10c should be blank
            count if m9==1 & ( (`hasPP' & !missing(m10b)) | (`hasPC' & !missing(m10c)) )
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} m9 m10b m10c if m9==1 & ///
                    ( (`hasPP' & !missing(m10b)) | (`hasPC' & !missing(m10c)) ) ///
                    using "${sec}/${LNG}_${mod}_`suf'_m10_filled_when_not_displaced.xlsx", ///
                    replace firstrow(varl) nol
            }
        }

    } // end logic checks

} // end wrapper

	
********************************************************************************
**# (H) HEALTH — logic checks for M07_med (new labels h2–h17)
********************************************************************************

{
    // -------- Load & merge roster (age/gender) --------
    use "$raw/${dta_file}_${date}_M07_med.dta", clear

    merge 1:1 hhid fmid using "$raw/${dta_file}_${date}_M01_roster.dta", ///
        assert(3) keep(3) keepusing(age gender) nogen
    order age gender, a(fmid)

    la lang ${LNG}

    // One-off fixes (optional)
    do "${wd}/fix/do/M07.do"
	
	
	
	/// MULTI TO SINGLE 
	
	
	******************************************************
	* h5: Transport to health facility (select_multiple binaries)
	* Create ranked single-choice variables h5_mode1, h5_mode2, ...
	******************************************************

	* --- 1) Value label (code = suffix of h5_# binary) ---
	capture label drop h5_mode_eng
	label define h5_mode_eng ///
		1  "By foot" ///
		2  "Used own vehicle (specify)" ///
		3  "Bicycle" ///
		4  "Motorcycle/Tricycle" ///
		5  "Jeepney/Bus" ///
		6  "Car/Taxi" ///
		7  "Boat" ///
		8  "Airplane" ///
		9  "Horse or water buffalo" ///
		15 "Van" ///
		43 "Train" ///
		44 "Truck" ///
		45 "Company service" ///
		49 "Sports Utility Vehicle (SUV)" ///
		50 "Pick Up Truck" ///
		51 "Government service" ///
		52 "Tractor" ///
		96 "Others (specify)" ///
		97 "Work from home" ///
		98 "Refused to answer" ///
		99 "Don't know" ///
		, replace

	* --- 2) Count selections and find max (how many ranked vars to create) ---
	egen h5_nmodes = rowtotal(h5_1 h5_2 h5_3 h5_4 h5_5 h5_6 h5_7 h5_8 h5_9 h5_15 h5_43 h5_44 h5_45 h5_49 h5_50 h5_51 h5_52 h5_96 h5_97 h5_98 h5_99)
	quietly summarize h5_nmodes, meanonly
	local max = r(max)

	* --- 3) Peel off selected modes into ranked single-choice variables ---
	local codes 1 2 3 4 5 6 7 8 9 15 43 44 45 49 50 51 52 96 97 98 99

	foreach c of local codes {
		gen byte h5_rem_`c' = h5_`c'
	}

	forvalues k = 1/`max' {
		gen h5_mode`k' = .

		foreach c of local codes {
			replace h5_mode`k' = `c' if h5_rem_`c' == 1 & missing(h5_mode`k')
		}

		foreach c of local codes {
			replace h5_rem_`c' = 0 if h5_mode`k' == `c'
		}

		label variable h5_mode`k' "Transport to health facility (rank `k')"
		label values  h5_mode`k' h5_mode_eng
	}

	drop h5_rem_*
		
	order h5_nmodes h5_mode*, before(h5_txt)	
		
	drop h5_1 - h5_99
	
	
	/// h11ba 
	
	
	******************************************************
	* h11ba: Medical payer (MEDS) (select_multiple binaries)
	* Create ranked single-choice variables h11ba_pay1, h11ba_pay2, ...
	******************************************************

	* --- 1) Value label (code = suffix of h11ba_# binary) ---
	capture label drop h11ba_payer_eng
	label define h11ba_payer_eng ///
		1  "Immediate family member" ///
		2  "Relative/friend support" ///
		3  "PhilHealth" ///
		4  "PCSO" ///
		5  "Private insurance (HMO)" ///
		6  "Government program (MAIP, Malasakit, etc.)" ///
		7  "Other insurance (SSS, GSIS)" ///
		8  "Politician" ///
		9  "LGU" ///
		11 "Own money" ///
		16 "Health care center" ///
		18 "From a loan" ///
		23 "Involved party in the accident" ///
		24 "None, free service" ///
		96 "Others" ///
		, replace

	* --- 2) Count selections and find max (how many ranked vars to create) ---
	egen h11ba_npay = rowtotal(h11ba_1 h11ba_2 h11ba_3 h11ba_4 h11ba_5 h11ba_6 h11ba_7 h11ba_8 h11ba_9 h11ba_11 h11ba_16 h11ba_18 h11ba_23 h11ba_24 h11ba_96)
	quietly summarize h11ba_npay, meanonly
	local max = r(max)

	* --- 3) Peel off selected payers into ranked single-choice variables ---
	local codes 1 2 3 4 5 6 7 8 9 11 16 18 23 24 96

	foreach c of local codes {
		gen byte h11ba_rem_`c' = h11ba_`c'
	}

	forvalues k = 1/`max' {
		gen h11ba_pay`k' = .

		foreach c of local codes {
			replace h11ba_pay`k' = `c' if h11ba_rem_`c' == 1 & missing(h11ba_pay`k')
		}

		foreach c of local codes {
			replace h11ba_rem_`c' = 0 if h11ba_pay`k' == `c'
		}

		label variable h11ba_pay`k' "Medical payer (MEDS) (rank `k')"
		label values  h11ba_pay`k' h11ba_payer_eng
	}

	drop h11ba_rem_*
		
	order h11ba_npay h11ba_pay*, before(h11ba_txt)
	
	drop h11ba_1 - h11ba_96
	
	
	
	/// H16 
	
	
	******************************************************
	* h16: Payer of hospital bill (select_multiple binaries)
	* Create ranked single-choice variables h16_pay1, h16_pay2, ...
	******************************************************

	* --- 1) Value label (code = suffix of h16_# binary) ---
	capture label drop h16_payer_eng
	label define h16_payer_eng ///
		1  "Immediate family member" ///
		2  "Relative/friend support" ///
		3  "PhilHealth" ///
		4  "PCSO" ///
		5  "Private insurance (HMO)" ///
		6  "Government program (MAIP, Malasakit, etc.)" ///
		7  "Other insurance (SSS, GSIS)" ///
		8  "Politician" ///
		9  "LGU" ///
		11 "Own money" ///
		16 "Health care center" ///
		18 "From a loan" ///
		23 "Involved party in the accident" ///
		24 "None, free service" ///
		96 "Others" ///
		, replace

	* --- 2) Count selections and find max (how many ranked vars to create) ---
	egen h16_npay = rowtotal(h16_1 h16_2 h16_3 h16_4 h16_5 h16_6 h16_7 h16_8 h16_9 h16_11 h16_16 h16_18 h16_23 h16_24 h16_96)
	quietly summarize h16_npay, meanonly
	local max = r(max)

	* --- 3) Peel off selected payers into ranked single-choice variables ---
	local codes 1 2 3 4 5 6 7 8 9 11 16 18 23 24 96

	foreach c of local codes {
		gen byte h16_rem_`c' = h16_`c'
	}

	forvalues k = 1/`max' {
		gen h16_pay`k' = .

		foreach c of local codes {
			replace h16_pay`k' = `c' if h16_rem_`c' == 1 & missing(h16_pay`k')
		}

		foreach c of local codes {
			replace h16_rem_`c' = 0 if h16_pay`k' == `c'
		}

		label variable h16_pay`k' "Payer of hospital bill (rank `k')"
		label values  h16_pay`k' h16_payer_eng
	}

	drop h16_rem_*
		
		
	order h16_npay h16_pay*, before(h16_txt)
	
	drop h16_1 - h16_96
	
	///
	
	
	
	

    // Save cleaned copy
    save "$dta/${dta_file}_${date}_M07_med.dta", replace

    // Module + output folders
    glo mod M07
	
    confirmdir "${fix}/${mod}/"
    if _rc ~= 0 mkdir "${fix}/${mod}"
    glo sec "${wd}/fix/${date}/${mod}"

    // Flat dump for quick inspection
    export excel using "${fix}/${mod}/${dta_file}_${date}_M07_med.xlsx", ///
        replace firstrow(var) nol


    /// ========================== LOGIC CHECKS ==========================
    {

        /*
          Label map (new):
            h2   Needed care but did not (1..4,98)
            h2a  Able to get care (1,2,98) — ask if h2 in {1..4}
            h3   Reason unable (1,2,3,4,5,6,96) — ask iff h2==4
            h4   Most frequent facility (1,2,3,4,5,96,99) — ask iff h2 in {2,3}
            h5_* Transport modes (multi) / h5txt_check
            h6   Travel time (mins)  ≥0 or -99 — ask iff h2 in {2,3}
            h7   Travel cost (PHP)   ≥0 or -99 — ask iff h2 in {2,3}
            h8   OOP consult cat (1 cash / 2 in-kind / 3 no) — ask iff h2 in {2,3}
            h8a  OOP consult amount  0..1,000,000 or -99
            h9a/b/c Prescribed meds/diag/other (1/2) — ask iff h2 in {2,3}
            h10a/b/c Obtained (1/2) — ask iff h9?==1
            h11aa/ab/ac Amounts 0..500,000 or -99 — ask iff h10?==1
            h12  Hospitalized (1/2)
            h13  Hospital type (1,2,96,99) — ask iff h12==1
            h14  Total bill  ≥0 or -99 — ask iff h12==1
            h15  OOP for bill ≥0 or -99 — ask iff h12==1
            h16_* Payers (multi) / h16_txt — required if bill>OOP and both known
            h17  PhilHealth (1/2/3)
        */

        // Prefix labels with var name for clear Excel headers
        foreach v of varlist _all {
            local vl : variable label `v'
            la var `v' "`v': `vl'"
        }

        // IDs shown in every export
        glo IDENT "hhid_str fmid date age gender h2 h2a h3 h4 h6 h7 h8 h8a h12 h13 h14 h15 h17"
		
		
		// DROP txt
		
		ren h16_txt h16mult
		
		ren h5_txt h5txt_check
		
		drop *_txt
		
        // Counter for export filenames
        local o = 0

        // ---------------- Keys (long data) ----------------
        capture noisily isid hhid fmid
        if _rc {
            duplicates tag hhid fmid, gen(__dup_hhf)
            count if __dup_hhf
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} hhid fmid if __dup_hhf using ///
                    "${sec}/${LNG}_${mod}_`suf'_dup_hhid_fmid.xlsx", ///
                    replace firstrow(varl) nol
            }
            drop __dup_hhf
        }

        // ---------------- Guard variable existence ----------------
        cap confirm var h2
        local haveH2 = !_rc
        cap confirm var h2a
        local haveH2A = !_rc
        cap confirm var h3
        local haveH3 = !_rc
        cap confirm var h4
        local haveH4 = !_rc
        cap confirm var h6
        local haveH6 = !_rc
        cap confirm var h7
        local haveH7 = !_rc
        cap confirm var h8
        local haveH8 = !_rc
        cap confirm var h8a
        local haveH8a = !_rc

        cap confirm var h9a
        local havePmed = !_rc
        cap confirm var h9b
        local havePdiag = !_rc
        cap confirm var h9c
        local havePoth = !_rc

        cap confirm var h10a
        local haveOmed = !_rc
        cap confirm var h10b
        local haveOdiag = !_rc
        cap confirm var h10c
        local haveOoth = !_rc

        cap confirm var h11aa
        local haveAmtM = !_rc
        cap confirm var h11ab
        local haveAmtD = !_rc
        cap confirm var h11ac
        local haveAmtO = !_rc

        cap confirm var h12
        local haveH12 = !_rc
        cap confirm var h13
        local haveH13 = !_rc
        cap confirm var h14
        local haveH14 = !_rc
        cap confirm var h15
        local haveH15 = !_rc

        cap unab H5D : h5_*
        local haveH5D = !_rc
        cap confirm var h5txt_check
        local haveH5TXT = !_rc

        cap unab H16D : h16_*
        local haveH16D = !_rc
        cap confirm var h16mult
        local haveH16TXT = !_rc

        cap confirm var h17
        local haveH17 = !_rc


        // ==================================================
        // 1) Basic code validity (H2 / H2A / H3 / H4)
        // ==================================================
        if `haveH2' {
            count if !inlist(h2,1,2,3,4,98) & !missing(h2)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} h2 if !inlist(h2,1,2,3,4,98) & !missing(h2) using ///
                    "${sec}/${LNG}_${mod}_`suf'_H2_bad_code.xlsx", replace firstrow(varl) nol
            }
        }

        if `haveH2' & `haveH2A' {
            count if inlist(h2,1,2,3,4) & (missing(h2a) | !inlist(h2a,1,2,98))
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} h2 h2a if inlist(h2,1,2,3,4) & (missing(h2a) | !inlist(h2a,1,2,98)) using ///
                    "${sec}/${LNG}_${mod}_`suf'_H2A_missing_or_bad.xlsx", replace firstrow(varl) nol
            }
        }

        if `haveH2' & `haveH3' {
            // H3 required when h2==4; otherwise blank
            count if h2==4 & (missing(h3) | !inlist(h3,1,2,3,4,5,6,95,96))
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} h2 h3 if h2==4 & (missing(h3) | !inlist(h3,1,2,3,4,5,6,95,96)) using ///
                    "${sec}/${LNG}_${mod}_`suf'_H3_required_missing_or_bad.xlsx", replace firstrow(varl) nol
            }
            count if h2!=4 & h2a==2 & missing(h3)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} h2 h3 if h2!=4 & h2a==2 & missing(h3) using ///
                    "${sec}/${LNG}_${mod}_`suf'_H3_filled_when_not_applicable.xlsx", replace firstrow(varl) nol
            }
        }

        if `haveH2' & `haveH4' {
            // H4 required when outpatient in H2
            count if inlist(h2,2,3) & (missing(h4) | !inlist(h4,1,2,3,4,5,96,99))
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} h2 h4 if inlist(h2,2,3) & (missing(h4) | !inlist(h4,1,2,3,4,5,96,99)) using ///
                    "${sec}/${LNG}_${mod}_`suf'_H4_missing_or_bad.xlsx", replace firstrow(varl) nol
            }
            count if !inlist(h2,2,3) & !missing(h4)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} h2 h4 if !inlist(h2,2,3) & !missing(h4) using ///
                    "${sec}/${LNG}_${mod}_`suf'_H4_filled_when_not_applicable.xlsx", replace firstrow(varl) nol
            }
        }

        // ==================================================
        // 2) H5–H7 transport/time/cost when H2 in {2,3}
        // ==================================================
        // Build "any transport selected" flag from dummies or cleaned string
        tempvar __h5_any
        gen byte `__h5_any' = .
        if `haveH5D' {
            tempvar __h5_sum
            egen `__h5_sum' = rowtotal(`H5D'), missing
            replace `__h5_any' = (`__h5_sum' > 0) if !missing(`__h5_sum')
            drop `__h5_sum'
        }
        else if `haveH5TXT' {
            replace `__h5_any' = (trim(h5txt_check)!="") if !missing(h5txt_check)
        }

        if `haveH2' {
            // H5 required when outpatient; blank otherwise
            count if inlist(h2,2,3) & (`__h5_any'!=1)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} h2 h5txt_check `H5D' if inlist(h2,2,3) & (`__h5_any'!=1) using ///
                    "${sec}/${LNG}_${mod}_`suf'_H5_missing_when_required.xlsx", replace firstrow(varl) nol
            }
            count if !inlist(h2,2,3) & (`__h5_any'==1)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} h2 h5txt_check `H5D' if !inlist(h2,2,3) & (`__h5_any'==1) using ///
                    "${sec}/${LNG}_${mod}_`suf'_H5_filled_when_not_applicable.xlsx", replace firstrow(varl) nol
            }
        }

        // H6 travel time
        if `haveH6' {
            count if (h6 < 0 & h6 != -99) & !missing(h6)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} h6 using ///
                    "${sec}/${LNG}_${mod}_`suf'_H6_negative_time.xlsx", replace firstrow(varl) nol
            }
            if `haveH2' {
                count if inlist(h2,2,3) & missing(h6)
                if r(N) {
                    local ++o
                    local suf = string(`o', "%02.0f")
                    export excel ${IDENT} h2 h6 using ///
                        "${sec}/${LNG}_${mod}_`suf'_H6_missing_when_required.xlsx", replace firstrow(varl) nol
                }
                count if !inlist(h2,2,3) & !missing(h6)
                if r(N) {
                    local ++o
                    local suf = string(`o', "%02.0f")
                    export excel ${IDENT} h2 h6 using ///
                        "${sec}/${LNG}_${mod}_`suf'_H6_filled_when_not_applicable.xlsx", replace firstrow(varl) nol
                }
            }
        }

        // H7 travel cost
        if `haveH7' {
            count if (h7 < 0 & h7 != -99) & !missing(h7)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} h7 using ///
                    "${sec}/${LNG}_${mod}_`suf'_H7_negative_cost.xlsx", replace firstrow(varl) nol
            }
            if `haveH2' {
                count if inlist(h2,2,3) & missing(h7)
                if r(N) {
                    local ++o
                    local suf = string(`o', "%02.0f")
                    export excel ${IDENT} h2 h7 using ///
                        "${sec}/${LNG}_${mod}_`suf'_H7_missing_when_required.xlsx", replace firstrow(varl) nol
                }
                count if !inlist(h2,2,3) & !missing(h7)
                if r(N) {
                    local ++o
                    local suf = string(`o', "%02.0f")
                    export excel ${IDENT} h2 h7 using ///
                        "${sec}/${LNG}_${mod}_`suf'_H7_filled_when_not_applicable.xlsx", replace firstrow(varl) nol
                }
            }
        }

        // ==================================================
        // 3) H8 OOP for consultation (category + amount)
        // ==================================================
        if `haveH8' {
            if `haveH2' {
                count if inlist(h2,2,3) & (missing(h8) | !inlist(h8,1,2,3))
                if r(N) {
                    local ++o
                    local suf = string(`o', "%02.0f")
                    export excel ${IDENT} h2 h8 using ///
                        "${sec}/${LNG}_${mod}_`suf'_H8_category_missing_or_bad.xlsx", replace firstrow(varl) nol
                }
                count if !inlist(h2,2,3) & !missing(h8)
                if r(N) {
                    local ++o
                    local suf = string(`o', "%02.0f")
                    export excel ${IDENT} h2 h8 using ///
                        "${sec}/${LNG}_${mod}_`suf'_H8_category_filled_when_not_applicable.xlsx", replace firstrow(varl) nol
                }
            }
            if `haveH8a' {
                count if inlist(h8,1,2) & (missing(h8a) | (h8a < 0 & h8a != -99) | h8a > 1000000)
                if r(N) {
                    local ++o
                    local suf = string(`o', "%02.0f")
                    export excel ${IDENT} h8 h8a using ///
                        "${sec}/${LNG}_${mod}_`suf'_H8_amount_issue.xlsx", replace firstrow(varl) nol
                }
                count if h8==3 & !missing(h8a)
                if r(N) {
                    local ++o
                    local suf = string(`o', "%02.0f")
                    export excel ${IDENT} h8 h8a using ///
                        "${sec}/${LNG}_${mod}_`suf'_H8_amount_filled_when_no.xlsx", replace firstrow(varl) nol
                }
            }
        }

        // ==================================================
        // 4) H9–H11a (meds/diag/other)
        // ==================================================
        local ITEMS "a b c"          // a=meds, b=diag, c=other
        local P9   "h9"              // prescribed
        local P10  "h10"             // obtained
        local P11A "h11a"            // amounts h11aa/ab/ac

        foreach s of local ITEMS {
            // Prescribed (H9?)
            cap confirm var `P9'`s'
            if !_rc & `haveH2' {
                count if inlist(h2,2,3) & (missing(`P9'`s') | !inlist(`P9'`s',1,2))
                if r(N) {
                    local ++o
                    local suf = string(`o', "%02.0f")
                    export excel ${IDENT} h2 `P9'`s' using ///
                        "${sec}/${LNG}_${mod}_`suf'_H9_`s'_bad_or_missing.xlsx", replace firstrow(varl) nol
                }
                count if !inlist(h2,2,3) & !missing(`P9'`s')
                if r(N) {
                    local ++o
                    local suf = string(`o', "%02.0f")
                    export excel ${IDENT} h2 `P9'`s' using ///
                        "${sec}/${LNG}_${mod}_`suf'_H9_`s'_filled_when_not_applicable.xlsx", replace firstrow(varl) nol
                }
            }

            // Obtained (H10?) — required when prescribed==1
            cap confirm var `P10'`s'
            if !_rc {
                count if `P9'`s'==1 & (missing(`P10'`s') | !inlist(`P10'`s',1,2))
                if r(N) {
                    local ++o
                    local suf = string(`o', "%02.0f")
                    export excel ${IDENT} `P9'`s' `P10'`s' using ///
                        "${sec}/${LNG}_${mod}_`suf'_H10_`s'_missing_or_bad.xlsx", replace firstrow(varl) nol
                }
                count if `P9'`s'!=1 & !missing(`P10'`s')
                if r(N) {
                    local ++o
                    local suf = string(`o', "%02.0f")
                    export excel ${IDENT} `P9'`s' `P10'`s' using ///
                        "${sec}/${LNG}_${mod}_`suf'_H10_`s'_filled_when_not_applicable.xlsx", replace firstrow(varl) nol
                }
            }

            // Amounts (H11a?) — required when obtained==1
            local amtvar = "`P11A'`s'"
            cap confirm var `amtvar'
            if !_rc {
                count if `P10'`s'==1 & (missing(`amtvar') | (`amtvar' < 0 & `amtvar' != -99) | `amtvar' > 500000)
                if r(N) {
                    local ++o
                    local suf = string(`o', "%02.0f")
                    export excel ${IDENT} `P10'`s' `amtvar' using ///
                        "${sec}/${LNG}_${mod}_`suf'_H11a_`s'_amount_issue.xlsx", replace firstrow(varl) nol
                }
                count if `P10'`s'!=1 & !missing(`amtvar')
                if r(N) {
                    local ++o
                    local suf = string(`o', "%02.0f")
                    export excel ${IDENT} `P10'`s' `amtvar' using ///
                        "${sec}/${LNG}_${mod}_`suf'_H11a_`s'_amount_when_not_obtained.xlsx", replace firstrow(varl) nol
                }
            }
        }

        // ==================================================
        // 5) Hospitalization (H12–H16)
        // ==================================================
        if `haveH12' {
            count if !inlist(h12,1,2) & !missing(h12)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} h12 using ///
                    "${sec}/${LNG}_${mod}_`suf'_H12_bad_code.xlsx", replace firstrow(varl) nol
            }
        }

        if `haveH12' & `haveH13' {
            count if h12==1 & (missing(h13) | !inlist(h13,1,2,96,99))
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} h12 h13 using ///
                    "${sec}/${LNG}_${mod}_`suf'_H13_missing_or_bad.xlsx", replace firstrow(varl) nol
            }
            count if h12!=1 & !missing(h13)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} h12 h13 using ///
                    "${sec}/${LNG}_${mod}_`suf'_H13_filled_when_not_applicable.xlsx", replace firstrow(varl) nol
            }
        }

        if `haveH12' & `haveH14' {
            count if (h14 < 0 & h14 != -99) & !missing(h14)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} h14 using ///
                    "${sec}/${LNG}_${mod}_`suf'_H14_negative_bill.xlsx", replace firstrow(varl) nol
            }
            count if h12==1 & missing(h14)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} h12 h14 using ///
                    "${sec}/${LNG}_${mod}_`suf'_H14_missing_when_required.xlsx", replace firstrow(varl) nol
            }
            count if h12!=1 & !missing(h14)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} h12 h14 using ///
                    "${sec}/${LNG}_${mod}_`suf'_H14_filled_when_not_applicable.xlsx", replace firstrow(varl) nol
            }
        }

        if `haveH12' & `haveH15' {
            count if h12==1 & missing(h15)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} h12 h15 using ///
                    "${sec}/${LNG}_${mod}_`suf'_H15_missing_when_required.xlsx", replace firstrow(varl) nol
            }
            count if (h15 < 0 & h15 != -99) & !missing(h15)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} h15 using ///
                    "${sec}/${LNG}_${mod}_`suf'_H15_negative_oop.xlsx", replace firstrow(varl) nol
            }
        }

        if `haveH14' & `haveH15' {
            // OOP vs Bill
            count if !inlist(h15,-99,.) & !inlist(h14,-99,.) & (h15 > h14)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} h14 h15 using ///
                    "${sec}/${LNG}_${mod}_`suf'_H15_oop_exceeds_bill.xlsx", replace firstrow(varl) nol
            }
            // Bill>0 ⇒ OOP>=1 (unless -99)
            count if h12==1 & h14>0 & !inlist(h15,-99,.) & h15<1
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} h14 h15 using ///
                    "${sec}/${LNG}_${mod}_`suf'_H15_oop_too_low_given_bill.xlsx", replace firstrow(varl) nol
            }
            // Bill==0 ⇒ OOP in {0,-99}
            count if h12==1 & h14==0 & !inlist(h15,0,-99,.)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} h14 h15 using ///
                    "${sec}/${LNG}_${mod}_`suf'_H15_oop_inconsistent_with_zero_bill.xlsx", replace firstrow(varl) nol
            }
        }

        // H16 payers required if bill>oop and both known
        tempvar __payer16_any
        gen byte `__payer16_any' = .
        if `haveH16D' {
            tempvar __p16_sum
            egen `__p16_sum' = rowtotal(`H16D'), missing
            replace `__payer16_any' = (`__p16_sum' > 0) if !missing(`__p16_sum')
            drop `__p16_sum'
        }
        else if `haveH16TXT' {
            replace `__payer16_any' = (trim(h16mult)!="") if !missing(h16mult)
        }

        if (`haveH14' & `haveH15') & (`haveH16D' | `haveH16TXT') {
            count if h12==1 & !inlist(h14,-99,.) & !inlist(h15,-99,.) & (h14 > h15) & (`__payer16_any' != 1)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} h14 h15 h16mult `H16D' if h12==1 & !inlist(h14,-99,.) & !inlist(h15,-99,.) & (h14 > h15) & (`__payer16_any' != 1) using ///
                    "${sec}/${LNG}_${mod}_`suf'_H16_payer_missing_when_required.xlsx", replace firstrow(varl) nol
            }
        }

        // ==================================================
        // 6) H17 PhilHealth — code validity
        // ==================================================
        if `haveH17' {
            count if !inlist(h17,1,2,3,4,5) & !missing(h17)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} h17 using ///
                    "${sec}/${LNG}_${mod}_`suf'_H17_bad_code.xlsx", replace firstrow(varl) nol
            }
        }

    } // end logic checks

} // end HEALTH module block

	
********************************************************************************
**# (FOOD) — hhid-level logic checks for M08_food using fo1–fo7
********************************************************************************

{
    use "$raw/${dta_file}_${date}_M08_food.dta", clear

    cap drop *_clean
    la lang ${LNG}

    // Optional fix-ups
    do "${wd}/fix/do/M08_food.do"
	
	
	
	// MULTI TO SINGLE 
	
		
	******************************************************
	* fo3: Transport to food source (select_multiple binaries)
	* Create ranked single-choice variables fo3_mode1, fo3_mode2, ...
	******************************************************

	* --- 1) Value label (code = suffix of fo3_# binary) ---
	capture label drop fo3_mode_eng
	label define fo3_mode_eng ///
		1  "By foot" ///
		2  "Used own vehicle (specify)" ///
		3  "Bicycle" ///
		4  "Motorcycle/Tricycle" ///
		5  "Jeepney/Bus" ///
		6  "Car/Taxi" ///
		7  "Boat" ///
		8  "Airplane" ///
		9  "Horse or water buffalo" ///
		15 "Van" ///
		43 "Train" ///
		44 "Truck" ///
		45 "Company service" ///
		49 "Sports Utility Vehicle (SUV)" ///
		50 "Pick Up Truck" ///
		51 "Government service" ///
		52 "Tractor" ///
		96 "Others (specify)" ///
		97 "Work from home" ///
		98 "Refused to answer" ///
		99 "Don't know" ///
		, replace

	* --- 2) Count selections and find max (how many ranked vars to create) ---
	egen fo3_nmodes = rowtotal(fo3_1 fo3_2 fo3_3 fo3_4 fo3_5 fo3_6 fo3_7 fo3_8 fo3_9 fo3_15 fo3_43 fo3_44 fo3_45 fo3_49 fo3_50 fo3_51 fo3_52 fo3_96 fo3_97 fo3_98 fo3_99)
	quietly summarize fo3_nmodes, meanonly
	local max = r(max)

	* --- 3) Peel off selected modes into ranked single-choice variables ---
	local codes 1 2 3 4 5 6 7 8 9 15 43 44 45 49 50 51 52 96 97 98 99

	foreach c of local codes {
		gen byte fo3_rem_`c' = fo3_`c'
	}

	forvalues k = 1/`max' {
		gen fo3_mode`k' = .

		foreach c of local codes {
			replace fo3_mode`k' = `c' if fo3_rem_`c' == 1 & missing(fo3_mode`k')
		}

		foreach c of local codes {
			replace fo3_rem_`c' = 0 if fo3_mode`k' == `c'
		}

		label variable fo3_mode`k' "Transport to food source (rank `k')"
		label values  fo3_mode`k' fo3_mode_eng
	}

	drop fo3_rem_*
		
		
	order fo3_nmodes fo3_mode*, before(fo3_txt)
	
	drop fo3_1 - fo3_99
	
	
	///
	
	

    save "$dta/${dta_file}_${date}_M08_food.dta", replace

    glo mod M08_food
    confirmdir "${fix}/${mod}/"
    if _rc ~= 0 mkdir "${fix}/${mod}"
    glo sec "${wd}/fix/${date}/${mod}"

    export excel using "${fix}/${mod}/${dta_file}_${date}_M08_food.xlsx", ///
        replace firstrow(var) nol


    /// ========================== LOGIC CHECKS ==========================
    {

        /*
          Mapping to new labels:
            fo1  = where buy most food (1..8,96,99)
            fo2  = frequency (1..5,99) — required iff fo1 in {1..8,96}
            fo3  = transport (MULTI) — require ≥1 mode iff fo1 in {1..8,96}
                   (we handle either fo3_* dummies or fo3_txt)
            fo4  = travel time to closest market (mins) — asked of all: >=0 & not missing
            fo5  = usual transport cost to/from market — asked of all: >=0 or -99 & not missing
            fo6  = receive receipt (1/2) — required iff fo1 in {1..8,96}
            fo7  = payment mode (1/2/3/96) — required iff fo1 in {1..8,96}
        */

        // Prefix labels with var name
        foreach v of varlist _all {
            local vl : variable label `v'
            la var `v' "`v': `vl'"
        }

        // IDs on every export
        glo IDENT "hhid_str date fo1 fo2 fo4 fo5 fo6 fo7"

        // Counter
        local o = 0
		
		// DROP txt
		
		drop *_txt

        // ---------- Key uniqueness (hhid) ----------
        capture noisily isid hhid
        if _rc {
            duplicates tag hhid, gen(__dup_hh)
            count if __dup_hh
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} hhid if __dup_hh using ///
                    "${sec}/${LNG}_${mod}_`suf'_dup_hhid.xlsx", replace firstrow(varl) nol
            }
            drop __dup_hh
        }
		
        // ---------- Existence guards ----------
        cap confirm var fo1
        local haveFO1 = !_rc
        cap confirm var fo2
        local haveFO2 = !_rc

        cap unab FO3D : fo3_*
        local haveFO3dum = !_rc
        cap confirm var fo3_txt
        local haveFO3txt = !_rc

        cap confirm var fo4
        local haveFO4 = !_rc
        cap confirm var fo5
        local haveFO5 = !_rc
        cap confirm var fo6
        local haveFO6 = !_rc
        cap confirm var fo7
        local haveFO7 = !_rc

        // Build FO3 varlist for exports
        local FO3LIST ""
        if `haveFO3txt' local FO3LIST "fo3_txt"
        if `haveFO3dum' {
            unab __fo3d : fo3_*
            local FO3LIST "`FO3LIST' `__fo3d'"
        }

        // ==================================================
        // 1) Code validity & routing by fo1
        // ==================================================

        // fo1 bad or missing
        if `haveFO1' {
            count if missing(fo1) | !inlist(fo1,1,2,3,4,5,6,7,8,96,99)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} fo1 using ///
                    "${sec}/${LNG}_${mod}_`suf'_FO1_bad_or_missing.xlsx", replace firstrow(varl) nol
            }
        }

        // fo2 required/blank by fo1
        if `haveFO1' & `haveFO2' {
            // required & valid when fo1 in {1..8,96}
            count if inlist(fo1,1,2,3,4,5,6,7,8,96) & (missing(fo2) | !inlist(fo2,1,2,3,4,5,99))
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} fo1 fo2 using ///
                    "${sec}/${LNG}_${mod}_`suf'_FO2_missing_or_bad_when_required.xlsx", replace firstrow(varl) nol
            }
            // should be blank when fo1==99 or missing
            count if (fo1==99 | missing(fo1)) & !missing(fo2)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} fo1 fo2 using ///
                    "${sec}/${LNG}_${mod}_`suf'_FO2_filled_when_not_applicable.xlsx", replace firstrow(varl) nol
            }
        }

        // fo6 required/blank by fo1
        if `haveFO1' & `haveFO6' {
            count if inlist(fo1,1,2,3,4,5,6,7,8,96) & (missing(fo6) | !inlist(fo6,1,2))
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} fo1 fo6 using ///
                    "${sec}/${LNG}_${mod}_`suf'_FO6_missing_or_bad_when_required.xlsx", replace firstrow(varl) nol
            }
            count if (fo1==99 | missing(fo1)) & !missing(fo6)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} fo1 fo6 using ///
                    "${sec}/${LNG}_${mod}_`suf'_FO6_filled_when_not_applicable.xlsx", replace firstrow(varl) nol
            }
        }

        // fo7 required/blank by fo1
        if `haveFO1' & `haveFO7' {
            count if inlist(fo1,1,2,3,4,5,6,7,8,96) & (missing(fo7) | !inlist(fo7,1,2,3,96))
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} fo1 fo7 using ///
                    "${sec}/${LNG}_${mod}_`suf'_FO7_missing_or_bad_when_required.xlsx", replace firstrow(varl) nol
            }
            count if (fo1==99 | missing(fo1)) & !missing(fo7)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} fo1 fo7 using ///
                    "${sec}/${LNG}_${mod}_`suf'_FO7_filled_when_not_applicable.xlsx", replace firstrow(varl) nol
            }
        }

        // fo3 presence by fo1 (works with fo3_* or fo3_txt)
        if `haveFO1' {
            tempvar __fo3_any
            gen byte `__fo3_any' = .

            if `haveFO3dum' {
                tempvar __fo3_sum
                egen `__fo3_sum' = rowtotal(`FO3D'), missing
                replace `__fo3_any' = (`__fo3_sum' > 0) if !missing(`__fo3_sum')
                drop `__fo3_sum'
            }
            else if `haveFO3txt' {
                replace `__fo3_any' = (trim(fo3_txt)!="") if !missing(fo3_txt)
            }

            // missing when required
            count if inlist(fo1,1,2,3,4,5,6,7,8,96) & (`__fo3_any'!=1)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                if "`FO3LIST'" != "" {
                    export excel ${IDENT} `FO3LIST' if inlist(fo1,1,2,3,4,5,6,7,8,96) & (`__fo3_any'!=1) using ///
                        "${sec}/${LNG}_${mod}_`suf'_FO3_missing_when_required.xlsx", replace firstrow(varl) nol
                }
                else {
                    export excel ${IDENT} if inlist(fo1,1,2,3,4,5,6,7,8,96) & (`__fo3_any'!=1) using ///
                        "${sec}/${LNG}_${mod}_`suf'_FO3_missing_when_required.xlsx", replace firstrow(varl) nol
                }
            }

            // filled when not applicable
            count if (fo1==99 | missing(fo1)) & (`__fo3_any'==1)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                if "`FO3LIST'" != "" {
                    export excel ${IDENT} `FO3LIST' if (fo1==99 | missing(fo1)) & (`__fo3_any'==1) using ///
                        "${sec}/${LNG}_${mod}_`suf'_FO3_filled_when_not_applicable.xlsx", replace firstrow(varl) nol
                }
                else {
                    export excel ${IDENT} if (fo1==99 | missing(fo1)) & (`__fo3_any'==1) using ///
                        "${sec}/${LNG}_${mod}_`suf'_FO3_filled_when_not_applicable.xlsx", replace firstrow(varl) nol
                }
            }
        }

        // ==================================================
        // 2) fo4 travel time (mins): not missing, ≥0
        // ==================================================
        if `haveFO4' {
            count if fo4 < 0 & !missing(fo4)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} fo4 using ///
                    "${sec}/${LNG}_${mod}_`suf'_FO4_negative_time.xlsx", replace firstrow(varl) nol
            }
            count if missing(fo4)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} fo4 using ///
                    "${sec}/${LNG}_${mod}_`suf'_FO4_missing.xlsx", replace firstrow(varl) nol
            }
        }

        // ==================================================
        // 3) fo5 usual transport cost: not missing; ≥0 or -99
        // ==================================================
        if `haveFO5' {
            count if (fo5 < 0 & fo5 != -99) & !missing(fo5)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} fo5 using ///
                    "${sec}/${LNG}_${mod}_`suf'_FO5_negative_cost.xlsx", replace firstrow(varl) nol
            }
            count if missing(fo5)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} fo5 using ///
                    "${sec}/${LNG}_${mod}_`suf'_FO5_missing.xlsx", replace firstrow(varl) nol
            }
        }

    } // end logic checks

} // end FOOD block


********************************************************************************
**# (NF) NON-FOOD — hhid-level logic checks for M08_nf using nf1/nf2/nf3
********************************************************************************

{
    use "$raw/${dta_file}_${date}_M08_nf.dta", clear

    cap drop *_clean
    la lang ${LNG}
	

    // Optional fix-ups
    do "${wd}/fix/do/M08_nf.do"
	
	
	
	
	/// MULTIPLE TO SINGLE 
	
	
	******************************************************
	* nf1: Non-food source (select_multiple binaries)
	* Create ranked single-choice variables nf1_src1, nf1_src2, ...
	******************************************************

	* --- 1) Value label (code = suffix of nf1_# binary) ---
	capture label drop nf1_source_eng
	label define nf1_source_eng ///
		1  "Market" ///
		2  "Large supermarket/Hypermarket" ///
		3  "Supermarket/Grocery" ///
		4  "Convenience store" ///
		5  "Sari-sari store" ///
		6  "Ambulant peddlers" ///
		7  "Open stalls in shopping centers, malls, and markets" ///
		8  "Department stores" ///
		9  "Appliance centers" ///
		10 "Online platforms" ///
		12 "Ukay-ukay" ///
		16 "From family members" ///
		17 "Warehouse / wholesale stores" ///
		18 "From relief assistance" ///
		96 "Others" ///
		99 "None" ///
		, replace

	* --- 2) Count selections and find max (how many ranked vars to create) ---
	egen nf1_nsrc = rowtotal(nf1_1 nf1_2 nf1_3 nf1_4 nf1_5 nf1_6 nf1_7 nf1_8 nf1_9 nf1_10 nf1_12 nf1_16 nf1_17 nf1_18 nf1_96 nf1_99)
	quietly summarize nf1_nsrc, meanonly
	local max = r(max)

	* --- 3) Peel off selected sources into ranked single-choice variables ---
	local codes 1 2 3 4 5 6 7 8 9 10 12 16 17 18 96 99

	foreach c of local codes {
		gen byte nf1_rem_`c' = nf1_`c'
	}

	forvalues k = 1/`max' {
		gen nf1_src`k' = .

		foreach c of local codes {
			replace nf1_src`k' = `c' if nf1_rem_`c' == 1 & missing(nf1_src`k')
		}

		foreach c of local codes {
			replace nf1_rem_`c' = 0 if nf1_src`k' == `c'
		}

		label variable nf1_src`k' "Non-food source (rank `k')"
		label values  nf1_src`k' nf1_source_eng
	}

	drop nf1_rem_*
		
	order nf1_nsrc nf1_src*, before(nf1_txt) 	
	
	
	/// NF2 
	
	
	******************************************************
	* NF2: Receipt received (Yes/No), aligned to NF1 sources
	******************************************************

	* --- 1) Preserve original item-level receipt variables ---
	rename nf2_1  nf2_item1
	rename nf2_2  nf2_item2
	rename nf2_3  nf2_item3
	rename nf2_4  nf2_item4
	rename nf2_5  nf2_item5
	rename nf2_6  nf2_item6
	rename nf2_7  nf2_item7
	rename nf2_8  nf2_item8
	rename nf2_9  nf2_item9
	rename nf2_10 nf2_item10
	rename nf2_96 nf2_item96


	* --- 2) Yes / No value label ---
	capture label drop yesno_eng
	label define yesno_eng ///
		1 "Yes" ///
		2 "No"


	* --- 3) Create ranked receipt variables nf2_1 nf2_2 ... ---
	*     (aligned with nf1_src1 nf1_src2 ...)

	ds nf1_src*
	local nsrc : word count `r(varlist)'

	forvalues k = 1/`nsrc' {
		gen nf2_`k' = .

		replace nf2_`k' = nf2_item1  if nf1_src`k' == 1
		replace nf2_`k' = nf2_item2  if nf1_src`k' == 2
		replace nf2_`k' = nf2_item3  if nf1_src`k' == 3
		replace nf2_`k' = nf2_item4  if nf1_src`k' == 4
		replace nf2_`k' = nf2_item5  if nf1_src`k' == 5
		replace nf2_`k' = nf2_item6  if nf1_src`k' == 6
		replace nf2_`k' = nf2_item7  if nf1_src`k' == 7
		replace nf2_`k' = nf2_item8  if nf1_src`k' == 8
		replace nf2_`k' = nf2_item9  if nf1_src`k' == 9
		replace nf2_`k' = nf2_item10 if nf1_src`k' == 10

		* treat 12 / 16 / 17 / 18 as Others (96)
		replace nf2_`k' = nf2_item96 if inlist(nf1_src`k', 12, 16, 17, 18, 96)

		label variable nf2_`k' "Receipt received for non-food source (rank `k')"
		label values  nf2_`k' yesno_eng
	}

			
	order nf2_1-nf2_8, after(nf1_txt)
	
	
	
	/// NF3 
	
	
	******************************************************
	* NF3: Usual mode of payment, aligned to NF1 sources
	******************************************************

	* --- 1) Preserve original item-level NF3 variables ---
	rename nf3_1   nf3_item1
	rename nf3_2   nf3_item2
	rename nf3_3   nf3_item3
	rename nf3_4   nf3_item4
	rename nf3_5   nf3_item5
	rename nf3_6   nf3_item6
	rename nf3_7   nf3_item7
	rename nf3_8   nf3_item8
	rename nf3_9   nf3_item9
	rename nf3_10  nf3_item10
	rename nf3_96  nf3_item96


	* --- 2) Create ranked payment-mode variables nf3_1 nf3_2 ... ---
	*     (aligned with nf1_src1 nf1_src2 ...)

	ds nf1_src*
	local nsrc : word count `r(varlist)'

	forvalues k = 1/`nsrc' {
		gen nf3_`k' = .

		replace nf3_`k' = nf3_item1   if nf1_src`k' == 1
		replace nf3_`k' = nf3_item2   if nf1_src`k' == 2
		replace nf3_`k' = nf3_item3   if nf1_src`k' == 3
		replace nf3_`k' = nf3_item4   if nf1_src`k' == 4
		replace nf3_`k' = nf3_item5   if nf1_src`k' == 5
		replace nf3_`k' = nf3_item6   if nf1_src`k' == 6
		replace nf3_`k' = nf3_item7   if nf1_src`k' == 7
		replace nf3_`k' = nf3_item8   if nf1_src`k' == 8
		replace nf3_`k' = nf3_item9   if nf1_src`k' == 9
		replace nf3_`k' = nf3_item10  if nf1_src`k' == 10

		* treat 12 / 16 / 17 / 18 as Others (96)
		replace nf3_`k' = nf3_item96 if inlist(nf1_src`k', 12, 16, 17, 18, 96)

		label variable nf3_`k' ///
			"Usual mode of payment for non-food source (rank `k')"

		label values nf3_`k' NF_PAY
	}
		
	
	
	
	
	/// DROP 
	
	
	drop nf1_1 - nf1_99
	drop nf2_item1 - nf3_item96
	
	order nf3_*, after(nf2_8)
	
	

    save "$dta/${dta_file}_${date}_M08_nf.dta", replace

    glo mod M08_nf
    confirmdir "${fix}/${mod}/"
    if _rc ~= 0 mkdir "${fix}/${mod}"
    glo sec "${wd}/fix/${date}/${mod}"

    export excel using "${fix}/${mod}/${dta_file}_${date}_M08_nf.xlsx", ///
        replace firstrow(var) nol


    /// ========================== LOGIC CHECKS ==========================
    {

        /*
          Mapping to new labels:
            nf1  = sources (MULTI via nf1_txt + nf1_* dummies)
            nf2_*= receipt by source (1=Yes, 2=No)
            nf3_*= payment by source (1=Cash, 2=Card, 3=Digital, 96=Other)

          Rules:
            NF1: require ≥1 source selected.
            NF2: if source selected → nf2_* must be 1/2; if not selected → nf2_* should be blank.
            NF3: if source selected → nf3_* must be in {1,2,3,96}; if not selected → nf3_* should be blank.
        */

        // Prefix labels with var name for clear Excel headers
        foreach v of varlist _all {
            local vl : variable label `v'
            la var `v' "`v': `vl'"
        }

        // IDs on every export (hhid-level)
        glo IDENT "hhid_str date"

        // File counter
        local o = 0
		
		// DROP txt
		
		drop *_txt

        // ---------- Key uniqueness (hhid) ----------
        capture noisily isid hhid
        if _rc {
            duplicates tag hhid, gen(__dup_hh)
            count if __dup_hh
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} hhid if __dup_hh using ///
                    "${sec}/${LNG}_${mod}_`suf'_dup_hhid.xlsx", replace firstrow(varl) nol
            }
            cap drop __dup_hh
        }

        // ---------- Existence guards ----------
        cap confirm var nf1_txt
        local haveNF1txt = !_rc
        cap unab NF1D : nf1_*
        local haveNF1dum = !_rc

        cap unab NF2D : nf2_*
        local haveNF2 = !_rc
        cap unab NF3D : nf3_*
        local haveNF3 = !_rc

        // Lists for export context
        local NF1LIST ""
        if `haveNF1txt' local NF1LIST "`NF1LIST' nf1_txt"
        if `haveNF1dum' {
            unab __nf1d : nf1_*
            local NF1LIST "`NF1LIST' `__nf1d'"
        }
        local NF2LIST ""
        if `haveNF2' {
            unab __nf2d : nf2_*
            local NF2LIST "`__nf2d'"
        }
        local NF3LIST ""
        if `haveNF3' {
            unab __nf3d : nf3_*
            local NF3LIST "`__nf3d'"
        }

        // ==================================================
        // NF1: require at least one source selected
        // ==================================================
        tempvar __nf1_any
        gen byte `__nf1_any' = .

        if `haveNF1dum' {
            tempvar __nf1_sum
            egen `__nf1_sum' = rowtotal(nf1_*), missing
            replace `__nf1_any' = (`__nf1_sum' > 0) if !missing(`__nf1_sum')
            drop `__nf1_sum'
        }
        else if `haveNF1txt' {
            replace `__nf1_any' = (trim(nf1_txt)!="") if !missing(nf1_txt)
        }
        else replace `__nf1_any' = 0

        count if `__nf1_any'!=1
        if r(N) {
            local ++o
            local suf = string(`o', "%02.0f")
            if "`NF1LIST'" != "" {
                export excel ${IDENT} `NF1LIST' using ///
                    "${sec}/${LNG}_${mod}_`suf'_NF1_none_selected.xlsx", replace firstrow(varl) nol
            }
            else {
                export excel ${IDENT} using ///
                    "${sec}/${LNG}_${mod}_`suf'_NF1_none_selected.xlsx", replace firstrow(varl) nol
            }
        }

        // ==================================================
        // NF2: receipt validity & gating by selection
        // ==================================================
        if `haveNF1dum' & `haveNF2' {
            tempvar __rc_bad
            gen byte `__rc_bad' = 0

            // Iterate through nf1_* dummies; check matching nf2_* if it exists
            local NF1vars "`__nf1d'"
            foreach v of local NF1vars {
                local sfx = subinstr("`v'","nf1_","",.)
                cap confirm var nf2_`sfx'
                if !_rc {
                    replace `__rc_bad' = 1 if ( ///
                        (nf1_`sfx'==1 & (missing(nf2_`sfx') | !inlist(nf2_`sfx',1,2))) | ///
                        (nf1_`sfx'!=1 & !missing(nf2_`sfx')) )
                }
            }

            count if `__rc_bad'==1
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} `NF1LIST' `NF2LIST' using ///
                    "${sec}/${LNG}_${mod}_`suf'_NF2_receipt_gating_or_badcode.xlsx", replace firstrow(varl) nol
            }
        }

        // ==================================================
        // NF3: payment validity & gating by selection
        // ==================================================
        if `haveNF1dum' & `haveNF3' {
            tempvar __pay_bad
            gen byte `__pay_bad' = 0

            local NF1vars "`__nf1d'"
            foreach v of local NF1vars {
                local sfx = subinstr("`v'","nf1_","",.)
                cap confirm var nf3_`sfx'
                if !_rc {
                    replace `__pay_bad' = 1 if ( ///
                        (nf1_`sfx'==1 & (missing(nf3_`sfx') | !inlist(nf3_`sfx',1,2,3,96))) | ///
                        (nf1_`sfx'!=1 & !missing(nf3_`sfx')) )
                }
            }

            count if `__pay_bad'==1
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} `NF1LIST' `NF3LIST' using ///
                    "${sec}/${LNG}_${mod}_`suf'_NF3_payment_gating_or_badcode.xlsx", replace firstrow(varl) nol
            }
        }

    } // end logic checks

} // end NON-FOOD block

	
********************************************************************************
**# (SSB) SWEETENED SUGARY BEVERAGES — person-level (uses roster)
**# Uses NEW labels (ssb1/ssb2/ssb3) and M08_ssb paths
********************************************************************************

{
    use "$raw/${dta_file}_${date}_M08_ssb.dta", clear

    // Merge roster info (age, gender) for simple age filters if needed
    merge 1:1 hhid fmid using "$raw/${dta_file}_${date}_M01_roster.dta", ///
        assert(2 3) keep(3) keepusing(age gender) nogen
    order age gender, a(fmid)

    la lang ${LNG}

    // corrections (optional)
    do "${wd}/fix/do/M08_ssb.do"

    save "$dta/${dta_file}_${date}_M08_ssb.dta", replace

    glo mod M08_ssb
	
    confirmdir "${fix}/${mod}/"
    if _rc ~= 0 mkdir "${fix}/${mod}"
    glo sec "${wd}/fix/${date}/${mod}"

    export excel using "${fix}/${mod}/${dta_file}_${date}_M08_ssb.xlsx", ///
        replace firstrow(var) nol


    /// ============================ LOGIC CHECKS ============================
    {

        /*
          Variables (NEW labels):
            ssb1 = HH-level incidence (1 Yes, 2 No)
            ssb2 = member-level incidence (1 Yes, 2 No)
            ssb3 = member-level weekly total (count; integer >=0)

          Checks:
            1) Key uniqueness (hhid fmid).
            2) Code validity for ssb1/ssb2 ∈ {1,2}; ssb3 ≥0; flag non-integers.
            3) HH gating (ssb1 vs ssb2): Yes→≥1 member yes; No→no member yes.
            4) Member gating (ssb2 vs ssb3): No with positive total; Yes with zero/missing total.
            5) HH says No but any member has positive ssb3.
        */

        // Prefix labels with var name for clearer Excel headers
        foreach v of varlist _all {
            local vl: variable label `v'
            la var `v' "`v': `vl'"
        }

        // IDs included in each export
        glo IDENT "hhid_str fmid age gender ssb1 ssb2 ssb3"

        // Counter
        local o = 0

        // ---------- Keys (long data) ----------
        capture noisily isid hhid fmid
        if _rc {
            duplicates tag hhid fmid, gen(__dup_hhf)
            count if __dup_hhf
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} hhid fmid if __dup_hhf using ///
                    "${sec}/${LNG}_${mod}_`suf'_dup_hhid_fmid.xlsx", replace firstrow(varl) nol
            }
            drop __dup_hhf
        }

        // ---------- Existence guards ----------
        cap confirm var ssb1
        local haveS1 = !_rc
        cap confirm var ssb2
        local haveS2 = !_rc
        cap confirm var ssb3
        local haveS3 = !_rc

        // ==================================================
        // 2) Coding validity
        // ==================================================
        if `haveS1' {
            count if !inlist(ssb1,1,2) & !missing(ssb1)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} ssb1 if !inlist(ssb1,1,2) & !missing(ssb1) using ///
                    "${sec}/${LNG}_${mod}_`suf'_badcode_ssb1.xlsx", replace firstrow(varl) nol
            }
        }

        if `haveS2' {
            count if !inlist(ssb2,1,2) & !missing(ssb2)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} ssb2 if !inlist(ssb2,1,2) & !missing(ssb2) using ///
                    "${sec}/${LNG}_${mod}_`suf'_badcode_ssb2.xlsx", replace firstrow(varl) nol
            }
        }

        if `haveS3' {
            // (a) Negative values
            count if ssb3<0 & !missing(ssb3)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} ssb3 if ssb3<0 & !missing(ssb3) using ///
                    "${sec}/${LNG}_${mod}_`suf'_ssb3_negative.xlsx", replace firstrow(varl) nol
            }

            // (b) Non-integers (optional)
            tempvar __frac
            gen byte `__frac' = (ssb3!=floor(ssb3)) if !missing(ssb3)
            count if `__frac'==1
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} ssb3 if `__frac'==1 using ///
                    "${sec}/${LNG}_${mod}_`suf'_ssb3_noninteger.xlsx", replace firstrow(varl) nol
            }
            drop `__frac'
        }

        // ==================================================
        // 3) HH gating: SSB1 (HH) vs SSB2 (members)
        // ==================================================
        // Choose HH key
        local hhkey ""
        cap confirm var hhid
        if !_rc local hhkey "hhid"
        else {
            cap confirm var hhsn
            if !_rc local hhkey "hhsn"
        }

        if "`hhkey'"!="" & `haveS1' & `haveS2' {
            // HH-level aggregates
            bysort `hhkey': egen byte __hh_any_yes = max(ssb2==1)

            // (a) HH says Yes but no member marked Yes
            preserve
                by `hhkey': keep if _n==1
                keep if ssb1==1 & __hh_any_yes==0
                if _N {
                    local ++o
                    local suf = string(`o', "%02.0f")
                    export excel `hhkey' ssb1 using ///
                        "${sec}/${LNG}_${mod}_`suf'_ssb1_yes_no_member_yes.xlsx", replace firstrow(var) nol
                }
            restore

            // (b) HH says No but some member marked Yes
            preserve
                by `hhkey': keep if _n==1
                keep if ssb1==2 & __hh_any_yes==1
                if _N {
                    local ++o
                    local suf = string(`o', "%02.0f")
                    export excel `hhkey' ssb1 using ///
                        "${sec}/${LNG}_${mod}_`suf'_ssb1_no_but_member_yes.xlsx", replace firstrow(var) nol
                }
            restore

            drop __hh_any_yes
        }

        // ==================================================
        // 4) Member-level gating with SSB3
        // ==================================================
        if `haveS2' & `haveS3' {
            // (a) Says "No" but has positive total
            count if ssb2==2 & ssb3>0 & !missing(ssb3)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} if ssb2==2 & ssb3>0 using ///
                    "${sec}/${LNG}_${mod}_`suf'_no_but_positive_total.xlsx", replace firstrow(varl) nol
            }

            // (b) Says "Yes" but total is missing or zero  (soft)
            count if ssb2==1 & (missing(ssb3) | ssb3==0)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} if ssb2==1 & (missing(ssb3) | ssb3==0) using ///
                    "${sec}/${LNG}_${mod}_`suf'_yes_but_zero_or_missing.xlsx", replace firstrow(varl) nol
            }
        }

        // ==================================================
        // 5) HH says "No" (ssb1==2) but members have positive totals
        // ==================================================
        if `haveS1' & `haveS3' & "`hhkey'"!="" {
            bysort `hhkey': egen byte __hh_pos_total = max(ssb3>0) if !missing(ssb3)
            preserve
                by `hhkey': keep if _n==1
                keep if ssb1==2 & __hh_pos_total==1
                if _N {
                    local ++o
                    local suf = string(`o', "%02.0f")
                    export excel `hhkey' ssb1 using ///
                        "${sec}/${LNG}_${mod}_`suf'_ssb1_no_but_positive_totals.xlsx", replace firstrow(var) nol
                }
            restore
            drop __hh_pos_total
        }

    } // end logic checks

} // end SSB module block


********************************************************************************
**# (NH) NATURAL HAZARDS — household-level, LONG by hazard (uses cleaned file)
**# Fixed: robust "any-selected" tests using explicit dummy lists (no wildcards),
**#        avoid picking up *_txt strings; use rowmax + coalesce to 0.
********************************************************************************

{
    use "$raw/${dta_file}_${date}_M09_nh.dta", clear
    la lang ${LNG}

    // Optional corrections
    do "${wd}/fix/do/M09.do"
	
	
	/// MULTIPLE TO SINGLE 
	
	
	******************************************************
	* nh3: Impacts experienced (select_multiple binaries)
	* Create ranked single-choice variables nh3_imp1, nh3_imp2, ...
	******************************************************

	* --- 1) Value label (code = suffix of nh3_# binary) ---
	capture label drop nh3_impact_eng
	label define nh3_impact_eng ///
		1  "Travel disruptions / time" ///
		2  "Children's school closure / interruption" ///
		3  "Damage to house" ///
		4  "Damage to other personal property" ///
		5  "Job disruption / reduced income earnings" ///
		6  "Health of a family member" ///
		7  "Death" ///
		8  "Disruption of basic utilities" ///
		11 "Damage to public property" ///
		26 "Price inflation" ///
		58 "Negative agricultural impact" ///
		66 "Negative emotional / mental impact" ///
		69 "Negative environmental impact" ///
		71 "Panic buying" ///
		79 "Lack of / no source of food" ///
		95 "None" ///
		96 "Others" ///
		, replace

	* --- 2) Count selections and find max (how many ranked vars to create) ---
	egen nh3_nimp = rowtotal( ///
		nh3_1 nh3_2 nh3_3 nh3_4 nh3_5 nh3_6 nh3_7 nh3_8 ///
		nh3_11 nh3_26 nh3_58 nh3_66 nh3_69 nh3_71 nh3_79 nh3_95 nh3_96 ///
	)
	quietly summarize nh3_nimp, meanonly
	local max = r(max)

	* --- 3) Peel off selected impacts into ranked single-choice variables ---
	* Put 95 (None) last so it doesn't override real impacts
	local codes 1 2 3 4 5 6 7 8 11 26 58 66 69 71 79 96 95

	foreach c of local codes {
		gen byte nh3_rem_`c' = nh3_`c'
	}

	forvalues k = 1/`max' {
		gen nh3_imp`k' = .

		foreach c of local codes {
			replace nh3_imp`k' = `c' if nh3_rem_`c' == 1 & missing(nh3_imp`k')
		}

		foreach c of local codes {
			replace nh3_rem_`c' = 0 if nh3_imp`k' == `c'
		}

		label variable nh3_imp`k' "Impact experienced (rank `k')"
		label values  nh3_imp`k' nh3_impact_eng
	}

	drop nh3_rem_*
		
	
	order nh3_nimp nh3_imp*, before(nh3_txt) 
	
	
	/// NH4 
	
	
	******************************************************
	* nh4: Assistance sources (select_multiple binaries)
	* Create ranked single-choice variables nh4_src1, nh4_src2, ...
	******************************************************

	* --- 1) Value label (code = suffix of nh4_# binary) ---
	capture label drop nh4_source_eng
	label define nh4_source_eng ///
		1  "Family member (would otherwise be part of household)" ///
		2  "Other relatives or friends" ///
		3  "Local government" ///
		4  "National government" ///
		5  "Government (unknown level)" ///
		6  "Private institutions (Churches / NGOs)" ///
		11 "Neighbors" ///
		96 "Others" ///
		99 "Did not receive assistance" ///
		, replace

	* --- 2) Count selections and find max (how many ranked vars to create) ---
	egen nh4_nsrc = rowtotal( ///
		nh4_1 nh4_2 nh4_3 nh4_4 nh4_5 nh4_6 nh4_11 nh4_96 nh4_99 ///
	)
	quietly summarize nh4_nsrc, meanonly
	local max = r(max)

	* --- 3) Peel off selected sources into ranked single-choice variables ---
	* Put 99 (Did not receive assistance) last
	local codes 1 2 3 4 5 6 11 96 99

	foreach c of local codes {
		gen byte nh4_rem_`c' = nh4_`c'
	}

	forvalues k = 1/`max' {
		gen nh4_src`k' = .

		foreach c of local codes {
			replace nh4_src`k' = `c' if nh4_rem_`c' == 1 & missing(nh4_src`k')
		}

		foreach c of local codes {
			replace nh4_rem_`c' = 0 if nh4_src`k' == `c'
		}

		label variable nh4_src`k' "Assistance source (rank `k')"
		label values  nh4_src`k' nh4_source_eng
	}

	drop nh4_rem_*
		
	order nh4_nsrc nh4_src*, after(nh4)	
		
		
		
	******************************************************
	* NH5: Assistance types by source (nh5_1_ ... nh5_7_)
	* Same assistance-type options for each source.
	* Creates ranked single-choice variables nh5_s#_typ1, nh5_s#_typ2, ...
	* where # = source number (1..7).
	******************************************************

	* --- A) Assistance type value label (shared across all sources) ---
	capture label drop nh5_type_eng
	label define nh5_type_eng ///
		1  "Food packs" ///
		2  "Cash" ///
		3  "Relief goods" ///
		4  "Fertilizer" ///
		5  "Insecticide" ///
		6  "Clothing" ///
		7  "Kitchen utensils" ///
		8  "Health and sanitation supplies" ///
		9  "Seedlings / seeds" ///
		10 "Road clearing" ///
		, replace

	* (optional) Source labels (for your reference / documentation)
	capture label drop nh5_source_eng
	label define nh5_source_eng ///
		1 "Family member (would otherwise be part of HH)" ///
		2 "Other relatives or friends" ///
		3 "Local government" ///
		4 "National government" ///
		5 "Gov't (unknown level)" ///
		6 "Private institutions (Churches/NGOs)" ///
		7 "Neighbors" ///
		8 "No did not receive assistance" ///
		96 "Others" ///
		, replace

	* --- B) Loop over sources 1..7 and create ranked type variables ---
	forvalues s = 1/7 {

		* count selections for this source (exclude nh5_`s'_txt automatically)
		egen nh5_`s'_ntype = rowtotal( ///
			nh5_`s'_1 nh5_`s'_2 nh5_`s'_3 nh5_`s'_4 nh5_`s'_5 ///
			nh5_`s'_6 nh5_`s'_7 nh5_`s'_8 nh5_`s'_9 nh5_`s'_10 ///
		)
		quietly summarize nh5_`s'_ntype, meanonly
		local max = r(max)

		* remaining flags
		forvalues c = 1/10 {
			gen byte nh5_`s'_rem_`c' = nh5_`s'_`c'
		}

		* ranked single-choice variables for this source
		forvalues k = 1/`max' {
			gen nh5_s`s'_typ`k' = .

			forvalues c = 1/10 {
				replace nh5_s`s'_typ`k' = `c' if nh5_`s'_rem_`c' == 1 & missing(nh5_s`s'_typ`k')
			}

			forvalues c = 1/10 {
				replace nh5_`s'_rem_`c' = 0 if nh5_s`s'_typ`k' == `c'
			}

			label variable nh5_s`s'_typ`k' "Assistance type (source `s') (rank `k')"
			label values  nh5_s`s'_typ`k' nh5_type_eng
		}

		drop nh5_`s'_rem_*
	}
		
	
	order nh5_1_ntype - nh5_7_ntype, after(nh4_txt)
	
	
	///	NH7 
	

	******************************************************
	* nh7: Warning channels (select_multiple binaries)
	* Create ranked single-choice variables nh7_ch1, nh7_ch2, ...
	******************************************************

	* --- 1) Value label (code = suffix of nh7_# binary) ---
	capture label drop nh7_channel_eng
	label define nh7_channel_eng ///
		1  "TV" ///
		2  "Radio" ///
		3  "In-person: LGU/barangay" ///
		4  "SMS" ///
		5  "Website" ///
		6  "Cell broadcast / emergency alert" ///
		7  "Sirens / loudspeakers" ///
		8  "Social media" ///
		9  "Newspapers / printed" ///
		21 "Word of mouth (friends/relatives)" ///
		23 "Weather forecast services" ///
		96 "Other (specify)" ///
		, replace

	* --- 2) Count selections and find max (how many ranked vars to create) ---
	egen nh7_nch = rowtotal( ///
		nh7_1 nh7_2 nh7_3 nh7_4 nh7_5 nh7_6 nh7_7 nh7_8 nh7_9 ///
		nh7_21 nh7_23 nh7_96 ///
	)
	quietly summarize nh7_nch, meanonly
	local max = r(max)

	* --- 3) Peel off selected channels into ranked single-choice variables ---
	local codes 1 2 3 4 5 6 7 8 9 21 23 96

	foreach c of local codes {
		gen byte nh7_rem_`c' = nh7_`c'
	}

	forvalues k = 1/`max' {
		gen nh7_ch`k' = .

		foreach c of local codes {
			replace nh7_ch`k' = `c' if nh7_rem_`c' == 1 & missing(nh7_ch`k')
		}

		foreach c of local codes {
			replace nh7_rem_`c' = 0 if nh7_ch`k' == `c'
		}

		label variable nh7_ch`k' "Warning channel (rank `k')"
		label values  nh7_ch`k' nh7_channel_eng
	}

	drop nh7_rem_*
	
	order nh7_nch nh7_ch*, before(nh7_txt)
	
	

	/// NH10 
	
	
	******************************************************
	* nh10: Actions taken (select_multiple binaries)
	* Create ranked single-choice variables nh10_act1, nh10_act2, ...
	******************************************************

	* --- 1) Value label (code = suffix of nh10_# binary) ---
	capture label drop nh10_action_eng
	label define nh10_action_eng ///
		1  "Evacuated to a safe place" ///
		2  "Reinforced the structure of the house" ///
		3  "Avoiding risky activities (e.g., avoiding travel to hazardous areas)" ///
		4  "Stocked up on food" ///
		5  "Sheltering in place (staying indoors or moving to a safe part of the house)" ///
		6  "Secured property and assets (moved valuables, etc.)" ///
		7  "Stockpiling and preparing supplies" ///
		8  "Assisting others (communicating with family/community, etc.)" ///
		11 "Stored enough water" ///
		12 "Drinking plenty of water" ///
		13 "Prepared medicines" ///
		14 "Rarely goes outside" ///
		15 "Bought insect repellent spray" ///
		16 "Sprayed pesticide to protect crops" ///
		17 "Regularly cleans pigpen" ///
		18 "Goes under the table" ///
		20 "Gives vitamins" ///
		21 "Avoids feeding meat to prevent infection" ///
		22 "Took shelter under a tree" ///
		23 "Be cautious" ///
		24 "Preparing a first aid kit" ///
		25 "Praying" ///
		26 "Bathing" ///
		27 "Going to a cold place" ///
		28 "Avoid visiting sick animals" ///
		29 "Be careful not to catch illness" ///
		30 "Open the windows" ///
		31 "Kept animals away from crowd" ///
		32 "Postponed planting" ///
		33 "Cleaned the chicken coop" ///
		35 "Sprayed medicine on crops" ///
		39 "Vaccination of pets/livestock" ///
		40 "Bring an umbrella" ///
		43 "Conserve water" ///
		44 "Got infected for protection" ///
		45 "Charged cellphones" ///
		49 "Put a mosquito net over the pig" ///
		51 "Kept watch" ///
		54 "Dug water pathways" ///
		56 "Tied down the roof" ///
		57 "Disinfected" ///
		58 "Went to the barangay hall" ///
		60 "Buried dead livestock" ///
		61 "Giving medicine to livestock" ///
		62 "Removed obstructing tree branches" ///
		63 "Temporarily stopped raising animals" ///
		64 "Planted early to avoid El Niño" ///
		65 "Pigs were confiscated by the Department of Agriculture" ///
		96 "Others" ///
		99 "Did not do anything" ///
		, replace

	* --- 2) Count selections and find max (how many ranked vars to create) ---
	egen nh10_nact = rowtotal( ///
		nh10_1 nh10_2 nh10_3 nh10_4 nh10_5 nh10_6 nh10_7 nh10_8 ///
		nh10_11 nh10_12 nh10_13 nh10_14 nh10_15 nh10_16 nh10_17 nh10_18 ///
		nh10_20 nh10_21 nh10_22 nh10_23 nh10_24 nh10_25 nh10_26 nh10_27 ///
		nh10_28 nh10_29 nh10_30 nh10_31 nh10_32 nh10_33 nh10_35 nh10_39 ///
		nh10_40 nh10_43 nh10_44 nh10_45 nh10_49 nh10_51 nh10_54 nh10_56 ///
		nh10_57 nh10_58 nh10_60 nh10_61 nh10_62 nh10_63 nh10_64 nh10_65 ///
		nh10_96 nh10_99 ///
	)
	quietly summarize nh10_nact, meanonly
	local max = r(max)

	* --- 3) Peel off selected actions into ranked single-choice variables ---
	* Put 99 (Did not do anything) last so it doesn't override real actions
	local codes 1 2 3 4 5 6 7 8 11 12 13 14 15 16 17 18 20 21 22 23 24 25 26 27 28 29 30 31 32 33 35 39 40 43 44 45 49 51 54 56 57 58 60 61 62 63 64 65 96 99

	foreach c of local codes {
		gen byte nh10_rem_`c' = nh10_`c'
	}

	forvalues k = 1/`max' {
		gen nh10_act`k' = .

		foreach c of local codes {
			replace nh10_act`k' = `c' if nh10_rem_`c' == 1 & missing(nh10_act`k')
		}

		foreach c of local codes {
			replace nh10_rem_`c' = 0 if nh10_act`k' == `c'
		}

		label variable nh10_act`k' "Action taken (rank `k')"
		label values  nh10_act`k' nh10_action_eng
	}

	drop nh10_rem_*
		
	
	order nh10_nact nh10_act*, before(nh10_txt)
	
	
	
	
	
	/// NH13 
	
		
	******************************************************
	* nh13: Source of hazard map awareness (select_multiple binaries)
	* Create ranked single-choice variables nh13_src1, nh13_src2, ...
	******************************************************

	* --- 1) Value label (code = suffix of nh13_# binary) ---
	capture label drop nh13_source_eng
	label define nh13_source_eng ///
		1  "National officials" ///
		2  "Local officials" ///
		3  "Family & friends" ///
		4  "School" ///
		5  "PHIVOLCS" ///
		6  "UP NOAH" ///
		8  "Facebook" ///
		9  "TikTok" ///
		10 "YouTube" ///
		11 "Barangay hall" ///
		12 "Red Cross" ///
		13 "PAG-ASA" ///
		14 "Company" ///
		15 "MDRRMC (Municipal Disaster Risk Reduction and Management Council)" ///
		16 "TV" ///
		17 "Google" ///
		18 "Radio" ///
		19 "Zoom Earth" ///
		20 "Roadside signage" ///
		21 "Municipal office" ///
		96 "Others" ///
		, replace

	* --- 2) Count selections and find max (how many ranked vars to create) ---
	egen nh13_nsrc = rowtotal( ///
		nh13_1 nh13_2 nh13_3 nh13_4 nh13_5 nh13_6 ///
		nh13_8 nh13_9 nh13_10 nh13_11 nh13_12 nh13_13 ///
		nh13_14 nh13_15 nh13_16 nh13_17 nh13_18 nh13_19 ///
		nh13_20 nh13_21 nh13_96 ///
	)
	quietly summarize nh13_nsrc, meanonly
	local max = r(max)

	* --- 3) Peel off selected sources into ranked single-choice variables ---
	local codes 1 2 3 4 5 6 8 9 10 11 12 13 14 15 16 17 18 19 20 21 96

	foreach c of local codes {
		gen byte nh13_rem_`c' = nh13_`c'
	}

	forvalues k = 1/`max' {
		gen nh13_src`k' = .

		foreach c of local codes {
			replace nh13_src`k' = `c' if nh13_rem_`c' == 1 & missing(nh13_src`k')
		}

		foreach c of local codes {
			replace nh13_rem_`c' = 0 if nh13_src`k' == `c'
		}

		label variable nh13_src`k' "Source of hazard map awareness (rank `k')"
		label values  nh13_src`k' nh13_source_eng
	}

	drop  nh13_rem_*
		
	
	order nh13_nsrc nh13_src*, before(nh13_txt) 
	
	
	
	
	/// DROP ALL MULTIPLES 
	
	
	drop nh3_1 - nh3_96
	drop nh4_1 - nh4_99
	drop nh5_1 - nh5_7_txt
	drop nh7_1 - nh7_96
	drop nh10_1 - nh10_99
	drop nh13_1 - nh13_96
	
		

    // Save working copy
    save "$dta/${dta_file}_${date}_M09_nh.dta", replace

    // Paths for issue dumps
    glo mod M09
    confirmdir "${fix}/${mod}/"
        if _rc ~= 0 mkdir "${fix}/${mod}"
    glo sec "${wd}/fix/${date}/${mod}"

    // Optional snapshot
    export excel using "${fix}/${mod}/${dta_file}_${date}_M09_nh.xlsx", ///
        replace firstrow(var) nol

/*

    /// ============================ LOGIC CHECKS ============================
    {

        /*
          Structure (cleaned long):
            - One row per (hhid, hazard). hazard ∈ {1..10}.
            - Singles (1 Yes, 2 No): nh1 nh2 nh6 nh8 nh9 nh11 nh12.
            - Multi-select DUMMIES (1 if selected, . if not):
                nh3_*  (1..7, 9, 96)       [Impact; 9=None]
                nh4_*  (1..6, 96, 99)      [Assistance; 99=No assistance]
                nh7_*  (1..9, 96)          [Warning channels]
                nh10_* (1..8, 96, 99)      [Actions; 99=Did not do anything]
                nh13_* (1..10, 96)         [Hazard map sources; HH level]
          Fixes:
            - NEVER use wildcards like nh3_* that can capture nh3_txt (string).
            - Use rowmax() across explicit numeric dummies and coalesce missing→0.
        */

        // Prefix labels with var name for clearer Excel headers
        foreach v of varlist _all {
            local L: variable label `v'
            la var `v' "`v': `L'"
        }

        // IDs to include in each export
        glo IDENT "hhid_str date hazard nh1 nh2 nh6 nh8 nh9 nh11 nh12"

        // Output counter
        local o = 0

        // ---------------- 0) KEYS ----------------
        capture noisily isid hhid hazard
        if _rc {
            duplicates tag hhid hazard, gen(__dup_hh_hz)
            count if __dup_hh_hz
            if r(N) {
                local ++o
                local suf = string(`o',"%02.0f")
                export excel ${IDENT} hhid hazard if __dup_hh_hz using ///
                    "${sec}/${LNG}_${mod}_`suf'_dup_hhid_hazard.xlsx", replace firstrow(varl) nol
            }
            drop __dup_hh_hz
        }

        // ---------------- 1) CODE VALIDITY ----------------
        cap confirm var hazard
        if !_rc {
            count if !inrange(hazard,1,10) & !missing(hazard)
            if r(N) {
                local ++o
                local suf = string(`o',"%02.0f")
                export excel ${IDENT} hazard if !inrange(hazard,1,10) & !missing(hazard) using ///
                    "${sec}/${LNG}_${mod}_`suf'_badcode_hazard.xlsx", replace firstrow(varl) nol
            }
        }

        foreach v in nh1 nh2 nh6 nh8 nh9 nh11 nh12 {
            cap confirm var `v'
            if !_rc {
                count if !inlist(`v',1,2) & !missing(`v')
                if r(N) {
                    local ++o
                    local suf = string(`o',"%02.0f")
                    export excel ${IDENT} `v' if !inlist(`v',1,2) & !missing(`v') using ///
                        "${sec}/${LNG}_${mod}_`suf'_badcode_`v'.xlsx", replace firstrow(varl) nol
                }
            }
        }

        // ---------------- helper: ANY-selected flags (explicit lists) ----------------
        tempvar __nh3_any __nh4_any __nh7_any __nh10_any __nh13_any __nh3_pos __nh4_pos __nh10_pos
        // Build only if at least one dummy exists to avoid errors.
        // nh3
        cap confirm var nh3_1
        if !_rc {
            egen `__nh3_any' = rowmax(nh3_1-nh3_96)
            replace `__nh3_any' = 0 if missing(`__nh3_any')
            egen `__nh3_pos' = rowmax(nh3_1-nh3_96)
            replace `__nh3_pos' = 0 if missing(`__nh3_pos')
        }
        else gen byte `__nh3_any' = 0

        // nh4
        cap confirm var nh4_1
        if !_rc {
            egen `__nh4_any' = rowmax(nh4_1 - nh4_96)
            replace `__nh4_any' = 0 if missing(`__nh4_any')
            egen `__nh4_pos' = rowmax(nh4_1 - nh4_96)
            replace `__nh4_pos' = 0 if missing(`__nh4_pos')
        }
        else gen byte `__nh4_any' = 0

        // nh7
        cap confirm var nh7_1
        if !_rc {
            egen `__nh7_any' = rowmax(nh7_1 - nh7_96)
            replace `__nh7_any' = 0 if missing(`__nh7_any')
        }
        else gen byte `__nh7_any' = 0

        // nh10
        cap confirm var nh10_1
        if !_rc {
            egen `__nh10_any' = rowmax(nh10_1 - nh10_96)
            replace `__nh10_any' = 0 if missing(`__nh10_any')
            egen `__nh10_pos' = rowmax(nh10_1 - nh10_96)
            replace `__nh10_pos' = 0 if missing(`__nh10_pos')
        }
        else gen byte `__nh10_any' = 0

        // nh13 (household-level)
        preserve
            bysort hhid (hazard): keep if _n==1
            tempvar __nh13_any_loc
            cap confirm var nh13_1
            if !_rc {
                egen `__nh13_any_loc' = rowmax(nh13_1 - nh13_96)
                replace `__nh13_any_loc' = 0 if missing(`__nh13_any_loc')
            }
            else gen byte `__nh13_any_loc' = 0
            tempfile __nh13flag
            keep hhid nh12 `__nh13_any_loc'
            rename `__nh13_any_loc' __nh13_any
            save `__nh13flag', replace
        restore
        merge m:1 hhid using `__nh13flag', nogen

        // ---------------- 2) NH1 ROUTING ----------------
        // nh2 presence: need when nh1==1; blank when nh1==2
        cap confirm var nh2
        if !_rc {
            count if nh1==1 & missing(nh2)
            if r(N) {
                local ++o
                local suf = string(`o',"%02.0f")
                export excel ${IDENT} nh2 if nh1==1 & missing(nh2) using ///
                    "${sec}/${LNG}_${mod}_`suf'_nh2_missing_when_nh1_yes.xlsx", replace firstrow(varl) nol
            }
            count if nh1==2 & !missing(nh2)
            if r(N) {
                local ++o
                local suf = string(`o',"%02.0f")
                export excel ${IDENT} nh2 if nh1==2 & !missing(nh2) using ///
                    "${sec}/${LNG}_${mod}_`suf'_nh2_filled_when_nh1_no.xlsx", replace firstrow(varl) nol
            }
        }

        // nh3 any when nh1==1; none when nh1==2
        count if nh1==1 & `__nh3_any'==0
        if r(N) {
            local ++o
            local suf = string(`o',"%02.0f")
            export excel ${IDENT} nh3_1-nh3_96 if nh1==1 & `__nh3_any'==0 using ///
                "${sec}/${LNG}_${mod}_`suf'_nh3_missing_when_nh1_yes.xlsx", replace firstrow(varl) nol
        }
        count if nh1==2 & `__nh3_any'>0
        if r(N) {
            local ++o
            local suf = string(`o',"%02.0f")
            export excel ${IDENT} nh3_1-nh3_96 if nh1==2 & `__nh3_any'>0 using ///
                "${sec}/${LNG}_${mod}_`suf'_nh3_filled_when_nh1_no.xlsx", replace firstrow(varl) nol
        }

        // nh3_9 (None) cannot co-exist with others
        cap confirm var nh3_9
        if !_rc {
            count if nh3_9==1 & `__nh3_pos'==1
            if r(N) {
                local ++o
                local suf = string(`o',"%02.0f")
                export excel ${IDENT} nh3_1-nh3_96 if nh3_95==1 & `__nh3_pos'==1 using ///
                    "${sec}/${LNG}_${mod}_`suf'_nh3_none_with_others.xlsx", replace firstrow(varl) nol
            }
        }

        // nh4 any when nh1==1; none when nh1==2
        count if nh1==1 & `__nh4_any'==0
        if r(N) {
            local ++o
            local suf = string(`o',"%02.0f")
            export excel ${IDENT} nh4_1-nh4_99 if nh1==1 & `__nh4_any'==0 using ///
                "${sec}/${LNG}_${mod}_`suf'_nh4_missing_when_nh1_yes.xlsx", replace firstrow(varl) nol
        }
        count if nh1==2 & `__nh4_any'>0
        if r(N) {
            local ++o
            local suf = string(`o',"%02.0f")
            export excel ${IDENT} nh4_1-nh4_99 if nh1==2 & `__nh4_any'>0 using ///
                "${sec}/${LNG}_${mod}_`suf'_nh4_filled_when_nh1_no.xlsx", replace firstrow(varl) nol
        }

        // nh4_99 (No assistance) cannot co-exist with other sources
        cap confirm var nh4_99
        if !_rc {
            count if nh4_99==1 & `__nh4_pos'==1
            if r(N) {
                local ++o
                local suf = string(`o',"%02.0f")
                export excel ${IDENT} nh4_99 nh4_1-nh4_6 nh4_96 if nh4_99==1 & `__nh4_pos'==1 using ///
                    "${sec}/${LNG}_${mod}_`suf'_nh4_noassist_with_others.xlsx", replace firstrow(varl) nol
            }
        }

        // ---------------- 3) NH6 ROUTING ----------------
        // Channels needed if nh6==1; must be none if nh6==2
        count if nh6==1 & `__nh7_any'==0
        if r(N) {
            local ++o
            local suf = string(`o',"%02.0f")
            export excel ${IDENT} nh7_1-nh7_9 nh7_96 if nh6==1 & `__nh7_any'==0 using ///
                "${sec}/${LNG}_${mod}_`suf'_nh7_missing_when_nh6_yes.xlsx", replace firstrow(varl) nol
        }
        count if nh6==2 & `__nh7_any'>0
        if r(N) {
            local ++o
            local suf = string(`o',"%02.0f")
            export excel ${IDENT} nh7_1-nh7_9 nh7_96 if nh6==2 & `__nh7_any'>0 using ///
                "${sec}/${LNG}_${mod}_`suf'_nh7_filled_when_nh6_no.xlsx", replace firstrow(varl) nol
        }

        // nh8/nh9/nh11 presence when nh6==1; must be blank when nh6==2
        foreach v in nh8 nh9 nh11 {
            cap confirm var `v'
            if !_rc {
                count if nh6==1 & missing(`v')
                if r(N) {
                    local ++o
                    local suf = string(`o',"%02.0f")
                    export excel ${IDENT} `v' if nh6==1 & missing(`v') using ///
                        "${sec}/${LNG}_${mod}_`suf'_`v'_missing_when_nh6_yes.xlsx", replace firstrow(varl) nol
                }
                count if nh6==2 & !missing(`v')
                if r(N) {
                    local ++o
                    local suf = string(`o',"%02.0f")
                    export excel ${IDENT} `v' if nh6==2 & !missing(`v') using ///
                        "${sec}/${LNG}_${mod}_`suf'_`v'_filled_when_nh6_no.xlsx", replace firstrow(varl) nol
                }
            }
        }

        // Actions needed if nh6==1; none if nh6==2
        count if nh6==1 & `__nh10_any'==0
        if r(N) {
            local ++o
            local suf = string(`o',"%02.0f")
            export excel ${IDENT} nh10_1-nh10_8 nh10_96 nh10_99 if nh6==1 & `__nh10_any'==0 using ///
                "${sec}/${LNG}_${mod}_`suf'_nh10_missing_when_nh6_yes.xlsx", replace firstrow(varl) nol
        }
        count if nh6==2 & `__nh10_any'>0
        if r(N) {
            local ++o
            local suf = string(`o',"%02.0f")
            export excel ${IDENT} nh10_1-nh10_8 nh10_96 nh10_99 if nh6==2 & `__nh10_any'>0 using ///
                "${sec}/${LNG}_${mod}_`suf'_nh10_filled_when_nh6_no.xlsx", replace firstrow(varl) nol
        }

        // nh10_99 (did nothing) cannot co-exist with other actions
        cap confirm var nh10_99
        if !_rc {
            count if nh10_99==1 & `__nh10_pos'==1
            if r(N) {
                local ++o
                local suf = string(`o',"%02.0f")
                export excel ${IDENT} nh10_99 nh10_1-nh10_8 nh10_96 if nh10_99==1 & `__nh10_pos'==1 using ///
                    "${sec}/${LNG}_${mod}_`suf'_nh10_none_with_others.xlsx", replace firstrow(varl) nol
            }
        }

        // ---------------- 4) NH12–NH13 (household-level) ----------------
        // Check NH12 consistency across hazards
        cap confirm var nh12
        if !_rc {
            bysort hhid: egen __nh12_min = min(nh12)
            bysort hhid: egen __nh12_max = max(nh12)
            gen byte __nh12_incon = (__nh12_min!=__nh12_max) if !missing(__nh12_min,__nh12_max)
            preserve
                bysort hhid: keep if _n==1 & __nh12_incon==1
                if _N {
                    local ++o
                    local suf = string(`o',"%02.0f")
                    export excel hhid using ///
                        "${sec}/${LNG}_${mod}_`suf'_nh12_inconsistent_within_hh.xlsx", replace firstrow(var) nol
                }
            restore
            drop __nh12_min __nh12_max __nh12_incon
        }

        // Gating NH13 by NH12 on 1st hazard row per HH (we already merged __nh13_any)
        preserve
            bysort hhid (hazard): keep if _n==1
            // Need sources when aware
            count if nh12==1 & __nh13_any==0
            if r(N) {
                local ++o
                local suf = string(`o',"%02.0f")
                export excel hhid date nh12 __nh13_any using ///
                    "${sec}/${LNG}_${mod}_`suf'_nh13_missing_when_nh12_yes.xlsx", replace firstrow(var) nol
            }
            // Should be none when not aware
            count if nh12==2 & __nh13_any==1
            if r(N) {
                local ++o
                local suf = string(`o',"%02.0f")
                export excel hhid date nh12 __nh13_any using ///
                    "${sec}/${LNG}_${mod}_`suf'_nh13_filled_when_nh12_no.xlsx", replace firstrow(var) nol
            }
        restore

        // Cleanup helper vars from merge
        cap drop __nh13_any
    } // end logic checks

	
	
	
*/
	
} // end NH module block


********************************************************************************
**# (DW) DWELLING — HH-level
**# Uses NEW labels (dw1–dw15) and M10_dwell paths
********************************************************************************

{
    use "$raw/${dta_file}_${date}_M10_dwell.dta", clear

    la lang ${LNG}

    // corrections (optional)
    // replace var = correctvalue if var == wrongvalue & hhid == "..."
    do "${wd}/fix/do/M10.do"

    save "$dta/${dta_file}_${date}_M10_dwell.dta", replace

    glo mod M10
    confirmdir "${fix}/${mod}/"
        if _rc ~= 0 mkdir "${fix}/${mod}"
    glo sec "${wd}/fix/${date}/${mod}"

    export excel using "${fix}/${mod}/${dta_file}_${date}_M10_dwell.xlsx", ///
        replace firstrow(var) nol


/// LOGIC CHECKS
{

/*
DWELLING — key logic & consistency (HH-level) — NEW VARS

1) Keys
   - hhid unique.

2) Code validity
   - dw1 ∈ {1,2,3,4,5,6,7,9}
   - dw2 ∈ {1..7,96}
   - dw3 ∈ {1..9,96}
   - dw5 ∈ {1..7,96}
   - dw6,dw8 ∈ {1,2,-99}
   - dw9,dw10 ∈ {1,2}
   - dw11a,dw11b ∈ {1,2,99}
   - dw12 ∈ {1,-99}
   - dw13 ∈ {1..4}
   - dw14 ∈ {1..5}
   - dw15 ∈ {1..6}

3) Bedrooms (dw4): 0–20 only; missing flagged

4) Paint routing (INTERIOR)
   - If dw6==1 → dw6a present & 1900..this year; dw7 present; dw9 present (1/2).
   - If dw6 in {2,-99} → dw6a/dw7/dw9 should be blank.

5) Paint routing (EXTERIOR)
   - If dw8==1 → dw8a present & 1900..this year; dw8b present; dw10 present (1/2).
   - If dw8 in {2,-99} → dw8a/dw8b/dw10 should be blank.

6) Cross-checks
   - If dw6==2 & dw8==2 → any paint-year/color/chipping filled → flag.
*/

    // Prefix labels with var name for clearer Excel headers
    foreach v of varlist _all {
        local vl: variable label `v'
        la var `v' "`v': `vl'"
    }

    // IDs included in each export
    glo IDENT "hhid_str date dw1 dw2 dw3 dw4 dw5"

    // Counter
    local o = 0

    // ---------- 0) Keys ----------
    capture noisily isid hhid
    if _rc {
        duplicates tag hhid, gen(__dup_hh)
        count if __dup_hh
        if r(N) {
            local ++o
            local suf = string(`o', "%02.0f")
            export excel ${IDENT} hhid if __dup_hh using ///
                "${sec}/${LNG}_${mod}_`suf'_dup_hhid.xlsx", replace firstrow(varl) nol
        }
        drop __dup_hh
    }

    // Helper: current year
    local THISYEAR = year(date(c(current_date),"DMY"))

    // ---------- 1) Code validity ----------
    cap confirm var dw1
    if !_rc {
        count if !inlist(dw1,1,2,3,4,5,6,7,9) & !missing(dw1)
        if r(N) {
            local ++o
            local suf = string(`o', "%02.0f")
            export excel ${IDENT} dw1 if !inlist(dw1,1,2,3,4,5,6,7,9) & !missing(dw1) using ///
                "${sec}/${LNG}_${mod}_`suf'_badcode_dw1_type.xlsx", replace firstrow(varl) nol
        }
    }

    cap confirm var dw2
    if !_rc {
        count if !(inrange(dw2,1,7) | dw2==96) & !missing(dw2)
        if r(N) {
            local ++o
            local suf = string(`o', "%02.0f")
            export excel ${IDENT} dw2 if !(inrange(dw2,1,7) | dw2==96) & !missing(dw2) using ///
                "${sec}/${LNG}_${mod}_`suf'_badcode_dw2_roof.xlsx", replace firstrow(varl) nol
        }
    }

    cap confirm var dw3
    if !_rc {
        count if !(inrange(dw3,1,9) | dw3==96) & !missing(dw3)
        if r(N) {
            local ++o
            local suf = string(`o', "%02.0f")
            export excel ${IDENT} dw3 if !(inrange(dw3,1,9) | dw3==96) & !missing(dw3) using ///
                "${sec}/${LNG}_${mod}_`suf'_badcode_dw3_wall.xlsx", replace firstrow(varl) nol
        }
    }

    cap confirm var dw5
    if !_rc {
        count if !(inrange(dw5,1,7) | dw5==96) & !missing(dw5)
        if r(N) {
            local ++o
            local suf = string(`o', "%02.0f")
            export excel ${IDENT} dw5 if !(inrange(dw5,1,7) | dw5==96) & !missing(dw5) using ///
                "${sec}/${LNG}_${mod}_`suf'_badcode_dw5_tenure.xlsx", replace firstrow(varl) nol
        }
    }

    foreach v in dw6 dw8 {
        cap confirm var `v'
        if !_rc {
            count if !inlist(`v',1,2,99) & !missing(`v')
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} `v' if !inlist(`v',1,2,99) & !missing(`v') using ///
                    "${sec}/${LNG}_${mod}_`suf'_badcode_`v'.xlsx", replace firstrow(varl) nol
            }
        }
    }

    foreach v in dw9 dw10 {
        cap confirm var `v'
        if !_rc {
            count if !inlist(`v',1,2) & !missing(`v')
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} `v' if !inlist(`v',1,2) & !missing(`v') using ///
                    "${sec}/${LNG}_${mod}_`suf'_badcode_`v'.xlsx", replace firstrow(varl) nol
            }
        }
    }

    foreach v in dw11a dw11b {
        cap confirm var `v'
        if !_rc {
            count if !inlist(`v',1,2,99) & !missing(`v')
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} `v' if !inlist(`v',1,2,99) & !missing(`v') using ///
                    "${sec}/${LNG}_${mod}_`suf'_badcode_`v'.xlsx", replace firstrow(varl) nol
            }
        }
    }

    cap confirm var dw12
    if !_rc {
        count if !inlist(dw12,1,99) & !missing(dw12)
        if r(N) {
            local ++o
            local suf = string(`o', "%02.0f")
            export excel ${IDENT} dw12 if !inlist(dw12,1,99) & !missing(dw12) using ///
                "${sec}/${LNG}_${mod}_`suf'_badcode_dw12.xlsx", replace firstrow(varl) nol
        }
    }

    cap confirm var dw13
    if !_rc {
        count if !inlist(dw13,1,2,3,4) & !missing(dw13)
        if r(N) {
            local ++o
            local suf = string(`o', "%02.0f")
            export excel ${IDENT} dw13 if !inlist(dw13,1,2,3,4) & !missing(dw13) using ///
                "${sec}/${LNG}_${mod}_`suf'_badcode_dw13_cookware.xlsx", replace firstrow(varl) nol
        }
    }

    cap confirm var dw14
    if !_rc {
        count if !inrange(dw14,1,5) & !missing(dw14)
        if r(N) {
            local ++o
            local suf = string(`o', "%02.0f")
            export excel ${IDENT} dw14 if !inrange(dw14,1,5) & !missing(dw14) using ///
                "${sec}/${LNG}_${mod}_`suf'_badcode_dw14_neighborhood.xlsx", replace firstrow(varl) nol
        }
    }

    cap confirm var dw15
    if !_rc {
        count if !inrange(dw15,1,6) & !missing(dw15)
        if r(N) {
            local ++o
            local suf = string(`o', "%02.0f")
            export excel ${IDENT} dw15 if !inrange(dw15,1,6) & !missing(dw15) using ///
                "${sec}/${LNG}_${mod}_`suf'_badcode_dw15_indoor.xlsx", replace firstrow(varl) nol
        }
    }

    // ---------- 2) Bedrooms (dw4) ----------
    cap confirm var dw4
    if !_rc {
        // out-of-range
        count if (dw4<0 | dw4>20) & !missing(dw4)
        if r(N) {
            local ++o
            local suf = string(`o', "%02.0f")
            export excel ${IDENT} dw4 if (dw4<0 | dw4>20) & !missing(dw4) using ///
                "${sec}/${LNG}_${mod}_`suf'_dw4_bedrooms_range.xlsx", replace firstrow(varl) nol
        }
        // missing (asked of all)
        count if missing(dw4)
        if r(N) {
            local ++o
            local suf = string(`o', "%02.0f")
            export excel ${IDENT} dw4 if missing(dw4) using ///
                "${sec}/${LNG}_${mod}_`suf'_dw4_bedrooms_missing.xlsx", replace firstrow(varl) nol
        }
    }

    // ---------- 3) Interior paint routing ----------
    cap confirm var dw6
    if !_rc {
        // Need year, color, chipping when dw6==1
        cap confirm var dw6a
        if !_rc {
            count if dw6==1 & missing(dw6a)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} dw6 dw6a if dw6==1 & missing(dw6a) using ///
                    "${sec}/${LNG}_${mod}_`suf'_int_year_missing.xlsx", replace firstrow(varl) nol
            }
            count if dw6==1 & !inrange(dw6a,1900,`THISYEAR')
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} dw6 dw6a if dw6==1 & !inrange(dw6a,1900,`THISYEAR') using ///
                    "${sec}/${LNG}_${mod}_`suf'_int_year_implausible.xlsx", replace firstrow(varl) nol
            }
            // year present when not needed
            count if inlist(dw6,2,99) & !missing(dw6a)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} dw6 dw6a if inlist(dw6,2,99) & !missing(dw6a) using ///
                    "${sec}/${LNG}_${mod}_`suf'_int_year_when_not_needed.xlsx", replace firstrow(varl) nol
            }
        }

        cap confirm var dw7
        if !_rc {
            count if dw6==1 & missing(dw7)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} dw6 dw7 if dw6==1 & missing(dw7) using ///
                    "${sec}/${LNG}_${mod}_`suf'_int_color_missing.xlsx", replace firstrow(varl) nol
            }
            count if inlist(dw6,2) & !missing(dw7)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} dw6 dw7 if inlist(dw6,2) & !missing(dw7) using ///
                    "${sec}/${LNG}_${mod}_`suf'_int_color_when_not_needed.xlsx", replace firstrow(varl) nol
            }
        }

        cap confirm var dw9
        if !_rc {
            count if dw6==1 & missing(dw9)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} dw6 dw9 if dw6==1 & missing(dw9) using ///
                    "${sec}/${LNG}_${mod}_`suf'_int_chipping_missing.xlsx", replace firstrow(varl) nol
            }
            count if inlist(dw6,2) & !missing(dw9)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} dw6 dw9 if inlist(dw6,2) & !missing(dw9) using ///
                    "${sec}/${LNG}_${mod}_`suf'_int_chipping_when_not_needed.xlsx", replace firstrow(varl) nol
            }
        }
    }

    // ---------- 4) Exterior paint routing ----------
    cap confirm var dw8
    if !_rc {
        // Need year, color, chipping when dw8==1
        cap confirm var dw8a
        if !_rc {
            count if dw8==1 & missing(dw8a)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} dw8 dw8a if dw8==1 & missing(dw8a) using ///
                    "${sec}/${LNG}_${mod}_`suf'_ext_year_missing.xlsx", replace firstrow(varl) nol
            }
            count if dw8==1 & !inrange(dw8a,1900,`THISYEAR')
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} dw8 dw8a if dw8==1 & !inrange(dw8a,1900,`THISYEAR') using ///
                    "${sec}/${LNG}_${mod}_`suf'_ext_year_implausible.xlsx", replace firstrow(varl) nol
            }
            // year present when not needed
            count if inlist(dw8,2,99) & !missing(dw8a)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} dw8 dw8a if inlist(dw8,2,99) & !missing(dw8a) using ///
                    "${sec}/${LNG}_${mod}_`suf'_ext_year_when_not_needed.xlsx", replace firstrow(varl) nol
            }
        }

        cap confirm var dw8b
        if !_rc {
            count if dw8==1 & missing(dw8b)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} dw8 dw8b if dw8==1 & missing(dw8b) using ///
                    "${sec}/${LNG}_${mod}_`suf'_ext_color_missing.xlsx", replace firstrow(varl) nol
            }
            count if inlist(dw8,2) & !missing(dw8b)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} dw8 dw8b if inlist(dw8,2) & !missing(dw8b) using ///
                    "${sec}/${LNG}_${mod}_`suf'_ext_color_when_not_needed.xlsx", replace firstrow(varl) nol
            }
        }

        cap confirm var dw10
        if !_rc {
            count if dw8==1 & missing(dw10)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} dw8 dw10 if dw8==1 & missing(dw10) using ///
                    "${sec}/${LNG}_${mod}_`suf'_ext_chipping_missing.xlsx", replace firstrow(varl) nol
            }
            count if inlist(dw8,2) & !missing(dw10)
            if r(N) {
                local ++o
                local suf = string(`o', "%02.0f")
                export excel ${IDENT} dw8 dw10 if inlist(dw8,2) & !missing(dw10) using ///
                    "${sec}/${LNG}_${mod}_`suf'_ext_chipping_when_not_needed.xlsx", replace firstrow(varl) nol
            }
        }
    }

    // ---------- 5) Cross-checks ----------
    cap confirm var dw6
    cap confirm var dw8
    if !_rc {
        tempvar __anypaint
        gen byte `__anypaint' = 0
        cap confirm var dw6a
        if !_rc replace `__anypaint' = 1 if !missing(dw6a)
        cap confirm var dw7
        if !_rc replace `__anypaint' = 1 if !missing(dw7)
        cap confirm var dw9
        if !_rc replace `__anypaint' = 1 if !missing(dw9)
        cap confirm var dw8a
        if !_rc replace `__anypaint' = 1 if !missing(dw8a)
        cap confirm var dw8b
        if !_rc replace `__anypaint' = 1 if !missing(dw8b)
        cap confirm var dw10
        if !_rc replace `__anypaint' = 1 if !missing(dw10)

        count if dw6==2 & dw8==2 & `__anypaint'==1
        if r(N) {
            local ++o
            local suf = string(`o', "%02.0f")
            export excel ${IDENT} dw6 dw8 dw6a dw7 dw9 dw8a dw8b dw10 ///
                if dw6==2 & dw8==2 & `__anypaint'==1 using ///
                "${sec}/${LNG}_${mod}_`suf'_both_nopaint_but_info.xlsx", replace firstrow(varl) nol
        }
        drop `__anypaint'
    }

} // end logic checks

} // end DWELLING module block


********************************************************************************
**# (SN) SANITATION   s1–s8 variables
********************************************************************************

{
    
	use "$raw/${dta_file}_${date}_M11_san.dta", clear

    la lang ${LNG}

    // here correcting the mistakes 
        // replace var = correctvalue if var == wrongvalue & hhid == "..."

    do "${wd}/fix/do/M11.do"
	
	
	
	/// MULTIPLE TO SINGLE 
	
	
	******************************************************
	* s5: Waste segregation categories (select_multiple binaries)
	* Create ranked single-choice variables s5_cat1, s5_cat2, ...
	******************************************************

	* --- 1) Value label (code = suffix of s5_# binary) ---
	capture label drop s5_category_eng
	label define s5_category_eng ///
		1 "Organic (food/yard)" ///
		2 "Recyclables (plastic, paper, metal, glass)" ///
		3 "Hazardous (batteries, chemicals)" ///
		4 "Medical waste" ///
		5 "None" ///
		, replace

	* --- 2) Count selections and find max (how many ranked vars to create) ---
	egen s5_ncat = rowtotal(s5_1 s5_2 s5_3 s5_4 s5_5)
	quietly summarize s5_ncat, meanonly
	local max = r(max)

	* --- 3) Peel off selected categories into ranked single-choice variables ---
	* Put 5 (None) last so it doesn't override real categories
	local codes 1 2 3 4 5

	foreach c of local codes {
		gen byte s5_rem_`c' = s5_`c'
	}

	forvalues k = 1/`max' {
		gen s5_cat`k' = .

		foreach c of local codes {
			replace s5_cat`k' = `c' if s5_rem_`c' == 1 & missing(s5_cat`k')
		}

		foreach c of local codes {
			replace s5_rem_`c' = 0 if s5_cat`k' == `c'
		}

		label variable s5_cat`k' "Waste segregation category (rank `k')"
		label values  s5_cat`k' s5_category_eng
	}

	drop s5_rem_*
		
	order s5_ncat s5_cat*, before(s5_txt)
		
	
	drop s5_1 - s5_5 
	
	
    save "$dta/${dta_file}_${date}_M11_san.dta", replace

    glo mod M11
    confirmdir "${fix}/${mod}/"
        if _rc ~= 0 mkdir "${fix}/${mod}"
    glo sec "${wd}/fix/${date}/${mod}"
    
    export excel using "${fix}/${mod}/${dta_file}_${date}_M11_san.xlsx", ///
        replace firstrow(var) nol


/*
/// LOGIC CHECKS
{
/*
SANITATION — key logic & consistency (HH-level)

1) Keys
   - hhid unique.

2) Code validity (+ required where asked of all)
   - s1 ∈ {0,1,2,3,4,5,6,7}          (asked all; flag missing)
   - s2 ∈ {1,2,3}                    (asked all; flag missing)
   - s3 ∈ {1,2} only when s2==3; otherwise blank.
   - s4 ∈ {1,2,3,4,96,99,9}          (asked all; flag missing)
   - s6 ∈ {1..5} only when s4 implies disposal (see #4).
   - s7 ∈ {1,2}                      (asked all; flag missing)
   - s8 ∈ {1..4}                     (asked all; flag missing)

3) Share facility routing (s3)
   - If s2==3 → s3 must be present in {1,2}.
   - If s2!=3 → s3 should be blank.
   - Soft: s1 says "shared" (2/4) but s3==2 → flag.
           s1 says "exclusive" (1/3) but s3==1 → flag.

4) s5/s6 gating from s4 (segregation & frequency)
   - If s4 in {1,2,3,4,96}: require ≥1 s5 category AND s6 present (1..5).
   - If s4 in {9,99}: both s5 and s6 should be blank.
   - "None" (s5 code 5) must not co-exist with any other s5 category.
   - If "None" only → s6 should be 1 (Never).
   - If any s5 category (1–4) selected → s6 should not be 1 (Never).

5) s7a amount
   - If s7==1: s7a required and ≥0.
   - If s7==2: s7a should be blank.

6) Soft sanity
   - If s1==0 ("None") but s2 is filled → flag (soft).
*/

    // Prefix labels with var name for clearer Excel headers
    foreach var of varlist _all {
        local vlab: variable label `var'
        la var `var' "`var': `vlab'"
    }

    // IDs included in each export
    glo IDENT "hhid_str date s1 s2 s3 s4 s5 s6 s7 s7a s8"

    // Counter
    local o = 0
	
	// DROP txt
	
	drop *_txt

    // ---------- 0) Keys ----------
    capture noisily isid hhid
    if _rc {
        duplicates tag hhid, gen(__dup_hh)
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if __dup_hh
        if `r(N)'>0 export excel ${IDENT} hhid if __dup_hh using ///
            "${sec}/${LNG}_${mod}_`suf'_dup_hhid.xlsx", replace firstrow(varl) nol
        drop __dup_hh
    }

    // ---------- 1) Code validity (and required where "Ask all") ----------
    // S1
    cap confirm var s1
    if !_rc {
        // bad code
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if !inlist(s1,1,2,3,4,5,6,7,9) & !missing(s1)
        if `r(N)'>0 export excel ${IDENT} s1 if !inlist(s1,1,2,3,4,5,6,7,9) & !missing(s1) using ///
            "${sec}/${LNG}_${mod}_`suf'_s1_badcode.xlsx", replace firstrow(varl) nol

        // missing
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if missing(s1)
        if `r(N)'>0 export excel ${IDENT} s1 if missing(s1) using ///
            "${sec}/${LNG}_${mod}_`suf'_s1_missing.xlsx", replace firstrow(varl) nol
    }

    // S2
    cap confirm var s2
    if !_rc {
        // bad code
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if !inlist(s2,1,2,3) & !missing(s2)
        if `r(N)'>0 export excel ${IDENT} s2 if !inlist(s2,1,2,3) & !missing(s2) using ///
            "${sec}/${LNG}_${mod}_`suf'_s2_badcode.xlsx", replace firstrow(varl) nol

        // missing
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if missing(s2)
        if `r(N)'>0 export excel ${IDENT} s2 if missing(s2) using ///
            "${sec}/${LNG}_${mod}_`suf'_s2_missing.xlsx", replace firstrow(varl) nol
    }

    // S4
    cap confirm var s4
    if !_rc {
        // bad code
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if !inlist(s4,1,2,3,4,96,99,9) & !missing(s4)
        if `r(N)'>0 export excel ${IDENT} s4 if !inlist(s4,1,2,3,4,96,99,9) & !missing(s4) using ///
            "${sec}/${LNG}_${mod}_`suf'_s4_badcode.xlsx", replace firstrow(varl) nol

        // missing
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if missing(s4)
        if `r(N)'>0 export excel ${IDENT} s4 if missing(s4) using ///
            "${sec}/${LNG}_${mod}_`suf'_s4_missing.xlsx", replace firstrow(varl) nol
    }

    // S7
    cap confirm var s7
    if !_rc {
        // bad code
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if !inlist(s7,1,2) & !missing(s7)
        if `r(N)'>0 export excel ${IDENT} s7 if !inlist(s7,1,2) & !missing(s7) using ///
            "${sec}/${LNG}_${mod}_`suf'_s7_badcode.xlsx", replace firstrow(varl) nol

        // missing
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if missing(s7)
        if `r(N)'>0 export excel ${IDENT} s7 if missing(s7) using ///
            "${sec}/${LNG}_${mod}_`suf'_s7_missing.xlsx", replace firstrow(varl) nol
    }

    // S8
    cap confirm var s8
    if !_rc {
        // bad code
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if !inlist(s8,1,2,3,4) & !missing(s8)
        if `r(N)'>0 export excel ${IDENT} s8 if !inlist(s8,1,2,3,4) & !missing(s8) using ///
            "${sec}/${LNG}_${mod}_`suf'_s8_badcode.xlsx", replace firstrow(varl) nol

        // missing
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if missing(s8)
        if `r(N)'>0 export excel ${IDENT} s8 if missing(s8) using ///
            "${sec}/${LNG}_${mod}_`suf'_s8_missing.xlsx", replace firstrow(varl) nol
    }

    // ---------- 2) Share facility routing (s3) ----------
    cap confirm var s3
    if !_rc {
        // need s3 when s2==3
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if s2==3 & missing(s3)
        if `r(N)'>0 export excel ${IDENT} s2 s3 if s2==3 & missing(s3) using ///
            "${sec}/${LNG}_${mod}_`suf'_s3_missing_when_loc3.xlsx", replace firstrow(varl) nol

        // should be blank when s2!=3
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if s2!=3 & !missing(s3)
        if `r(N)'>0 export excel ${IDENT} s2 s3 if s2!=3 & !missing(s3) using ///
            "${sec}/${LNG}_${mod}_`suf'_s3_filled_when_not_loc3.xlsx", replace firstrow(varl) nol

        // soft cross-check vs s1
        cap confirm var s1
        if !_rc {
            // s1 says shared (2/4) but s3==2 (No)
            local o = `o' + 1
            local suf = string(`o', "%02.0f")
            count if s2==3 & inlist(s1,2,4) & s3==2
            if `r(N)'>0 export excel ${IDENT} s1 s2 s3 if s2==3 & inlist(s1,2,4) & s3==2 using ///
                "${sec}/${LNG}_${mod}_`suf'_s1shared_s3no.xlsx", replace firstrow(varl) nol

            // s1 says exclusive (1/3) but s3==1 (Yes)
            local o = `o' + 1
            local suf = string(`o', "%02.0f")
            count if s2==3 & inlist(s1,1,3) & s3==1
            if `r(N)'>0 export excel ${IDENT} s1 s2 s3 if s2==3 & inlist(s1,1,3) & s3==1 using ///
                "${sec}/${LNG}_${mod}_`suf'_s1exclusive_s3yes.xlsx", replace firstrow(varl) nol
        }
    }

    // ---------- 3) s5/s6 gating from s4 ----------
    // Build "any s5 selected", and detect "None" (5) vs other categories (1–4)
    tempvar __s5_any __s5_none __s5_any_other
    quietly {
        gen byte `__s5_any' = .
        gen byte `__s5_none' = .
        gen byte `__s5_any_other' = .

        // Prefer dummies if present
        cap unab S5D : s5_*
        if !_rc {
            tempvar __s5_sum
            egen `__s5_sum' = rowtotal(s5_*), missing
            replace `__s5_any' = (`__s5_sum'>0) if !missing(`__s5_sum')
            replace `__s5_none' = (s5_5==1) if !missing(s5_5)
            replace `__s5_any_other' = 0
            foreach k in 1 2 3 4 {
                cap confirm var s5_`k'
                if !_rc replace `__s5_any_other' = 1 if s5_`k'==1
            }
        }
        else {
            // fall back to cleaned string
            cap confirm var s5_txt
            if !_rc {
                replace `__s5_any'       = (s5_txt!="")
                replace `__s5_none'      = regexm(s5_txt,"(^|;)5(;|$)")
                replace `__s5_any_other' = regexm(s5_txt,"(^|;)(1|2|3|4)(;|$)")
            }
            else {
                // final fallback: raw string
                cap confirm var s5
                if !_rc replace `__s5_any' = (trim(s5)!="")
            }
        }
    }

    // Require s5 + s6 when disposal happened (1,2,3,4,96)
    cap confirm var s6
    if !_rc {
        // missing s5 when required
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if inlist(s4,1,2,3,4,96) & (`__s5_any'==0 | missing(`__s5_any'))
        if `r(N)'>0 export excel ${IDENT} s4 s5 s6 if inlist(s4,1,2,3,4,96) & (`__s5_any'==0 | missing(`__s5_any')) using ///
            "${sec}/${LNG}_${mod}_`suf'_s5_missing_when_required.xlsx", replace firstrow(varl) nol

        // missing/bad s6 when required
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if inlist(s4,1,2,3,4,96) & (missing(s6) | !inrange(s6,1,5))
        if `r(N)'>0 export excel ${IDENT} s4 s6 if inlist(s4,1,2,3,4,96) & (missing(s6) | !inrange(s6,1,5)) using ///
            "${sec}/${LNG}_${mod}_`suf'_s6_missing_or_bad_when_required.xlsx", replace firstrow(varl) nol

        // s5/s6 should be blank when no waste or DK (9,99)
 //       local o = `o' + 1
 //       local suf = string(`o', "%02.0f")
 //       count if inlist(s4,9,99) & ( s5 == . | !missing(s6) )
 //       if `r(N)'>0 export excel ${IDENT} s4 s5 s6 if inlist(s4,9,99) & ( s5 == . | !missing(s6) ) using ///
            //"${sec}/${LNG}_${mod}_`suf'_s5s6_filled_when_not_needed.xlsx", replace firstrow(varl) nol

        // "None" with any other category
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if `__s5_none'==1 & `__s5_any_other'==1
        if `r(N)'>0 export excel ${IDENT} s5 if `__s5_none'==1 & `__s5_any_other'==1 using ///
            "${sec}/${LNG}_${mod}_`suf'_s5_none_with_others.xlsx", replace firstrow(varl) nol

        // If "None" only → s6 should be Never (1)
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if inlist(s4,1,2,3,4,96) & `__s5_none'==1 & `__s5_any_other'==0 & s6!=1
        if `r(N)'>0 export excel ${IDENT} s4 s5 s6 if inlist(s4,1,2,3,4,96) & `__s5_none'==1 & `__s5_any_other'==0 & s6!=1 using ///
            "${sec}/${LNG}_${mod}_`suf'_s6_not_never_when_none.xlsx", replace firstrow(varl) nol

        // If any category selected (1–4) → s6 should not be Never (1)
///        local o = `o' + 1
///        local suf = string(`o', "%02.0f")
///        count if inlist(s5,1,2,3,4,96) & `__s5_any_other'==1 & s6==1
///        if `r(N)'>0 export excel ${IDENT} s4 s5 s6 if inlist(s5,1,2,3,4,96) & `__s5_any_other'==1 & s6==1 using ///
            ///"${sec}/${LNG}_${mod}_`suf'_s6_never_but_has_categories.xlsx", replace firstrow(varl) nol
    }

    // ---------- 4) s7a amount rules ----------
    cap confirm var s7
    if !_rc {
        cap confirm var s7a

        // need non-missing, >=0 when Yes
        if !_rc {
            local o = `o' + 1
            local suf = string(`o', "%02.0f")
            count if s7==1 & (missing(s7a) | s7a<0)
            if `r(N)'>0 export excel ${IDENT} s7 s7a if s7==1 & (missing(s7a) | s7a<0) using ///
                "${sec}/${LNG}_${mod}_`suf'_s7a_missing_or_negative.xlsx", replace firstrow(varl) nol
        }

        // should be blank when No
        if !_rc {
            local o = `o' + 1
            local suf = string(`o', "%02.0f")
            count if s7==2 & !missing(s7a)
            if `r(N)'>0 export excel ${IDENT} s7 s7a if s7==2 & !missing(s7a) using ///
                "${sec}/${LNG}_${mod}_`suf'_s7a_present_when_no.xlsx", replace firstrow(varl) nol
        }
    }

    // ---------- 5) Soft sanity ----------
    cap confirm var s1
    cap confirm var s2
    if !_rc {
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if s1==0 & !missing(s2)
        if `r(N)'>0 export excel ${IDENT} s1 s2 if s1==0 & !missing(s2) using ///
            "${sec}/${LNG}_${mod}_`suf'_s1_none_but_loc_filled.xlsx", replace firstrow(varl) nol
    }
}

*/


}


********************************************************************************
**# (WT) WATER — uses M12_water.dta and w1–w8 variables
********************************************************************************

{
    use "$raw/${dta_file}_${date}_M12_water.dta", clear

    cap drop *_clean
    la lang ${LNG}

    // here correcting the mistakes 
        // replace var = correctvalue if var == wrongvalue & hhid == "..."

    do "${wd}/fix/do/M12_water.do"
	
	
	
	******************************************************
	* w7: Water treatment methods (select_multiple binaries)
	* Create ranked single-choice variables w7_meth1, w7_meth2, ...
	******************************************************

	* --- 1) Value label (code = suffix of w7_# binary) ---
	capture label drop w7_method_eng
	label define w7_method_eng ///
		1  "Boiled it" ///
		2  "Add bleach/chlorine" ///
		3  "Strain it through a cloth" ///
		4  "Use water filter (ceramic, sand, composite, etc.)" ///
		5  "Solar disinfection" ///
		6  "Let it stand and settle" ///
		96 "Others" ///
		99 "Don't know" ///
		, replace

	* --- 2) Count selections and find max (how many ranked vars to create) ---
	egen w7_nmeth = rowtotal(w7_1 w7_2 w7_3 w7_4 w7_5 w7_6 w7_96 w7_99)
	quietly summarize w7_nmeth, meanonly
	local max = r(max)

	* --- 3) Peel off selected methods into ranked single-choice variables ---
	local codes 1 2 3 4 5 6 96 99

	foreach c of local codes {
		gen byte w7_rem_`c' = w7_`c'
	}

	forvalues k = 1/`max' {
		gen w7_meth`k' = .

		foreach c of local codes {
			replace w7_meth`k' = `c' if w7_rem_`c' == 1 & missing(w7_meth`k')
		}

		foreach c of local codes {
			replace w7_rem_`c' = 0 if w7_meth`k' == `c'
		}

		label variable w7_meth`k' "Water treatment method (rank `k')"
		label values  w7_meth`k' w7_method_eng
	}

	drop w7_rem_*
	
	order w7_nmeth w7_meth*, before(w7_txt)
	
	drop w7_1 - w7_99 
	
	
    save "$dta/${dta_file}_${date}_M12_water.dta", replace

    glo mod M12_water
    confirmdir "${fix}/${mod}/"
        if _rc ~= 0 mkdir "${fix}/${mod}"
    glo sec "${wd}/fix/${date}/${mod}"
    
    export excel using "${fix}/${mod}/${dta_file}_${date}_M12_water.xlsx", ///
        replace firstrow(var) nol


/*

/// LOGIC CHECKS
{

/*
WATER — key logic & consistency (HH-level)

1) Keys
   - hhid unique.

2) Code validity (+ required where asked of all)
   - w1  ∈ {1–16,96}; missing flagged. (Main source)
   - w4  ∈ {1,2};     missing flagged. (Location)
   - w5  ∈ {1–16,96}; missing flagged. (Drinking source)
   - w8  ∈ {1..4};    missing flagged. (Safety)

3) W2 (time to collect) asked only if W1 in {11,12}
   - If w1∈{11,12}: w2 must be present; value ≥0 or in {0,99}.
   - If w1∉{11,12}: w2 should be blank.
   - Any negative value is flagged (no -99 in the new scheme).

4) W3 (provider) asked only if W1 in {1..5}
   - If w1∈{1..5}: w3 must be present and in {1,2,3,99}.
   - If w1∉{1..5}: w3 should be blank.
   - Soft: If w1∈{1..5} & w3==3 ("No water system") → flag.

5) W6–W7 gating from W5 (drinking source)
   - If w5∈{2,3} ("piped to yard/lot" or "piped to neighbor"):
       w6 required in {1,2,99}.
     Else: w6 should be blank.
   - If w6==1: at least one W7 method must be selected.
     If w6!=1: W7 methods should be blank.
   - W7 "Don't know (99)" must not co-exist with any other method.
*/

    // Prefix labels with var name for clearer Excel headers
    foreach var of varlist _all {
        local vlab: variable label `var'
        la var `var' "`var': `vlab'"
    }
	
    // IDs included in each export
    glo IDENT "hhid_str date w1 w2 w3 w4 w5 w6 w8"

	// DROP txt
	tostring hhid_str, replace
	drop *_txt
	
    // Build W7 varlist (for cleaner exports)
    local W7LIST ""
    cap unab W7D : w7_*
    if !_rc {
        unab __w7d : w7_*
        local W7LIST "`__w7d'"
    }
    else {
        cap confirm var w7_txt
        if !_rc local W7LIST "w7_txt"
    }

    // Counter
    local o = 0

    // ---------- 0) Keys ----------
    capture noisily isid hhid
    if _rc {
        duplicates tag hhid, gen(__dup_hh)
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if __dup_hh
        if `r(N)'>0 export excel ${IDENT} hhid if __dup_hh using ///
            "${sec}/${LNG}_${mod}_`suf'_dup_hhid.xlsx", replace firstrow(varl) nol
        drop __dup_hh
    }

    // ---------- 1) Code validity (and required where "Ask all") ----------
    // W1 main source
    cap confirm var w1
    if !_rc {
        // bad code
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if !(inrange(w1,1,16) | w1==96) & !missing(w1)
        if `r(N)'>0 export excel ${IDENT} w1 if !(inrange(w1,1,16) | w1==96) & !missing(w1) using ///
            "${sec}/${LNG}_${mod}_`suf'_w1_badcode.xlsx", replace firstrow(varl) nol

        // missing
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if missing(w1)
        if `r(N)'>0 export excel ${IDENT} w1 if missing(w1) using ///
            "${sec}/${LNG}_${mod}_`suf'_w1_missing.xlsx", replace firstrow(varl) nol
    }

    // W4 location (asked all)
    cap confirm var w4
    if !_rc {
        // bad code
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if !inlist(w4,1,2) & !missing(w4)
        if `r(N)'>0 export excel ${IDENT} w4 if !inlist(w4,1,2) & !missing(w4) using ///
            "${sec}/${LNG}_${mod}_`suf'_w4_badcode.xlsx", replace firstrow(varl) nol

        // missing
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if missing(w4)
        if `r(N)'>0 export excel ${IDENT} w4 if missing(w4) using ///
            "${sec}/${LNG}_${mod}_`suf'_w4_missing.xlsx", replace firstrow(varl) nol
    }

    // W5 drinking source (asked all)
    cap confirm var w5
    if !_rc {
        // bad code
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if !(inrange(w5,1,16) | w5==21 | w5==96) & !missing(w5)
        if `r(N)'>0 export excel ${IDENT} w5 if !(inrange(w5,1,16) | w5==21 | w5==96) & !missing(w5) using ///
            "${sec}/${LNG}_${mod}_`suf'_w5_badcode.xlsx", replace firstrow(varl) nol

        // missing
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if missing(w5)
        if `r(N)'>0 export excel ${IDENT} w5 if missing(w5) using ///
            "${sec}/${LNG}_${mod}_`suf'_w5_missing.xlsx", replace firstrow(varl) nol
    }

    // W8 safety (asked all)
    cap confirm var w8
    if !_rc {
        // bad code
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if !inlist(w8,1,2,3,4) & !missing(w8)
        if `r(N)'>0 export excel ${IDENT} w8 if !inlist(w8,1,2,3,4) & !missing(w8) using ///
            "${sec}/${LNG}_${mod}_`suf'_w8_badcode.xlsx", replace firstrow(varl) nol

        // missing
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if missing(w8)
        if `r(N)'>0 export excel ${IDENT} w8 if missing(w8) using ///
            "${sec}/${LNG}_${mod}_`suf'_w8_missing.xlsx", replace firstrow(varl) nol
    }

    // ---------- 2) W2 (time) gating from W1 ----------
    cap confirm var w2
    if !_rc {
        // need W2 when W1 in {11,12}
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if inlist(w1,11,12) & missing(w2)
        if `r(N)'>0 export excel ${IDENT} w1 w2 if inlist(w1,11,12) & missing(w2) using ///
            "${sec}/${LNG}_${mod}_`suf'_w2_missing_when_needed.xlsx", replace firstrow(varl) nol

        // negative values
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if inlist(w1,11,12) & w2<0 & w2!=-99
        if `r(N)'>0 export excel ${IDENT} w2 if inlist(w1,11,12) & w2<0 & w2!=-99 using ///
            "${sec}/${LNG}_${mod}_`suf'_w2_negative.xlsx", replace firstrow(varl) nol

        // should be blank when W1 not in {11,12}
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if !inlist(w1,11,12) & !missing(w2)
        if `r(N)'>0 export excel ${IDENT} w1 w2 if !inlist(w1,11,12) & !missing(w2) using ///
            "${sec}/${LNG}_${mod}_`suf'_w2_filled_when_not_needed.xlsx", replace firstrow(varl) nol
    }

    // ---------- 3) W3 (provider) gating from W1 ----------
    cap confirm var w3
    if !_rc {
        // bad code in general
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if !inlist(w3,1,2,3,99) & !missing(w3)
        if `r(N)'>0 export excel ${IDENT} w3 if !inlist(w3,1,2,3,99) & !missing(w3) using ///
            "${sec}/${LNG}_${mod}_`suf'_w3_badcode.xlsx", replace firstrow(varl) nol

        // need provider when W1 in 1..5
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if inrange(w1,1,5) & missing(w3)
        if `r(N)'>0 export excel ${IDENT} w1 w3 if inrange(w1,1,5) & missing(w3) using ///
            "${sec}/${LNG}_${mod}_`suf'_w3_missing_when_needed.xlsx", replace firstrow(varl) nol

        // should be blank when W1 not in 1..5
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if !inrange(w1,1,5) & !missing(w3)
        if `r(N)'>0 export excel ${IDENT} w1 w3 if !inrange(w1,1,5) & !missing(w3) using ///
            "${sec}/${LNG}_${mod}_`suf'_w3_filled_when_not_needed.xlsx", replace firstrow(varl) nol

        // soft: piped but "no water system"
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if inrange(w1,1,5) & w3==3
        if `r(N)'>0 export excel ${IDENT} w1 w3 if inrange(w1,1,5) & w3==3 using ///
            "${sec}/${LNG}_${mod}_`suf'_w3_soft_piped_no_system.xlsx", replace firstrow(varl) nol
    }

    // ---------- 4) W6–W7 gating from W5 ----------
    // W6 incidence
    cap confirm var w6
    if !_rc {
        // need W6 when W5 in {2,3}
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if inlist(w5,2,3) & (missing(w6) | !inlist(w6,1,2,99))
        if `r(N)'>0 export excel ${IDENT} w5 w6 if inlist(w5,2,3) & (missing(w6) | !inlist(w6,1,2,99)) using ///
            "${sec}/${LNG}_${mod}_`suf'_w6_missing_or_bad_when_needed.xlsx", replace firstrow(varl) nol

        // should be blank when W5 not in {2,3}
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if !inlist(w5,2,3) & !missing(w6)
        if `r(N)'>0 export excel ${IDENT} w5 w6 if !inlist(w5,2,3) & !missing(w6) using ///
            "${sec}/${LNG}_${mod}_`suf'_w6_filled_when_not_needed.xlsx", replace firstrow(varl) nol
    }

    // W7 methods presence / exclusivity
    tempvar __w7_any __w7_dk __w7_any_other
    gen byte `__w7_any' = .
    gen byte `__w7_dk' = .
    gen byte `__w7_any_other' = .

    cap unab W7D : w7_*
    if !_rc {
        tempvar __w7_sum
        egen `__w7_sum' = rowtotal(w7_*), missing
        replace `__w7_any' = (`__w7_sum'>0) if !missing(`__w7_sum')
        replace `__w7_dk' = (w7_99==1) if !missing(w7_99)
        replace `__w7_any_other' = 0
        foreach k in 1 2 3 4 5 6 96 {
            cap confirm var w7_`k'
            if !_rc replace `__w7_any_other' = 1 if w7_`k'==1
        }
    }
    else {
        cap confirm var w7_txt
        if !_rc {
            replace `__w7_any'       = (w7_txt!="")
            replace `__w7_dk'        = regexm(w7_txt,"(^|;)99(;|$)")
            replace `__w7_any_other' = regexm(w7_txt,"(^|;)(1|2|3|4|5|6|96)(;|$)")
        }
    }

    // If w6==1 need ≥1 method
    cap confirm var w6
    if !_rc {
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if w6==1 & (`__w7_any'==0 | missing(`__w7_any'))
        if `r(N)'>0 {
            if "`W7LIST'" != "" ///
                export excel ${IDENT} `W7LIST' if w6==1 & (`__w7_any'==0 | missing(`__w7_any')) using ///
                    "${sec}/${LNG}_${mod}_`suf'_w7_missing_when_treat_yes.xlsx", replace firstrow(varl) nol
            else ///
                export excel ${IDENT} if w6==1 & (`__w7_any'==0 | missing(`__w7_any')) using ///
                    "${sec}/${LNG}_${mod}_`suf'_w7_missing_when_treat_yes.xlsx", replace firstrow(varl) nol
        }

        // If w6!=1 then methods should be blank
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if (w6!=1 | missing(w6)) & `__w7_any'==1
        if `r(N)'>0 {
            if "`W7LIST'" != "" ///
                export excel ${IDENT} `W7LIST' if (w6!=1 | missing(w6)) & `__w7_any'==1 using ///
                    "${sec}/${LNG}_${mod}_`suf'_w7_filled_when_treat_no.xlsx", replace firstrow(varl) nol
            else ///
                export excel ${IDENT} if (w6!=1 | missing(w6)) & `__w7_any'==1 using ///
                    "${sec}/${LNG}_${mod}_`suf'_w7_filled_when_treat_no.xlsx", replace firstrow(varl) nol
        }

        // DK method must be exclusive
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if `__w7_dk'==1 & `__w7_any_other'==1
        if `r(N)'>0 {
            if "`W7LIST'" != "" ///
                export excel ${IDENT} `W7LIST' if `__w7_dk'==1 & `__w7_any_other'==1 using ///
                    "${sec}/${LNG}_${mod}_`suf'_w7_dk_with_others.xlsx", replace firstrow(varl) nol
            else ///
                export excel ${IDENT} if `__w7_dk'==1 & `__w7_any_other'==1 using ///
                    "${sec}/${LNG}_${mod}_`suf'_w7_dk_with_others.xlsx", replace firstrow(varl) nol
        }
    }
}

*/


}

	
********************************************************************************
**# (EL) ELECTRICITY — uses M12_elec.dta and el1–el5 variables
********************************************************************************

{
    use "$raw/${dta_file}_${date}_M12_elec.dta", clear

    cap drop *_clean
    la lang ${LNG}

    // here correcting the mistakes 
        // replace var = correctvalue if var == wrongvalue & hhid == "..."

    do "${wd}/fix/do/M12_elect.do"

    save "$dta/${dta_file}_${date}_M12_elec.dta", replace

    glo mod M12_elec
    confirmdir "${fix}/${mod}/"
        if _rc ~= 0 mkdir "${fix}/${mod}"
    glo sec "${wd}/fix/${date}/${mod}"
	
    export excel using "${fix}/${mod}/${dta_file}_${date}_M12_elec.xlsx", ///
        replace firstrow(var) nol



/// LOGIC CHECKS
{

/*
ELECTRICITY — key logic & consistency (HH-level)

1) Keys
   - hhid unique.

2) Code validity + required (asked of all unless gated)
   - el1 ∈ {1,2}; missing flagged. (availability)
   - el2 ∈ {1,2}; required if el1==1; blank if el1==2. (ownership)
   - el3 ∈ {1,2,3,4,96}; required if el1==1; blank if el1==2. (source)
   - el4 ∈ {1,2,3,99}; required if el1==1; blank if el1==2. (provider)
   - el5 numeric: ≥0; required if el1==1; blank if el1==2. (hours outage)
     Soft cap: >168 hours (more than a week) flagged.

3) Soft consistency
   - If el3==1 (local grid/provider) & el4==3 ("No electric system") → soft flag.
*/

    // Prefix labels with var name for clearer Excel headers
    foreach var of varlist _all {
        local vlab: variable label `var'
        la var `var' "`var': `vlab'"
    }

    // IDs included in each export
    glo IDENT "hhid_str date el1 el2 el3 el4 el5"

    // Counter
    local o = 0

    // ---------- 0) Keys ----------
    capture noisily isid hhid
    if (_rc) {
        duplicates tag hhid, gen(__dup_hh)
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if __dup_hh
        if `r(N)'>0 export excel ${IDENT} hhid if __dup_hh using ///
            "${sec}/${LNG}_${mod}_`suf'_dup_hhid.xlsx", replace firstrow(varl) nol
        drop __dup_hh
    }

    // Guard existence flags
    cap confirm var el1
    local hasEL1 = !_rc
    cap confirm var el2
    local hasEL2 = !_rc
    cap confirm var el3
    local hasEL3 = !_rc
    cap confirm var el4
    local hasEL4 = !_rc
    cap confirm var el5
    local hasEL5 = !_rc

    // ---------- 1) el1 availability: code validity & missing ----------
    if `hasEL1' {
        // bad code
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if !inlist(el1,1,2) & !missing(el1)
        if `r(N)'>0 export excel ${IDENT} el1 if !inlist(el1,1,2) & !missing(el1) using ///
            "${sec}/${LNG}_${mod}_`suf'_el1_badcode.xlsx", replace firstrow(varl) nol

        // missing
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if missing(el1)
        if `r(N)'>0 export excel ${IDENT} el1 if missing(el1) using ///
            "${sec}/${LNG}_${mod}_`suf'_el1_missing.xlsx", replace firstrow(varl) nol
    }

    // ---------- 2) el2 ownership: gating + code ----------
    if `hasEL2' {
        // bad code (anytime it's filled)
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if !inlist(el2,1,2) & !missing(el2)
        if `r(N)'>0 export excel ${IDENT} el2 if !inlist(el2,1,2) & !missing(el2) using ///
            "${sec}/${LNG}_${mod}_`suf'_el2_badcode.xlsx", replace firstrow(varl) nol

        // required when el1==1
        if `hasEL1' {
            local o = `o' + 1
            local suf = string(`o', "%02.0f")
            count if el1==1 & missing(el2)
            if `r(N)'>0 export excel ${IDENT} el1 el2 if el1==1 & missing(el2) using ///
                "${sec}/${LNG}_${mod}_`suf'_el2_missing_when_el1_yes.xlsx", replace firstrow(varl) nol

            // should be blank when el1==2
            local o = `o' + 1
            local suf = string(`o', "%02.0f")
            count if el1==2 & !missing(el2)
            if `r(N)'>0 export excel ${IDENT} el1 el2 if el1==2 & !missing(el2) using ///
                "${sec}/${LNG}_${mod}_`suf'_el2_filled_when_el1_no.xlsx", replace firstrow(varl) nol
        }
    }

    // ---------- 3) el3 source: gating + code ----------
    if `hasEL3' {
        // bad code (anytime it's filled)
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if !inlist(el3,1,2,3,4,96) & !missing(el3)
        if `r(N)'>0 export excel ${IDENT} el3 if !inlist(el3,1,2,3,4,96) & !missing(el3) using ///
            "${sec}/${LNG}_${mod}_`suf'_el3_badcode.xlsx", replace firstrow(varl) nol

        // required when el1==1
        if `hasEL1' {
            local o = `o' + 1
            local suf = string(`o', "%02.0f")
            count if el1==1 & missing(el3)
            if `r(N)'>0 export excel ${IDENT} el1 el3 if el1==1 & missing(el3) using ///
                "${sec}/${LNG}_${mod}_`suf'_el3_missing_when_el1_yes.xlsx", replace firstrow(varl) nol

            // should be blank when el1==2
            local o = `o' + 1
            local suf = string(`o', "%02.0f")
            count if el1==2 & !missing(el3)
            if `r(N)'>0 export excel ${IDENT} el1 el3 if el1==2 & !missing(el3) using ///
                "${sec}/${LNG}_${mod}_`suf'_el3_filled_when_el1_no.xlsx", replace firstrow(varl) nol
        }
    }

    // ---------- 4) el4 provider: gating + code + soft rule ----------
    if `hasEL4' {
        // bad code (anytime it's filled)
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if !inlist(el4,1,2,3,99) & !missing(el4)
        if `r(N)'>0 export excel ${IDENT} el4 if !inlist(el4,1,2,3,99) & !missing(el4) using ///
            "${sec}/${LNG}_${mod}_`suf'_el4_badcode.xlsx", replace firstrow(varl) nol

        // required when el1==1
        if `hasEL1' {
            local o = `o' + 1
            local suf = string(`o', "%02.0f")
            count if el1==1 & missing(el4)
            if `r(N)'>0 export excel ${IDENT} el1 el4 if el1==1 & missing(el4) using ///
                "${sec}/${LNG}_${mod}_`suf'_el4_missing_when_el1_yes.xlsx", replace firstrow(varl) nol

            // should be blank when el1==2
            local o = `o' + 1
            local suf = string(`o', "%02.0f")
            count if el1==2 & !missing(el4)
            if `r(N)'>0 export excel ${IDENT} el1 el4 if el1==2 & !missing(el4) using ///
                "${sec}/${LNG}_${mod}_`suf'_el4_filled_when_el1_no.xlsx", replace firstrow(varl) nol
        }

        // soft: grid source but provider == "No electric system"
        if `hasEL3' {
            local o = `o' + 1
            local suf = string(`o', "%02.0f")
            count if el3==1 & el4==3
            if `r(N)'>0 export excel ${IDENT} el3 el4 if el3==1 & el4==3 using ///
                "${sec}/${LNG}_${mod}_`suf'_el4_soft_grid_no_system.xlsx", replace firstrow(varl) nol
        }
    }

    // ---------- 5) el5 hours unavailable: gating + value checks ----------
    if `hasEL5' {
        // negative values (no DK code in new scheme)
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if !missing(el5) & el5<0
        if `r(N)'>0 export excel ${IDENT} el5 if !missing(el5) & el5<0 using ///
            "${sec}/${LNG}_${mod}_`suf'_el5_negative.xlsx", replace firstrow(varl) nol

        // soft cap: >168 hours in past week
        local o = `o' + 1
        local suf = string(`o', "%02.0f")
        count if el5>168 & el5!=.
        if `r(N)'>0 export excel ${IDENT} el5 if el5>168 & el5!=. using ///
            "${sec}/${LNG}_${mod}_`suf'_el5_over_168hrs.xlsx", replace firstrow(varl) nol

        // required when el1==1
        if `hasEL1' {
            local o = `o' + 1
            local suf = string(`o', "%02.0f")
            count if el1==1 & missing(el5)
            if `r(N)'>0 export excel ${IDENT} el1 el5 if el1==1 & missing(el5) using ///
                "${sec}/${LNG}_${mod}_`suf'_el5_missing_when_el1_yes.xlsx", replace firstrow(varl) nol

            // should be blank when el1==2
            local o = `o' + 1
            local suf = string(`o', "%02.0f")
            count if el1==2 & !missing(el5)
            if `r(N)'>0 export excel ${IDENT} el1 el5 if el1==2 & !missing(el5) using ///
                "${sec}/${LNG}_${mod}_`suf'_el5_filled_when_el1_no.xlsx", replace firstrow(varl) nol
        }
    }
}
}


********************************************************************************
**# (NET) INTERNET — LOGIC & CONSISTENCY CHECKS (renamed to N1–N6; uses M12_net.dta)
********************************************************************************

{
    use "$raw/${dta_file}_${date}_M12_net.dta", clear
	
    
	
    la lang ${LNG}

    // here correcting the mistakes 
        // replace var = correctvalue if var == wrongvalue & hhid == "..."

    do "${wd}/fix/do/M12_net.do"
	
	
	
	/// MULTIPLE TO SINGLE 
	
	
	******************************************************
	* n1: Internet at home (select_multiple binaries)
	* Create ranked single-choice variables n1_type1, n1_type2, ...
	******************************************************

	* --- 1) Value label (code = suffix of n1_# binary) ---
	capture label drop n1_type_eng
	label define n1_type_eng ///
		1 "Yes, Fixed (wired) broadband network" ///
		2 "Yes, Fixed (wireless) broadband network" ///
		3 "Yes, Satellite broadband network" ///
		4 "Yes, Mobile broadband network" ///
		5 "No" ///
		, replace

	* --- 2) Count selections and find max (how many ranked vars to create) ---
	egen n1_ntype = rowtotal(n1_1 n1_2 n1_3 n1_4 n1_5)
	quietly summarize n1_ntype, meanonly
	local max = r(max)

	* --- 3) Peel off selected types into ranked single-choice variables ---
	* Put 5 (No) last so it does not override real internet types
	local codes 1 2 3 4 5

	foreach c of local codes {
		gen byte n1_rem_`c' = n1_`c'
	}

	forvalues k = 1/`max' {
		gen n1_type`k' = .

		foreach c of local codes {
			replace n1_type`k' = `c' if n1_rem_`c' == 1 & missing(n1_type`k')
		}

		foreach c of local codes {
			replace n1_rem_`c' = 0 if n1_type`k' == `c'
		}

		label variable n1_type`k' "Internet at home (rank `k')"
		label values  n1_type`k' n1_type_eng
	}

	drop n1_rem_*
	
	order n1_ntype n1_type*, before(n1_txt)
	
	
	/// N2 
	
	
	******************************************************
	* n2: Internet access devices (select_multiple binaries)
	* Create ranked single-choice variables n2_dev1, n2_dev2, ...
	******************************************************

	* --- 1) Value label (code = suffix of n2_# binary) ---
	capture label drop n2_device_eng
	label define n2_device_eng ///
		1  "Personal computer (PC) / Desktop" ///
		2  "Laptop" ///
		3  "Tablet" ///
		4  "Smartphone" ///
		5  "Smart TV / Monitor" ///
		11 "Piso Net (coin-operated internet kiosk)" ///
		12 "Basic phone (non-smartphone with limited internet capability)" ///
		96 "Others" ///
		, replace

	* --- 2) Count selections and find max (how many ranked vars to create) ---
	egen n2_ndev = rowtotal(n2_1 n2_2 n2_3 n2_4 n2_5 n2_11 n2_12 n2_96)
	quietly summarize n2_ndev, meanonly
	local max = r(max)

	* --- 3) Peel off selected devices into ranked single-choice variables ---
	local codes 1 2 3 4 5 11 12 96

	foreach c of local codes {
		gen byte n2_rem_`c' = n2_`c'
	}

	forvalues k = 1/`max' {
		gen n2_dev`k' = .

		foreach c of local codes {
			replace n2_dev`k' = `c' if n2_rem_`c' == 1 & missing(n2_dev`k')
		}

		foreach c of local codes {
			replace n2_rem_`c' = 0 if n2_dev`k' == `c'
		}

		label variable n2_dev`k' "Internet access device (rank `k')"
		label values  n2_dev`k' n2_device_eng
	}

	drop n2_rem_*
		
		
	order n2_ndev n2_dev*, before(n2_txt)
	
	
	
	/// N3 
	
		
	******************************************************
	* n3: Internet subscription types (select_multiple binaries)
	* Create ranked single-choice variables n3_sub1, n3_sub2, ...
	******************************************************

	* --- 1) Value label (code = suffix of n3_# binary) ---
	capture label drop n3_sub_eng
	label define n3_sub_eng ///
		1  "Prepaid" ///
		2  "Postpaid / billed monthly by a provider" ///
		12 "Connecting to neighbor's WiFi" ///
		96 "Others" ///
		, replace

	* --- 2) Count selections and find max (how many ranked vars to create) ---
	egen n3_nsub = rowtotal(n3_1 n3_2 n3_12 n3_96)
	quietly summarize n3_nsub, meanonly
	local max = r(max)

	* --- 3) Peel off selected subscription types into ranked single-choice variables ---
	local codes 1 2 12 96

	foreach c of local codes {
		gen byte n3_rem_`c' = n3_`c'
	}

	forvalues k = 1/`max' {
		gen n3_sub`k' = .

		foreach c of local codes {
			replace n3_sub`k' = `c' if n3_rem_`c' == 1 & missing(n3_sub`k')
		}

		foreach c of local codes {
			replace n3_rem_`c' = 0 if n3_sub`k' == `c'
		}

		label variable n3_sub`k' "Internet subscription type (rank `k')"
		label values  n3_sub`k' n3_sub_eng
	}

	drop n3_rem_*
		
	
	order n3_nsub n3_sub*, before(n3_txt)
	
	
	/// N4 
	
		
	******************************************************
	* n4: Internet purposes (select_multiple binaries)
	* Create ranked single-choice variables n4_purp1, n4_purp2, ...
	******************************************************

	* --- 1) Value label (code = suffix of n4_# binary) ---
	capture label drop n4_purpose_eng
	label define n4_purpose_eng ///
		1  "Communication / social networking" ///
		2  "Payments / banking" ///
		3  "Search for information / news / current events" ///
		4  "Online shopping" ///
		5  "Online education" ///
		6  "Non-gig work" ///
		7  "Gig work" ///
		8  "Telehealth / medicine" ///
		9  "Use government services" ///
		10 "Access government information" ///
		11 "Search for jobs" ///
		12 "Entertainment / gaming" ///
		, replace

	* --- 2) Count selections and find max (how many ranked vars to create) ---
	egen n4_npurp = rowtotal(n4_1 n4_2 n4_3 n4_4 n4_5 n4_6 n4_7 n4_8 n4_9 n4_10 n4_11 n4_12)
	quietly summarize n4_npurp, meanonly
	local max = r(max)

	* --- 3) Peel off selected purposes into ranked single-choice variables ---
	local codes 1 2 3 4 5 6 7 8 9 10 11 12

	foreach c of local codes {
		gen byte n4_rem_`c' = n4_`c'
	}

	forvalues k = 1/`max' {
		gen n4_purp`k' = .

		foreach c of local codes {
			replace n4_purp`k' = `c' if n4_rem_`c' == 1 & missing(n4_purp`k')
		}

		foreach c of local codes {
			replace n4_rem_`c' = 0 if n4_purp`k' == `c'
		}

		label variable n4_purp`k' "Internet purpose (rank `k')"
		label values  n4_purp`k' n4_purpose_eng
	}

	drop n4_rem_*
		
	order n4_npurp n4_purp*, before(n4_txt)	
	
	
	
	******************************************************
	* n6: Access internet outside home (select_multiple binaries)
	* Create ranked single-choice variables n6_acc1, n6_acc2, ...
	******************************************************

	* --- 1) Value label (code = suffix of n6_# binary) ---
	capture label drop n6_access_eng
	label define n6_access_eng ///
		1 "Piso WiFi" ///
		2 "Hotspots from government offices" ///
		3 "Hotspots from private establishments (malls, cafes, etc.)" ///
		4 "School / office" ///
		5 "Neighbors / other households" ///
		6 "Mobile broadband network / mobile data" ///
		7 "None" ///
		, replace

	* --- 2) Count selections and find max (how many ranked vars to create) ---
	egen n6_nacc = rowtotal(n6_1 n6_2 n6_3 n6_4 n6_5 n6_6 n6_7)
	quietly summarize n6_nacc, meanonly
	local max = r(max)

	* --- 3) Peel off selected access options into ranked single-choice variables ---
	* Put 7 (None) last so it doesn't override real access options
	local codes 1 2 3 4 5 6 7

	foreach c of local codes {
		gen byte n6_rem_`c' = n6_`c'
	}

	forvalues k = 1/`max' {
		gen n6_acc`k' = .

		foreach c of local codes {
			replace n6_acc`k' = `c' if n6_rem_`c' == 1 & missing(n6_acc`k')
		}

		foreach c of local codes {
			replace n6_rem_`c' = 0 if n6_acc`k' == `c'
		}

		label variable n6_acc`k' "Access internet outside home (rank `k')"
		label values  n6_acc`k' n6_access_eng
	}

	drop n6_rem_*
		
	
	order n6_nacc n6_acc*, before(n6_txt)	
	
	
	
	/// DROP MULTIPLES 
	
	drop n1_1 - n1_5
	drop n2_1 - n2_96
	drop n3_1 - n3_96
	drop n4_1 - n4_12
	drop n6_1 - n6_7
	

    save "$dta/${dta_file}_${date}_M12_net.dta", replace

    glo mod M12_net
    confirmdir "${fix}/${mod}/"
        if _rc ~= 0 mkdir "${fix}/${mod}"
    glo sec "${wd}/fix/${date}/${mod}"
	
    export excel using "${fix}/${mod}/${dta_file}_${date}_M12_net.xlsx", ///
        replace firstrow(var) nol



/*

/// LOGIC CHECKS (ALL MULTI-SELECT GATING USES n#_<code> DUMMIES)

{

/*
N1 n1_* (1–4 any=has internet; 5=No):
  - Missing N1 if sum(n1_1..n1_5)==0.
  - Conflict: n1_5==1 with any of n1_1..n1_4==1.

N2 n2_* (1,2,3,4,5,96) — asked only if any N1 in {1..4}:
  - If has internet, require ≥1 device; if no internet, should be blank (sum==0).

N3 n3_* (1,2,96) — asked only if any N1 in {1..4}:
  - If has internet, require ≥1; if no internet, should be blank.

N4 n4_* (1..12) — asked only if any N1 in {1..4}:
  - If has internet, require ≥1; if no internet, should be blank.

N5 n5 (single) — asked only if any N1 in {1..4}:
  - If has internet: must be 1/2 and present.
  - If no internet: should be blank.

N6 n6_* (1..7; 7=None) — asked of all:
  - If n6_7==1, no other (1..6) should be selected.
*/

    // Prefix labels with var name for clearer Excel headers
    foreach var of varlist _all {
        local vlab: variable label `var'
        la var `var' "`var': `vlab'"
    }

    // IDs in each export
    glo IDENT "hhid_str date"

    // Counter
    local o = 0
	
	// Drop txt
	
	drop *_txt

    // ---------- Household key check ----------
    capture noisily isid hhid
    if _rc {
        duplicates tag hhid, gen(__dup_hh)
        local o   = `++o'
        local suf = string(`o', "%02.0f")
        count if __dup_hh
        if `r(N)'>0 export excel ${IDENT} hhid if __dup_hh using ///
            "${sec}/${LNG}_${mod}_`suf'_dup_hhid.xlsx", replace firstrow(varl) nol
        drop __dup_hh
    }

    // ---------- N1: derive has/no internet from dummies ----------
    tempvar n1_yes_ct anyNet hasNoNet n1_all_ct

    cap unab _N1YES : n1_1 n1_2 n1_3 n1_4
    if !_rc egen double `n1_yes_ct' = rowtotal(`_N1YES'), missing

    cap confirm var n1_5
    if !_rc gen byte `hasNoNet' = (n1_5==1)

    if (!_rc) & ("`_N1YES'"!="") egen double `n1_all_ct' = rowtotal(`_N1YES' n1_5), missing

    // anyNet = 1 if any of 1..4 selected
    cap gen byte `anyNet' = (`n1_yes_ct'>0) if !missing(`n1_yes_ct')

    // 1a) N1 missing (no option chosen at all)
    if "`n1_all_ct'"!="" {
        local o   = `++o'
        local suf = string(`o', "%02.0f")
        count if `n1_all_ct'==0
        if `r(N)'>0 export excel ${IDENT} n1_* if `n1_all_ct'==0 using ///
            "${sec}/${LNG}_${mod}_`suf'_n1_missing.xlsx", replace firstrow(varl) nol
    }

    // 1b) N1 conflict: "No" together with any Yes (1..4)
    if "`hasNoNet'"!="" & "`anyNet'"!="" {
        local o   = `++o'
        local suf = string(`o', "%02.0f")
        count if `hasNoNet'==1 & `anyNet'==1
        if `r(N)'>0 export excel ${IDENT} n1_* if `hasNoNet'==1 & `anyNet'==1 using ///
            "${sec}/${LNG}_${mod}_`suf'_n1_no_with_yes_conflict.xlsx", replace firstrow(varl) nol
    }

    // ---------- N2: devices gating ----------
    tempvar n2_ct
    cap unab _N2 : n2_*
    if !_rc egen double `n2_ct' = rowtotal(`_N2'), missing

    if "`anyNet'"!="" & "`n2_ct'"!="" {
        // Need ≥1 when has internet
        local o   = `++o'
        local suf = string(`o', "%02.0f")
        count if `anyNet'==1 & (`n2_ct'<=0)
        if `r(N)'>0 export excel ${IDENT} n1_* n2_* if `anyNet'==1 & (`n2_ct'<=0) using ///
            "${sec}/${LNG}_${mod}_`suf'_n2_missing_when_has_net.xlsx", replace firstrow(varl) nol

        // Should be blank when no internet
        local o   = `++o'
        local suf = string(`o', "%02.0f")
        count if `anyNet'==0 & (`n2_ct'>0)
        if `r(N)'>0 export excel ${IDENT} n1_* n2_* if `anyNet'==0 & (`n2_ct'>0) using ///
            "${sec}/${LNG}_${mod}_`suf'_n2_filled_when_no_net.xlsx", replace firstrow(varl) nol
    }

    // ---------- N3: subscription gating ----------
    tempvar n3_ct
    cap unab _N3 : n3_*
    if !_rc egen double `n3_ct' = rowtotal(`_N3'), missing

    if "`anyNet'"!="" & "`n3_ct'"!="" {
        local o   = `++o'
        local suf = string(`o', "%02.0f")
        count if `anyNet'==1 & (`n3_ct'<=0)
        if `r(N)'>0 export excel ${IDENT} n1_* n3_* if `anyNet'==1 & (`n3_ct'<=0) using ///
            "${sec}/${LNG}_${mod}_`suf'_n3_missing_when_has_net.xlsx", replace firstrow(varl) nol

        local o   = `++o'
        local suf = string(`o', "%02.0f")
        count if `anyNet'==0 & (`n3_ct'>0)
        if `r(N)'>0 export excel ${IDENT} n1_* n3_* if `anyNet'==0 & (`n3_ct'>0) using ///
            "${sec}/${LNG}_${mod}_`suf'_n3_filled_when_no_net.xlsx", replace firstrow(varl) nol
    }

    // ---------- N4: purposes gating ----------
    tempvar n4_ct
    cap unab _N4 : n4_*
    if !_rc egen double `n4_ct' = rowtotal(`_N4'), missing

    if "`anyNet'"!="" & "`n4_ct'"!="" {
        local o   = `++o'
        local suf = string(`o', "%02.0f")
        count if `anyNet'==1 & (`n4_ct'<=0)
        if `r(N)'>0 export excel ${IDENT} n1_* n4_* if `anyNet'==1 & (`n4_ct'<=0) using ///
            "${sec}/${LNG}_${mod}_`suf'_n4_missing_when_has_net.xlsx", replace firstrow(varl) nol

        local o   = `++o'
        local suf = string(`o', "%02.0f")
        count if `anyNet'==0 & (`n4_ct'>0)
        if `r(N)'>0 export excel ${IDENT} n1_* n4_* if `anyNet'==0 & (`n4_ct'>0) using ///
            "${sec}/${LNG}_${mod}_`suf'_n4_filled_when_no_net.xlsx", replace firstrow(varl) nol
    }

    // ---------- N5: interruption validity & gating ----------
    cap confirm var n5
    if !_rc & "`anyNet'"!="" {
        // bad code
        local o   = `++o'
        local suf = string(`o', "%02.0f")
        count if !inlist(n5,1,2) & !missing(n5)
        if `r(N)'>0 export excel ${IDENT} n5 n1_* if !inlist(n5,1,2) & !missing(n5) using ///
            "${sec}/${LNG}_${mod}_`suf'_n5_badcode.xlsx", replace firstrow(varl) nol

        // missing when has internet
        local o   = `++o'
        local suf = string(`o', "%02.0f")
        count if `anyNet'==1 & missing(n5)
        if `r(N)'>0 export excel ${IDENT} n5 n1_* if `anyNet'==1 & missing(n5) using ///
            "${sec}/${LNG}_${mod}_`suf'_n5_missing_when_has_net.xlsx", replace firstrow(varl) nol

        // filled when no internet
        local o   = `++o'
        local suf = string(`o', "%02.0f")
        count if `anyNet'==0 & !missing(n5)
        if `r(N)'>0 export excel ${IDENT} n5 n1_* if `anyNet'==0 & !missing(n5) using ///
            "${sec}/${LNG}_${mod}_`suf'_n5_filled_when_no_net.xlsx", replace firstrow(varl) nol
    }

}


*/

}

	
********************************************************************************
**# (DUR) DURABLES — LOGIC & CONSISTENCY CHECKS (HH-level; uses HC* vars)
**   Source: $raw/${dta_file}_${date}_M13_hc.dta   (from the new labeling do-file)
********************************************************************************

{
    use "$raw/${dta_file}_${date}_M13_hc.dta", clear

    // here correcting the mistakes 
        // replace var = correctvalue if var == wrongvalue & hhid == "..."

    do "${wd}/fix/do/M13.do"

    save "$dta/${dta_file}_${date}_M13_hc.dta", replace
	
    glo mod M13
    confirmdir "${fix}/${mod}/"
        if _rc ~= 0 mkdir "${fix}/${mod}"
    glo sec "${wd}/fix/${date}/${mod}"
	
    export excel using "${fix}/${mod}/${dta_file}_${date}_M13_hc.xlsx", ///
        replace firstrow(var) nol




/// LOGIC CHECKS
{

/*
HC1 ASSETS (counts): each hc1_* must be integer in [0,20]; missing flagged.
HC2 SERVICES (maid/cook/driver/other): codes must be 1/2; missing flagged.
HC3 COOKING FUELS (electricity/LPG/kerosene/fuelwood/charcoal/other): codes 1/2; missing flagged.
Soft cross-check: stove present (hc1_4 or hc1d) but all fuels = No → flag.

Exports follow the numbering, headers use variable labels.
*/

    // Prefix labels with var name for clearer Excel headers
    foreach var of varlist _all {
        local vlab : variable label `var'
        la var `var' "`var': `vlab'"
    }

    // IDs included in each export
    glo IDENT "hhid_str date"

    // Counter
    local o = 0

    // ---------- Household key ----------
    capture noisily isid hhid
    if _rc {
        duplicates tag hhid, gen(__dup_hh)
        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if __dup_hh
        if `r(N)'>0 export excel ${IDENT} hhid if __dup_hh using ///
            "${sec}/${LNG}_${mod}_`suf'_dup_hhid.xlsx", replace firstrow(varl) nol
        drop __dup_hh
    }

    // ---------- HC1: Assets 0–20, integer, not missing ----------
    // Collect existing asset vars (underscore and/or lettered)
    local ASSETS
    foreach v in hc1_1 hc1_2 hc1_3 hc1_4 hc1_5 hc1_6 hc1_7 hc1_8 ///
                 hc1a  hc1b  hc1c  hc1d  hc1e  hc1f  hc1g  hc1h {
        capture confirm numeric variable `v'
        if !_rc local ASSETS "`ASSETS' `v'"
    }

    if "`ASSETS'" != "" {
        tempvar __minA __maxA __nonint __allmiss
        egen double `__minA' = rowmin(`ASSETS')
        egen double `__maxA' = rowmax(`ASSETS')

        gen byte `__nonint' = 0
        foreach v of local ASSETS {
            replace `__nonint' = 1 if (`v'!=floor(`v')) & !missing(`v')
        }

        egen byte `__allmiss' = rownonmiss(`ASSETS')
        // 1) Negative values present
        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if `__minA' < 0
        if `r(N)'>0 export excel ${IDENT} `ASSETS' if `__minA' < 0 using ///
            "${sec}/${LNG}_${mod}_`suf'_assets_negative.xlsx", replace firstrow(varl) nol

        // 2) >20 values present
        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if `__maxA' > 20
        if `r(N)'>0 export excel ${IDENT} `ASSETS' if `__maxA' > 20 using ///
            "${sec}/${LNG}_${mod}_`suf'_assets_over20.xlsx", replace firstrow(varl) nol

        // 3) Non-integers
        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if `__nonint'==1
        if `r(N)'>0 export excel ${IDENT} `ASSETS' if `__nonint'==1 using ///
            "${sec}/${LNG}_${mod}_`suf'_assets_noninteger.xlsx", replace firstrow(varl) nol

        // 4) All asset items missing (no response on HC1 block)
        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if `__allmiss'==0
        if `r(N)'>0 export excel ${IDENT} `ASSETS' if `__allmiss'==0 using ///
            "${sec}/${LNG}_${mod}_`suf'_assets_all_missing.xlsx", replace firstrow(varl) nol
    }

    // ---------- HC2: Services (each should be 1/2, and present) ----------
    local SERS
    foreach v in hc2a hc2b hc2c hc2d {
        capture confirm numeric variable `v'
        if !_rc local SERS "`SERS' `v'"
    }
    if "`SERS'" != "" {
        tempvar __bad_sers __miss_sers
        gen byte `__bad_sers' = 0
        gen byte `__miss_sers' = 0
        foreach v of local SERS {
            replace `__bad_sers' = 1 if !inlist(`v',1,2) & !missing(`v')
            replace `__miss_sers' = 1 if missing(`v')
        }

        // 5) Any bad code in HC2
        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if `__bad_sers'==1
        if `r(N)'>0 export excel ${IDENT} `SERS' if `__bad_sers'==1 using ///
            "${sec}/${LNG}_${mod}_`suf'_hc2_badcode.xlsx", replace firstrow(varl) nol

        // 6) Any missing response in HC2
        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if `__miss_sers'==1
        if `r(N)'>0 export excel ${IDENT} `SERS' if `__miss_sers'==1 using ///
            "${sec}/${LNG}_${mod}_`suf'_hc2_missing.xlsx", replace firstrow(varl) nol
    }

    // ---------- HC3: Cooking fuels (each should be 1/2, and present) ----------
    local FUELS
    foreach v in hc3a hc3b hc3c hc3d hc3e hc3f ///
                 hc3_1 hc3_2 hc3_3 hc3_4 hc3_5 hc3_6 {
        capture confirm numeric variable `v'
        if !_rc local FUELS "`FUELS' `v'"
    }
    if "`FUELS'" != "" {
        tempvar __bad_fuel __miss_fuel __fy __fnm __allno
        gen byte   `__bad_fuel' = 0
        gen byte   `__miss_fuel' = 0
        gen double `__fy'  = 0   // yes count
        gen double `__fnm' = 0   // non-missing count
        foreach v of local FUELS {
            replace `__bad_fuel' = 1 if !inlist(`v',1,2) & !missing(`v')
            replace `__miss_fuel' = 1 if missing(`v')
            replace `__fy'  = `__fy'  + (`v'==1) if !missing(`v')
            replace `__fnm' = `__fnm' + (!missing(`v'))
        }

        // 7) Any bad code in HC3
        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if `__bad_fuel'==1
        if `r(N)'>0 export excel ${IDENT} `FUELS' if `__bad_fuel'==1 using ///
            "${sec}/${LNG}_${mod}_`suf'_hc3_badcode.xlsx", replace firstrow(varl) nol

        // 8) Any missing response in HC3
        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if `__miss_fuel'==1
        if `r(N)'>0 export excel ${IDENT} `FUELS' if `__miss_fuel'==1 using ///
            "${sec}/${LNG}_${mod}_`suf'_hc3_missing.xlsx", replace firstrow(varl) nol

        // 9) Soft: all fuels answered and all are "No"
        local K : word count `FUELS'
        gen byte `__allno' = (`__fnm'==`K' & `__fy'==0)
        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if `__allno'==1
        if `r(N)'>0 export excel ${IDENT} `FUELS' if `__allno'==1 using ///
            "${sec}/${LNG}_${mod}_`suf'_hc3_all_no_fuels.xlsx", replace firstrow(varl) nol
    }

    // ---------- Cross-check: stove present but all fuels = No ----------
    // Stove count can be in hc1_4 or hc1d (use whichever exists)
    tempvar __stove
    gen byte `__stove' = .
    capture confirm numeric variable hc1_4
    if !_rc replace `__stove' = (hc1_4>0) if !missing(hc1_4)
    else {
        capture confirm numeric variable hc1d
        if !_rc replace `__stove' = (hc1d>0) if !missing(hc1d)
    }

    if "`FUELS'"!="" & "`: type `__stove''" != "" {
        tempvar __fy2 __fnm2 __allno2
        gen double `__fy2'  = 0
        gen double `__fnm2' = 0
        foreach v of local FUELS {
            replace `__fy2'  = `__fy2'  + (`v'==1) if !missing(`v')
            replace `__fnm2' = `__fnm2' + (!missing(`v'))
        }
        local K2 : word count `FUELS'
        gen byte `__allno2' = (`__fnm2'==`K2' & `__fy2'==0)

        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if `__stove'==1 & `__allno2'==1
        if `r(N)'>0 export excel ${IDENT} hc1_4 hc1d `FUELS' if `__stove'==1 & `__allno2'==1 using ///
            "${sec}/${LNG}_${mod}_`suf'_stove_but_no_fuels.xlsx", replace firstrow(varl) nol
    }
}
}


********************************************************************************
**# (VW) VIEWS — CLEAN SAVE + LOGIC & CONSISTENCY CHECKS (HH-level)
**   Uses NEW labels (v1..v10e). Source dta from labeling file: M14_view.dta
********************************************************************************

{
    use "$raw/${dta_file}_${date}_M14_view.dta", clear

    // Bring in a HH flag for having any child (<18) from roster
    preserve
        use "$raw/${dta_file}_${date}_M01_roster.dta", clear
        keep hhid* age
        cap drop if missing(hhid)
        gen byte __is_child = (age<18) if !missing(age)
        bys hhid: egen byte hh_has_child_u18 = max(__is_child)
        keep hhid* hh_has_child_u18
        duplicates drop
        tempfile childflag
        save `childflag', replace
    restore
    merge 1:1 hhid using `childflag', nogen

    la lang ${LNG}

    // here correcting the mistakes 
        // replace var = correctvalue if var == wrongvalue & hhid == "..."

    do "${wd}/fix/do/M14.do"

    save "$dta/${dta_file}_${date}_M14_view.dta", replace

    glo mod M14
    confirmdir "${fix}/${mod}/"
        if _rc ~= 0 mkdir "${fix}/${mod}"
    glo sec "${wd}/fix/${date}/${mod}"
	
    export excel using "${fix}/${mod}/${dta_file}_${date}_M14_view.xlsx", ///
        replace firstrow(var) nol




/// LOGIC CHECKS
{

/*
V1..V2, V5..V8, V9 (a,b,c,d,e,g,h,i,j,k), V10 (a..e): single codes — bad codes + missing.
V3 & V4 (children-only): if hh_has_child_u18==1 → must be filled & valid;
                         if hh_has_child_u18!=1 → should be blank.
V9f (education worry): codes 1–5; 6 allowed only when no children.
Keys duplicated (hh-level) flagged.
*/

    // Prefix labels with var name for clearer Excel headers
    foreach var of varlist _all {
        local vlab: variable label `var'
        la var `var' "`var': `vlab'"
    }

    // IDs included in each export
    glo IDENT "hhid_str date hh_has_child_u18 v1 v2 v3 v4 v5 v6 v7 v8"

    // Counter
    local o = 0

    // ---------------- Keys (hh-level uniqueness) ----------------
    capture noisily isid hhid
    if _rc {
        duplicates tag hhid, gen(__dup_hh)
        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if __dup_hh
        if `r(N)'>0 export excel ${IDENT} hhid if __dup_hh using ///
            "${sec}/${LNG}_${mod}_`suf'_dup_hhid.xlsx", replace firstrow(varl) nol
        drop __dup_hh
    }

    // ---------------- V1 ----------------
    cap confirm var v1
    if !_rc {
        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if !inlist(v1,1,2,3,4,5) & !missing(v1)
        if `r(N)'>0 export excel ${IDENT} v1 if !inlist(v1,1,2,3,4,5) & !missing(v1) using ///
            "${sec}/${LNG}_${mod}_`suf'_v1_badcode.xlsx", replace firstrow(varl) nol

        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if missing(v1)
        if `r(N)'>0 export excel ${IDENT} v1 if missing(v1) using ///
            "${sec}/${LNG}_${mod}_`suf'_v1_missing.xlsx", replace firstrow(varl) nol
    }

    // ---------------- V2 ----------------
    cap confirm var v2
    if !_rc {
        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if !inlist(v2,1,2,3,4,5) & !missing(v2)
        if `r(N)'>0 export excel ${IDENT} v2 if !inlist(v2,1,2,3,4,5) & !missing(v2) using ///
            "${sec}/${LNG}_${mod}_`suf'_v2_badcode.xlsx", replace firstrow(varl) nol

        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if missing(v2)
        if `r(N)'>0 export excel ${IDENT} v2 if missing(v2) using ///
            "${sec}/${LNG}_${mod}_`suf'_v2_missing.xlsx", replace firstrow(varl) nol
    }

    // ---------------- V3 (children-only) ----------------
    cap confirm var v3
    if !_rc {
        // Valid codes
        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if !inlist(v3,1,2,3,4,5) & !missing(v3)
        if `r(N)'>0 export excel ${IDENT} v3 if !inlist(v3,1,2,3,4,5) & !missing(v3) using ///
            "${sec}/${LNG}_${mod}_`suf'_v3_badcode.xlsx", replace firstrow(varl) nol

        // Missing when has child
        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if hh_has_child_u18==1 & missing(v3)
        if `r(N)'>0 export excel ${IDENT} v3 hh_has_child_u18 if hh_has_child_u18==1 & missing(v3) using ///
            "${sec}/${LNG}_${mod}_`suf'_v3_missing_when_has_child.xlsx", replace firstrow(varl) nol

        // Filled when no child
        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if (hh_has_child_u18!=1 | missing(hh_has_child_u18)) & !missing(v3)
        if `r(N)'>0 export excel ${IDENT} v3 hh_has_child_u18 if (hh_has_child_u18!=1 | missing(hh_has_child_u18)) & !missing(v3) using ///
            "${sec}/${LNG}_${mod}_`suf'_v3_filled_when_no_child.xlsx", replace firstrow(varl) nol
    }

    // ---------------- V4 (children-only) ----------------
    cap confirm var v4
    if !_rc {
        // Valid codes (1..6)
        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if !inlist(v4,1,2,3,4,5,6) & !missing(v4)
        if `r(N)'>0 export excel ${IDENT} v4 if !inlist(v4,1,2,3,4,5,6) & !missing(v4) using ///
            "${sec}/${LNG}_${mod}_`suf'_v4_badcode.xlsx", replace firstrow(varl) nol

        // Missing when has child
        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if hh_has_child_u18==1 & missing(v4)
        if `r(N)'>0 export excel ${IDENT} v4 hh_has_child_u18 if hh_has_child_u18==1 & missing(v4) using ///
            "${sec}/${LNG}_${mod}_`suf'_v4_missing_when_has_child.xlsx", replace firstrow(varl) nol

        // Filled when no child
        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if (hh_has_child_u18!=1 | missing(hh_has_child_u18)) & !missing(v4)
        if `r(N)'>0 export excel ${IDENT} v4 hh_has_child_u18 if (hh_has_child_u18!=1 | missing(hh_has_child_u18)) & !missing(v4) using ///
            "${sec}/${LNG}_${mod}_`suf'_v4_filled_when_no_child.xlsx", replace firstrow(varl) nol
    }

    // ---------------- V5 ----------------
    cap confirm var v5
    if !_rc {
        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if !inlist(v5,1,2,3,4,5) & !missing(v5)
        if `r(N)'>0 export excel ${IDENT} v5 if !inlist(v5,1,2,3,4,5) & !missing(v5) using ///
            "${sec}/${LNG}_${mod}_`suf'_v5_badcode.xlsx", replace firstrow(varl) nol

        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if missing(v5)
        if `r(N)'>0 export excel ${IDENT} v5 if missing(v5) using ///
            "${sec}/${LNG}_${mod}_`suf'_v5_missing.xlsx", replace firstrow(varl) nol
    }

    // ---------------- V6 ----------------
    cap confirm var v6
    if !_rc {
        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if !inlist(v6,1,2,3,4,99) & !missing(v6)
        if `r(N)'>0 export excel ${IDENT} v6 if !inlist(v6,1,2,3,4,99) & !missing(v6) using ///
            "${sec}/${LNG}_${mod}_`suf'_v6_badcode.xlsx", replace firstrow(varl) nol

        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if missing(v6)
        if `r(N)'>0 export excel ${IDENT} v6 if missing(v6) using ///
            "${sec}/${LNG}_${mod}_`suf'_v6_missing.xlsx", replace firstrow(varl) nol
    }

    // ---------------- V7 ----------------
    cap confirm var v7
    if !_rc {
        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if !inlist(v7,1,2,3,4,5,6,7,8,9) & !missing(v7)
        if `r(N)'>0 export excel ${IDENT} v7 if !inlist(v7,1,2,3,4,5,6,7,8,9) & !missing(v7) using ///
            "${sec}/${LNG}_${mod}_`suf'_v7_badcode.xlsx", replace firstrow(varl) nol

        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if missing(v7)
        if `r(N)'>0 export excel ${IDENT} v7 if missing(v7) using ///
            "${sec}/${LNG}_${mod}_`suf'_v7_missing.xlsx", replace firstrow(varl) nol
    }

    // ---------------- V8 ----------------
    cap confirm var v8
    if !_rc {
        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if !inlist(v8,1,2,3,4,5,99) & !missing(v8)
        if `r(N)'>0 export excel ${IDENT} v8 if !inlist(v8,1,2,3,4,5,99) & !missing(v8) using ///
            "${sec}/${LNG}_${mod}_`suf'_v8_badcode.xlsx", replace firstrow(varl) nol

        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if missing(v8)
        if `r(N)'>0 export excel ${IDENT} v8 if missing(v8) using ///
            "${sec}/${LNG}_${mod}_`suf'_v8_missing.xlsx", replace firstrow(varl) nol
    }

    // ---------------- V9 items ----------------
    // Items with 1..5 only
    local V9_5  "v9a v9b v9c v9d v9e v9g v9h v9i v9j v9k"
    foreach v of local V9_5 {
        cap confirm var `v'
        if !_rc {
            local o = `++o'
            local suf = string(`o', "%02.0f")
            count if !inlist(`v',1,2,3,4,5) & !missing(`v')
            if `r(N)'>0 export excel ${IDENT} `v' if !inlist(`v',1,2,3,4,5) & !missing(`v') using ///
                "${sec}/${LNG}_${mod}_`suf'_`v'_badcode.xlsx", replace firstrow(varl) nol

            local o = `++o'
            local suf = string(`o', "%02.0f")
            count if missing(`v')
            if `r(N)'>0 export excel ${IDENT} `v' if missing(`v') using ///
                "${sec}/${LNG}_${mod}_`suf'_`v'_missing.xlsx", replace firstrow(varl) nol
        }
    }

    // V9f: allows 6=No children
    cap confirm var v9f
    if !_rc {
        // bad code
        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if !inlist(v9f,1,2,3,4,5,6) & !missing(v9f)
        if `r(N)'>0 export excel ${IDENT} v9f if !inlist(v9f,1,2,3,4,5,6) & !missing(v9f) using ///
            "${sec}/${LNG}_${mod}_`suf'_v9f_badcode.xlsx", replace firstrow(varl) nol

        // missing
        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if missing(v9f)
        if `r(N)'>0 export excel ${IDENT} v9f if missing(v9f) using ///
            "${sec}/${LNG}_${mod}_`suf'_v9f_missing.xlsx", replace firstrow(varl) nol

        // No children but answered 1–5
        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if (hh_has_child_u18!=1 | missing(hh_has_child_u18)) & inlist(v9f,1,2,3,4,5)
        if `r(N)'>0 export excel ${IDENT} v9f hh_has_child_u18 if (hh_has_child_u18!=1 | missing(hh_has_child_u18)) & inlist(v9f,1,2,3,4,5) using ///
            "${sec}/${LNG}_${mod}_`suf'_v9f_answered_without_children.xlsx", replace firstrow(varl) nol

        // Has children but selected 6=No child
        local o = `++o'
        local suf = string(`o', "%02.0f")
        count if hh_has_child_u18==1 & v9f==6
        if `r(N)'>0 export excel ${IDENT} v9f hh_has_child_u18 if hh_has_child_u18==1 & v9f==6 using ///
            "${sec}/${LNG}_${mod}_`suf'_v9f_nochild_but_has_children.xlsx", replace firstrow(varl) nol
    }

    // ---------------- V10 items (a..e: 1–5) ----------------
    local V10 "v10a v10b v10c v10d v10e"
    foreach v of local V10 {
        cap confirm var `v'
        if !_rc {
            local o = `++o'
            local suf = string(`o', "%02.0f")
            count if !inlist(`v',1,2,3,4,5) & !missing(`v')
            if `r(N)'>0 export excel ${IDENT} `v' if !inlist(`v',1,2,3,4,5) & !missing(`v') using ///
                "${sec}/${LNG}_${mod}_`suf'_`v'_badcode.xlsx", replace firstrow(varl) nol

            local o = `++o'
            local suf = string(`o', "%02.0f")
            count if missing(`v')
            if `r(N)'>0 export excel ${IDENT} `v' if missing(`v') using ///
                "${sec}/${LNG}_${mod}_`suf'_`v'_missing.xlsx", replace firstrow(varl) nol
        }
    }
}
}
	
	
*******************************************************************************
**# (X) NEXT       
********************************************************************************
{

	use "$raw/${dta_file}_${date}_M15_next.dta", clear
	
	
	/// LOGIC CHECKS
	
	
	glo mod M15
    confirmdir "${fix}/${mod}/"
        if _rc ~= 0 mkdir "${fix}/${mod}"
    glo sec "${wd}/fix/${date}/${mod}"
	
    export excel using "${fix}/${mod}/${dta_file}_${date}_M15_next.xlsx", ///
        replace firstrow(var) nol 
	
	
	cap do "${wd}/fix/do/M15.do"
	
	
	save "$dta/${dta_file}_${date}_M15_next.dta", replace
	

	}	


	
clear all	
		