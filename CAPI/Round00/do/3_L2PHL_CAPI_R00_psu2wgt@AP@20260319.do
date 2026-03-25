********************************************************************************
* L2Phl 2025 Baseline Weight Construction
* Author: Avralt-Od Purevjav (apurevjav@worldbank.org)
* Last updated: Mar 19, 2026
*
* Two-stage stratified design:
*   Stage 1 (actual): PSUs selected PPS using population MOS → π^(1)_{sp} = n_s * POP_sp / POP_s
*   Stage 2 (actual): m_sp households selected in PSU p with equal prob → π^(2)_{sph} = m_sp / HH_sp
* Combined (actual):  π_{sph} = (n_s * m_sp * hhsize_sp) / POP_s,  hhsize_sp = POP_sp/HH_sp
*
* Base HH weight: W_design = 1 / π = POP_s / (n_s * m_sp * hhsize_sp)
*
* Exact MOS-mismatch correction to reproduce PPS(HH):
*   W_adj = W_design * (hhsize_sp / hhsize_s), where hhsize_s = POP_s / HH_s
*   ⇒ W_adj = HH_s / (n_s * m_sp), so constant within stratum if m_sp is constant
*
* Post-stratification (HH): align to HH_census_s
* Person weight (default):  popw = hhw * hhsize   [optional calibration to POP_s if needed]
********************************************************************************

{
    clear all
    set more off
    set excelxlsxlargefile on
    set maxvar 10000

    loc  user = "AP" // AP or BB or LD

// 	if ( "`user'"=="AP" )  ///
// 		glo wd "C:\Users\wb463427\OneDrive - WBG\Liliana D. Sousa's files - L2PHL\8 - CAPI"	
    if ( "`user'"=="AP" ) ///
        glo wd "~/Library/CloudStorage/GoogleDrive-avraltod@gmail.com/My Drive/L2Phl/CAPI"
    cd "$wd"

    glo LNG ENG
    glo R 00
    glo pR 00

    glo M 10
    glo D 15
    glo Y 2025

    glo dta_file l2phl

    glo date ${Y}${M}${D}
    glo date_filter "date <= mdy($M, $D, $Y)"

    cap adopath - "$wd\ado\"
    foreach prog in kobo2stata _gwtmean extremes ///
        winsor2 povdeco apoverty ds3 ///
        clonevar confirmdir unique copydesc {
        cap which `prog'
        if _rc ssc install `prog', replace all
    }
    adopath + "$wd\ado\"

    foreach dir in raw fix dta zzz {
        confirmdir "${wd}/`dir'/" 
        if _rc ~= 0 mkdir "${wd}/`dir'"
    }
    foreach dir in raw fix dta zzz {
        confirmdir "${wd}/`dir'/$date"
        if _rc ~= 0 mkdir "${wd}/`dir'/$date"
    }

    glo ado "$wd/ado"
    glo raw "$wd/raw/$date"
    glo xls "$wd/xls"
    glo sav "$wd/sav"
    glo zzz "$wd/zzz/$date"
    glo call "$wd/call/$date"
    glo fix "$wd/fix/$date"
    glo tab "$wd/tab/$date"
    glo dta "$wd/dta/$date"
    glo aud "$wd/aud/$date"
}

