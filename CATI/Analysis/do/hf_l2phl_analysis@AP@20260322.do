//Analyze HF data of L2PHL
//created by Avralt-Od Purevjav
//modified on Mar 22, 2026
// Changes vs @20260320: added Section 4 – module cleanup & reorder.
//   Each pooled M00–M09 file is stripped of admin/processing variables
//   and its columns are put in questionnaire order so the panel structure
//   is consistent across modules and rounds.

	//Preamble
		clear all
		set more off
		set excelxlsxlargefile on
// 		set processors 4 //8

	//Set file location
		*loc ws "Work" //Home //Server

		loc ow = c(os)
		di "`ow'"
		if ( "`ow'"=="Windows" )  ///
			glo root "C:\Users\wb463427\OneDrive - WBG\ECAPOV\L2Ss\L2Ukr\CATI"
		if ( "`ow'"=="MacOSX" )  ///
			glo root "~/iDrive/GitHub/PHL/L2PHL"   // updated: moved from Google Drive to GitHub folder

// 		-- Previous root paths (kept for reference) --
// 		if ( "`ow'"=="MacOSX" )  ///
// 			glo root "~/Library/CloudStorage/GoogleDrive-avraltod@gmail.com/My Drive/L2PHL"  // old: Google Drive
// 		if ( "`ow'"=="MacOSX" )  ///
// 			glo root "~/iDrive/Dropbox/WB/L2Ukr/CATI"  // old: Dropbox

		glo hf "$root/CATI/Analysis/HF"
// 		glo baseline "$root/Analysis/Baseline"
// 		glo weight "$root/Analysis/Weights"
// 		glo out "$root/Analysis/Reporting"
// 		glo pool "$root/Pool"


// 		cd "$out"

		glo date 20260319	// change date each time you run the code
		glo LNG ENG  //change language of the data set: ENG RUS UKR
		glo RDATES "20251125 20251228 20260128 20260228 $date "

	//Locals

		glo R=5  // change it in each round
		loc file l2phl_hf_result_${date}



	// =========================================================================
	// SECTION 1: Move round files into HF/R*/
	// =========================================================================

	//moving the files into input folder
		foreach r of numlist 1/$R {
			loc r : di %02.0f `r'
			di "`r'"
			loc d: word `r' of $RDATES

			//deleting files in the folder
			local dtafiles : dir "${hf}/R`r'" files "*.dta"
			foreach file in `dtafiles' {
				di 	"`file'"
					cap erase "${hf}/R`r'/`file'"
			}

			//moving the files into input folder
			local dtafiles : dir "$root/CATI/Round`r'/dta/`d'" files "*.dta"
			foreach file in `dtafiles' {
				di 	"`file'"
				cap erase "${hf}/R`r'/`file'"
					copy  "$root/CATI/Round`r'/dta/`d'/`file'" ///
						"${hf}/R`r'/`file'", replace
			}

		}

	// =========================================================================
	// SECTION 2: Build panel weights
	// =========================================================================

	//Open baseline weight file
		use "$hf/R00/final_weights.dta", clear
			merge m:1 hhid using "$hf/R00/l2phl_20251015_M00_passport.dta", ///
				assert(3) nogen keepusing(stg_id)

			tab region [iw = popw] if tag_hh
			tab region [iw = hhw] if tag_hh
			tab region [iw = indw]
