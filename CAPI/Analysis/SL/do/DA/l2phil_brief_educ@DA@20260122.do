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


use "$in/l2phl_${date}_M02_edu.dta", clear

merge m:1 hhid using "$in/${dta_file}_M00_passport.dta", assert(3) keep(3) nogen keepusing(locale region)
merge 1:1 hhid fmid using "$in/weights_ind.dta", assert(3) keep(3) nogen keepusing(indw popw tag_hh)


* merge 1:1 hhid using "$in/${dta_file}_M09_nh.dta", assert(3) keep(3) nogen 
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
replace age_group = 0 if age <5
replace age_group = 1 if age >= 5& age <= 11
replace age_group = 2 if age >= 12 & age <= 15
replace age_group = 3 if age >= 16 & age <= 17
replace age_group = 4 if age >= 18 & age <= 24
replace age_group = 5 if age >= 25

label define age_group 0 "<5" 1 "5-11" 2 "12-15" 3 "16-17" 4 "18-24" 5 "25<" 
label values age_group age_group  




gen ed3_agg = .

	* 1 Pre-primary (daycare + kindergarten)
	replace ed3_agg = 1 if inlist(ed3, 1, 2)

	* 2 Primary (Grades 1–6)
	replace ed3_agg = 2 if inrange(ed3, 3, 8)

	* 3 Junior high (Grades 7–10)
	replace ed3_agg = 3 if inrange(ed3, 9, 12)

	* 4 Senior high (Grades 11–12)
	replace ed3_agg = 4 if inrange(ed3, 13, 14)

	* 5 ALS / SPED basic education (elementary + high school)
	replace ed3_agg = 5 if inlist(ed3, 28, 29, 30, 31)

	* 6 Post-secondary non-college / TVET
	replace ed3_agg = 6 if inrange(ed3, 32, 35)

	* 7 College (undergraduate years)
	replace ed3_agg = 7 if inrange(ed3, 36, 40)

	* 8 Postgraduate (Master's)
	replace ed3_agg = 8 if ed3 == 42

label define ed3_agg ///
  1 "Pre-primary (Daycare/Kindergarten)" ///
  2 "Primary (Grades 1–6)" ///
  3 "Junior high (Grades 7–10)" ///
  4 "Senior high (Grades 11–12)" ///
  5 "ALS/SPED basic education" ///
  6 "Post-secondary non-college / TVET" ///
  7 "College (undergraduate)" ///
  8 "Postgraduate (Master's)"

label values ed3_agg ed3_agg



label define yesno 0 "No" 1 "Yes", replace

foreach k of numlist 1/13 {
    gen ed4_r`k' = .
    replace ed4_r`k' = (strpos(ed4_txt, ";`k';")>0) if !missing(ed4_txt)
    label values ed4_r`k' yesno
}


	gen ed4_rother = .
	replace ed4_rother = regexm(ed4_txt, ";(1[4-9]|[2-9][0-9]);") if !missing(ed4_txt)
		label values ed4_rother yesno
		label var ed4_rother "Other reason (code >13)"

		local lab1  "Reason not attending: Difficulty getting to school"
		local lab2  "Illness/disability"
		local lab3  "Pregnancy"
		local lab4  "Marriage"
		local lab5  "High cost/financial concern"
		local lab6  "Employment"
		local lab7  "Finished schooling/post-sec/college"
		local lab8  "Looking for work"
		local lab9  "Lack of personal interest"
		local lab10 "Too young to go to school"
		local lab11 "Bullying"
		local lab12 "Family matters"
		local lab13 "School is pointless"

		forvalues k=1/13 {
			label var ed4_r`k' "`lab`k''"
		}


foreach k in 1 3 4 5 6 7 {
    gen ed9_r`k' = .
    replace ed9_r`k' = (strpos(ed9_txt, ";`k';")>0) if !missing(ed9_txt)
    label values ed9_r`k' yesno
}

gen ed9_rother = .
replace ed9_rother = regexm(ed9_txt, ";([^1-7];|[1-9][0-9];)") if !missing(ed9_txt)
label values ed9_rother yesno
label var ed9_rother "Other transport mode"

label var ed9_r1 "Mode of transportation: By foot"
label var ed9_r3 "Bicycle"
label var ed9_r4 "Motorcycle/Tricycle"
label var ed9_r5 "Jeepney/Bus"
label var ed9_r6 "Car/Taxi"
label var ed9_r7 "Boat"	
		
		
gen ed11_agg = .

* Keep main categories
replace ed11_agg = 1 if ed11 == 10   // Tagalog
replace ed11_agg = 2 if ed11 == 2    // Bisaya/Binisaya
replace ed11_agg = 3 if ed11 == 4    // English
replace ed11_agg = 4 if ed11 == 5    // Hiligaynon/Ilonggo
replace ed11_agg = 5 if ed11 == 3    // Cebuano

* Other Philippine languages (small groups)
replace ed11_agg = 6 if inlist(ed11, 1,6,7,9,11)

* Unknown / other (junk codes + DK)
replace ed11_agg = 7 if inlist(ed11, 28,30,33,34,36,37,38,39,40,45,47,99)

label define ed11_agg ///
  1 "Tagalog" ///
  2 "Bisaya/Binisaya" ///
  3 "English" ///
  4 "Hiligaynon/Ilonggo" ///
  5 "Cebuano" ///
  6 "Other Philippine languages" ///
  7 "Unknown / other"

label values ed11_agg ed11_agg


gen ed12_agg = .

	* 1 No schooling / pre-primary
	replace ed12_agg = 1 if inlist(ed12, 77, 1, 2)

	* 2 Primary
	replace ed12_agg = 2 if inrange(ed12, 3, 8) | ///
						   inrange(ed12, 16, 21) | ///
						   inlist(ed12, 22, 28, 30)

	* 3 Lower secondary (Junior HS)
	replace ed12_agg = 3 if inrange(ed12, 9, 12) | ///
						   inrange(ed12, 23, 26)

	* 4 Upper secondary (Senior HS)
	replace ed12_agg = 4 if inlist(ed12, 13, 14, 27, 29, 31)

	* 5 Post-secondary non-tertiary (TVET)
	replace ed12_agg = 5 if inlist(ed12, 34, 35)

	* 6 Tertiary and above
	replace ed12_agg = 6 if inlist(ed12, 46, 47, 43, 45)

label define ed12_agg ///
  1 "No schooling / pre-primary" ///
  2 "Primary education" ///
  3 "Lower secondary (Junior HS)" ///
  4 "Upper secondary (Senior HS)" ///
  5 "Post-secondary non-tertiary (TVET)" ///
  6 "Tertiary and above"

label values ed12_agg ed12_agg

label variable ed11_agg "Language of teaching "
label variable ed12_agg "HIghest educ. attaintment"


* Current attendance

table age_group gender , stat(fvpercent  ed1)  name (c1) replace
	 collect style header age_group ed1, title(hide) 
	 		collect preview, name(c1) 
  collect export "$out/Phil_Brief_Education_Graphs_${date}", as(xlsx) sheet(school) replace


  
local varlist ed1 ed2 ed3_agg ed4_r1 ed4_r2 ed4_r3 ed4_r4 ed4_r5 ed4_r6 ed4_r7 ed4_r8 ed4_r9 ed4_r10 ed4_r11 ed4_r12 ed4_r13 ed4_rother ed6 ed8_tutor1 ed9_r1 ed9_r3 ed9_r4 ed9_r5 ed9_r6 ed9_r7 ed9_rother ed11_agg ed12_agg

// foreach var of local varlist {
//      table `var' , stat(percent)
// 	 collect export "$out/Phil_Brief_Dwelling_Graphs_${date}", as(xlsx) sheet(`var') cell(A1) modify
//      }


collect clear
foreach var of local varlist {
      table (locale) [aw= indw] ,  name(Table) append  stat(fvpercent `var') nformat(%9.2f)
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Education_Graphs_${date}", as(xlsx) sheet(urban_edu) modify

collect clear
foreach var of local varlist {
      table (locale) (`var' ), m name(Table) append
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Education_Graphs_${date}", as(xlsx) sheet(urban_edu_num) modify


collect clear
foreach var of local varlist {
      table (macro_region) [aw= indw] ,  name(Table) append  stat(fvpercent `var')  nformat(%9.2f)
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Education_Graphs_${date}", as(xlsx) sheet(region_edu) modify

  
collect clear
foreach var of local varlist {
       table (macro_region) (`var' ), m name(Table) append
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Education_Graphs_${date}", as(xlsx) sheet(region_edu_num) modify


collect clear
foreach var of local varlist {
      table (gender) [aw= indw] ,  name(Table) append  stat(fvpercent `var')  nformat(%9.2f)
     }

  collect layout (`varlist') (gender)
  collect export "$out/Phil_Brief_Education_Graphs_${date}", as(xlsx) sheet(gender_edu) modify

collect clear
foreach var of local varlist {
      table (gender)  (`var' ), m name(Table) append
     }

  collect layout (`varlist') (gender)
  collect export "$out/Phil_Brief_Education_Graphs_${date}", as(xlsx) sheet(gender_edu_num) modify
  

collect clear
foreach var of local varlist {
      table (age_group) [aw= indw] ,  name(Table) append  stat(fvpercent `var')  nformat(%9.2f)
     }

  collect layout (`varlist') (age_group)
  collect export "$out/Phil_Brief_Education_Graphs_${date}", as(xlsx) sheet(age_edu) modify

collect clear
foreach var of local varlist {
      table (age_group)  (`var' ), m name(Table) append
     }

  collect layout (`varlist') (age_group)
  collect export "$out/Phil_Brief_Education_Graphs_${date}", as(xlsx) sheet(age_edu_num) modify
  
 
collect clear

table (locale)  [aw= indw] , ///
    statistic(mean ed5a) ///
    statistic(mean ed5b) ///
    statistic(mean ed5c) ///
    statistic(mean ed5d) ///
    statistic(mean ed5e) ///
    statistic(mean ed5f) ///
    statistic(mean ed5g) ///
    statistic(mean ed5h) ///
    statistic(mean ed5i) ///	
    statistic(mean ed7)  nformat(%9.2f mean) ///		
    name(Table)
table (locale), ///
    statistic(count ed5a) ///
    statistic(min ed5a) ///
    statistic(max ed5a) ///	
    statistic(count ed5b) ///
    statistic(min ed5b) ///	
    statistic(max ed5b) ///	
    statistic(count ed5c) ///
    statistic(min ed5c) ///
    statistic(max ed5c) ///	
    statistic(count ed5d) ///
    statistic(min ed5d) ///
    statistic(max ed5d) ///	
    statistic(count ed5e) ///
    statistic(min ed5e) ///
    statistic(max ed5e) ///	
    statistic(count ed5f) ///
    statistic(min ed5f) ///
    statistic(max ed5f) ///	
    statistic(count ed5g) ///
    statistic(min ed5g) ///
    statistic(max ed5g) ///	
    statistic(count ed5h) ///
    statistic(min ed5h) ///
    statistic(max ed5h) ///	
    statistic(count ed5i) ///
    statistic(min ed5i) ///
    statistic(max ed5i) ///	
    statistic(count ed7) ///
    statistic(min ed7) ///
    statistic(max ed7) ///			
    name(Table) append
collect layout (colname # result) (locale)
collect export "$out/Phil_Brief_Education_Graphs_${date}.xlsx", ///
    sheet(urban_costs_edu) modify
 
  
collect clear

table (gender)  [aw= indw] , ///
    statistic(mean ed5a) ///
    statistic(mean ed5b) ///
    statistic(mean ed5c) ///
    statistic(mean ed5d) ///
    statistic(mean ed5e) ///
    statistic(mean ed5f) ///
    statistic(mean ed5g) ///
    statistic(mean ed5h) ///
    statistic(mean ed5i) ///	
    statistic(mean ed7)  nformat(%9.2f mean) ///		
    name(Table)
table (gender), ///
    statistic(count ed5a) ///
    statistic(min ed5a) ///
    statistic(max ed5a) ///	
    statistic(count ed5b) ///
    statistic(min ed5b) ///	
    statistic(max ed5b) ///	
    statistic(count ed5c) ///
    statistic(min ed5c) ///
    statistic(max ed5c) ///	
    statistic(count ed5d) ///
    statistic(min ed5d) ///
    statistic(max ed5d) ///	
    statistic(count ed5e) ///
    statistic(min ed5e) ///
    statistic(max ed5e) ///	
    statistic(count ed5f) ///
    statistic(min ed5f) ///
    statistic(max ed5f) ///	
    statistic(count ed5g) ///
    statistic(min ed5g) ///
    statistic(max ed5g) ///	
    statistic(count ed5h) ///
    statistic(min ed5h) ///
    statistic(max ed5h) ///	
    statistic(count ed5i) ///
    statistic(min ed5i) ///
    statistic(max ed5i) ///	
    statistic(count ed7) ///
    statistic(min ed7) ///
    statistic(max ed7) ///			
    name(Table) append

collect layout (colname # result) (gender)
collect export "$out/Phil_Brief_Education_Graphs_${date}.xlsx", ///
    sheet(gender_costs_edu) modify 
  
local varlist ed13 ed14 
 
collect clear
foreach var of local varlist {
      table (locale) [aw= popw] if tag_hh==1,  name(Table) append  stat(fvpercent `var')  nformat(%9.2f)
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Education_Graphs_${date}", as(xlsx) sheet(urban_edu_parent) modify

  collect clear
foreach var of local varlist {
      table (locale) if tag_hh==1,  name(Table) append  stat(fvfrequency `var') 
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Education_Graphs_${date}", as(xlsx) sheet(urban_edu_parent_num) modify



collect clear
foreach var of local varlist {
      table (macro_region) [aw= popw] if tag_hh==1, name(Table) append  stat(fvpercent `var')  nformat(%9.2f)
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Education_Graphs_${date}", as(xlsx) sheet(region_edu_parent) modify

collect clear
foreach var of local varlist {
      table (macro_region) if tag_hh==1, name(Table) append  stat(fvfrequency `var')  
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Education_Graphs_${date}", as(xlsx) sheet(region_edu_parent_num) modify
    
  
reshape long ed9_trans ed10_time, i(hhid fmid) j(option)
drop if missing(ed9_trans) | missing(ed10_time)
  
  gen transport_agg = .

* Official categories
replace transport_agg = ed9_trans if inrange(ed9_trans, 1, 7)

* Everything else
replace transport_agg = 99 if !inrange(ed9_trans, 1, 7)
label define transport_agg ///
  1 "By foot" ///
  2 "Own vehicle" ///
  3 "Bicycle" ///
  4 "Motorcycle/Tricycle" ///
  5 "Jeepney/Bus" ///
  6 "Car/Taxi" ///
  7 "Boat" ///
  99 "Other transport"

label values transport_agg transport_agg

collect clear
table transport_agg locale [aw= indw] , stat(mean ed10_time)  nformat(%9.2f mean)
  table (transport_agg) (locale), m append stat(count ed10_time)
collect export "$out/Phil_Brief_Education_Graphs_${date}.xlsx", ///
    sheet(urban_time) modify 

collect clear
table transport_agg gender [aw= indw] , stat(mean ed10_time)  nformat(%9.2f mean)
  table (transport_agg) (gender), m append stat(count ed10_time)
collect export "$out/Phil_Brief_Education_Graphs_${date}.xlsx", ///
    sheet(gender_time) modify 


graph box ed10_time [aw= indw] ,  over(locale) over(transport_agg) ///
    ytitle("Travel time to school (minutes)") ///
    title("Travel time by transport mode")	
		graph export $out/duration.png, replace width(2000)

  
  
 use "$in/l2phl_${date}_M14_view.dta", clear
    merge 1:1 hhid using "$in/${dta_file}_M00_passport.dta",  keep(3) nogen keepusing(locale region)
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
	
  table  locale [aw= popw], stat(fvpercent v7 ) replace  nformat(%9.2f)
  table (locale) (v7), m append
  collect export "$out/Phil_Brief_Education_Graphs_${date}", as(xlsx) sheet(value_educ) modify

  recode v9f (6=.)
    table  locale [aw= popw], stat(fvpercent v9f )  replace  nformat(%9.2f)
	  table (locale) (v9f), m append
  collect export "$out/Phil_Brief_Education_Graphs_${date}", as(xlsx) sheet(worry_educ) modify

     table  locale [aw= popw], stat(fvpercent v4 )  replace  nformat(%9.2f)
		table (locale) (v4) , m append 
  collect export "$out/Phil_Brief_Education_Graphs_${date}", as(xlsx) sheet(future_educ) modify

  
  
* Row percentages: current group -> future group
bys v2: egen n = count(v3)
bys v2 v3: gen z = _N
bys v2: replace z = 100 * z / n

heatplot z v2 v3 [aw= popw], ///
    discrete ///
    values(format(%4.1f)) ///
    xlabel( ///
        1 "Lowest" ///
        2 "Low" ///
        3 "Middle" ///
        4 "High" ///
        5 "Highest", angle(45)) ///
    ylabel( ///
        1 "Lowest" ///
        2 "Low" ///
        3 "Middle" ///
        4 "High" ///
        5 "Highest") ///
    title("Perceived Income Mobility") ///
    xtitle("Imagined future income group") ///
    ytitle("Current income group") ///
    legend(on)
	
	
	graph export $out/perceived_income_mobility.png, replace width(2000)