********************************************************************************
**# 1. PREPARE SAMPLING FRAME (PSU LEVEL)
********************************************************************************

	use "$ado/Census 2020_PSU_BGY.dta", clear
	
		table (region) , stat(sum population)

	/* NCR sub-region coding (PSGC-level regrouping) */
		replace region = 101 if province=="CITY OF VALENZUELA"
		replace region = 101 if province=="CITY OF CALOOCAN"
		replace region = 101 if province=="CITY OF MALABON"
		replace region = 101 if province=="CITY OF NAVOTAS"

		replace region = 102 if province=="CITY OF MANDALUYONG"
		replace region = 102 if province=="CITY OF MARIKINA"
		replace region = 102 if province=="CITY OF PASIG"
		replace region = 102 if province=="CITY OF SAN JUAN"

		replace region = 103 if province=="CITY OF MANILA"

		replace region = 104 if province=="CITY OF LAS PIÑAS"
		replace region = 104 if province=="CITY OF MUNTINLUPA"
		replace region = 104 if province=="CITY OF PARAÑAQUE"
		replace region = 104 if province=="PASAY CITY"
		replace region = 104 if province=="PATEROS"
		replace region = 104 if province=="CITY OF MAKATI"
		replace region = 104 if province=="CITY OF TAGUIG"

		replace region = 105 if province=="QUEZON CITY"

	/* Drop PSUs with missing POP or missing urban flag */
	g popmiss = 0
	replace popmiss = 1 if population==0
	drop if popmiss==1

	g rurbmiss = 0
	replace rurbmiss = 1 if urban==0 | urban==.
	drop if rurbmiss==1

	/* Stratum totals (frame POP_s used for Stage-1 probability denominator) */
	bys region urban: egen strat_pop = sum(population)

	/* IMPORTANT: Do NOT winsorize the MOS used for Stage-1.
	   Keep a QA copy only (not used in weights). */
	clonevar population_wz = population
	winsor2 population_wz, c(1 99.9) replace

	/* IDs and keep only what we need */
	unique PSGC
	clonevar psgc = PSGC
	g psgc_len = strlen(psgc)
	tab psgc_len
	unique psgc
	ren psgc psgc_str

	/* Stage-1 MOS and stratum total from the frame actually used to draw PSUs */
	ren population pop_psu       // POP_sp (MOS)
	ren strat_pop pop_strat      // POP_s (frame total for pr1)

	keep psgc_str region pop* urban

	/* PSGC fixes */
		replace psgc_str = "0906611001" if psgc_str == "1906611001"
		replace psgc_str = "0906611030" if psgc_str == "1906611030"
		replace psgc_str = "1804502015" if psgc_str == "0604502015"
		replace psgc_str = "1804507017" if psgc_str == "0604507017"
		replace psgc_str = "1804513016" if psgc_str == "0604513016"
		replace psgc_str = "1804515030" if psgc_str == "0604515030"
		replace psgc_str = "1804521018" if psgc_str == "0604521018"
		replace psgc_str = "1804527012" if psgc_str == "0604527012"
		replace psgc_str = "1804604017" if psgc_str == "0704604017"
		replace psgc_str = "1804611002" if psgc_str == "0704611002"
		replace psgc_str = "1381500029" if psgc_str == "1380300003"
		replace psgc_str = "1381500033" if psgc_str == "1380300019"
		replace psgc_str = "1908822002" if psgc_str == "1903817003"
		replace psgc_str = "1908818004" if psgc_str == "1903833004"
		replace psgc_str = "1908705030" if psgc_str == "1903807032"
		replace psgc_str = "1908705031" if psgc_str == "1903807033"
		replace psgc_str = "1908704001" if psgc_str == "1903830001"

	table region , stat(sum pop_psu)	
	table region if region >  100, stat(sum pop_psu)
		/*	
		.         table region , stat(sum pop_psu)        


		Total

		Region                                          
		Ilocos Region                        5,301,139
		Cagayan Valley                       3,685,744
		Central Luzon                       12,422,172
		CALABARZON                          16,195,042
		Bicol Region                         6,076,706
		Western Visayas                      5,331,551
		Central Visayas                      6,545,603
		Eastern Visayas                      4,547,150
		Zamboanga Peninsula                  3,875,576
		Northern Mindanao                    5,022,768
		Davao Region                         5,243,536
		SOCCSKSARGEN                         4,360,974
		Cordillera Administrative Region     1,797,660
		Caraga                               2,804,788
		MIMAROPA Region                      3,228,558
		Negros Island Region                 4,159,557
		BARMM                                4,944,800
		101                                  3,004,627
		102                                  1,811,323
		103                                  1,846,513
		104                                  3,861,951
		105                                  2,960,048
		Total                              109,027,786
		*/

	tempfile frm
	save `frm'

//	
// /* 2020 Census controls by (region,urban): HH_s and POP_s (for anchors/calibration) */
// 	clear
// 		input ///
// 		region urban hh_census_s pop_census_s
// 		/* NCR subregions (urban only) */
// 		101 1 754685   2998412
// 		102 1 465783   1798432
// 		103 1 486293   1837785
// 		104 1 1054167  3818429
// 		105 1 738724   2950493
// 		/* CAR */
// 		14  1 154722   593830
// 		14  2 284444   1197291
// 		/* Region I */
// 		1   1 331189   1345992
// 		1   2 975067   3946305
// 		/* Region II */
// 		2   1 176190   714250
// 		2   2 731282   2965498
// 		/* Region III */
// 		3   1 2013745  8203454
// 		3   2 1026743  4184357
// 		/* Region IV-A */
// 		4   1 2891287  11425282
// 		4   2 1171433  4714488
// 		/* Region IV-B */
// 		17  1 283135   1128362
// 		17  2 509740   2083925
// 		/* Region V */
// 		5   1 316038   1439079
// 		5   2 1049006  4628211
// 		/* Region VI */
// 		6   1 251455   1059103
// 		6   2 907631   3660141
// 		/* Region VII */
// 		7   1 909111   3642608
// 		7   2 683711   2872115
// 		/* Region VIII */
// 		8   1 153067   657671
// 		8   2 929039   3866372
// 		/* NIR */
// 		19  1 678452   2805179
// 		19  2 476217   1942670
// 		/* Region IX */
// 		9   1 395654   1831338
// 		9   2 666385   3029925
// 		/* Region X */
// 		10  1 612397   2516622
// 		10  2 585339   2491176
// 		/* Region XI */
// 		11  1 895190   3486252
// 		11  2 442591   1737550
// 		/* Region XII */
// 		12  1 591573   2410541
// 		12  2 473880   1941232
// 		/* CARAGA */
// 		16  1 245919   1021678
// 		16  2 415854   1773662
// 		/* BARMM */
// 		18  1 179533   1007651
// 		18  2 487235   2932213
// 		end
//		
// 		table region , stat(sum pop_census_s)
// 		table region if region > 100, stat(sum pop_census_s)
//
// 		/*
// 		region	             
// 			1	5,292,297
// 			2	3,679,748
// 			3	12,387,811
// 			4	16,139,770
// 			5	6,067,290
// 			6	4,719,244
// 			7	6,514,723
// 			8	4,524,043
// 			9	4,861,263
// 			10	5,007,798
// 			11	5,223,802
// 			12	4,351,773
// 			14	1,791,121
// 			16	2,795,340
// 			17	3,212,287
// 			18	3,939,864
// 			19	4,747,849
// 			101	2,998,412
// 			102	1,798,432
// 			103	1,837,785
// 			104	3,818,429
// 			105	2,950,493
// 			Total	108,659,574
//			
// 			region	            
// 				101	2,998,412
// 				102	1,798,432
// 				103	1,837,785
// 				104	3,818,429
// 				105	2,950,493
// 				Total	13,403,551
//	
//
//	
// 		*/
//
//
//		
// 	tempfile ctrls
// 	save `ctrls', replace
	


