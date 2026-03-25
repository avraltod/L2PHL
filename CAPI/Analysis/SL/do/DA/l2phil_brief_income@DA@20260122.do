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

	glo date 20251015								// match with the latest updates on the data
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
		copy "${dta}/${dta_file}_M08_food.dta"  ///
				"$in/${dta_file}_M08_food.dta", replace	
		copy "${dta}/${dta_file}_M08_nf.dta"  ///
				"$in/${dta_file}_M08_nf.dta", replace		
		copy "${dta}/${dta_file}_M08_ssb.dta"  ///
				"$in/${dta_file}_M08_ssb.dta", replace	
		copy "${dta}/${dta_file}_M04_inc1.dta"  ///
				"$in/${dta_file}_M04_inc1.dta", replace		
		copy "${dta}/${dta_file}_M04_inc2.dta"  ///
				"$in/${dta_file}_M04_inc2.dta", replace									
		copy "${dta}/final_weights.dta"  ///
				"$in/weights_ind.dta", replace							
	}
	



* Load Passport data with weights


use "$in/l2phl_${date}_M04_inc2.dta", clear

merge 1:1 hhid using "$in/${dta_file}_M00_passport.dta", assert(3) keep(3) nogen keepusing(locale region)
merge 1:m hhid using "$in/weights_ind.dta", assert(3) keep(3) nogen keepusing(hhw popw tag_hh)

drop if tag_hh==0
drop tag_hh

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

label define yesno 0 "No" 1 "Yes", replace

