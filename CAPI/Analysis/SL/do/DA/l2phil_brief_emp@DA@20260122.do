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


use "$in/l2phl_${date}_M03_emp.dta", clear

merge m:1 hhid using "$in/${dta_file}_M00_passport.dta", assert(3) keep(3) nogen keepusing(locale region)

merge 1:1 hhid fmid using "$in/${dta_file}_M02_edu.dta", assert(3) keep(3) nogen keepusing(ed12)
merge 1:1 hhid fmid using "$in/weights_ind.dta", assert(3) keep(3) nogen keepusing(indw popw tag_hh)



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
replace age_group = 1 if age >= 15 & age <= 24
replace age_group = 2 if age >= 25 & age <= 34
replace age_group = 3 if age >= 35 & age <= 44
replace age_group = 4 if age >= 45 & age <= 54
replace age_group = 5 if age >= 55 & age <= 65

label define age_group 1 "15-24" 2 "25-34" 3 "35-44" 4 "45-54" 5 "55-64"
label values age_group age_group


label values a13 JOB_INC
label values a15 JOB_INC


forvalues k = 1/7 {
    gen choice_`k' = (strpos(a19_txt, ";`k';") > 0)
}

recode choice* (0=.) if a19_txt==""

label variable choice_1 "Employment benefit: Workplace pension plan"
label variable choice_2 "Paid leave (vacation/annual, sick, maternity/paternity)"
label variable choice_3 "SSS/GSIS"
label variable choice_4 "PhilHealth"
label variable choice_5 "Private health insurance/HMO"
label variable choice_7 "None of the above"

label define yesno 0 "No" 1 "Yes", replace

label values choice*  yesno