/* stratum-level population counts */
	import excel using "$ado/cph2020_f2_summary@AP@v3.xlsx", ///
		sheet("pop") first clear case(lower) allstring
		
		destring _all, replace 
			drop reg 
		ren a region 
				drop if region  == 13
		g urban = . 
		replace urban = 1 if urb == "Urban"
		replace urban = 2 if urb == "Rural"
		
		table region urban, stat(sum pop) 
		
		collapse (sum) pop , by(region urban)
		
		table region urban, stat(sum pop) 
		
		rename pop pop_census_s
		
		tempfile popcen
		save `popcen' , replace 

	
/* stratum-level n of households */
	import excel using "$ado/cph2020_f2_summary@AP@v3.xlsx", ///
		sheet("hh_count") first clear case(lower) allstring
		
		destring _all, replace 
			drop region 
		ren a region 
				drop if region  == 13
		g urban = . 
		replace urban = 1 if urb == "Urban"
		replace urban = 2 if urb == "Rural"
		
		table region urban, stat(sum hh) 
		
		collapse (sum) hh , by(region urban)
		
		table region urban, stat(sum hh) 
		
		rename hh hh_census_s
		
		tempfile nhhcen
		save `nhhcen' , replace 
		
		
/* stratum-level n of households and population counts */

		use `popcen', clear 
			merge 1:1 region urban using `nhhcen' , assert(3) nogen keep(3)
			
		tempfile ctrls 
		save `ctrls', replace 

		
/* PSU-level HH and household population from Excel (exact HH_sp; POP_sp QA) */
	import excel using "$ado/Updated PSGC Codes & HH Population.xlsx", ///
		sheet("PSGC Codes") first clear case(lower) allstring

	keep psgcupdated householdpopulation numberofhousehold
		ren psgcupdated psgc
		ren householdpopulation pop
		ren numberofhousehold nhh
		destring psgc pop nhh, replace
		drop if pop==. & nhh==.

		tostring psgc, format(%010.0f) g(psgc_str)
		unique psgc_str
		g psgc_len = strlen(psgc_str)
		tab psgc_len

	/* PSGC reverse-fixes (Excel-to-frame alignment) */
		replace psgc_str = "1908704001" if psgc_str == "1903627028"
		replace psgc_str = "1608501027" if psgc_str == "1608502004"
		replace psgc_str = "1001305007" if psgc_str == "1003511013"
		replace psgc_str = "0702221006" if psgc_str == "0701230029"
		replace psgc_str = "1380610014" if psgc_str == "1380614033"
		replace psgc_str = "0702239012" if psgc_str == "0702245008"


	tempfile pop
	save `pop', replace

