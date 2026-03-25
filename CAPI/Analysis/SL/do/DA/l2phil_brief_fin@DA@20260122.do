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
		copy "${dta}/final_weights.dta"  ///
				"$in/weights_ind.dta", replace							
	}
	



* Load Passport data with weights


use "$in/l2phl_${date}_M05_fin.dta", clear

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

recode f12 (13=96) (14=96) (15=96) (17=96)

* merge 1:1 hhid using "$in/${dta_file}_M09_nh.dta", assert(3) keep(3) nogen 


table f1 , stat(percent)
collect export "$out/Phil_Brief_Finance_Graphs_${date}", ///
			as(xlsx) sheet("f1") cell(A1) replace	

  
 forvalues k = 1/7 {
    gen choice_`k' = (strpos(f8_txt, ";`k';") > 0)
}


gen choice_96 = 0

foreach v of varlist f8_purp1-f8_purp7 {
    replace choice_96 = 1 if inrange(`v',11,89)
}


recode choice* (0=.) if f8_txt==""
recode f9 (12=96) (13=96) (14=96)  (15=96)

label variable choice_1 "Loan purpose: Housing"
label variable choice_2 "Car/transportation"
label variable choice_3 "Food"
label variable choice_4 "Other consumption"
label variable choice_5 "Business"
label variable choice_6 "Education" 
label variable choice_7 "Health"   
label variable choice_96 "Other"   
  
 recode	choice*	 (0=2)
		
label define yesno 2 "No" 1 "Yes"		
label values choice*	yesno	

 
local varlist f1 f2 f3 f4 f5 f6 f7 choice_1 choice_2 choice_3 choice_4 choice_5 choice_6 choice_7 choice_96 f9 f10 f11 f12
  

foreach var of local varlist {
      table (locale)  [aw= popw],  name(Table) append  stat(fvpercent `var') nformat(%9.2f)
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Finance_Graphs_${date}", as(xlsx) sheet(urban_finance) modify
 
 collect clear
foreach var of local varlist {
      table (locale) ( `var') , m name(Table) append 
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Finance_Graphs_${date}", as(xlsx) sheet(urban_finance_num) modify

 
 
foreach var of local varlist {
     table (macro_region) [aw= popw],  name(Table) append  stat(fvpercent `var') nformat(%9.2f)
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Finance_Graphs_${date}", as(xlsx) sheet(macro_region_finance) modify
 
  collect clear
foreach var of local varlist {
      table (macro_region) ( `var') , m name(Table) append 
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Finance_Graphs_${date}", as(xlsx) sheet(macro_region_finance_num) modify


