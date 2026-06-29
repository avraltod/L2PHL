// =============================================================================
// Filename:      _series_emit.do
// Author:        Avralt-Od Purevjav
// Last Modified: Avraa
// Date:          2026-06-29
// =============================================================================
// Storyline series emitter — one indicator → an R1–R8 series (overall + by each
// requested breakdown), written into sl_series.json via the _stat_emit primitives.
// Per-round subpop means, so indicators present in only some rounds (e.g. f17/f18
// R5–R8) emit JSON null for the empty rounds. Requires _stat_emit.do included.

	version 18

	cap program drop series_emit
	program define series_emit
		* series_emit <name> <indicator>, round(rvar) [label() unit() ///
		*             quintile(qvar) region(rgvar) urbrur(uvar) scale(real 100)]
		syntax namelist(min=2 max=2) [, Label(string) Unit(string) ///
			Round(varname) Quintile(varname) Region(varname) Urbrur(varname) ///
			Scale(real 100)]
		gettoken nm ind : namelist
		if "`unit'" == "" local unit "pct"
		qui levelsof `round', local(RDS)
		tempvar sp
		local mincell 30                              // suppress cells with <30 obs (methodology rule)

		* --- meta + rounds ---
		_se_guard "series.`nm'.label"
		_se_append `"${SE_q}series.`nm'.label${SE_q}:${SE_q}`label'${SE_q}"'
		_se_guard "series.`nm'.unit"
		_se_append `"${SE_q}series.`nm'.unit${SE_q}:${SE_q}`unit'${SE_q}"'
		stat_arr "series.`nm'.rounds" `RDS'

		* --- overall: per-round subpop mean (null where not estimable) ---
		local ov ""
		foreach r of local RDS {
			qui count if `round'==`r' & !missing(`ind')
			if r(N) < `mincell' {
				local ov "`ov' null"
			}
			else {
				cap drop `sp'
				qui gen byte `sp' = (`round'==`r')
				qui svy, subpop(`sp'): mean `ind'
				local v = string(_b[`ind']*`scale', "%9.1f")
				local ov "`ov' `v'"
			}
		}
		stat_arr "series.`nm'.overall" `ov'

		* --- breakdowns: per (round × level) subpop mean ---
		foreach bd in quintile region urbrur {
			local bv ``bd''
			if "`bv'" == "" continue
			qui count if !missing(`bv')
			if r(N) == 0 continue
			local jkey = cond("`bd'"=="quintile","by_quintile", ///
			             cond("`bd'"=="region","by_region","by_urbrur"))
			qui levelsof `bv', local(LV)
			foreach L of local LV {
				local lab : label (`bv') `L'
				if `"`lab'"' == "`L'" local lab "`bd'`L'"
				local arr ""
				foreach r of local RDS {
					qui count if `round'==`r' & `bv'==`L' & !missing(`ind')
					if r(N) < `mincell' {
						local arr "`arr' null"
					}
					else {
						cap drop `sp'
						qui gen byte `sp' = (`round'==`r' & `bv'==`L')
						qui svy, subpop(`sp'): mean `ind'
						local v = string(_b[`ind']*`scale', "%9.1f")
						local arr "`arr' `v'"
					}
				}
				stat_arr "series.`nm'.`jkey'.`lab'" `arr'
			}
		}
	end