********************************************************************************
**# 2. MERGE SURVEY HOUSEHOLDS WITH FRAME
********************************************************************************

/* Build household size from roster (count of members per hhid) */
	use "$dta/${dta_file}_${date}_M01_roster.dta", clear
		unique hhid fmid
		egen tag_hh = tag(hhid)
		ren hhsize hhsize_old
		bys hhid (fmid): g hhsize = _N
		assert hhsize == hhsize_old if tag_hh
		drop hhsize_old
		keep if tag_hh
		keep hhid hhsize
	tempfile hhsize
	save `hhsize', replace

/* Passport + attach hhsize + frame + PSU-level (POP, HH) + census stratum controls */
	use "$dta/${dta_file}_${date}_M00_passport.dta", clear
	keep hhid psgc_str
	merge 1:1 hhid using `hhsize', assert(3) nogen

	/* PSGC fixes again on survey side */
		replace psgc_str = "0906611001" if psgc_str == "1906611001"
		replace psgc_str = "0906611030" if psgc_str == "1906611030"
		replace psgc_str = "1804502015" if psgc_str == "0604502015"
		replace psgc_str = "1804507017" if psgc_str == "0604507017"
		replace psgc_str = "1804513016" if psgc_str == "0604513016"
		replace psgc_str = "1804515030" if psgc_str == "0604515030"
		replace psgc_str = "1804521018" if psgc_str == "0604521018"
		replace psgc_str = "1804527012" if psgc_str == "0604527012"
		replace psgc_str = "1804604017" if psgc_str == "0704604017"
		replace psgc_str = "1804611002" if psgc_str == "0704611002"
		replace psgc_str = "1381500029" if psgc_str == "1380300003"
		replace psgc_str = "1381500033" if psgc_str == "1380300019"
		replace psgc_str = "1908822002" if psgc_str == "1903817003"
		replace psgc_str = "1908818004" if psgc_str == "1903833004"
		replace psgc_str = "1908705030" if psgc_str == "1903807032"
		replace psgc_str = "1908705031" if psgc_str == "1903807033"
		replace psgc_str = "1908704001" if psgc_str == "1903830001"
		replace psgc_str = "0307707015" if psgc_str == "307707015"

	/* Merge frame (Stage-1 MOS) */
	merge m:1 psgc_str using `frm' ///
		, keepusing(region urban pop* ) update
	unique psgc_str if _m==1
	egen tag_m = tag(hhid)
	list psgc_str if _m==1 & tag_m
	keep if _m==3
	drop _m

	/* Merge PSU exact HH and (Excel) POP for QA; keep pop_psu from frame for pr1 */
	merge m:1 psgc_str using `pop' ///
		, keepusing(pop nhh) update assert(3) nogen
	ren nhh hh_psu                    // HH_sp (exact from Excel)
	* 'pop' from Excel is household population; we keep it only for QA. Stage-1 uses 'pop_psu'.

	/* Merge stratum-level census controls */
	merge m:1 region urban using `ctrls' ///
		, keepusing(*census*) update assert(3) nogen

	/* Build stratum and psu ids */
	cap drop stratum
	egen stratum = group(region urban)
	cap drop psu
	clonevar psu = psgc_str
	
********************************************************************************
**# 3. PSU & STRATUM HH SIZE (ratio-of-totals) + sampled HHs per PSU
********************************************************************************
/* Exact from controls (frame/Excel): */
	cap drop hhsize_sp hhsize_s
	g hhsize_sp = pop_psu      / hh_psu      // POP_sp / HH_sp  (PSU)
	g hhsize_s  = pop_census_s / hh_census_s // POP_s  / HH_s   (stratum)

/* For continuity with existing plots (not used in weights): */
	cap drop ave_hhsize_psu ave_hhsize_strat ave_hhsize_smooth
	g ave_hhsize_psu   = hhsize_sp
	g ave_hhsize_strat = hhsize_s
	g ave_hhsize_smooth = hhsize_sp

/* Realized m_sp: number of sampled HHs per PSU in the data */
	bys stratum psu: g nhh_psu_sel = _N

********************************************************************************
**# 4. STAGE-1 AND STAGE-2 INCLUSION PROBABILITIES (exact)
********************************************************************************
/* Distinct PSUs per stratum (n_s) */
	egen tag_psu = tag(stratum psu)
	bys stratum: egen npsu_strat = total(tag_psu)

/* Stage 1 (actual PPS by population MOS) */
	g pr1 = (npsu_strat * pop_psu) / pop_strat
	replace pr1 = 1 if pr1>1     // certainty PSU guard

/* Stage 2 (equal-prob HH within PSU; exact) */
	g pr2 = nhh_psu_sel / hh_psu
	replace pr2 = 1 if pr2>1     // guard (should not happen)

/* Combined inclusion prob and base household weight */
	g pr_tot  = pr1 * pr2
	g hhw_design = 1 / pr_tot
	bys psu: replace hhw_design = hhw_design[1]   // constant within PSU

********************************************************************************
**# 5. EXACT PPS(pop) => PPS(HH) CORRECTION IN WEIGHT SPACE
********************************************************************************
/* adj_mos = hhsize_sp / hhsize_s  (PSU / stratum) */
	g adj_mos = hhsize_sp / hhsize_s
	g hhw_adj = hhw_design * adj_mos
	bys psu: replace hhw_adj = hhw_adj[1]

/* QA: if m_sp is constant, hhw_adj should be constant within stratum */
	bys stratum: egen sd_hhw_adj = sd(hhw_adj)
	su sd_hhw_adj

********************************************************************************
**# 6. POST-STRATIFICATION TO CENSUS HH TOTALS
********************************************************************************
	bys stratum: egen sum_hhw_adj = total(hhw_adj)
	g g_post = hh_census_s / sum_hhw_adj
	bys stratum: replace g_post = g_post[1]
	g hhw_post = hhw_adj * g_post

********************************************************************************
**# 7. PERSON WEIGHT (default identity; optional calibration if needed)
********************************************************************************
/* Default identity: popw = hhw_post * hhsize (roster size) */
	g popw = hhw_post * hhsize

/* OPTIONAL (commented): calibrate person weights to POP_s if any stratum gap > 3%
	bys stratum: egen sum_popw = total(popw)
	g pct_gap = 100*(sum_popw - pop_census_s)/pop_census_s
	egen max_abs_gap = max(abs(pct_gap))
	su max_abs_gap
	local need_cal = (r(max) > 3)
	if `need_cal' {
		bys stratum: egen sum_popw2 = total(popw)
		g k_pop = pop_census_s / sum_popw2
		bys stratum: replace k_pop = k_pop[1]
		g popw_cal = popw * k_pop
		label var popw_cal "person weight calibrated to census pop totals (stratum)"
	}
	else {
		g popw_cal = popw
		label var popw_cal "person weight (identity = hhw × hhsize)"
	}
