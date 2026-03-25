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
		copy "${dta}/final_weights.dta"  ///
				"$in/weights_ind.dta", replace			
	}
	



* Load Passport data with weights


use "$in/l2phl_${date}_M07_med.dta", clear

merge m:1 hhid using "$in/${dta_file}_M00_passport.dta", assert(3) keep(3) nogen keepusing(locale region)
merge 1:1 hhid fmid using "$in/weights_ind.dta", assert(3) keep(3) nogen keepusing(popw indw )


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
bysort hhid (fmid): gen hh_tag = (_n==1)


* merge 1:1 hhid using "$in/${dta_file}_M09_nh.dta", assert(3) keep(3) nogen 

table h2 if hh_tag==1 , stat(percent)
collect export "$out/Phil_Brief_Health_Graphs_${date}", ///
			as(xlsx) sheet("h2") cell(A1) replace	
			
			
 forvalues k = 1/6 {
    gen choice_`k' = (strpos(h5_txt, ";`k';") > 0)
}
			
gen choice_15_50 = 0

foreach v of varlist h5_mode1-h5_mode3 {
    replace choice_15_50 = 1 if inrange(`v',11,50)
}



gen choice_51 = 0
			
foreach v of varlist h5_mode1-h5_mode3 {
    replace choice_51 = 1 if `v'==51
}			

recode choice* (0=.) if h5_txt==""

label variable choice_1 "By foot"
label variable choice_3 "Bicycle"
label variable choice_4 "Motorcycle/Tricycle"
label variable choice_5 "Jeepney/Bus"
label variable choice_6 "Car/Taxi" 
label variable choice_15_50 "Van/SUV/Truck"   
label variable choice_51 "Government service"   
  

			
 forvalues k = 1/9 {
    gen h11_choice_`k' = (strpos(h11ba_txt, ";`k';") > 0)
}

gen h11_choice_11=0

foreach v of varlist h11ba_pay1-h11ba_pay3{
    replace h11_choice_11 = 1 if `v'==11
}			


gen h11_choice_16=0

foreach v of varlist h11ba_pay1-h11ba_pay3{
    replace h11_choice_16 = 1 if `v'==16
}	

gen h11_choice_18=0

foreach v of varlist h11ba_pay1-h11ba_pay3{
    replace h11_choice_18 = 1 if `v'==18
}	

recode h11_choice* (0=.) if h11ba_txt==""


label variable h11_choice_1 "Medical payer: Immediate family member"
label variable h11_choice_2 "Relative/friend support"
label variable h11_choice_3 "PhilHealth"
label variable h11_choice_4 "PCSO"
label variable h11_choice_5 "Private insurance (HMO)"
label variable h11_choice_6 "Government program (MAIP, Malasakit, et al)" 
label variable h11_choice_8 "Politician" 
label variable h11_choice_9 "LGU" 
label variable h11_choice_11 "Own money"   
label variable h11_choice_16 "Health care center"   
label variable h11_choice_18 "From a loan"   



 forvalues k = 1/9 {
    gen h16_choice_`k' = (strpos(h16_txt, ";`k';") > 0)
}

gen h16_choice_11=0

foreach v of varlist h16_pay1-h16_pay7{
    replace h16_choice_11 = 1 if `v'==11
}			


gen h16_choice_18=0

foreach v of varlist h16_pay1-h16_pay7{
    replace h16_choice_18 = 1 if `v'==18
}	

recode h16_choice* (0=.) if h16_txt==""


label variable h16_choice_1 "Other payer of hospital bill: Immediate family member"
label variable h16_choice_2 "Relative/friend support"
label variable h16_choice_3 "PhilHealth"
label variable h16_choice_4 "PCSO"
label variable h16_choice_5 "Private insurance (HMO)"
label variable h16_choice_6 "Government program (MAIP, Malasakit, et al)" 
label variable h16_choice_8 "Politician" 
label variable h16_choice_7 "Other insurance (i.e., SSS, GSIS)" 
label variable h16_choice_9 "LGU" 
label variable h16_choice_11 "Own money"   
label variable h16_choice_18 "From a loan"   



 recode	choice*	h11_choice*  h16_choice* (0=2)
		
label define yesno 2 "No" 1 "Yes"		
label values choice* h11_choice* h16_choice* yesno	


local varlist h2 h2a h3 h4 choice_1 choice_3 choice_4 choice_5 choice_6 choice_15_50 choice_51 h8 h9a h10a  h9b h10b h9c h10c h11_choice_1 h11_choice_2 h11_choice_3 h11_choice_4 h11_choice_5 h11_choice_6 h11_choice_8 h11_choice_9 h11_choice_11 h11_choice_16 h11_choice_18 h12 h13 h16_choice_1 h16_choice_2 h16_choice_3 h16_choice_4 h16_choice_5 h16_choice_6 h16_choice_7 h16_choice_8 h16_choice_9 h16_choice_11 h16_choice_18 





// foreach var of local varlist {
//      table `var' , stat(percent)
// 	 collect export "$out/Phil_Brief_Dwelling_Graphs_${date}", as(xlsx) sheet(`var') cell(A1) modify
//      }


foreach var of local varlist {
      table (locale) [aw= popw] if hh_tag==1,  name(Table) append  stat(fvpercent `var') nformat(%9.2f)
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Health_Graphs_${date}", as(xlsx) sheet(urban_health) modify

collect clear
foreach var of local varlist {
      table (locale) (`var' ), m name(Table) append
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Health_Graphs_${date}", as(xlsx) sheet(urban_health_num) modify
  
  
  
foreach var of local varlist {
     table (macro_region) [aw= popw] if hh_tag==1,  name(Table) append  stat(fvpercent `var')  nformat(%9.2f)
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Health_Graphs_${date}", as(xlsx) sheet(macro_region_health) modify
  
collect clear
foreach var of local varlist {
      table (macro_region) (`var' ), m name(Table) append
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Health_Graphs_${date}", as(xlsx) sheet(macro_region_health_num) modify
  

  
  recode h6 h7 h11aa h11ab h11ac h14 h15 (-99=.)

local varlist h6 h7 h11aa h11ab h11ac h14 h15


collect clear

table (locale) [aw= popw] if hh_tag==1, ///
    statistic(mean h6) ///
    statistic(mean h7) ///
    statistic(mean h11aa) ///
    statistic(mean h11ab) ///
    statistic(mean h11ac) ///
    statistic(mean h14) ///
    statistic(mean h15)  nformat(%9.2f mean) ///
    name(Table)
table (locale) if hh_tag==1, ///
    statistic(count h6) ///
    statistic(min h6) ///
    statistic(max h6) ///	
    statistic(count h7) ///
    statistic(min h7) ///	
    statistic(max h7) ///	
    statistic(count h11aa) ///
    statistic(min h11aa) ///
    statistic(max h11aa) ///	
    statistic(count h11ab) ///
    statistic(min h11ab) ///
    statistic(max h11ab) ///	
    statistic(count h11ac) ///
    statistic(min h11ac) ///
    statistic(max h11ac) ///	
    statistic(count h14) ///
    statistic(min h14) ///
    statistic(max h14) ///	
    statistic(count h15) ///
    statistic(min h15) ///
    statistic(max h15) ///			
    name(Table) append
collect layout (colname # result) (locale)
collect export "$out/Phil_Brief_Health_Graphs_${date}.xlsx", ///
    sheet(By_urban_costs_dur) modify

	
collect clear

table (macro_region) [aw= popw] if hh_tag==1, ///
    statistic(mean h6) ///
    statistic(mean h7) ///
    statistic(mean h11aa) ///
    statistic(mean h11ab) ///
    statistic(mean h11ac) ///
    statistic(mean h14) ///
    statistic(mean h15)  nformat(%9.2f mean) ///
    name(Table)
table (macro_region) if hh_tag==1, ///
    statistic(count h6) ///
    statistic(min h6) ///
    statistic(max h6) ///	
    statistic(count h7) ///
    statistic(min h7) ///	
    statistic(max h7) ///	
    statistic(count h11aa) ///
    statistic(min h11aa) ///
    statistic(max h11aa) ///	
    statistic(count h11ab) ///
    statistic(min h11ab) ///
    statistic(max h11ab) ///	
    statistic(count h11ac) ///
    statistic(min h11ac) ///
    statistic(max h11ac) ///	
    statistic(count h14) ///
    statistic(min h14) ///
    statistic(max h14) ///	
    statistic(count h15) ///
    statistic(min h15) ///
    statistic(max h15) ///			
    name(Table) append
collect layout (colname # result) (macro_region)

collect export "$out/Phil_Brief_Health_Graphs_${date}.xlsx", ///
    sheet(By_region_costs_dur) modify

	
table gender [aw= indw], stat(fvpercent  h17) name(c1) replace 
table gender (h17) ,m name(c1) append 
		collect label levels gender 1 "Men" 2 "Women", name(c1) modify  		
		collect export "$out/Phil_Brief_Health_Graphs_${date}", ///
			name(c1) as(xlsx) sheet("insurance_gender") cell(A1) modify	

table locale [aw= indw], stat(fvpercent  h17) name(c1) replace 
table locale (h17) ,m name(c1) append 
		collect export "$out/Phil_Brief_Health_Graphs_${date}", ///
			name(c1) as(xlsx) sheet("insurance_urban") cell(A1) modify	

table macro_region [aw= indw], stat(fvpercent  h17) name(c1) replace 
table macro_region (h17) ,m name(c1) append 
		collect export "$out/Phil_Brief_Health_Graphs_${date}", ///
			name(c1) as(xlsx) sheet("insurance_region") cell(A1) modify	
	