forvalues k = 1/9 {
    gen ib1_cat`k'_any = 0
    replace ib1_cat`k'_any = 1 if ///
        ib1_cat1==`k' | ib1_cat2==`k' | ///
        ib1_cat3==`k' | ib1_cat4==`k'
    label values ib1_cat`k'_any yesno
}

label var ib1_cat1_any "Rice sales (past 6 months)"
label var ib1_cat2_any "Corn sales (past 6 months)"
label var ib1_cat3_any "Other cereals sales (past 6 months)"
label var ib1_cat4_any "Fruit sales (past 6 months)"
label var ib1_cat5_any "Vegetables sales (past 6 months)"
label var ib1_cat6_any "Fishing & aquaculture sales (past 6 months)"
label var ib1_cat7_any "Livestock & poultry sales (past 6 months)"
label var ib1_cat8_any "Livestock & poultry products sales (past 6 months)"
label var ib1_cat9_any "Other agriculture sales (past 6 months)"


gen ib1_crop = (ib1_cat1_any | ib1_cat2_any | ib1_cat3_any | ib1_cat4_any | ib1_cat5_any)
gen ib1_livestock = (ib1_cat7_any | ib1_cat8_any)
gen ib1_fish = ib1_cat6_any


foreach k in 1 2 3 4 5 6 7 8 9 11 12 15 23 96 {
    gen ic4_src`k'_any = 0 if ic4_txt!="" 
    replace ic4_src`k'_any = 1 if ///
        ic4_src1==`k' | ic4_src2==`k' | ic4_src3==`k' | ic4_src4==`k'
    label values ic4_src`k'_any yesno
}

label var ic4_src1_any  "Support: family member (otherwise paid)"
label var ic4_src2_any  "Support: other relatives/friends"
label var ic4_src3_any  "Support: government institutions"
label var ic4_src4_any  "Support: CCT/Pantawid/4Ps"
label var ic4_src5_any  "Support: AICS"
label var ic4_src6_any  "Support: AKAP"
label var ic4_src7_any  "Support: rice/agri support programs"
label var ic4_src8_any  "Support: Walang Gutom 2027"
label var ic4_src9_any  "Support: scholarships/education aid"
label var ic4_src11_any "Support: other social programs (pension etc.)"
label var ic4_src12_any "Support: private institutions (church/NGO)"
label var ic4_src15_any "Support: political parties"
label var ic4_src23_any "Support: government candidates"
label var ic4_src96_any "Support: other (specify)"

gen recieved_abroad=(ic1_1!=.)
label variable recieved_abroad "Recieved from members who are OCW/Working abroad"

local varlist  ib1_cat1_any ib1_cat2_any ib1_cat3_any ib1_cat4_any ib1_cat5_any  ib1_cat6_any ib1_cat7_any ib1_cat8_any ib1_cat9_any  ib1_ncats recieved_abroad ic3 ic4_src1_any ic4_src2_any ic4_src3_any ic4_src4_any ic4_src5_any ic4_src6_any ic4_src8_any ic4_src7_any ic4_src9_any ic4_src11_any ic4_src12_any ic4_src15_any ic4_src23_any ic4_src96_any ic6 ic8a ic8b ic8c  id1  ie1a ie1b ie1c ie1d ie1e 

table (ib1_cat9_any) (locale) [aw= popw]
collect export "$out/Phil_Brief_Income_Graphs_${date}.xlsx", ///
    sheet(ib1_cat9_any) replace

collect clear
foreach var of local varlist {
      table (locale) [aw= popw] ,  name(Table) append  stat(fvpercent `var')  nformat(%9.2f)
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Income_Graphs_${date}", as(xlsx) sheet(urban_other_income) modify

  
collect clear
foreach var of local varlist {
      table (locale) (`var') , m  name(Table) append 
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Income_Graphs_${date}", as(xlsx) sheet(urban_other_income_num) modify

  
  
  
collect clear  
foreach var of local varlist {
     table (macro_region) [aw= popw] ,  name(Table) append  stat(fvpercent `var')   nformat(%9.2f)
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Income_Graphs_${date}", as(xlsx) sheet(macro_region_other_income) modify

collect clear  
foreach var of local varlist {
     table (macro_region) (`var') , m  name(Table) append 
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Income_Graphs_${date}", as(xlsx) sheet(macro_region_other_income_num) modify
  
  
use "$in/l2phl_${date}_M04_inc1.dta", clear

  merge m:1 hhid using "$in/${dta_file}_M00_passport.dta", assert(3) keep(3) nogen keepusing(locale region)
	merge 1:1 hhid fmid using "$in/weights_ind.dta", assert(3) keep(3) nogen keepusing(indw popw indw tag_hh)


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

gen age_group = .
replace age_group = 1 if age >= 15 & age <= 24
replace age_group = 2 if age >= 25 & age <= 34
replace age_group = 3 if age >= 35 & age <= 44
replace age_group = 4 if age >= 45 & age <= 54
replace age_group = 5 if age >= 55 & age <= 65

label define age_group 1 "15-24" 2 "25-34" 3 "35-44" 4 "45-54" 5 "55-64"
label values age_group age_group

recode ia2 ia5 (.=2)
	
local varlist ia1 ia4


**# Bookmark #1
collect clear
foreach var of local varlist {
      table (locale) [aw= popw] if tag_hh==1 ,  name(Table) append  stat(fvpercent `var')   nformat(%9.2f)
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Income_Graphs_${date}", as(xlsx) sheet(urban_income_hh) modify

 
collect clear
foreach var of local varlist {
      table (locale) (`var') if tag_hh==1 , m name(Table) append  
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Income_Graphs_${date}", as(xlsx) sheet(urban_income_hh_num) modify
 

collect clear  
foreach var of local varlist {
     table (macro_region) [aw= popw] if tag_hh==1 ,  name(Table) append  stat(fvpercent `var')   nformat(%9.2f)
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Income_Graphs_${date}", as(xlsx) sheet(macro_region_income_hh) modify

 collect clear  
foreach var of local varlist {
     table (macro_region)  (`var') if tag_hh==1 , m name(Table) append  
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Income_Graphs_${date}", as(xlsx) sheet(macro_region_income_hh_num) modify
 
  
  
 local varlist ia2 ia5


collect clear
foreach var of local varlist {
      table (locale) [aw= indw]  , m name(Table) append  stat(fvpercent `var')   nformat(%9.2f)
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Income_Graphs_${date}", as(xlsx) sheet(urban_income) modify

collect clear
foreach var of local varlist {
      table (locale)  (`var')   , m  name(Table) append 
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Income_Graphs_${date}", as(xlsx) sheet(urban_income_num) modify
  
  
collect clear  
foreach var of local varlist {
     table (macro_region) [aw= indw] ,  name(Table) append  stat(fvpercent `var')   nformat(%9.2f)
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Income_Graphs_${date}", as(xlsx) sheet(macro_region_income) modify
 
 collect clear  
foreach var of local varlist {
     table (macro_region)  (`var') , m  name(Table) append 
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Income_Graphs_${date}", as(xlsx) sheet(macro_region_income_num) modify

 
collect clear
foreach var of local varlist {
      table (gender) [aw= indw]  ,  name(Table) append  stat(fvpercent `var')   nformat(%9.2f)
     }

  collect layout (`varlist') (gender)
  collect export "$out/Phil_Brief_Income_Graphs_${date}", as(xlsx) sheet(gender_income) modify

collect clear
foreach var of local varlist {
      table (gender) (`var') , m  name(Table) append 
     }

  collect layout (`varlist') (gender)
  collect export "$out/Phil_Brief_Income_Graphs_${date}", as(xlsx) sheet(gender_income_num) modify
  
  
collect clear  
foreach var of local varlist {
     table (age_group) [aw= indw] ,  name(Table) append  stat(fvpercent `var')   nformat(%9.2f)
     }

  collect layout (`varlist') (age_group)
  collect export "$out/Phil_Brief_Income_Graphs_${date}", as(xlsx) sheet(age_income) modify  
  
  
collect clear  
foreach var of local varlist {
     table (age_group) (`var') , m  name(Table) append 
     }

  collect layout (`varlist') (age_group)
  collect export "$out/Phil_Brief_Income_Graphs_${date}", as(xlsx) sheet(age_income_num) modify  
    