*/

********************************************************************************
**# 8. VALIDATION (BY STRATUM)
********************************************************************************
	egen tag_strat = tag(stratum)

/* HH totals should match census */
	bys stratum: egen sum_hhw_post = total(hhw_post)
	list stratum hh_census_s sum_hhw_post if tag_strat, noobs sepby(stratum)
	
/* Person totals (identity) vs census POP_s (for information) */
	bys stratum: egen sum_popw = total(popw)
	list stratum pop_census_s sum_popw if tag_strat, noobs sepby(stratum)


********************************************************************************
**# 9. QUICK DIAGNOSTICS (OPTIONAL)
********************************************************************************
preserve
    collapse (mean) ave_hhsize_psu (mean) ave_hhsize_smooth (mean) ave_hhsize_strat ///
             (mean) adj_mos (mean) hhw_adj, by(stratum psu)

    /* Plot idea: remove destring psu to avoid errors if psu is string.
       Users can encode psu if they want numeric axes. */
    * encode psu, gen(psu_id)
    * twoway (scatter ave_hhsize_psu psu_id, mcolor(gs8) msize(small) ///
    *         ytitle("Household size") xtitle("PSU") ///
    *         title("PSU HH size: PSU (gray) & stratum mean (red)") legend(off)) ///
    *        (function y = ave_hhsize_strat[1], range(psu_id) lcolor(red) lpattern(dash))

