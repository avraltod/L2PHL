* ========================================================================= *
* Project: Thematic Brief (IDPS) in Philippines
* Dataset: L2Phil Baseline
* Program: Create figures
* by Dilnovoz Abdurazzakova 
* Last updated: 01/22/2026
* ========================================================================= */

	clear
	clear mata
	clear matrix
	set more off

// 	glo root "~/Dropbox/DA/L2Geo/CAPI"
	glo root "/Users/dilnovozabdurazzakova/Library/CloudStorage/Dropbox/Philippines/CAPI"

	glo wd "${root}/3_dta2brf"
	cd "$wd"

	glo date 20251015							// match with the latest updates on the data
	glo dta_file l2phl_${date}					// choose the name for the data set 
	glo LNG ENG 									// change language for variable labels and value labels

	glo dta "${root}/1_odk2dta/dta/$date"
	glo in  "${wd}/input"
	glo out "${wd}/output"
	glo tab "${wd}/tables"
	glo png "${wd}/png"
	glo fig "${wd}/figures"	

	
	if 1 {
// 		copy "${root}/2_dta2pov/output/l2arm_baseline_weight@1.dta"  ///
// 				"$in/l2arm_baseline_weight@1.dta", replace 
		copy "${dta}/${dta_file}_M03_emp.dta"  ///
				"$in/${dta_file}_M03_emp.dta", replace 
		copy "${dta}/${dta_file}_M14_view.dta"  ///
				"$in/${dta_file}_M14_view.dta", replace
		copy "${dta}/${dta_file}_M06_mig.dta"  ///
				"$in/${dta_file}_M06_mig.dta", replace	
		copy "${dta}/${dta_file}_M07_med.dta"  ///
				"$in/${dta_file}_M07_med.dta", replace		
		copy "${dta}/${dta_file}_M12_elec.dta"  ///
				"$in/${dta_file}_M12_elec.dta", replace		
		copy "${dta}/${dta_file}_M12_net.dta"  ///
				"$in/${dta_file}_M12_net.dta", replace		
		copy "${dta}/${dta_file}_M02_edu.dta"  ///
				"$in/${dta_file}_M02_edu.dta", replace	
		copy "${dta}/${dta_file}_M00_passport.dta"  ///
				"$in/${dta_file}_M00_passport.dta", replace	
		copy "${dta}/${dta_file}_M08_ssb.dta"  ///
				"$in/${dta_file}_M08_ssb.dta", replace	
		copy "${dta}/${dta_file}_M09_nh.dta"  ///
				"$in/${dta_file}_M09_nh.dta", replace		
		copy "${dta}/${dta_file}_M14_view.dta"  ///
				"$in/${dta_file}_M14_view.dta", replace		
		copy "${dta}/${dta_file}_M01_roster.dta"  ///
				"$in/${dta_file}_M01_roster.dta", replace											
		copy "${dta}/final_weights.dta"  ///
				"$in/weights_ind.dta", replace						
	}
	



* Load Passport data with weights


use "$in/${dta_file}_M01_roster.dta", clear

merge m:1 hhid using "$in/${dta_file}_M00_passport.dta", assert(3) keep(3) nogen keepusing(locale region)
merge 1:1 hhid fmid using "$in/weights_ind.dta",  keep(3) nogen keepusing(indw popw hhw tag_hh)



 gen macro_region = .

* NCR
replace macro_region = 1 if region == 13

* Luzon excluding NCR
replace macro_region = 2 if inlist(region, ///
    1, 2, 3, 4, 5, 14, 17)

* Visayas
replace macro_region = 3 if inlist(region, ///
    6, 7, 8, 18)

* Mindanao
replace macro_region = 4 if inlist(region, ///
    9, 10, 11, 12, 16, 19 )

  
 label define macro_lab ///
    1 "NCR" ///
    2 "Luzon (excl. NCR)" ///
    3 "Visayas" ///
    4 "Mindanao" 

label values macro_region macro_lab
label var macro_region "Macro-region" 


table hhsize,  nototal name(c1) replace 
		collect export "$out/Phil_Brief_Roster_Graphs_${date}", ///
			name(c1) as(xlsx) sheet("hhsize") cell(A1) replace	

  
gen dob = date(bday_under_5yo, "MDY")
format dob %td 
  
gen age_months = ///
    (year(date) - year(dob)) * 12 + ///
    (month(date) - month(dob)) - ///
    (day(date) < day(dob))
 
replace age_months=. if age_months<0|age_months>59 
zscore06, a(age_months) w(weight_kg) h(height_cm) s(gender)  
replace weight_kg=. if age_months==.
replace height_cm =. if age_months==.

  
gen stunted     = haz < -2 if haz < .
gen wasted      = whz < -2 if whz < .
gen underweight = waz < -2 if waz < .  
  
