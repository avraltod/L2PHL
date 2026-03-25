
	{
	clear all 
	set more off
	set excelxlsxlargefile on
//     set processors 6 //8
	set maxvar 10000
	
	loc  user = "AP" //AP or BB or LD 
	

	if ( "`user'"=="AP" )  ///
		glo wd "~/Library/CloudStorage/GoogleDrive-avraltod@gmail.com/My Drive/L2Phl/CAPI"
	if ( "`user'"=="BB" )  ///
		glo wd "/Users/batmandakh/Library/CloudStorage/GoogleDrive-bt.mandah@gmail.com/My Drive/L2Phl/CAPI"		
	if ( "`user'"=="LD" )  ///
		glo wd "C:\Users\Liz Danganan\OneDrive - PSRC\3 MACROS & TEMPLATES\TIPON\TIPON\data"	
		
	cd "$wd" //changing directory 

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
	// making sure are there defined commands
	foreach prog in kobo2stata _gwtmean extremes ///
		winsor2 povdeco apoverty ds3 ///
			clonevar confirmdir unique copydesc {
				cap which `prog'
					if _rc ssc install `prog' , replace all
	}
	adopath + "$wd\ado\"
	
		foreach dir in raw fix dta zzz {
			confirmdir "${wd}/`dir'/"
			if _rc ~= 0 {
				mkdir "${wd}/`dir'"
			}	
		}
		
		foreach dir in raw fix dta zzz {
			confirmdir "${wd}/`dir'/$date"
			if _rc ~= 0 {
				mkdir "${wd}/`dir'/$date"
			}			
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

	

	
    use "$dta/${dta_file}_${date}_M00_passport.dta" , clear 
	
		keep hhid psgc_str locale region province city barangay 
		
		clonevar psu = psgc_str 
		clonevar urban = locale 
		
		format hhid %016.0f 
		
		g hhid_str = "" 
		replace hhid_str = strofreal(hhid, "%016.0f")
		
		unique hhid 
		unique psu 
		unique psu urban 
		
		set seed 20251027 
		
		g rnd = uniform() 
		
		bys psu (rnd): g order = _n 
		
		g sample = ""
		replace sample = "main" if order < 7 & urban == 1 
		replace sample = "main" if order < 8 & urban == 2 
		replace sample = "replacement" + " " + string(order) if sample == ""
		
		g selected = (sample == "main")
		g replacement = (sample ~= "main") 
		
		
	export excel using "$xls/l2phl_cati_sample.xlsx", first(var) nol replace 
	save "$dta/l2phl_cati_sample.dta", replace 
		
		

		
		
	

	
		
