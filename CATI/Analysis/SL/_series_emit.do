// =============================================================================
// Filename:      _series_emit.do
// Author:        Avralt-Od Purevjav
// Last Modified: Avraa
// Date:          2026-06-29
// =============================================================================
// Storyline series emitter — one indicator → an R1–R8 series (overall + by each
// requested breakdown), written into sl_series.json via the _stat_emit primitives.
// Requires _stat_emit.do already included (stat_arr / _se_guard / _se_append in scope).

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

		* --- rounds present (sorted) ---
		qui levelsof `round', local(RDS)
		local nr : word count `RDS'

		* --- meta (strings emitted directly through the _stat_emit body) ---
		_se_guard "series.`nm'.label"
		_se_append `"${SE_q}series.`nm'.label${SE_q}:${SE_q}`label'${SE_q}"'
		_se_guard "series.`nm'.unit"
		_se_append `"${SE_q}series.`nm'.unit${SE_q}:${SE_q}`unit'${SE_q}"'
		stat_arr "series.`nm'.rounds" `RDS'

		* --- overall series over rounds ---
		qui svy: mean `ind', over(`round')
		matrix bmat = e(b)
		local ov ""
		forvalues k = 1/`nr' {
			local v = string(bmat[1,`k']*`scale', "%9.1f")
			local ov "`ov' `v'"
		}
		stat_arr "series.`nm'.overall" `ov'

		* --- breakdowns: one subpop per level, over rounds ---
		foreach bd in quintile region urbrur {
			local bv ``bd''
			if "`bv'" == "" continue
			qui count if !missing(`bv')
			if r(N) == 0 continue                       // var absent/degraded (e.g. inc_q)
			local jkey = cond("`bd'"=="quintile","by_quintile", ///
			             cond("`bd'"=="region","by_region","by_urbrur"))
			qui levelsof `bv', local(LV)
			tempvar sp
			foreach L of local LV {
				qui gen byte `sp' = (`bv'==`L')
				qui svy, subpop(`sp'): mean `ind', over(`round')
				matrix bsub = e(b)
				local arr ""
				forvalues k = 1/`nr' {
					local v = string(bsub[1,`k']*`scale', "%9.1f")
					local arr "`arr' `v'"
				}
				local lab : label (`bv') `L'
				if `"`lab'"' == "`L'" local lab "`bd'`L'"   // no value label → fallback
				stat_arr "series.`nm'.`jkey'.`lab'" `arr'
				drop `sp'
			}
		}
	end