gen sev_stunted = haz < -3 if haz < .
gen sev_wasted  = whz < -3 if whz < .
gen sev_underwt = waz < -3 if waz < .  
  			
gen age_group = .
replace age_group = 0 if age <10
replace age_group = 1 if age >= 10& age <= 19
replace age_group = 2 if age >= 20 & age <= 29
replace age_group = 3 if age >= 30 & age <= 39
replace age_group = 4 if age >= 40 & age <= 49
replace age_group = 5 if age >= 50 & age <= 59
replace age_group = 6 if age >= 60 & age <= 69
replace age_group = 7 if age >= 70 

label define age_group 0 "<10" 1 "10-19" 2 "20-29" 3 "30-39" 4 "40-49" 5 "50-59" 6 "60-69"  7 "70<" 
label values age_group age_group 

			
recode member_disability (.=0)		

replace language_primary=96 if language_primary>20&language_primary<50
  

local vl : value label disability_type1

* get all possible codes from ONE variable
levelsof disability_type1, local(codes)

* create "any of the 3" dummies
foreach c of local codes {
    local lab : label `vl' `c'
    
    gen dis_any_`c' = ///
        (disability_type1==`c' | disability_type2==`c' | disability_type3==`c')
        
    label var dis_any_`c' "`lab'"
}
  
recode dis_any* (0=.) if disability_type_txt ==""   


label define yesno 0 "No" 1 "Yes"	
label values dis_any_1 dis_any_2 dis_any_3 dis_any_4 dis_any_5 dis_any_6 dis_any_16 dis_any_17 dis_any_21 dis_any_22 dis_any_26 dis_any_27 dis_any_28 dis_any_30 dis_any_32 dis_any_33 dis_any_34 dis_any_38 dis_any_39 dis_any_43 dis_any_44 dis_any_45 dis_any_46 dis_any_47 dis_any_49 dis_any_52 dis_any_53 dis_any_56 dis_any_57 dis_any_58 dis_any_59 dis_any_60 dis_any_61 dis_any_62 dis_any_63 dis_any_66 dis_any_67 stunted wasted underweight sev_stunted sev_wasted sev_underwt member_disability yesno

local varlist relationship gender age_group marital_status member_disability disability_ntypes inci_pwdid pob_country hh_member_status por_5yo weight height stunted wasted underweight sev_stunted sev_wasted sev_underwt



