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
		copy "${dta}/final_weights.dta"  ///
				"$in/weights_ind.dta", replace							
	}
	



* Load Passport data with weights


use "$in/l2phl_${date}_M08_nf.dta", clear

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

 forvalues k = 1/10{
    gen choice_`k' = (strpos(nf1_txt, ";`k';") > 0)
}

gen choice_12=0
gen choice_16=0
gen choice_17=0
gen choice_99=0
foreach v of varlist nf1_src1-nf1_src8 {
    replace choice_12 = 1 if `v'==12
	replace choice_16 = 1 if `v'==16
	replace choice_17 = 1 if `v'==17
	replace choice_99 = 1 if `v'==99
}

recode choice* (0=.) if nf1_txt==""

label variable choice_1 "Market"
label variable choice_2 "Large supermarket/Hypermarket"
label variable choice_3 "Supermarket?Grocery"
label variable choice_4 "Convenience store"
label variable choice_5 "Sari-sari store"
label variable choice_6 "Ambulant peddlers"
label variable choice_7 "Open stalls in shopping centers, malls,"
label variable choice_8 "Department stores"
label variable choice_9 "Appliance centers"
label variable choice_10 "Online platforms"
label variable choice_12 "Ukay-ukay"
label variable choice_16 "From family members"
label variable choice_17 "Warehouse / wholesale stores"
label variable choice_99 "None"


recode	choice*	 (0=2)
		
label define yesno 2 "No" 1 "Yes"		
label values choice*	yesno	

local varlist choice_1 choice_2 choice_3 choice_4 choice_5 choice_6 choice_7 choice_8 choice_9 choice_10 choice_12 choice_16 choice_17 choice_99

// foreach var of local varlist {
//      table `var' , stat(percent)
// 	 collect export "$out/Phil_Brief_Dwelling_Graphs_${date}", as(xlsx) sheet(`var') cell(A1) modify
//      }

table (choice_1) (locale) [aw= popw]
collect export "$out/Phil_Brief_Nonfood_Graphs_${date}.xlsx", ///
    sheet(choice1) replace

collect clear
foreach var of local varlist {
      table (locale) [aw= hhw] ,  name(Table) append  stat(fvpercent `var') nformat(%9.2f)
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Nonfood_Graphs_${date}", as(xlsx) sheet(urban_nonfood) modify

  
collect clear
foreach var of local varlist {
      table (locale) (`var' ), m name(Table) append  
 }
  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Nonfood_Graphs_${date}", as(xlsx) sheet(urban_nonfood_num) modify
  
  
  
collect clear  
foreach var of local varlist {
     table (macro_region) [aw= hhw] ,  name(Table) append  stat(fvpercent `var') nformat(%9.2f)
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Nonfood_Graphs_${date}", as(xlsx) sheet(macro_region_nonfood) modify

  collect clear  
foreach var of local varlist {
     table (macro_region) (`var' ), m name(Table) append  
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Nonfood_Graphs_${date}", as(xlsx) sheet(macro_region_nonfood_num) modify

  
reshape long nf1_src nf2_ nf3_, i(hhid) j(slot)
drop if missing(nf1_src)

* merge 1:1 hhid using "$in/${dta_file}_M09_nh.dta", assert(3) keep(3) nogen 
local varlist nf2_ nf3_

collect clear	
foreach var of local varlist {
     table (nf1_src) [aw= hhw] ,  name(Table) append  stat(fvpercent `var') nformat(%9.2f)
     }

  collect layout (`varlist') (nf1_src)
collect export "$out/Phil_Brief_Nonfood_Graphs_${date}.xlsx", ///
    sheet(market_urban) modify

collect clear	
foreach var of local varlist {
     table (nf1_src) (`var')  , m name(Table) append  
     }

  collect layout (`varlist') (nf1_src)
collect export "$out/Phil_Brief_Nonfood_Graphs_${date}.xlsx", ///
    sheet(market_urban_num) modify
		
