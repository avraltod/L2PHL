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

	glo date 20251015						// match with the latest updates on the data
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
		copy "${dta}/${dta_file}_M05_fin.dta"  ///
				"$in/${dta_file}_M05_fin.dta", replace	
		copy "${dta}/${dta_file}_M10_dwell.dta"  ///
				"$in/${dta_file}_M10_dwell.dta", replace	
		copy "${dta}/${dta_file}_M11_san.dta"  ///
				"$in/${dta_file}_M11_san.dta", replace					
		copy "${dta}/${dta_file}_M12_water.dta"  ///
				"$in/${dta_file}_M12_water.dta", replace									
		copy "${dta}/final_weights.dta"  ///
				"$in/weights_ind.dta", replace					
				
								
	}
	



* Load Passport data with weights


use "$in/l2phl_${date}_M00_passport.dta", clear

merge 1:m hhid using "$in/weights_ind.dta", assert(3) keep(3) nogen keepusing(hhw popw tag_hh)
drop if tag_hh==0
drop tag_hh
keep hhw popw hhid region locale
merge 1:m hhid using "$in/${dta_file}_M09_nh.dta", assert(3) keep(3) nogen 



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



* Create dummies for each code appearing in nh3
foreach c in 1 2 3 4 5 6 7 8 11 26 58 66 69 71 79 {
    gen nh3_`c' = .
    replace nh3_`c' = regexm(";" + nh3 + ";", ";`c';") if !missing(nh3) & nh3 != "."
}


label var nh3_1  "Damages/Impact: Travel disruptions / time"
label var nh3_2  "Damages/Impact: Children's school closure / interruption"
label var nh3_3  "Damages/Impact: Damage to house"
label var nh3_4  "Damages/Impact: Damage to other personal property"
label var nh3_5  "Damages/Impact: Job disruption / reduced income earning"
label var nh3_6  "Damages/Impact: Health of a family member"
label var nh3_7  "Damages/Impact: Death"
label var nh3_8  "Damages/Impact: Disruption of basic utilities"
label var nh3_11 "Damages/Impact: Damage to public property"
label var nh3_26 "Damages/Impact: Price inflation"
label var nh3_58 "Damages/Impact: Negative agricultural impact"
label var nh3_66 "Damages/Impact: Negative emotional / mental impact"
label var nh3_69 "Damages/Impact: Negative environmental impact"
label var nh3_71 "Damages/Impact: Panic buying"
label var nh3_79 "Damages/Impact: Lack of / no source of food"

label define yesno 0 "No" 1 "Yes"
foreach c in 1 2 3 4 5 6 7 8 11 26 58 66 69 71 79 {
    label values nh3_`c' yesno
}




foreach c in 1 2 3 4 5 6 99 {
    gen nh4_`c' = .
    replace nh4_`c' = regexm(";" + nh4 + ";", ";`c';") ///
        if !missing(nh4) & nh4 != "."
}

label var nh4_1  "Assistance source: Family member"
label var nh4_2  "Assistance source: Other relatives or friends"
label var nh4_3  "Assistance source: Local government"
label var nh4_4  "Assistance source: National government"
label var nh4_5  "Assistance source: Government (unknown level)"
label var nh4_6  "Assistance source: Private institutions (Churches / NGOs)"
label var nh4_99 "Did not receive assistance"

foreach c in 1 2 3 4 5 6 99 {
    label values nh4_`c' yesno
}



foreach c in 1 2 3 4 5 6 7 8 21 23 99 {
    gen nh7_`c' = .
    replace nh7_`c' = regexm(";" + nh7 + ";", ";`c';") ///
        if !missing(nh7) & nh7 != "."
}

label var nh7_1  "Warning channel: TV"
label var nh7_2  "Warning channel: Radio"
label var nh7_3  "Warning channel: In-person: LGU/barangay"
label var nh7_4  "Warning channel: SMS"
label var nh7_5  "Warning channel: Website"
label var nh7_6  "Warning channel: Cell broadcast / emergency alert"
label var nh7_7  "Warning channel: Sirens / loudspeakers"
label var nh7_8  "Warning channel: Social media"
label var nh7_21 "Warning channel: Word of mouth (friends/relatives)"
label var nh7_23 "Warning channel: Weather forecast services"
label var nh7_99 "Warning channel: N.A."

foreach c in 1 2 3 4 5 6 7 8 21 23 99 {
    label values nh7_`c' yesno
}


* Main categories
foreach c in 1 2 3 4 5 6 7 8 99 {
    gen nh10_`c' = .
    replace nh10_`c' = regexm(";" + nh10 + ";", ";`c';") ///
        if !missing(nh10) & nh10 != "."
}

* Other = any code above 10, excluding 99
gen nh10_other = .
replace nh10_other = 0 if !missing(nh10) & nh10 != "."

foreach c in 11 12 13 14 15 16 17 20 21 22 23 25 26 27 28 29 30 31 32 33 35 40 43 44 45 51 54 56 57 58 60 61 62 64 65 {
    replace nh10_other = 1 if regexm(";" + nh10 + ";", ";`c';") ///
        & !missing(nh10) & nh10 != "."
}

label var nh10_1     "Action taken: Evacuated to a safe place"
label var nh10_2     "Action taken: Reinforced the structure of the house"
label var nh10_3     "Action taken: Avoiding risky activities"
label var nh10_4     "Action taken: Stocked up on food"
label var nh10_5     "Action taken: Sheltering in place"
label var nh10_6     "Action taken: Secured property and assets"
label var nh10_7     "Action taken: Stockpiling and preparing supplies"
label var nh10_8     "Action taken: Assisting others"
label var nh10_other "Action taken: Other actions"
label var nh10_99    "Did not do anything"