collect clear
foreach var of local varlist {
      table (locale) [aw= indw] ,  name(Table) append  stat(fvpercent `var') nformat(%9.2f) 
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Roster_Graphs_${date}", as(xlsx) sheet(urban_ros) modify

collect clear
foreach var of local varlist {
      table (locale) ( `var'), m  name(Table) append  
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Roster_Graphs_${date}", as(xlsx) sheet(urban_ros_num) modify



collect clear
foreach var of local varlist {
      table (macro_region) [aw= indw] ,  name(Table) append  stat(fvpercent `var') nformat(%9.2f) 
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Roster_Graphs_${date}", as(xlsx) sheet(region_ros) modify

  
 collect clear
foreach var of local varlist {
      table (macro_region) ( `var'), m  name(Table) append  
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Roster_Graphs_${date}", as(xlsx) sheet(region_ros_num) modify

 
 local varlist relationship age_group marital_status member_disability disability_ntypes inci_pwdid pob_country hh_member_status por_5yo weight height stunted wasted underweight sev_stunted sev_wasted sev_underwt


collect clear
foreach var of local varlist {
      table (gender) [aw= indw] ,  name(Table) append  stat(fvpercent `var') nformat(%9.2f) 
     }

  collect layout (`varlist') (gender)
  collect export "$out/Phil_Brief_Roster_Graphs_${date}", as(xlsx) sheet(gender_ros) modify


  
collect clear
foreach var of local varlist {
      table (gender)  ( `var'), m  name(Table) append  
     }

  collect layout (`varlist') (gender)
  collect export "$out/Phil_Brief_Roster_Graphs_${date}", as(xlsx) sheet(gender_ros_num) modify

 
local varlist relationship gender marital_status member_disability disability_ntypes inci_pwdid pob_country por_5yo age_months weight height stunted wasted underweight sev_stunted sev_wasted sev_underwt
  

collect clear
foreach var of local varlist {
      table (age_group) [aw= indw] ,  name(Table) append  stat(fvpercent `var') nformat(%9.2f) 
     }

  collect layout (`varlist') (age_group)
  collect export "$out/Phil_Brief_Roster_Graphs_${date}", as(xlsx) sheet(age_ros) modify


collect clear
foreach var of local varlist {
      table (age_group)  ( `var'), m  name(Table) append  
     }

  collect layout (`varlist') (age_group)
  collect export "$out/Phil_Brief_Roster_Graphs_${date}", as(xlsx) sheet(age_ros_num) modify

 
 
  
  
  local varlist  hhsize language_primary migrant_int migrant_dom inci_remit inci_disability
  
  
  collect clear
foreach var of local varlist {
      table (locale) [aw= popw] if tag_hh==1,  name(Table) append  stat(fvpercent `var') nformat(%9.2f) 
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Roster_Graphs_${date}", as(xlsx) sheet(urban_hh_ros) modify

  collect clear
foreach var of local varlist {
      table (locale) ( `var') if tag_hh==1, m  name(Table) append  
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Roster_Graphs_${date}", as(xlsx) sheet(urban_hh_ros_num) modify



collect clear
foreach var of local varlist {
      table (macro_region) [aw= popw] if tag_hh==1, name(Table) append  stat(fvpercent `var') nformat(%9.2f) 
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Roster_Graphs_${date}", as(xlsx) sheet(region_hh_ros) modify

  
collect clear
foreach var of local varlist {
      table (macro_region)  ( `var') if tag_hh==1, m  name(Table) append   
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Roster_Graphs_${date}", as(xlsx) sheet(region_hh_ros_num) modify
  


local varlist dis_any_1 dis_any_2 dis_any_3 dis_any_4 dis_any_5 dis_any_6 dis_any_16 dis_any_17 dis_any_21 dis_any_22 dis_any_26 dis_any_27 dis_any_28 dis_any_30 dis_any_32 dis_any_33 dis_any_34 dis_any_38 dis_any_39 dis_any_43 dis_any_44 dis_any_45 dis_any_46 dis_any_47 dis_any_49 dis_any_52 dis_any_53 dis_any_56 dis_any_57 dis_any_58 dis_any_59 dis_any_60 dis_any_61 dis_any_62 dis_any_63 dis_any_66 dis_any_67

collect clear
foreach var of local varlist {
      table (locale) [aw= indw] ,  name(Table) append  stat(fvpercent `var') nformat(%9.2f) 
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Roster_Graphs_${date}", as(xlsx) sheet(disability_urban) modify

collect clear
foreach var of local varlist {
      table (locale) ( `var'), m  name(Table) append  
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Roster_Graphs_${date}", as(xlsx) sheet(disability_urban_num) modify

collect clear
foreach var of local varlist {
      table (gender) [aw= indw] ,  name(Table) append  stat(fvpercent `var') nformat(%9.2f) 
     }

  collect layout (`varlist') (gender)
  collect export "$out/Phil_Brief_Roster_Graphs_${date}", as(xlsx) sheet(gender_disability) modify


  
collect clear
foreach var of local varlist {
      table (gender)  ( `var'), m  name(Table) append  
     }

  collect layout (`varlist') (gender)
  collect export "$out/Phil_Brief_Roster_Graphs_${date}", as(xlsx) sheet(gender_disability_num) modify
  
table (gender)  [aw= indw] , ///
    statistic(mean weight_kg) ///
    statistic(mean height_cm) ///
    statistic(mean age_months) ///
    statistic(mean waz06) ///
    statistic(mean whz06) ///
    statistic(mean haz06) ///
    statistic(mean stunted) ///
    statistic(mean wasted) ///
    statistic(mean underweight)  nformat(%9.2f mean) ///		
    name(Table)
table (gender), ///
    statistic(count weight_kg) ///
    statistic(min weight_kg) ///
    statistic(max weight_kg) ///	
    statistic(count height_cm) ///
    statistic(min height_cm) ///	
    statistic(max height_cm) ///	
    statistic(count age_months) ///
    statistic(min age_months) ///
    statistic(max age_months) ///	
    statistic(count waz06) ///
    statistic(min waz06) ///
    statistic(max waz06) ///	
    statistic(count whz06) ///
    statistic(min whz06) ///
    statistic(max whz06) ///	
    statistic(count haz06) ///
    statistic(min haz06) ///
    statistic(max haz06) ///	
    statistic(count stunted) ///
    statistic(min stunted) ///
    statistic(max stunted) ///	
    statistic(count wasted) ///
    statistic(min wasted) ///
    statistic(max wasted) ///	
    statistic(count underweight) ///
    statistic(min underweight) ///
    statistic(max underweight)  ///			
    name(Table) append

collect layout (colname # result) (gender)
collect export "$out/Phil_Brief_Roster_Graphs_${date}.xlsx", ///
    sheet(gender_nutrition) modify   