* Official modes 1–7
foreach k in 1 3 4 5 6 7 {
    gen a21_r`k' = .
    replace a21_r`k' = (strpos(a21_txt, ";`k';")>0) if !missing(a21_txt)
    label values a21_r`k' yesno
}

* Work from home (97)
gen a21_r97 = .
replace a21_r97 = (strpos(a21_txt, ";97;")>0) if !missing(a21_txt)
label values a21_r97 yesno
label var a21_r97 "Work from home"

* Other = everything else
gen a21_rother = .
replace a21_rother = regexm(a21_txt, ";([^1-7]|9[689]);|;[1-9][0-9];") if !missing(a21_txt)
label values a21_rother yesno
label var a21_rother "Other transport"


label var a21_r1 "Mode of transport: By foot"
label var a21_r3 "Bicycle"
label var a21_r4 "Motorcycle/Tricycle"
label var a21_r5 "Jeepney/Bus"
label var a21_r6 "Car/Taxi"
label var a21_r7 "Boat"

tab1 a21_r1-a21_r7 a21_r97 a21_rother

recode a22 a23 (-99=.)
recode a13 a15 (.=2)

drop if age>64|age<15




table (age_gr) (gender) [aw= indw], statistic(fvpercent a1) nototal name(c1) replace 
 		collect style header age_gr, title(hide)  name(c1)
		collect label levels gender 1 "Men" 2 "Women", name(c1) modify  		
		collect preview, name(c1) 
		collect export "$out/Phil_Brief_Emp_Graphs_${date}", ///
			name(c1) as(xlsx) sheet("emp_age") cell(A1) replace	

label define DIGIPLATFORM 99 "Don't know", add
label define REASON_NOWORK 99 "Don't know", add


local varlist a1 a2 a3 a5 a6 a7 a8 a9 a10 a13 a15 a16 a17 a18 choice_1 choice_2 choice_3 choice_4 choice_5 choice_7 a20 a21_r1 a21_r3 a21_r4 a21_r5 a21_r6 a21_r7 a21_r97 a21_rother



collect clear
foreach var of local varlist {
      table (locale) [aw= indw] ,  name(Table) append  stat(fvpercent `var') nformat(%9.2f)
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Emp_Graphs_${date}", as(xlsx) sheet(urban_emp) modify

  
collect clear
foreach var of local varlist {
      table (locale)  ( `var')  , m name(Table) append 
     }

  collect layout (`varlist') (locale)
  collect export "$out/Phil_Brief_Emp_Graphs_${date}", as(xlsx) sheet(urban_emp_num) modify
  


collect clear
foreach var of local varlist {
      table (macro_region) [aw= indw] ,  name(Table) append  stat(fvpercent `var') nformat(%9.2f)
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Emp_Graphs_${date}", as(xlsx) sheet(region_emp) modify

collect clear
foreach var of local varlist {
      table (macro_region)  ( `var')  , m name(Table) append 
     }

  collect layout (`varlist') (macro_region)
  collect export "$out/Phil_Brief_Emp_Graphs_${date}", as(xlsx) sheet(region_emp_num) modify

  
collect clear
foreach var of local varlist {
      table (gender) [aw= indw] ,  name(Table) append  stat(fvpercent `var') nformat(%9.2f)
     }

  collect layout (`varlist') (gender)
  collect export "$out/Phil_Brief_Emp_Graphs_${date}", as(xlsx) sheet(gender_emp) modify

collect clear
foreach var of local varlist {
      table (gender) ( `var')  , m name(Table) append 
     }

  collect layout (`varlist') (gender)
  collect export "$out/Phil_Brief_Emp_Graphs_${date}", as(xlsx) sheet(gender_emp_num) modify
  

collect clear
foreach var of local varlist {
      table (age_group) [aw= indw] ,  name(Table) append  stat(fvpercent `var') nformat(%9.2f)
     }

  collect layout (`varlist') (age_group)
  collect export "$out/Phil_Brief_Emp_Graphs_${date}", as(xlsx) sheet(age_emp) modify

collect clear
foreach var of local varlist {
      table (age_group) ( `var')  , m name(Table) append 
     }

  collect layout (`varlist') (age_group)
  collect export "$out/Phil_Brief_Emp_Graphs_${date}", as(xlsx) sheet(age_emp_num) modify
  
 
collect clear

table (locale)  [aw= indw] , ///
    statistic(mean a11) ///
    statistic(mean a22) ///
    statistic(mean a23)     nformat(%9.2f mean) ///
    name(Table)
table (locale), ///
    statistic(count a11) ///
    statistic(min a11) ///
    statistic(max a11) ///	
    statistic(count a22) ///
    statistic(min a22) ///	
    statistic(max a22) ///	
    statistic(count a23) ///
    statistic(min a23) ///
    statistic(max a23) ///				
    name(Table) append

collect layout (colname # result) (locale)
collect export "$out/Phil_Brief_Emp_Graphs_${date}.xlsx", ///
    sheet(urban_costs_emp) modify
  
collect clear

table (gender)  [aw= indw] , ///
    statistic(mean a11) ///
    statistic(mean a22) ///
    statistic(mean a23)    nformat(%9.2f mean) ///
    name(Table)
table (gender), ///
    statistic(count a11) ///
    statistic(min a11) ///
    statistic(max a11) ///	
    statistic(count a22) ///
    statistic(min a22) ///	
    statistic(max a22) ///	
    statistic(count a23) ///
    statistic(min a23) ///
    statistic(max a23) ///				
    name(Table) append
collect layout (colname # result) (gender)
collect export "$out/Phil_Brief_Emp_Graphs_${date}.xlsx", ///
    sheet(gender_costs_emp) modify
	
collect clear
table (gender) [aw= indw] ,  name(Table) append  stat(fvpercent a4) 
table (gender)  ( a4)	 ,  name(Table) append 
	collect export "$out/Phil_Brief_Emp_Graphs_${date}.xlsx", ///
    sheet(occupation) modify

collect clear
table (a5) [aw= indw] ,  name(Table) append  stat(fvpercent a16) 
table (a5)  ( a16)	 ,  name(Table) append 
	collect export "$out/Phil_Brief_Emp_Graphs_${date}.xlsx", ///
    sheet(sector_contract) modify	
	
/*
	
table (macro_region) (gender) , statistic(mean employment) nototal name(c1) replace 
 		collect style header age_gr, title(hide)  name(c1)
		collect label levels gender 1 "Men" 2 "Women", name(c1) modify  		
		collect preview, name(c1) 
		collect export "$out/Phil_Brief_Emp_Graphs_${date}", ///
			name(c1) as(xlsx) sheet("emp_reg") cell(A1) modify				
			
table (urban) (gender) , statistic(mean a10) nototal name(c1) replace 
 		collect style header age_gr, title(hide)  name(c1)
		collect label levels gender 1 "Men" 2 "Women", name(c1) modify  		
		collect preview, name(c1) 
		collect export "$out/Phil_Brief_Emp_Graphs_${date}", ///
			name(c1) as(xlsx) sheet("workdays") cell(A1) modify	
			
			
recode a3 (10=99)  (4=99)  (2=99) 
replace a3=99 if a3>11&a3<50 

table gender, stat(fvpercent  a3) name(c1) replace 
 		collect style header gender, title(hide)  name(c1)
		collect label levels gender 1 "Men" 2 "Women", name(c1) modify  		
		collect preview, name(c1) 
		collect export "$out/Phil_Brief_Emp_Graphs_${date}", ///
			name(c1) as(xlsx) sheet("reason_not") cell(A1) modify	

table gender, stat(fvpercent  a6) name(c1) replace 
 		collect style header gender, title(hide)  name(c1)
		collect label levels gender 1 "Men" 2 "Women", name(c1) modify  		
		collect preview, name(c1) 
		collect export "$out/Phil_Brief_Emp_Graphs_${date}", ///
			name(c1) as(xlsx) sheet("class_work") cell(A1) modify	

recode a16 a17 a18 (99=.)

table (urban) (gender) , statistic(fvpercent a16) name(c1) replace 
 		collect style header a16, title(hide)  name(c1)
		collect label levels gender 1 "Men" 2 "Women", name(c1) modify  		
		collect preview, name(c1) 
		collect export "$out/Phil_Brief_Emp_Graphs_${date}", ///
			name(c1) as(xlsx) sheet("contract") cell(A1) modify				

table (gender) , statistic(fvpercent a17) nototal name(c1) replace 
 		collect style header a16, title(hide)  name(c1)
		collect label levels gender 1 "Men" 2 "Women", name(c1) modify  		
		collect preview, name(c1) 
		collect export "$out/Phil_Brief_Emp_Graphs_${date}", ///
			name(c1) as(xlsx) sheet("dur_contr") cell(A1) modify				

table (urban) (gender) , statistic(fvpercent a18) name(c1) replace 

		collect label levels gender 1 "Men" 2 "Women", name(c1) modify  		
		collect preview, name(c1) 
		collect export "$out/Phil_Brief_Emp_Graphs_${date}", ///
			name(c1) as(xlsx) sheet("pension") cell(A1) modify				
					


table (gender) ,  stat(mean choice_1 choice_2 choice_3 choice_4 choice_5 choice_7)  name(c1) replace
 		collect style header gender, title(hide)  name(c1)
		collect label levels gender 1 "Men" 2 "Women", name(c1) modify  		
		collect preview, name(c1) 
		collect export "$out/Phil_Brief_Emp_Graphs_${date}", ///
			name(c1) as(xlsx) sheet("benefits") cell(A1) modify	
	
replace a21_mode1=96 if a21_mode1>5&a21_mode1<77
replace a21_mode1=. if a21_mode1>97


table (urban) (gender),  stat(fvpercent a21_mode1)  name(c1) replace
 		collect style header a21_mode1 gender urban, title(hide)  name(c1)
		collect label levels gender 1 "Men" 2 "Women", name(c1) modify  		
		collect preview, name(c1) 
		collect export "$out/Phil_Brief_Emp_Graphs_${date}", ///
			name(c1) as(xlsx) sheet("mode_transport") cell(A1) modify	
			
			
			
table (macro_region) (gender), nototal stat(fvpercent a21_mode1)  name(c1) replace
 		collect style header a21_mode1 gender urban, title(hide)  name(c1)
		collect label levels gender 1 "Men" 2 "Women", name(c1) modify  		
		collect preview, name(c1) 
		collect export "$out/Phil_Brief_Emp_Graphs_${date}", ///
			name(c1) as(xlsx) sheet("mode_transport_reg") cell(A1) modify	
			
			
			

			
replace a22=. if a22<0
			
table (urban) (gender),  stat(mean a22)  name(c1) replace
 		collect style header a21_mode1 gender urban, title(hide)  name(c1)
		collect label levels gender 1 "Men" 2 "Women", name(c1) modify  		
		collect preview, name(c1) 
		collect export "$out/Phil_Brief_Emp_Graphs_${date}", ///
			name(c1) as(xlsx) sheet("time_arrive") cell(A1) modify	
			
			
table (macro_region) (gender),  stat(mean a22) nototal name(c1) replace
 		collect style header a21_mode1 gender urban, title(hide)  name(c1)
		collect label levels gender 1 "Men" 2 "Women", name(c1) modify  		
		collect preview, name(c1) 
		collect export "$out/Phil_Brief_Emp_Graphs_${date}", ///
			name(c1) as(xlsx) sheet("time_arrive_reg") cell(A1) modify	
*/
			
			
			

 use "$in/l2phl_${date}_M14_view.dta", clear
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
	
collect clear	
  table  locale  [aw= popw], stat(fvpercent v9g )  name (c1) replace 
    table  locale  ( v9g ),  m  name (c1) append 
  collect export "$out/Phil_Brief_Emp_Graphs_${date}", as(xlsx) sheet(worry_lose) modify

  collect clear
  table  locale [aw= popw], stat(fvpercent v9h )  name (c1) replace 
    table  locale  ( v9h ),  m  name (c1) append 
  collect export "$out/Phil_Brief_Emp_Graphs_${date}", as(xlsx) sheet(worry_lose_work) modify  

  collect clear
  table  macro_region [aw= popw], stat(fvpercent v9g ) nototal name (c1) replace 
    table  macro_region  ( v9g ),  m  name (c1) append 
  collect export "$out/Phil_Brief_Emp_Graphs_${date}", as(xlsx) sheet(worry_lose_region) modify

  collect clear
  table  macro_region [aw= popw], stat(fvpercent v9h ) nototal name (c1) replace 
    table  macro_region  ( v9h ),  m  name (c1) append 
  collect export "$out/Phil_Brief_Emp_Graphs_${date}", as(xlsx) sheet(worry_lose_work_reg) modify  

  
  

  