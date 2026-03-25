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


use "$in/l2phl_${date}_M08_food.dta", clear

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


* merge 1:1 hhid using "$in/${dta_file}_M09_nh.dta", assert(3) keep(3) nogen 

 forvalues k = 1/6 {
    gen choice_`k' = (strpos(fo3_txt, ";`k';") > 0)
}
			
gen choice_15_98 = 0

foreach v of varlist fo3_mode1-fo3_mode3{
    replace choice_15_98 = 1 if inrange(`v',11,98)
}


recode choice* (0=.) if fo3_txt==""

label variable choice_1 "Transport for food source: By foot"
label variable choice_3 "Bicycle"
label variable choice_4 "Motorcycle/Tricycle"
label variable choice_5 "Jeepney/Bus"
label variable choice_6 "Car/Taxi" 
label variable choice_15_98 "Other"   

 recode	choice*	 (0=2)
		
label define yesno 2 "No" 1 "Yes"		
label values choice* yesno	

  
recode fo5 (-99=.)

table fo1 , stat(percent)
collect export "$out/Phil_Brief_Food_Graphs_${date}", ///
			as(xlsx) sheet("f01") cell(A1) replace	

local varlist fo1 fo2 choice_1 choice_3 choice_4 choice_5 choice_6 choice_15_98 fo6 fo7


foreach var of local varlist {
      table (locale) [aw= popw],  name(Table) append  stat(fvpercent `var') nformat(%9.2f)
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Food_Graphs_${date}", as(xlsx) sheet(urban_food) modify

collect clear
foreach var of local varlist {
      table (locale) (`var'), m name(Table) append 
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Food_Graphs_${date}", as(xlsx) sheet(urban_food_num) modify
  
  
  
foreach var of local varlist {
     table (macro_region) [aw= popw],  name(Table) append  stat(fvpercent `var')  nformat(%9.2f)
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Food_Graphs_${date}", as(xlsx) sheet(macro_region_food) modify

collect clear  
foreach var of local varlist {
     table (macro_region) (`var'), m name(Table) append 
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Food_Graphs_${date}", as(xlsx) sheet(macro_region_food_num) modify
  


collect clear

collect clear
table (locale) [aw= popw], ///
    statistic(mean fo4) ///
    statistic(mean fo5)  nformat(%9.2f mean) ///
    name(Table)
table (locale), ///
    statistic(count fo4) ///
    statistic(min fo4) ///
    statistic(max fo4) ///	
    statistic(count fo5) ///
    statistic(min fo5) ///	
    statistic(max fo5) ///		
    name(Table) append
collect layout (colname # result) (locale)
collect export "$out/Phil_Brief_Food_Graphs_${date}.xlsx", ///
    sheet(urban_costs_dur) modify


	
collect clear
table (macro_region) [aw= popw], ///
    statistic(mean fo4) ///
    statistic(mean fo5) nformat(%9.2f mean) ///
    name(Table)
table (macro_region), ///
    statistic(count fo4) ///
    statistic(min fo4) ///
    statistic(max fo4) ///	
    statistic(count fo5) ///
    statistic(min fo5) ///	
    statistic(max fo5) ///		
    name(Table) append

collect layout (colname # result) (macro_region)
collect export "$out/Phil_Brief_Food_Graphs_${date}.xlsx", ///
    sheet(region_costs_dur) modify	
* Sweet beverages 


use "$in/l2phl_${date}_M08_ssb.dta", clear

merge m:1 hhid using "$in/${dta_file}_M00_passport.dta", assert(3) keep(3) nogen keepusing(locale region)
merge 1:1 hhid fmid using "$in/weights_ind.dta", assert(3) keep(3) nogen keepusing(hhw popw indw tag_hh)



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


* merge 1:1 hhid using "$in/${dta_file}_M09_nh.dta", assert(3) keep(3) nogen 

gen age_group = .
replace age_group = 1 if age <= 10
replace age_group = 2 if age >= 11 & age <= 20
replace age_group = 3 if age >= 21 & age <= 30
replace age_group = 4 if age >= 31 & age <= 40
replace age_group = 5 if age >= 41 & age <= 50
replace age_group = 6 if age >= 51 & age <= 60
replace age_group = 7 if age >= 61

label define age_group 1 "<10" 2 "11-20" 3 "21-30" 4 "31-40"  5 "41-50" 6 "51-60"  7 ">60" 
label values age_group age_group  

replace ssb2=2 if ssb1==2


collect clear
table (locale) [aw= popw] if tag_hh==1,  stat(fvpercent ssb1) 
table (locale) (ssb1) if tag_hh==1, m append
collect export "$out/Phil_Brief_Food_Graphs_${date}.xlsx", ///
    sheet(sweet_urban) modify
	
	
collect clear
table (macro_region) [aw= popw] if tag_hh==1,  append  stat(fvpercent ssb1) 
table (macro_region) (ssb1) if tag_hh==1, m append
collect export "$out/Phil_Brief_Food_Graphs_${date}.xlsx", ///
    sheet(sweet_region) modify


collect clear
table  (age_group) (gender) [aw= indw],  append  stat(fvpercent ssb2) 
table  (age_group) (gender),  append  stat(fvfrequency  ssb2) 
collect export "$out/Phil_Brief_Food_Graphs_${date}.xlsx", ///
    sheet(sweet_age_gender) modify


collect clear
table  (age_group) (gender) [aw= indw],  append  stat(mean ssb3) nformat(%9.2f mean)
table  (age_group) (gender),  append  stat(count ssb3) 
table  (age_group) (gender),  append  stat(min ssb3) 
table  (age_group) (gender),  append  stat(max ssb3) 
collect export "$out/Phil_Brief_Food_Graphs_${date}.xlsx", ///
    sheet(sweet_age_gender_cons) modify