foreach v in nh10_1 nh10_2 nh10_3 nh10_4 nh10_5 nh10_6 nh10_7 nh10_8 nh10_other nh10_99 {
    label values `v' yesno
}


foreach c in 1 2 3 4 5 8 10 11 12 14 16 18 20 21 {
    gen nh13_`c' = .
    replace nh13_`c' = regexm(";" + nh13 + ";", ";`c';") ///
        if !missing(nh13) & nh13 != "."
}

label var nh13_1  "Source of awareness: National officials"
label var nh13_2  "Source of awareness: Local officials"
label var nh13_3  "Source of awareness: Family & friends"
label var nh13_4  "Source of awareness: School"
label var nh13_5  "Source of awareness: PHIVOLCS"
label var nh13_8  "Source of awareness: Facebook"
label var nh13_10 "Source of awareness: YouTube"
label var nh13_11 "Source of awareness: Barangay hall"
label var nh13_12 "Source of awareness: Red Cross"
label var nh13_14 "Source of awareness: Company"
label var nh13_16 "Source of awareness: TV"
label var nh13_18 "Source of awareness: Radio"
label var nh13_20 "Source of awareness: Roadside signage"
label var nh13_21 "Source of awareness: Municipal office"

foreach c in 1 2 3 4 5 8 10 11 12 14 16 18 20 21 {
    label values nh13_`c' yesno
}

drop nh3_imp* nh4_src* nh7_ch* nh10_act* nh13_src*  

collect clear
table (macro_region) (hazard) [aw= hhw],  name(Table) replace  stat(fvpercent nh1) nformat(%9.2f)
collect export "$out/Phil_Brief_Hazards_Graphs_${date}", ///
			as(xlsx) sheet("Hazards") cell(A1) replace	

collect clear
table (macro_region) (hazard) ,  name(Table) replace  stat(fvfrequency nh1)
collect export "$out/Phil_Brief_Hazards_Graphs_${date}", ///
			as(xlsx) sheet("Hazards_num") cell(A1) modify	

local varlist nh1 nh2 nh3_1 nh3_2 nh3_3 nh3_4 nh3_5 nh3_6 nh3_7 nh3_8 nh3_11 nh3_26 nh3_58 nh3_66 nh3_69 nh3_71 nh3_79 nh4_1 nh4_2 nh4_3 nh4_4 nh4_5 nh4_6 nh4_99 nh6 nh7_1 nh7_2 nh7_3 nh7_4 nh7_5 nh7_6 nh7_7 nh7_8 nh7_21 nh7_23 nh7_99 nh8 nh9 nh10_1 nh10_2 nh10_3 nh10_4 nh10_5 nh10_6 nh10_7 nh10_8 nh10_99 nh10_other nh11 nh12 nh13_1 nh13_2 nh13_3 nh13_4 nh13_5 nh13_8 nh13_10 nh13_11 nh13_12 nh13_14 nh13_16 nh13_18 nh13_20 nh13_21

collect clear
foreach var of local varlist {
      table (hazard) [aw= hhw],  name(Table) append  stat(fvpercent `var') nformat(%9.2f)
     }

  collect layout (`varlist') (hazard)
  collect export "$out/Phil_Brief_Hazards_Graphs_${date}", as(xlsx) sheet(hazard_info) modify

  collect clear   
 foreach var of local varlist {
      table (hazard) (`var') , m  name(Table) append 
     }

  collect layout (`varlist') (hazard)
  collect export "$out/Phil_Brief_Hazards_Graphs_${date}", as(xlsx) sheet(hazard_info_num) modify
 
*** Typhoon  
 collect clear
foreach var of local varlist {
      table (locale) [aw= hhw] if hazard==1,  name(Table) append  stat(fvpercent `var') nformat(%9.2f)
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Hazards_Graphs_${date}", as(xlsx) sheet(locale_Typhoon) modify

  collect clear   
 foreach var of local varlist {
      table (locale) (`var') if hazard==1 , m  name(Table) append 
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Hazards_Graphs_${date}", as(xlsx) sheet(locale_Typhoon_num) modify
 
 
 collect clear
foreach var of local varlist {
      table (macro_region) [aw= hhw] if hazard==1,  name(Table) append  stat(fvpercent `var') nformat(%9.2f)
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Hazards_Graphs_${date}", as(xlsx) sheet(macro_region_Typhoon) modify

  collect clear   
 foreach var of local varlist {
      table (macro_region) (`var')  if hazard==1, m  name(Table) append 
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Hazards_Graphs_${date}", as(xlsx) sheet(macro_region_Typhoon_num) modify
 
 ***  Extreme heat
 collect clear
foreach var of local varlist {
      table (locale) [aw= hhw]  if hazard==8,  name(Table) append  stat(fvpercent `var') nformat(%9.2f)
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Hazards_Graphs_${date}", as(xlsx) sheet(locale_extreme_heat) modify

  collect clear   
 foreach var of local varlist {
      table (locale) (`var')  if hazard==8, m  name(Table) append 
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Hazards_Graphs_${date}", as(xlsx) sheet(locale_extreme_heat_num) modify
 

 collect clear
foreach var of local varlist {
      table (macro_region) [aw= hhw] if hazard==8,  name(Table) append  stat(fvpercent `var') nformat(%9.2f)
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Hazards_Graphs_${date}", as(xlsx) sheet(macro_region_extreme_heat) modify

  collect clear   
 foreach var of local varlist {
      table (macro_region) (`var')  if hazard==8, m  name(Table) append 
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Hazards_Graphs_${date}", as(xlsx) sheet(macro_region_extreme_heat_num) modify
 
  
 
 
 
 