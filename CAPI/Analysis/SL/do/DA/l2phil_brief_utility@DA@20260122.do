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


use "$in/l2phl_${date}_M12_water.dta", clear

merge 1:1 hhid using "$in/${dta_file}_M00_passport.dta", assert(3) keep(3) nogen keepusing(locale region)

merge 1:1 hhid using "$in/${dta_file}_M12_elec.dta", assert(3) keep(3) nogen 

merge 1:1 hhid using "$in/${dta_file}_M12_net.dta", assert(3) keep(3) nogen 

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

label define WAT_SOURCE 21 "Gallon of water", modify
label define WAT_SOURCE 26 "Water pump" 28 "Own filter", add


* merge 1:1 hhid using "$in/${dta_file}_M09_nh.dta", assert(3) keep(3) nogen 


table w1 , stat(percent)
collect export "$out/Phil_Brief_Utility_Graphs_${date}", ///
			as(xlsx) sheet("w1") cell(A1) replace	

local varlist w1 w3 w4 w5 w6 w8

// foreach var of local varlist {
//      table `var' , stat(percent)
// 	 collect export "$out/Phil_Brief_Dwelling_Graphs_${date}", as(xlsx) sheet(`var') cell(A1) modify
//      }


foreach var of local varlist {
      table (locale) [aw= hhw],  name(Table) append  stat(fvpercent `var') nformat(%9.2f)
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Utility_Graphs_${date}", as(xlsx) sheet(urban_water) modify

  collect clear   
 foreach var of local varlist {
      table (locale) (`var') , m  name(Table) append 
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Utility_Graphs_${date}", as(xlsx) sheet(urban_water_num) modify
 
  
foreach var of local varlist {
     table (macro_region) [aw= hhw],  name(Table) append  stat(fvpercent `var')  nformat(%9.2f)
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Utility_Graphs_${date}", as(xlsx) sheet(macro_region_water) modify
  
  collect clear   
 foreach var of local varlist {
      table (macro_region) (`var') , m  name(Table) append 
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Utility_Graphs_${date}", as(xlsx) sheet(macro_region_water_num) modify

  
  
 label define ELEC_SOURCE 12 "Fossil Fuel", add
 
local varlist el5 el2 el3 el4 el5
		
		
foreach var of local varlist {
      table (locale) [aw= hhw],  name(Table) append  stat(fvpercent `var') nformat(%9.2f) 
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Utility_Graphs_${date}", as(xlsx) sheet(urban_elec) modify

  collect clear   
 foreach var of local varlist {
      table (locale) (`var') , m  name(Table) append 
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Utility_Graphs_${date}", as(xlsx) sheet(urban_elec_num) modify
  
  
foreach var of local varlist {
     table (macro_region) [aw= hhw],  name(Table) append  stat(fvpercent `var') nformat(%9.2f) 
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Utility_Graphs_${date}", as(xlsx) sheet(macro_region_elec) modify
 
 collect clear   
 foreach var of local varlist {
      table (macro_region) (`var') , m  name(Table) append 
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Utility_Graphs_${date}", as(xlsx) sheet(macro_region_elec_num) modify
 
  
  
  
  
 forvalues k = 1/5 {
    gen n1_choice_`k' = (strpos(n1_txt, ";`k';") > 0)
}

recode n1_choice* (0=.) if n1_txt==""

label variable n1_choice_1 "Internet at home: Yes, Fixed (wired) broadband network"
label variable n1_choice_2 "Yes, Fixed (wireless) broadband network"
label variable n1_choice_3 "Yes, Satellite broadband network"
label variable n1_choice_4 "Yes, Mobile broadband network"
label variable n1_choice_5 "No"
		
		
 forvalues k = 1/5 {
    gen n2_choice_`k' = (strpos(n2_txt, ";`k';") > 0)
}

recode n2_choice* (0=.) if n2_txt==""

label variable n2_choice_1 "Internet access device: Personal Computer (PC) / Desktop"
label variable n2_choice_2 "Laptop"
label variable n2_choice_3 "Tablet"
label variable n2_choice_4 "Smartphone"
label variable n2_choice_5 "Smart TV/Monitor"		
		
 foreach k in 1 2 12 {
    gen n3_choice_`k' = (strpos(n3_txt, ";`k';") > 0)
}

recode n3_choice* (0=.) if n3_txt==""

label variable n3_choice_1 "Internet subscription type: Prepaid"
label variable n3_choice_2 "Postpaid / billed monthly by a provider"
label variable n3_choice_12 "Connecting to neighbor's WiFi"
		
		
forvalues k = 1/12 {
    gen n4_choice_`k' = (strpos(n4_txt, ";`k';") > 0)
}

recode n4_choice* (0=.) if n4_txt==""

label variable n4_choice_1 "Internet purpose: Communication/social networking"
label variable n4_choice_2 "Payments/banking"
label variable n4_choice_3 "Search for information/news/current events "
label variable n4_choice_4 "Online shopping"
label variable n4_choice_5 "Online education"
label variable n4_choice_6 "Non-gig work"
label variable n4_choice_7 "Gig work"
label variable n4_choice_8 "Telehealth/medicine"
label variable n4_choice_9 "Use government services"
label variable n4_choice_10 "Access government information"
label variable n4_choice_11 "Search for jobs"
label variable n4_choice_12 "Entertainment/gaming "

		
forvalues k = 1/7 {
    gen n6_choice_`k' = (strpos(n6_txt, ";`k';") > 0)
}

recode n6_choice* (0=.) if n6_txt==""

label variable n6_choice_1 "Access internet outside home: Piso wifi"
label variable n6_choice_2 "Hotspots from government offices"
label variable n6_choice_3 "Hotspots from private establishments (like malls, cafes, etc.)"
label variable n6_choice_4 "School / Office"
label variable n6_choice_5 "Neighbors/ Other households"
label variable n6_choice_6 "Mobile broadband network/ Mobile data"
label variable n6_choice_7 "None"		
		

		
recode	n6_choice*	n4_choice* n2_choice* n1_choice* n3_choice* (0=2)
		
label values n6_choice*	n4_choice* n2_choice* n1_choice* n3_choice*	NET_YN	
		
		
local varlist n1_choice_1 n1_choice_2 n1_choice_3 n1_choice_4 n1_choice_5 n2_choice_1 n2_choice_2 n2_choice_3 n2_choice_4 n2_choice_5 n3_choice_1 n3_choice_2 n3_choice_12 n4_choice_1 n4_choice_2 n4_choice_3 n4_choice_4 n4_choice_5 n4_choice_6 n4_choice_7 n4_choice_8 n4_choice_9 n4_choice_10 n4_choice_11 n4_choice_12 n5 n6_choice_1 n6_choice_2 n6_choice_3 n6_choice_4 n6_choice_5 n6_choice_6 n6_choice_7
		
		
foreach var of local varlist {
      table (locale) [aw= hhw],  name(Table) append  stat(fvpercent `var')  nformat(%9.2f)
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Utility_Graphs_${date}", as(xlsx) sheet(urban_net) modify
  
collect clear   
 foreach var of local varlist {
      table (locale) (`var') , m  name(Table) append 
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Utility_Graphs_${date}", as(xlsx) sheet(urban_net_num) modify
    
  
foreach var of local varlist {
     table (macro_region) [aw= hhw],  name(Table) append  stat(fvpercent `var')  nformat(%9.2f)
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Utility_Graphs_${date}", as(xlsx) sheet(macro_region_net) modify

collect clear   
 foreach var of local varlist {
      table (macro_region) (`var') , m  name(Table) append 
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Utility_Graphs_${date}", as(xlsx) sheet(macro_region_net_num) modify
  

			