//     hist adj_mos, bin(20) percent ///
//         title("Adjustment factor: hhsize_sp / hhsize_s") ///
//         xtitle("adj_mos")
restore

********************************************************************************
**# 10. SAVE FINAL WEIGHTS
********************************************************************************
	ren hhw_post hhw
/* Keep identity person weight; if you used calibration above, also keep popw_cal */
	keep hhid hhw popw region urban stratum psu psgc_str ///
		pop_psu pop_strat npsu_strat hh_psu nhh_psu_sel pr1 pr2 hhw_design hhw_adj  ///
		hhsize* adj_mos 

/* Do NOT rescale/round the analytic weights; use formats only */
	format hhw popw %12.0fc

	tab region [iw=hhw]
	tab region [iw=popw]
	
	sort stratum psu hhid 
		
	foreach v of varlist popw hhw {
		cap drop sd_w 
		bys stratum: egen sd_w = sd(`v')
		replace sd_w = round(sd_w)
		di in red "						`v' by stratum"		
		summ sd_w	
		
		cap drop sd_w 
		bys psu: egen sd_w = sd(`v')
		replace sd_w = round(sd_w)
		di in red "						`v' by psu"		
		summ sd_w	
	}	
	
save "$ado/design_weights.dta", replace

********************************************************************************
**# 11. POPULATION BY STRATUM, GENDER, and AGE 
********************************************************************************
/* stratum-level population by gender-age group */
	import excel using "$ado/cph2020_f2_summary@AP@v3.xlsx", ///
		sheet("pop") first clear case(lower) allstring
		
		destring _all, replace 
		
		
		ren a region 
				drop if region  == 13

		collapse (sum) pop , by(region reg urb sex agegrp)
		
		table region , stat(sum pop) 
		/*		
.          table region , stat(sum pop) 

				----------------------
						|        Total
				--------+-------------
				region  |             
				  1     |    5,292,297
				  2     |    3,679,748
				  3     |   12,387,811
				  4     |   16,139,770
				  5     |    6,067,290
				  6     |    4,719,244
									  7     |    6,617,737
									  8     |    4,531,512
									  9     |    3,862,588
				  10    |    5,007,798
				  11    |    5,223,802
				  12    |    4,351,773
				  14    |    1,791,121
				  16    |    2,795,340
				  17    |    3,212,287
				  18    |    4,644,835
				  19    |    4,938,539
				  101   |    2,998,412
				  102   |    1,798,432
				  103   |    1,837,785
				  104   |    3,818,429
				  105   |    2,950,493
				  Total |  108,667,043
				  
		region	             
			1	5,292,297
			2	3,679,748
			3	12,387,811
			4	16,139,770
			5	6,067,290
			6	4,719,244
									7	6,514,723
									8	4,524,043
									9	4,861,263
			10	5,007,798
			11	5,223,802
			12	4,351,773
			14	1,791,121
			16	2,795,340
			17	3,212,287
			18	3,939,864
			19	4,747,849
			101	2,998,412
			102	1,798,432
			103	1,837,785
			104	3,818,429
			105	2,950,493
			Total	108,659,574
			
				  
		*/
	
	unique region reg urb sex agegrp 
		as `r(N)' == `r(unique)'
	
	
			
		g urban = . 
		replace urban = 1 if urb == "Urban"
		replace urban = 2 if urb == "Rural"
		
		g gender = . 
		replace gender = 1 if sex == "Male"
		replace gender = 2 if sex == "Female"
		
		g age_grp = . 
		replace age_grp = 1 if agegrp == "0 - 17"
		replace age_grp = 2 if agegrp == "18 - 45"
		replace age_grp = 3 if agegrp == "46 - 59"
		replace age_grp = 3 if agegrp == "60 up"
		
		la def AGEGRP 1 "0-17" 2 "18-45" 3 "46+" , replace 
		la val age_grp AGEGRP
		
		collapse (sum) pop , by(region urban gender age_grp)

		merge m:1 region urban using `ctrls' , assert(3) update nogen 
		
		table (region) (urban), stat(sum pop)
		egen tag = tag(region urban)
		table (region) (urban) if tag, stat(sum pop_census_s)
		
		* rescale 
		bys region urban: egen pop_strat = sum(pop)
		g pop_cell = pop* (pop_census_s/pop_strat)
		
		table (region) (urban), stat(sum pop_cell)
		
	keep region urban gender age_grp hh_census_s pop_census_s pop_cell 
	
	tempfile pop_cell 
	save `pop_cell', replace 
	

********************************************************************************
**# 11. ROSTER - 
********************************************************************************

	use "$dta/${dta_file}_${date}_M01_roster.dta", clear
		unique hhid fmid
		egen tag_hh = tag(hhid)
		ren hhsize hhsize_old
		bys hhid (fmid): g hhsize = _N
		assert hhsize == hhsize_old if tag_hh
		drop hhsize_old
		keep hhid fmid hhsize age gender 
		
		
	merge m:1 hhid using "$ado/design_weights.dta" ///
		, assert(3) nogen update ///
			keepusing(region urban stratum popw hhw hhsize *pop* *psu* ) 
		
		
		table (region) (urban), stat(sum hhw )

		g indw = popw / hhsize 	
			as round(indw, 4) == round(hhw, 4) 
				
		ren popw popw_design 
		ren hhw hhw_design 
		ren indw indw_design 

		* gender 
		tab gender 
		as gender ~= . 
		
		* age group 
		su age 
		as age ~= . 
		as age >= 0 
		
		g age_grp = . 
		replace age_grp = 1 if age >=0 & age <= 17
		replace age_grp = 2 if age >= 18 & age <= 45
		replace age_grp = 3 if age >= 46 & age < .
// 		replace age_grp = 4 if age >= 66 & age < .
		la def AGEGRP 1 "0-17" 2 "18-45" 3 "46+" , replace 
		la val age_grp AGEGRP
		
		table (stratum) (age_grp gender)
		
		foreach v of varlist indw_design {
			cap drop sd_w 
			bys stratum age_grp gender: egen sd_w = sd(`v')
			replace sd_w = round(sd_w)
			di in red "				`v' by stratum and age group and gender"
			summ sd_w	
				assert sd_w == 0 
				
			cap drop sd_w 
			bys stratum: egen sd_w = sd(`v')
			replace sd_w = round(sd_w)
			di in red "				`v' by stratum"
			summ sd_w	
				assert sd_w == 0 

			cap drop sd_w 
			bys psu: egen sd_w = sd(`v')
			replace sd_w = round(sd_w)
			di in red "				`v' by psu"
			summ sd_w	
				assert sd_w == 0 
				
			drop sd_w 
		}	

	
	merge m:1 region urban gender age_grp using `pop_cell' 	///
		, assert(3) nogen update ///
			keepusing(*census* pop_cell) 
			
		table (stratum) (age_grp gender), stat(sum indw_design)

		egen tag_cell = tag(region urban gender age_grp)
		
		table (stratum) (age_grp gender) if tag_cell , stat(sum pop_cell)

		bys urban region gender age_grp : egen tot_indw = sum(indw_design)
		
		g indw = indw_design * (pop_cell/tot_indw)
		la var indw "Individual weight (Individual-level data)"
		
		table (stratum) (age_grp gender), stat(sum indw)
		
		bys hhid (fmid): egen popw = sum(indw) 
		la var popw "Population weight (Household-level data)"

		bys hhid (fmid): egen hhw = mean(indw) 
		bys psu (hhid fmid): egen ave_hhw = mean(hhw)

		
		foreach v of varlist indw popw hhw ave_hhw {
			cap drop sd_w 
			bys stratum age_grp gender: egen sd_w = sd(`v')
			replace sd_w = round(sd_w)
			di in red "				`v' by stratum and age group and gender"
			summ sd_w	
				
			cap drop sd_w 
			bys stratum: egen sd_w = sd(`v')
			replace sd_w = round(sd_w)
			di in red "				`v' by stratum"
			summ sd_w	

			cap drop sd_w 
			bys psu: egen sd_w = sd(`v')
			replace sd_w = round(sd_w)
			di in red "				`v' by psu"
			summ sd_w	
				
			drop sd_w 
		}	
		
			kdensity hhw  ///
			, normal lc(blue%50) lw(*1.5) normopts(lp(dash) lw(*.5) lc(blue%50)) ///
				legend( order(1 "HHW" 2 "Normal distribution") ///
				ring(0) pos(11)) title("") ///
				xla(, nogrid) yla(, nogrid) note("") xsize(7)
				
			kdensity ave_hhw  ///
			, normal lc(blue%50) lw(*1.5) normopts(lp(dash) lw(*.5) lc(blue%50)) ///
				legend( order(1 "HHW" 2 "Normal distribution") ///
				ring(0) pos(11)) title("") ///
				xla(, nogrid) yla(, nogrid) note("") xsize(7)
		
		replace hhw = ave_hhw 				
		la var hhw "Household weight (Household-level data)"
			drop ave_hhw 
		
		egen tag_hh = tag(hhid)
		table (region) (urban) if tag_hh, stat(sum popw)
		table (region) (urban) if tag_hh, stat(sum hhw)
		
		egen tag_strat = tag(urban region)
		table (region) (urban) if tag_strat, stat(sum hh_census_s)
		
		
		bys region urban : egen tot_hhw = sum(hhw*(tag_hh == 1))
		replace hhw = hhw * (hh_census_s/tot_hhw)
		table (region) (urban) if tag_hh, stat(sum hhw)
		
		outdetect popw 
			drop _out 
		outdetect indw 
			drop _out 
		outdetect hhw 
			drop _out 			
	
	save "$dta/final_weights.dta", replace