// 			keep hhid hhw popw

		clonevar stratum_pop = pop_census_s
		clonevar stratum_nhh = hh_census_s

		foreach v of varlist indw popw hhw indw_design popw_design hhw_design {
			cap drop sd_w
			bys stratum age_grp gender: egen sd_w = sd(`v')
			replace sd_w = round(sd_w)
			di in red "					`v' by stratum age_grp gender"
			summ sd_w

			cap drop sd_w
			bys stratum: egen sd_w = sd(`v')
			replace sd_w = round(sd_w)
			di in red "					`v' by stratum "
			summ sd_w

			cap drop sd_w
			bys psu : egen sd_w = sd(`v')
			replace sd_w = round(sd_w)
			di in red "					`v' by psu "
			summ sd_w

			drop sd_w

		}

// 		bys stratum (psu hhid): egen stratum_pop = total(popw)
// 		bys stratum (psu hhid): egen stratum_nhh = total(hhw)

		isid hhid fmid
		isid stg_id fmid
			drop hhid
				ren stg_id hhid

		tempfile indw
		save `indw' , replace

			keep if tag_hh

		tempfile hhw
		save `hhw' , replace

		use `indw', clear

			cap drop sd_w
			bys stratum age_grp gender: egen sd_w = sd(indw)
			replace sd_w = round(sd_w)
			di in red "					`v' by stratum age_grp gender"
			summ sd_w

			bys stratum age_grp gender (hhid fmid): keep if _n == _N

			isid stratum age_grp gender

		tempfile cell
		save `cell', replace

	//Merge with baseline
		//refusal/unable to participate in round 1
		clear
			g round = .
		//appending all rounds
		foreach r of numlist 1/$R {
			loc R : di %02.0f `r'
				di "`r' and `R'"
					loc d: word `r' of $RDATES
						di "`d'"

			append using "$hf/R`R'/l2phl_`d'_M01_roster.dta", force
				replace round = `r' if round == .
		}

		keep round hhid fmid hhsize age gender isfmid

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


			merge m:1 hhid using `hhw', ///
				assert(2 3) keep(3) nogen keepusing(stratum psu region urban) update

					table (stratum) (age_grp gender) (round)

			merge m:1 stratum age_grp gender using `cell' ///
				, assert(3) nogen keepusing(indw *census* pop_cell ) update

				ren indw indw_base

				table (stratum) (age_grp gender) (round), stat(sum indw_base) nototals

			egen tag_cell = tag(round stratum gender age_grp)

			table (stratum) (age_grp gender) (round) if tag_cell , stat(sum pop_cell) nototals

			bys round stratum gender age_grp : egen tot_indw = sum(indw_base)

			g indw = indw_base * (pop_cell/tot_indw)
			la var indw "Individual weight (Individual-level data)"

			table (stratum) (age_grp gender) (round), stat(sum indw)

			table (stratum) (round), stat(sum indw)

			bys round hhid (fmid): egen popw = sum(indw)
			la var popw "Population weight (Household-level data)"

			bys round hhid (fmid): egen hhw = mean(indw)
			la var hhw "Household weight (Household-level data)"

			bys round psu (hhid fmid): egen ave_hhw = mean(hhw)
			la var ave_hhw "Smoothed Household weight (Household-level data)"

			replace hhw = ave_hhw
				drop ave_hhw

			cap drop tag_hh
			egen tag_hh = tag(hhid round)

			table (stratum) (round) if tag_hh, stat(sum hhw)

			bys round stratum (psu hhid fmid)  : egen tot_hhw_s = sum( hhw*tag_hh )
			replace hhw = hhw * (hh_census_s/tot_hhw_s)

			table (stratum) (round) if tag_hh , stat(sum hhw)

		preserve
			keep round hhid fmid age age_grp gender region urban stratum psu indw

			save "$hf/l2phl_cati_indw.dta", replace
		restore

			isid round hhid fmid
			bys round hhid (fmid): keep if _n == _N
			isid round hhid fmid

			keep round hhid fmid age age_grp gender region urban stratum psu popw hhw
			save "$hf/l2phl_cati_hhw.dta", replace


	// =========================================================================
	// SECTION 3: Pool rounds for each module
	// =========================================================================

	//Merging rounds — HH-level modules
	foreach ss in 	M00_passport ///
					M03_shock ///
					M06_finance ///
					M08_food_nonfood ///
					M09_views ///
					HH_Level_Data ///
					{
		clear all
		cap drop round
		g round = .

		foreach r of numlist 1/$R {
			loc r : di %02.0f `r'

			di "`ss'-`r'"

			local dt: word `r' of $RDATES
			cap append using  "${hf}/R`r'/l2phl_`dt'_`ss'.dta" , force

			replace round = `r' if round == .
				tab round
		}

		merge 1:1 round hhid using "$hf/l2phl_cati_hhw.dta" ///
			, assert(1 3) keep(3) nogen

	save "${hf}/l2phl_`ss'.dta", replace

	}

	//Merging rounds — Individual-level modules
	foreach ss in 	M01_roster ///
					M02_education ///
					M04_employment ///
					M05_income ///
					M07_health ///
					Roster_Level_Data ///
					{
		clear all
		cap drop round
		g round = .

		foreach r of numlist 1/$R {
			loc r : di %02.0f `r'

			di "`ss'-`r'"

			local dt: word `r' of $RDATES
			cap append using  "${hf}/R`r'/l2phl_`dt'_`ss'.dta" , force

			replace round = `r' if round == .
				tab round
		}

		merge 1:1 round hhid fmid using "$hf/l2phl_cati_indw.dta" ///
			, assert(1 2 3) keep(3) nogen

	save "${hf}/l2phl_`ss'.dta", replace

	}


	// =========================================================================
	// =========================================================================
	// SECTION 4: Clean, label, and reorder pooled module files
	// -------------------------------------------------------------------------
	// For each module:
	//   • drop admin/processing vars (excess_int dropped EXCEPT in M00)
	//   • drop duplicate geo/demographic vars redundant in HH-level modules
	//   • apply value labels inline (la var → la def → la val → note per variable)
	//   • add notes for round-specific / provenance variables
	//   • enforce a consistent column order:
	//       HH-level  : hhid round | stratum psu region urban popw hhw | [Q vars]
	//       Ind-level : hhid round fmid | stratum psu region urban
	//                   age age_grp gender indw | [Q vars]
	//
	// Duration variables (dur_*): kept in M00 passport only for QC purposes.
	// excess_int: kept in M00 (R4-only QC flag, n=6 NCR over-quota HHs).
	// trailer_tag: kept in M01 (R1-only data provenance flag, n≈220 HHs).
	//
	// Labeling convention: la var → la def (indented, first use of each label
	// name, with ", replace") → la val (indented) → note (indented, where
	// applicable). Subsequent modules reuse la val only — no repeat la def.
	//
	// NOTE: hhw/indw files are still live here; erased in Section 5.
	// =========================================================================


	// ── M00 Passport ──────────────────────────────────────────────────────────
	// HH-level. fmid kept (= respondent ID).
	// Duration vars (dur_*) KEPT for QC purposes; excess_int KEPT as QC flag.
	// Province/city/barangay/locale kept as questionnaire geographic descriptors.

	use "${hf}/l2phl_M00_passport.dta", clear

		cap drop x15 subm_date date_str subm_time time_str int_id round_lastint
		// drop person-level vars added by hhw merge (these belong in M01)
		cap drop age gender age_grp

		order hhid round stratum psu region urban popw hhw ///
		      call_attemp call_status1 correct_resp agreement ///
		      refusal_reason refusal_reason_oth interview_record ///
		      address_unchanged new_address_str province city barangay locale hhsize ///
		      survey_lang date_of_interview time_of_interview ///
		      start_date end_date start_time end_time call_result fmid sample ///
		      dur_pp dur_rr dur_educ dur_sh dur_emp dur_inc dur_fin ///
		      dur_hlt dur_f_nf dur_vw dur_tot ///
		      excess_int

		la var hhid              "L2PHL Household ID"
		la var round             "L2PHL CATI Round"
		la var stratum           "Sampling stratum"
		la var psu               "Primary sampling unit (PSU)"
		la var region            "Region"
			la def REGION ///
				13 "NCR"  14 "CAR" ///
				1  "I Ilocos"              2  "II Cagayan Valley" ///
				3  "III Central Luzon"     4  "IV-A Calabarzon" ///
				17 "IV-B MIMAROPA"         5  "V Bicol" ///
				6  "VI Western Visayas"    18 "NIR Negros Island Region" ///
				7  "VII Central Visayas"   8  "VIII Eastern Visayas" ///
				9  "IX Zamboanga Peninsula" ///
				10 "X Northern Mindanao"   11 "XI Davao Region" ///
				12 "XII SOCCSKSARGEN"      16 "XIII Caraga" ///
				19 "BARMM", replace
			la val region REGION
			note region :
		la var urban             "Urban/rural classification"
			la def LOCALE ///
				1 "Urban" ///
				2 "Rural", replace
			la val urban LOCALE
			note urban :
		la var popw              "Population weight (household-level data)"
		la var hhw               "Household weight (household-level data)"
		la var call_attemp       "Call attempt number"
			la def ATTEMPT ///
				1 "1st attempt" ///
				2 "2nd attempt" ///
				3 "3rd attempt", replace
			la val call_attemp ATTEMPT
		la var call_status1      "Did you speak with someone?"
			la def CALL_STATUS1 ///
				1 "Yes" ///
				2 "No", replace
			la val call_status1 CALL_STATUS1
		la var correct_resp      "Were you able to speak with the correct respondent?"
			la def YES_NO_ENG ///
				1 "Yes" ///
				2 "No", replace
			la val correct_resp YES_NO_ENG
		la var agreement         "Agreement to participate (Listening to the Philippines)"
			la def AGREE ///
				1 "I agree" ///
				2 "No, I do not agree", replace
			la val agreement AGREE
		la var refusal_reason    "Reason for refusal to participate"
			la def REASON_REF ///
				1  "No time/busy" ///
				2  "Do not want to share personal information" ///
				3  "No answer/do not know" ///
				4  "Call back at another time (specify date and time)" ///
				96 "Other (specify)", replace
			la val refusal_reason REASON_REF
		la var refusal_reason_oth "Reason for refusal: other (specify)"
		la var interview_record  "Willing to have interview recorded"
			la val interview_record AGREE
		la var address_unchanged "Do you still live in this address?"
			la val address_unchanged YES_NO_ENG
		la var new_address_str   "New address if moved (text)"
		la var province          "Province"
		la var city              "City/Municipality"
		la var barangay          "Barangay"
		la var locale            "Locale (urban/rural, current address)"
			la val locale LOCALE
		la var hhsize            "Household size"
		la var survey_lang       "Survey language"
			la def SURVEY_LANGOPT ///
				1 "English" ///
				2 "Filipino", replace
			la val survey_lang SURVEY_LANGOPT
		la var date_of_interview "Date of interview"
		la var time_of_interview "Time of interview"
		la var start_date        "Interview start date"
		la var end_date          "Interview end date"
		la var start_time        "Interview start time"
		la var end_time          "Interview end time"
		la var call_result       "Result of the interview"
			la def CALLREM ///
				1  "Complete" ///
				2  "Partially complete, no more callback" ///
				3  "Language barrier" ///
				4  "Respondent unavailable" ///
				5  "Wrong number" ///
				6  "No answer" ///
				7  "Busy/Engaged" ///
				8  "Refused" ///
				9  "Disconnected/invalid number" ///
				10 "Reference person can't connect to household", replace
			la val call_result CALLREM
		la var fmid              "Respondent family member ID"
		la var sample            "Household is in the main sample"
			la def SAMPLE ///
				1 "Yes, in sample" ///
				2 "No, not in sample", replace
			la val sample SAMPLE
		la var dur_pp            "Duration of Passport section (min)"
			note dur_pp: "QC use only. Duration variables (dur_pp through dur_tot) kept in M00 passport for quality control. Missing in rounds where timing was not recorded."
		la var dur_rr            "Duration of Roster section (min)"
		la var dur_educ          "Duration of Education section (min)"
		la var dur_sh            "Duration of Shocks section (min)"
		la var dur_emp           "Duration of Employment section (min)"
		la var dur_inc           "Duration of Income section (min)"
		la var dur_fin           "Duration of Finance section (min)"
		la var dur_hlt           "Duration of Health section (min)"
		la var dur_f_nf          "Duration of Food & Non-Food section (min)"
		la var dur_vw            "Duration of Views section (min)"
		la var dur_tot           "Duration of interview: all sections combined (min)"
		la var excess_int        "QC flag: excess interview in NCR (R4 only)"
			note excess_int: "R4 only: Flags 6 NCR households sampled in excess of regional quota. Set excess_int=1 to flag for exclusion from analysis. Missing (.) in all other rounds."

	compress
	save "${hf}/l2phl_M00_passport.dta", replace


	// ── M02 Education ─────────────────────────────────────────────────────────
	// Individual-level. Variables renamed in HF processing:
	//   ed1–ed14 (questionnaire) → ed15 (school attendance) and ed16 (dropout reason).
	// Processed BEFORE M01 so ed15 can be merged into the roster below.

	use "${hf}/l2phl_M02_education.dta", clear

		cap drop dur_educ isfmid dur_emp hhsize excess_int

		order hhid round fmid stratum psu region urban age age_grp gender indw ///
		      ed15 ed16 ed16_oth ed16_1 ed16_2

		la var hhid     "L2PHL Household ID"
		la var round    "L2PHL CATI Round"
		la var fmid     "Family member ID"
		la var stratum  "Sampling stratum"
		la var psu      "Primary sampling unit (PSU)"
		la var region   "Region"
			la val region REGION
		la var urban    "Urban/rural classification"
			la val urban LOCALE
		la var age      "Age of household member"
		la var age_grp  "Age group"
			la val age_grp AGEGRP
		la var gender   "Gender of household member"
			la def GENDER_ENG ///
				1 "Male" ///
				2 "Female", replace
			la val gender GENDER_ENG
		la var indw     "Individual weight (individual-level data)"
		la var ed15     "Is the person still attending school?"
			la def ED15_YN_ENG ///
				1 "Yes, still attending school" ///
				2 "No, not attending school", replace
			la val ed15 ED15_YN_ENG
		la var ed16     "Why did the person drop out from school?"
		la var ed16_oth "Why did the person drop out: other (specify)"
		la var ed16_1   "Why person dropped out: answer 1 (multi-select)"
		la var ed16_2   "Why person dropped out: answer 2 (multi-select)"

	compress
	save "${hf}/l2phl_M02_education.dta", replace


	// ── M01 Roster ────────────────────────────────────────────────────────────
	// Individual-level. The roster is the dynamic panel backbone:
	//   • isfmid tracks member status each round (active/left/correction/new)
	//   • New members (isfmid=6) enter with a fresh fmid and full demographics
	//   • Departing members (isfmid=2) keep their historical rows; fmid unchanged
	// Core demographics per member: age, gender, relationship, school attendance
	//
	// NOTE: marital status not yet collected (R1–R5). To add in R6: include
	// marital_status in the new-member intake section of the roster module,
	// alongside age, gender, relationship, and education.
	//
	// age_grp, stratum, psu, region, urban, indw come from the indw merge.
	// trailer_tag: R1-only flag for HHs whose isfmid was recovered via Trailer.

	use "${hf}/l2phl_M01_roster.dta", clear

		// drop system/admin vars only — isfmid KEPT (member status for panel tracking)
		cap drop dur_rr excess_int

		// fix fmidpermanent for new members (isfmid==6): assign their own fmid
		// (they have no baseline round, so fmidpermanent is otherwise missing)
		replace fmidpermanent = fmid if isfmid == 6 & fmidpermanent == .

		// bring in school-attendance status from the cleaned M02 file
		// (covers ~79% of age group 1 [0-17]; missing for adults/elderly)
		merge 1:1 round hhid fmid using "${hf}/l2phl_M02_education.dta" ///
			, assert(1 2 3) keep(1 3) nogen keepusing(ed15 ed16)

		order hhid round fmid stratum psu region urban age age_grp gender indw ///
		      isfmid fmidpermanent hhsize relationship ed15 ed16 ///
		      member_leftreason member_leftreason_oth member_leftreason_other ///
		      moved_in_reason moved_in_reason_oth ///
		      country_moved prov_moved city_moved ///
		      country_migrated_from province_migrated_from city_migrated_from ///
		      trailer_tag

		la var hhid                    "L2PHL Household ID"
			note hhid: "Dynamic panel roster: members who leave (isfmid=2) retain their rows in earlier rounds with their fmid unchanged. New members (isfmid=6) receive a completely new fmid and have full demographics (age, gender, relationship, ed15) collected at entry. Marital status was NOT collected in R1–R5 — planned for R6 new-member intake."
		la var round                   "L2PHL CATI Round"
		la var fmid                    "Family member ID"
		la var stratum                 "Sampling stratum"
		la var psu                     "Primary sampling unit (PSU)"
		la var region                  "Region"
			la val region REGION
		la var urban                   "Urban/rural classification"
			la val urban LOCALE
		la var age                     "Age of household member"
		la var age_grp                 "Age group"
			la val age_grp AGEGRP
		la var gender                  "Gender of household member"
			la val gender GENDER_ENG
		la var indw                    "Individual weight (individual-level data)"
		la var isfmid                  "Member status in this round"
			la def D5AOPT ///
				1 "Yes, member in the household in the last 30 days" ///
				2 "No, member not in the household in the last 30 days" ///
				3 "Yes, name is recorded incorrectly" ///
				4 "Yes, age is recorded incorrectly" ///
				5 "Yes, sex is recorded incorrectly" ///
				6 "New member (joined this round)", replace
			la val isfmid D5AOPT
			note isfmid: "Tracks each member's status in every round: 1=active, 2=left HH, 3=name correction, 4=age correction, 5=sex correction, 6=new member. Essential for unbalanced panel construction — use isfmid==1 or ==6 to keep currently active members."
		la var fmidpermanent           "Permanent family member ID (first round entered)"
			note fmidpermanent: "Permanent fmid from the first round the member appears. For baseline members (R1) this equals their R1 fmid. For new members (isfmid=6) who joined in R3–R5, fmidpermanent is set equal to their fmid (assigned when they joined)."
		la var hhsize                  "Household size"
		la var relationship            "Relationship of member to household head"
			la def RELATIONSHIP_ENG ///
				1  "Head" ///
				2  "Wife/Spouse" ///
				3  "Son/daughter" ///
				4  "Son-in-law/Daughter-in-law" ///
				5  "Grandchild" ///
				6  "Parent/Parent-in-law" ///
				7  "Sibling" ///
				8  "Other relative" ///
				9  "Domestic helper" ///
				10 "Boarder/Lodger" ///
				11 "Non-relative", replace
			la val relationship RELATIONSHIP_ENG
		la var ed15                    "Is the person still attending school? (from M02)"
			la val ed15 ED15_YN_ENG
			note ed15: "School attendance status merged from M02 education module. Covers ~79% of age group 1 (0-17) and ~14% of age group 2 (18-45). Missing for age group 3 (46+) — not collected."
		la var ed16                    "Why did the person drop out from school? (from M02)"
			note ed16: "Dropout reason merged from M02 education module. Only populated when ed15==2 (not attending school)."
		la var member_leftreason       "Reason why household member left"
		la var member_leftreason_oth   "Reason member left: other (specify)"
		la var member_leftreason_other "Reason member left: other (string)"
		la var moved_in_reason         "Reason new member moved into household"
		la var moved_in_reason_oth     "Reason moved in: other (specify)"
		la var country_moved           "Country where member moved to"
		la var prov_moved              "Province where member moved to"
		la var city_moved              "City/Municipality where member moved to"
		la var country_migrated_from   "Country where new member came from"
		la var province_migrated_from  "Province where new member came from"
		la var city_migrated_from      "City/Municipality where new member came from"
		la var trailer_tag             "R1 flag: isfmid recovered via Trailer questionnaire"
			note trailer_tag: "R1 only: Flags ~220 households whose household head fmid (isfmid) was recovered using the Round 1 Trailer questionnaire. Missing (.) in R2–R5."

	compress
	save "${hf}/l2phl_M01_roster.dta", replace


	// ── M03 Shocks ────────────────────────────────────────────────────────────
	// HH-level. Combines Utilities (el5/n5), Natural Hazards (NH*), and Shocks (SH*).
	// nh14–nh17 variants are processing artefacts (not in questionnaire).

	use "${hf}/l2phl_M03_shock.dta", clear

		cap drop dur_sh nh14_1 nh15_1 nh16_1 nh17_1_1 nh14_2 nh17_1_2 shocks_end excess_int
		cap drop fmid age gender age_grp

		order hhid round stratum psu region urban popw hhw ///
		      el5 n5 ///
		      nh2_1 nh2_2 nh3_1_1 nh3_1_2 nh3_2_1 nh3_3_1 nh3_4_1 ///
		      nh7_1_1 nh7_1_2 nh7_2_1 nh7_2_2 nh7_3_1 nh7_4_1 nh7_5_1 nh7_oth_1 ///
		      nh10_1_1 nh10_1_2 nh10_2_1 nh10_3_1 nh10_4_1 nh10_5_1 nh10_6_1 nh10_oth_1 ///
		      sh1 sh1b sh1b_1 sh1b_2 sh1b_3 sh1b_4 ///
		      sh2_1 sh2_1_1 sh2_1_2 sh2_1_3 sh2_1_4 sh2_1_5 sh2_1_6 ///
		             sh2_1_7 sh2_1_8 sh2_1_9 sh2_1_oth ///
		      sh2_2 sh2_2_1 sh2_2_2 sh2_2_3 sh2_2_4 sh2_2_5 sh2_2_oth ///
		      sh2_3 sh2_3_1 sh2_3_2 sh2_3_3 sh2_3_oth ///
		      sh2_4_1 sh3 sh4 n1 n3 n3_1

		la var hhid    "L2PHL Household ID"
		la var round   "L2PHL CATI Round"
		la var stratum "Sampling stratum"
		la var psu     "Primary sampling unit (PSU)"
		la var region  "Region"
			la val region REGION
		la var urban   "Urban/rural classification"
			la val urban LOCALE
		la var popw    "Population weight (household-level data)"
		la var hhw     "Household weight (household-level data)"
		la var el5     "Total hours electricity was unavailable in the past week"
		la var n5      "Experienced internet interruption >1 hour in the past month?"
			la val n5 YES_NO_ENG
		la var nh2_1   "Type of natural hazard experienced – hazard 1"
		la var nh2_2   "Type of natural hazard experienced – hazard 2"
		la var nh3_1_1 "Natural hazard 1: affected dimension 1"
		la var nh3_1_2 "Natural hazard 1: affected dimension 2"
		la var nh3_2_1 "Natural hazard 2: affected dimension 1"
		la var nh3_3_1 "Natural hazard 3: affected dimension 1"
		la var nh3_4_1 "Natural hazard 4: affected dimension 1"
		la var nh7_1_1 "Natural hazard 1: impact/consequence 1"
		la var nh7_1_2 "Natural hazard 1: impact/consequence 2"
		la var nh7_2_1 "Natural hazard 2: impact/consequence 1"
		la var nh7_2_2 "Natural hazard 2: impact/consequence 2"
		la var nh7_3_1 "Natural hazard 3: impact/consequence 1"
		la var nh7_4_1 "Natural hazard 4: impact/consequence 1"
		la var nh7_5_1 "Natural hazard 5: impact/consequence 1"
		la var nh7_oth_1 "Natural hazard (other): impact/consequence 1"
		la var nh10_1_1  "Natural hazard 1: coping mechanism 1"
		la var nh10_1_2  "Natural hazard 1: coping mechanism 2"
		la var nh10_2_1  "Natural hazard 2: coping mechanism 1"
		la var nh10_3_1  "Natural hazard 3: coping mechanism 1"
		la var nh10_4_1  "Natural hazard 4: coping mechanism 1"
		la var nh10_5_1  "Natural hazard 5: coping mechanism 1"
		la var nh10_6_1  "Natural hazard 6: coping mechanism 1"
		la var nh10_oth_1 "Natural hazard (other): coping mechanism 1"
		la var sh1     "Any HH member exposed to a shock in the past 30 days?"
			la val sh1 YES_NO_ENG
		la var sh1b    "Types of shock HH was exposed to in the past 30 days"
		la var sh1b_1  "Shock type 1"
		la var sh1b_2  "Shock type 2"
		la var sh1b_3  "Shock type 3"
		la var sh1b_4  "Shock type 4"
		la var sh2_1   "Coping mechanisms for shock 1"
		la var sh2_1_1 "Coping mechanism for shock 1 – 1"
		la var sh2_1_2 "Coping mechanism for shock 1 – 2"
		la var sh2_1_3 "Coping mechanism for shock 1 – 3"
		la var sh2_1_4 "Coping mechanism for shock 1 – 4"
		la var sh2_1_5 "Coping mechanism for shock 1 – 5"
		la var sh2_1_6 "Coping mechanism for shock 1 – 6"
		la var sh2_1_7 "Coping mechanism for shock 1 – 7"
		la var sh2_1_8 "Coping mechanism for shock 1 – 8"
		la var sh2_1_9 "Coping mechanism for shock 1 – 9"
		la var sh2_1_oth "Coping mechanism for shock 1 – other (specify)"
		la var sh2_2   "Coping mechanisms for shock 2"
		la var sh2_2_1 "Coping mechanism for shock 2 – 1"
		la var sh2_2_2 "Coping mechanism for shock 2 – 2"
		la var sh2_2_3 "Coping mechanism for shock 2 – 3"
		la var sh2_2_4 "Coping mechanism for shock 2 – 4"
		la var sh2_2_5 "Coping mechanism for shock 2 – 5"
		la var sh2_2_oth "Coping mechanism for shock 2 – other (specify)"
		la var sh2_3   "Coping mechanisms for shock 3"
		la var sh2_3_1 "Coping mechanism for shock 3 – 1"
		la var sh2_3_2 "Coping mechanism for shock 3 – 2"
		la var sh2_3_3 "Coping mechanism for shock 3 – 3"
		la var sh2_3_oth "Coping mechanism for shock 3 – other (specify)"
		la var sh2_4_1 "Coping mechanism for shock 4 – 1"
		la var sh3     "Any unexpected disruption in drinking water supply in past 30 days?"
			la val sh3 YES_NO_ENG
		la var sh4     "Number of days with water supply disruption in past 30 days"
		la var n1      "Any natural hazard experienced in the past 30 days?"
			la val n1 YES_NO_ENG
		la var n3      "Type of natural hazard experienced"
		la var n3_1    "Type of natural hazard – 1"

	compress
	save "${hf}/l2phl_M03_shock.dta", replace


	// ── M04 Employment ────────────────────────────────────────────────────────
	// Individual-level. a24–a27, a25_old* are legacy/recoded vars not in questionnaire.
	// isfmid kept: flags the primary respondent (interview focal member).
	// a9: gig platform, collected R3 onwards. a10/a11: days/hours, collected R3 onwards.

	use "${hf}/l2phl_M04_employment.dta", clear

		cap drop a24 a27 a25 a25_olda6 a25_olda8a9 a25_olda10 a25_olda11 a26 ///
		         trailer_tag dur_emp emp_status excess_int

		order hhid round fmid stratum psu region urban age age_grp gender indw ///
		      isfmid ///
		      a1 a3 a3_oth a4 a4_oth a5 a5_oth a6 a7 a8 a9 a10 a11 ///
		      a16 a17 a18 ///
		      a19 a19_1 a19_2 a19_3 a19_4 a19_5 a19_oth ///
		      a20 a21 a21_1 a21_2 a21_3 a21_oth a21_own a22 a23

		la var hhid    "L2PHL Household ID"
		la var round   "L2PHL CATI Round"
		la var fmid    "Family member ID"
		la var stratum "Sampling stratum"
		la var psu     "Primary sampling unit (PSU)"
		la var region  "Region"
			la val region REGION
		la var urban   "Urban/rural classification"
			la val urban LOCALE
		la var age     "Age of household member"
		la var age_grp "Age group"
			la val age_grp AGEGRP
		la var gender  "Gender of household member"
			la val gender GENDER_ENG
		la var indw    "Individual weight (individual-level data)"
		la var isfmid  "Did this member live in the HH in the past 30 days? (interview focal member)"
			la val isfmid D5AOPT
		la var a1      "Did [member] do any work for at least one hour during the past week?"
			la val a1 YES_NO_ENG
		la var a3      "Main reason [member] did not try to find a paid job or start a business"
		la var a3_oth  "Main reason for not looking for job: other (specify)"
		la var a4      "Primary occupation during the past week"
		la var a4_oth  "Primary occupation: other (specify)"
		la var a5      "Industry in which [member] worked during the past week"
		la var a5_oth  "Industry: other (specify)"
		la var a6      "Class of worker of [member] during the past month"
		la var a7      "Are the products [member] works on intended for sale or own use?"
		la var a8      "Is [member]'s work a gig work / digital platform work?"
			la def YES_NO_DK_ENG ///
				1  "Yes" ///
				2  "No" ///
				99 "Don't know", replace
			la val a8 YES_NO_DK_ENG
		la var a9      "Digital platform of [member]'s gig work"
			note a9: "Collected from R3 onwards. Records the digital platform used for gig work. Missing (.) in R1–R2 (question not asked)."
		la var a10     "How many days does [member] usually work in a week?"
			note a10: "Collected from R3 onwards. Number of days usually worked per week. Missing (.) in R1–R2. Fix: a10/a11 set to missing if a1==2 (not working) — applied R1–R5 (497 cases). See fix/do/ files."
		la var a11     "How many hours does [member] usually work in a week?"
			note a11: "Collected from R3 onwards. Number of hours usually worked per week. Missing (.) in R1–R2. Fix: see a10 note above."
		la var a16     "Does [member] have a written contract or oral agreement?"
		la var a17     "Total length of current contract or agreement"
		la var a18     "Does employer pay contributions to pension or unemployment insurance?"
			la val a18 YES_NO_DK_ENG
		la var a19     "Employment benefits [member] has access to (multi-select)"
		la var a19_1   "Employment benefit 1"
		la var a19_2   "Employment benefit 2"
		la var a19_3   "Employment benefit 3"
		la var a19_4   "Employment benefit 4"
		la var a19_5   "Employment benefit 5"
		la var a19_oth "Employment benefit: other (specify)"
		la var a20     "For whom did [member] work?"
		la var a21     "Mode of transport [member] usually uses to and from work (multi-select)"
		la var a21_1   "Mode of transport 1"
		la var a21_2   "Mode of transport 2"
		la var a21_3   "Mode of transport 3"
		la var a21_oth "Mode of transport: other (specify)"
		la var a21_own "Owns a vehicle for commuting?"
		la var a22     "Travel time from home to workplace (minutes)"
		la var a23     "Usual transport cost to and from work (PhP)"

	compress
	save "${hf}/l2phl_M04_employment.dta", replace


	// ── M05 Income ────────────────────────────────────────────────────────────
	// Individual-level. Computed income totals dropped — derive from ia3/ia6 if needed.
	// R4 fix: ia3_a–ia3_f set to missing if ia2==2 (90 skip logic violations).

	use "${hf}/l2phl_M05_income.dta", clear

		cap drop isfmid n_ia3 trailer_tag dur_inc excess_int ///
		         regular_cash_income regular_inkind_income total_regular_income ///
		         season_cash_income season_inkind_income total_season_income ///
		         total_income regular_cash_earnings

		order hhid round fmid stratum psu region urban age age_grp gender indw ///
		      ia2 ia3_a ia3_b ia3_c ia3_d ia3_e ia3_f ///
		      ia5 ia6_a ia6_b ia6_c ia6_d ia6_e ia6_f ia7

		la var hhid    "L2PHL Household ID"
		la var round   "L2PHL CATI Round"
		la var fmid    "Family member ID"
		la var stratum "Sampling stratum"
		la var psu     "Primary sampling unit (PSU)"
		la var region  "Region"
			la val region REGION
		la var urban   "Urban/rural classification"
			la val urban LOCALE
		la var age     "Age of household member"
		la var age_grp "Age group"
			la val age_grp AGEGRP
		la var gender  "Gender of household member"
			la val gender GENDER_ENG
		la var indw    "Individual weight (individual-level data)"
		la var ia2     "Received regular salaries and wages (cash & in-kind) in the past month?"
			la val ia2 YES_NO_ENG
		la var ia3_a   "Cash earnings: basic salaries and wages (PhP)"
			note ia3_a: "R4 fix: ia3_a–ia3_f set to missing if ia2==2 (not receiving regular wages) — 90 skip logic violations corrected in R4. See fix/do/ files."
		la var ia3_b   "Cash earnings: other (bonus, commission, gratuities, honoraria) (PhP)"
		la var ia3_c   "In-kind earnings: basic salaries and wages (PhP)"
		la var ia3_d   "In-kind earnings: housing (PhP)"
		la var ia3_e   "In-kind earnings: food (PhP)"
		la var ia3_f   "In-kind earnings: other transport/education/clothing/goods (PhP)"
		la var ia5     "Received salaries/wages as seasonal or occasional worker in the past month?"
			la val ia5 YES_NO_ENG
		la var ia6_a   "Seasonal/gig cash earnings: basic salaries and wages (PhP)"
		la var ia6_b   "Seasonal/gig cash earnings: other bonus/commission/etc. (PhP)"
		la var ia6_c   "Seasonal/gig in-kind earnings: basic salaries and wages (PhP)"
		la var ia6_d   "Seasonal/gig in-kind earnings: housing (PhP)"
		la var ia6_e   "Seasonal/gig in-kind earnings: food (PhP)"
		la var ia6_f   "Seasonal/gig in-kind earnings: other transport/education/etc. (PhP)"
		la var ia7     "Of total income, how much is from gig work? (PhP)"

	compress
	save "${hf}/l2phl_M05_income.dta", replace


	// ── M06 Finance ───────────────────────────────────────────────────────────
	// HH-level. f13–f18 are processing artefacts not in questionnaire.
	// f4/f5/f11/f12 are in questionnaire but not collected in this panel.

	use "${hf}/l2phl_M06_finance.dta", clear

		cap drop n_f13 f13_a f13_b f14 f15 f16 f17 f18 dur_fin excess_int
		cap drop fmid age gender age_grp

		order hhid round stratum psu region urban popw hhw ///
		      f1 f2 f3 f6 f7 ///
		      f8 f8_1 f8_2 f8_3 f8_4 f8_5 f8_6 f8_7 f8_oth ///
		      f9 f9_oth f10

		la var hhid    "L2PHL Household ID"
		la var round   "L2PHL CATI Round"
		la var stratum "Sampling stratum"
		la var psu     "Primary sampling unit (PSU)"
		la var region  "Region"
			la val region REGION
		la var urban   "Urban/rural classification"
			la val urban LOCALE
		la var popw    "Population weight (household-level data)"
		la var hhw     "Household weight (household-level data)"
		la var f1      "HH received/deposited money into a formal bank account in past 30 days?"
			la def YES_NONE_REF_ENG ///
				1 "Yes" ///
				2 "No" ///
				3 "None" ///
				98 "Refused", replace
			la val f1 YES_NONE_REF_ENG
		la var f2      "HH received/deposited money into mobile money/e-wallet in past 30 days?"
			la val f2 YES_NONE_REF_ENG
		la var f3      "Able to save some money for the future in past 30 days?"
			la def YES_NO_REF_ENG ///
				1  "Yes" ///
				2  "No" ///
				98 "Refused", replace
			la val f3 YES_NO_REF_ENG
		la var f6      "HH could currently pay an emergency expense of PhP300,000?"
			la val f6 YES_NO_REF_ENG
		la var f7      "Any HH member applied or tried to take credit or a loan in past 30 days?"
			la def YES_NO_REF_DK_ENG ///
				1  "Yes" ///
				2  "No" ///
				98 "Refused" ///
				99 "Don't know", replace
			la val f7 YES_NO_REF_DK_ENG
		la var f8      "Purpose of the loan/credit (multi-select)"
		la var f8_1    "Loan purpose 1"
		la var f8_2    "Loan purpose 2"
		la var f8_3    "Loan purpose 3"
		la var f8_4    "Loan purpose 4"
		la var f8_5    "Loan purpose 5"
		la var f8_6    "Loan purpose 6"
		la var f8_7    "Loan purpose 7"
		la var f8_oth  "Loan purpose: other (specify)"
		la var f9      "Institution/person to whom HH applied for largest loan/credit"
		la var f9_oth  "Institution for loan: other (specify)"
		la var f10     "Was the loan approved?"
			la val f10 YES_NO_REF_DK_ENG

	compress
	save "${hf}/l2phl_M06_finance.dta", replace


	// ── M07 Health ────────────────────────────────────────────────────────────
	// Conceptually HH-level (one row per HH per round; fmid = respondent).
	// Pooled in the individual loop → fix by dropping indw; re-merge hhw.
	// h4/h7/h8 collected from R4 onwards.
	// h9a/h9b/h9c and h12–h16 are R5 only.

	use "${hf}/l2phl_M07_health.dta", clear

		cap drop dur_hlt name excess_int age age_grp
		// swap individual weight for HH-level weights
		cap drop fmid indw
		merge m:1 round hhid using "${hf}/l2phl_cati_hhw.dta" ///
			, assert(1 3) keep(3) nogen keepusing(popw hhw)

		order hhid round stratum psu region urban popw hhw ///
		      h2 h2a h3 h3_oth h4 h4_oth h7 h8 h8_amt ///
		      h9_1 h9_2 h9_3 h9a h9b h9c ///
		      h10_1 h10_2 h10_3 ///
		      h11a_1 h11a_2 h11a_3 ///
		      h11b_1__1 h11b_1__2 h11b_1__3 h11b_1__oth ///
		      h11b_2__1 h11b_2__2 h11b_2__3 h11b_2__oth ///
		      h11b_3__1 h11b_3__2 h11b_3__3 h11b_3__oth ///
		      h17 h12 h13 h13_oth h14 h15 h16 h16_1 h16_2 h16_3 h16_4 h16_5 h16_oth

		la var hhid      "L2PHL Household ID"
		la var round     "L2PHL CATI Round"
		la var stratum   "Sampling stratum"
		la var psu       "Primary sampling unit (PSU)"
		la var region    "Region"
			la val region REGION
		la var urban     "Urban/rural classification"
			la val urban LOCALE
		la var popw      "Population weight (household-level data)"
		la var hhw       "Household weight (household-level data)"
		la var h2        "In the last 30 days, was it necessary for any HH member to get health care services?"
			la def H2_ENG ///
				1  "Yes, inpatient" ///
				2  "Yes, outpatient" ///
				3  "Yes, both inpatient and outpatient" ///
				4  "No" ///
				98 "Don't want to answer / Refused", replace
			la val h2 H2_ENG
		la var h2a       "Were you or the HH member able to get the health care services?"
			la def YES_NO_DKREF_ENG ///
				1  "Yes" ///
				2  "No" ///
				98 "Don't want to answer / Refused", replace
			la val h2a YES_NO_DKREF_ENG
		la var h3        "Main reason [member] was not able to get health care service"
			la def H3_ENG ///
				1  "Lack of money / Cannot afford" ///
				2  "No medical personnel available" ///
				3  "Turned away because facility was full" ///
				4  "Limited/No transportation" ///
				5  "Restriction to go outside" ///
				6  "Afraid" ///
				11 "Medical services not yet needed" ///
				13 "Not able to avail" ///
				16 "No health programs/services available" ///
				19 "Health care providers choose who to help" ///
				22 "Not qualified" ///
				32 "Lack of services provided" ///
				46 "Used alternative medicine instead" ///
				47 "Chose another health care provider" ///
				52 "Too busy" ///
				95 "None" ///
				96 "Others (specify)" ///
				99 "Don't know", replace
			la val h3 H3_ENG
		la var h3_oth    "Main reason unable to get health care: other (specify)"
		la var h4        "Most frequent health care facility visited?"
			la def H4_ENG ///
				1  "Barangay Health Station" ///
				2  "Rural Health Center (RHU)/Health Center" ///
				3  "Private Clinic" ///
				4  "Public Hospital" ///
				5  "Private Hospital" ///
				96 "Others (specify)" ///
				99 "Don't know", replace
			la val h4 H4_ENG
			note h4: "Not collected in R1–R3. Most frequent health care facility visited. Missing (.) in rounds where the question was not asked."
		la var h4_oth    "Most frequent health care facility: other (specify)"
		la var h7        "Usual amount spent on transportation for consultation (PhP)"
		la var h8        "Did [member] pay out-of-pocket for consultation?"
			la def H8_ENG ///
				1 "Yes, in cash (specify amount)" ///
				2 "Yes, in kind (specify amount)" ///
				3 "No", replace
			la val h8 H8_ENG
		la var h8_amt    "Amount paid out-of-pocket for consultation (PhP)"
		la var h9_1      "Incidence of being prescribed/asked to get services – health visit 1"
			la def YES_NO_HEALTH ///
				1 "Yes" ///
				2 "No", replace
			la val h9_1 YES_NO_HEALTH
		la var h9_2      "Incidence of being prescribed/asked to get services – health visit 2"
			la val h9_2 YES_NO_HEALTH
		la var h9_3      "Incidence of being prescribed/asked to get services – health visit 3"
			la val h9_3 YES_NO_HEALTH
		la var h9a       "Prescribed/asked to get: Medicines?"
			la val h9a YES_NO_HEALTH
			note h9a: "R5 only: h9a, h9b, h9c added in Round 5. Incidence of being prescribed medicines, diagnostic services, or other services. Missing (.) in R1–R4."
		la var h9b       "Prescribed/asked to get: Diagnostic services?"
			la val h9b YES_NO_HEALTH
		la var h9c       "Prescribed/asked to get: Other services?"
			la val h9c YES_NO_HEALTH
		la var h10_1     "Were you able to buy/get prescribed service – health visit 1?"
			la val h10_1 YES_NO_HEALTH
		la var h10_2     "Were you able to buy/get prescribed service – health visit 2?"
			la val h10_2 YES_NO_HEALTH
		la var h10_3     "Were you able to buy/get prescribed service – health visit 3?"
			la val h10_3 YES_NO_HEALTH
		la var h11a_1    "Amount spent on prescribed service – health visit 1 (PhP)"
		la var h11a_2    "Amount spent on prescribed service – health visit 2 (PhP)"
		la var h11a_3    "Amount spent on prescribed service – health visit 3 (PhP)"
		la var h11b_1__1   "Who paid for prescribed service – visit 1, payer 1"
		la var h11b_1__2   "Who paid for prescribed service – visit 1, payer 2"
		la var h11b_1__3   "Who paid for prescribed service – visit 1, payer 3"
		la var h11b_1__oth "Who paid for prescribed service – visit 1, other (specify)"
		la var h11b_2__1   "Who paid for prescribed service – visit 2, payer 1"
		la var h11b_2__2   "Who paid for prescribed service – visit 2, payer 2"
		la var h11b_2__3   "Who paid for prescribed service – visit 2, payer 3"
		la var h11b_2__oth "Who paid for prescribed service – visit 2, other (specify)"
		la var h11b_3__1   "Who paid for prescribed service – visit 3, payer 1"
		la var h11b_3__2   "Who paid for prescribed service – visit 3, payer 2"
		la var h11b_3__3   "Who paid for prescribed service – visit 3, payer 3"
		la var h11b_3__oth "Who paid for prescribed service – visit 3, other (specify)"
		la var h17       "PhilHealth membership status and whether currently paying?"
		la var h12       "Was any HH member hospitalized in the past 30 days?"
			la val h12 YES_NO_HEALTH
			note h12: "R5 only: h12–h16 added in Round 5 to capture hospitalization experience. Missing (.) in R1–R4."
		la var h13       "Type of health care facility where hospitalized"
			la def H13_ENG ///
				1  "Public Hospital" ///
				2  "Private Hospital" ///
				3  "Clinic" ///
				96 "Others (specify)" ///
				99 "Don't know", replace
			la val h13 H13_ENG
		la var h13_oth   "Health care facility type: other (specify)"
		la var h14       "Total hospital bill (PhP)"
			la def DN_ENG ///
				-99 "Don't know", replace
			la val h14 DN_ENG
		la var h15       "Out-of-pocket expense on hospital bill (PhP)"
			la val h15 DN_ENG
		la var h16       "Who paid for the rest of the hospital bill (multi-select)"
		la var h16_1     "Who paid for hospital bill: payer 1"
		la var h16_2     "Who paid for hospital bill: payer 2"
		la var h16_3     "Who paid for hospital bill: payer 3"
		la var h16_4     "Who paid for hospital bill: payer 4"
		la var h16_5     "Who paid for hospital bill: payer 5"
		la var h16_oth   "Who paid for hospital bill: other (specify)"

	compress
	save "${hf}/l2phl_M07_health.dta", replace


	// ── M08 Food & Non-Food ────────────────────────────────────────────────────
	// HH-level. f08_a–f08_e are HF-restructured versions of the food insecurity
	// experience scale (FIES) items (original questionnaire: fo*/nf*/ssb*).

	use "${hf}/l2phl_M08_food_nonfood.dta", clear

		cap drop dur_f_nf excess_int
		cap drop fmid age gender age_grp

		order hhid round stratum psu region urban popw hhw ///
		      f08_a f08_b f08_c f08_d f08_e

		la var hhid    "L2PHL Household ID"
		la var round   "L2PHL CATI Round"
		la var stratum "Sampling stratum"
		la var psu     "Primary sampling unit (PSU)"
		la var region  "Region"
			la val region REGION
		la var urban   "Urban/rural classification"
			la val urban LOCALE
		la var popw    "Population weight (household-level data)"
		la var hhw     "Household weight (household-level data)"
		la var f08_a   "Worried about not having enough food because of lack of money or resources?"
			la val f08_a YES_NO_ENG
		la var f08_b   "Ate less than you thought you should because of a lack of money or resources?"
			la val f08_b YES_NO_ENG
		la var f08_c   "Ran out of food because of a lack of money or resources?"
			la val f08_c YES_NO_ENG
		la var f08_d   "Were hungry but did not eat because there was not enough money or resources?"
			la val f08_d YES_NO_ENG
		la var f08_e   "Went without eating for a whole day because of a lack of money or resources?"
			la val f08_e YES_NO_ENG

	compress
	save "${hf}/l2phl_M08_food_nonfood.dta", replace


	// ── M09 Opinions & Views ──────────────────────────────────────────────────
	// HH-level. v11/v12 are processing artefacts not in questionnaire.
	// v9_d/v9_h absent from HF data (skip logic — not collected).

	use "${hf}/l2phl_M09_views.dta", clear

		cap drop v11 v12 dur_vw excess_int
		cap drop fmid age gender age_grp

		order hhid round stratum psu region urban popw hhw ///
		      v1 v5 ///
		      v9_a v9_b v9_c v9_e v9_f v9_g v9_i v9_j v9_k v9_l v9_m

		la var hhid    "L2PHL Household ID"
		la var round   "L2PHL CATI Round"
		la var stratum "Sampling stratum"
		la var psu     "Primary sampling unit (PSU)"
		la var region  "Region"
			la val region REGION
		la var urban   "Urban/rural classification"
			la val urban LOCALE
		la var popw    "Population weight (household-level data)"
		la var hhw     "Household weight (household-level data)"
		la var v1      "Life satisfaction (1=not satisfied at all, 5=completely satisfied)"
			la def SATISFACTION_ENG ///
				1 "Not satisfied at all" ///
				2 "Partly satisfied" ///
				3 "Satisfied" ///
				4 "More than Satisfied" ///
				5 "Completely satisfied", replace
			la val v1 SATISFACTION_ENG
		la var v5      "Relative to last month, change in the economic situation of your household"
			la def QLI_ENG ///
				1 "Significantly worsened" ///
				2 "Slightly worsened" ///
				3 "Stayed the same" ///
				4 "Slightly improved" ///
				5 "Significantly improved", replace
			la val v5 QLI_ENG
		la var v9_a    "Prices for the things I buy are rising too quickly"
			la def AGREEMENT_ENG ///
				1 "Strongly disagree" ///
				2 "Disagree" ///
				3 "Neither agree nor disagree" ///
				4 "Agree" ///
				5 "Strongly agree", replace
			la val v9_a AGREEMENT_ENG
		la var v9_b    "I trust in the national government"
			la val v9_b AGREEMENT_ENG
		la var v9_c    "I am optimistic about the economic future of the country"
			la val v9_c AGREEMENT_ENG
		la var v9_e    "Citizens should have more say in important government decisions"
			la val v9_e AGREEMENT_ENG
		la var v9_f    "I am worried about being able to give my children a good education"
			la def AGREEMENT_NOCHILD_ENG ///
				1 "Strongly disagree" ///
				2 "Disagree" ///
				3 "Neither agree nor disagree" ///
				4 "Agree" ///
				5 "Strongly agree" ///
				6 "No child", replace
			la val v9_f AGREEMENT_NOCHILD_ENG
		la var v9_g    "I am worried about losing my job (or not finding a job)"
			la val v9_g AGREEMENT_ENG
		la var v9_i    "I am worried about political instability in my country"
			la val v9_i AGREEMENT_ENG
		la var v9_j    "Digital public services helped me save time or cost over the past month"
			la val v9_j AGREEMENT_ENG
		la var v9_k    "The taxes that I pay are being well spent on priorities to help the country"
			la val v9_k AGREEMENT_ENG
		la var v9_l    "The national government is doing a good job fighting corruption"
			la val v9_l AGREEMENT_ENG
		la var v9_m    "The country is generally on the right track on political, social, and economic reforms"
			la val v9_m AGREEMENT_ENG

	compress
	save "${hf}/l2phl_M09_views.dta", replace


	// =========================================================================
	// SECTION 5: Build household- and individual-level master datasets
	// =========================================================================

	use "${hf}/l2phl_HH_Level_Data.dta", clear

			gunique hhid round
				as `r(N)' == `r(unique)'

			merge 1:1 round hhid using "$hf/l2phl_cati_hhw.dta" ///
				, assert(1 3) keep(3) nogen

			g date = subm_date
			replace date = date_of_interview if date == .
			replace date = 24050 if date == . & round == 1
			su *date*

			cap drop year
			g year = year(date)

			cap drop quarter
			g quarter = quarter(date)

			cap drop qofd
			g qofd =qofd(date)
				format qofd %tq_CCYY_!Qq

			cap drop month
			g month = month(date)

			cap drop mofd
			g mofd = mofd(date)
				format mofd %tm_CCYY!mNN

	save "${hf}/l2phl_cati_household.dta", replace

	use "${hf}/l2phl_Roster_Level_Data.dta", clear

			gunique hhid round fmid
				as `r(N)' == `r(unique)'

			merge 1:1 round hhid fmid using "$hf/l2phl_cati_indw.dta" ///
				, assert(1 3) keep(3) nogen

			merge m:1 round hhid using "${hf}/l2phl_cati_household.dta" ///
				, assert(1 3) keep(3) nogen keepusing(date year quarter qofd month mofd)

	save "${hf}/l2phl_cati_individual.dta", replace

		cap erase "${hf}/l2phl_Roster_Level_Data.dta"
		cap erase "${hf}/l2phl_HH_Level_Data.dta"
		cap erase "${hf}/l2phl_cati_indw.dta"
		cap erase "${hf}/l2phl_cati_hhw.dta"
