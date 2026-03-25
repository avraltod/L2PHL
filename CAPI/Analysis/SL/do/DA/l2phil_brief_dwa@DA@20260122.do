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
//	glo date 20251127
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
		copy "${dta}/final_weights.dta"  ///
				"$in/weights_ind.dta", replace					
	}
	



* Load Passport data with weights


use "$in/l2phl_${date}_M10_dwell.dta", clear

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

label define DWL_WALL 11 "Mixed Wood and Metal Sheets" 13 "Wall Cladding Material" , add 


* merge 1:1 hhid using "$in/${dta_file}_M09_nh.dta", assert(3) keep(3) nogen 


table dw1 , stat(percent)
collect export "$out/Phil_Brief_Dwelling_Graphs_${date}", ///
			as(xlsx) sheet("dw1") cell(A1) replace	

local varlist dw1 dw2 dw3 dw4 dw5 dw6 dw8 dw9 dw10 dw11a dw11b dw12 dw13 dw14 dw15

// foreach var of local varlist {
//      table `var' , stat(percent)
// 	 collect export "$out/Phil_Brief_Dwelling_Graphs_${date}", as(xlsx) sheet(`var') cell(A1) modify
//      }


foreach var of local varlist {
      table (locale)  [aw= hhw],  name(Table) append  stat(fvpercent `var')  nformat(%9.2f)
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Dwelling_Graphs_${date}", as(xlsx) sheet(urban_dwelling) modify

   collect clear
foreach var of local varlist {
      table (locale) ( `var'), m  name(Table) append 
     }
  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Dwelling_Graphs_${date}", as(xlsx) sheet(urban_dwelling_num) modify


  
foreach var of local varlist {
     table (macro_region)  [aw= hhw],  name(Table) append  stat(fvpercent `var')  nformat(%9.2f)
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Dwelling_Graphs_${date}", as(xlsx) sheet(macro_region_dwelling) modify
 
 collect clear
foreach var of local varlist {
      table (macro_region) ( `var'), m  name(Table) append 
     }
  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Dwelling_Graphs_${date}", as(xlsx) sheet(macro_region_dwelling_num) modify
 

  table (locale)  [aw= hhw],  stat(fvpercent  dw7 )  name(c1) replace
  table (locale) ( dw7 ), m  name(c1) append

		collect export "$out/Phil_Brief_Dwelling_Graphs_${date}", ///
			name(c1) as(xlsx) sheet("paint_inside") cell(A1) modify	
 
 
   table (locale)  [aw= hhw],  stat(fvpercent dw8b)  name(c1) replace 
  table (locale) ( dw8b ), m  name(c1) append
		collect export "$out/Phil_Brief_Dwelling_Graphs_${date}", ///
			name(c1) as(xlsx) sheet("paint_outside") cell(A1) modify	

			
gen years_since_inside_paint=2025-dw6a
gen years_since_outside_paint=2025-dw8a			
			
table (locale)  [aw= hhw], ///
    statistic(mean years_since_inside_paint) ///
    statistic(mean years_since_outside_paint)  nformat(%9.2f mean) ///
    name(Table)
table (locale), ///
    statistic(count years_since_inside_paint) ///
    statistic(min years_since_inside_paint) ///
    statistic(max years_since_inside_paint) ///	
    statistic(count years_since_outside_paint) ///
    statistic(min years_since_outside_paint) ///	
    statistic(max years_since_outside_paint) ///			
    name(Table) append
collect layout (colname # result) (locale)
collect export "$out/Phil_Brief_Dwelling_Graphs_${date}.xlsx", ///
    sheet(years_since_paint) modify
