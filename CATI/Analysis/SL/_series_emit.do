// =============================================================================
// Filename:      _series_emit.do
// Author:        Avralt-Od Purevjav
// Last Modified: Avraa
// Date:          2026-06-29
// =============================================================================
// Storyline series emitter — one indicator → an R1–R8 series (overall + by each
// requested breakdown), written into sl_series.json via the _stat_emit primitives.
// Per-round subpop means, so indicators present in only some rounds (e.g. f17/f18
// R5–R8) emit JSON null for the empty rounds. With group(<g>) it ALSO emits the
// prose point-stats (<g>.r1/r5/r8/drop/peak/q1_r8/q5_r8) as Stata scalars, so the
// HTML only ever DISPLAYS Stata-computed numbers (single source of truth).
// Requires _stat_emit.do included.

	version 18

	cap program drop series_emit
	program define series_emit
		* series_emit <name> <indicator>, round(rvar) [label() unit() group(g) ///
		*             quintile(qvar) region(rgvar) urbrur(uvar) scale(real 100)]
		syntax namelist(min=2 max=2) [, Label(string) Unit(string) Group(string) ///
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
		local first .
		local last .
		local r5val .
		local pk .
		foreach r of local RDS {
			qui count if `round'==`r' & !missing(`ind')
			if r(N) < `mincell' {
				local ov "`ov' null"
			}
			else {
				cap drop `sp'
				qui gen byte `sp' = (`round'==`r')
				qui svy, subpop(`sp'): mean `ind'
				local m = _b[`ind']*`scale'
				local v = string(`m', "%9.1f")
				local ov "`ov' `v'"
				if `first'==. local first = `m'
				local last = `m'
				if `r'==5 local r5val = `m'
				if `pk'==. | `m'>`pk' local pk = `m'
			}
		}
		stat_arr "series.`nm'.overall" `ov'

		* --- breakdowns: per (round × level) subpop mean ---
		local q1last .
		local q5last .
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
						local m = _b[`ind']*`scale'
						local v = string(`m', "%9.1f")
						local arr "`arr' `v'"
						if "`bd'"=="quintile" & strpos(lower(`"`lab'"'),"poorest") local q1last = `m'
						if "`bd'"=="quintile" & strpos(lower(`"`lab'"'),"richest") local q5last = `m'
					}
				}
				stat_arr "series.`nm'.`jkey'.`lab'" `arr'
			}
		}

		* --- prose point-stats (Stata-computed scalars; full precision, formatter rounds) ---
		if "`group'" != "" {
			stat_put "`group'.r1"   = `first'
			stat_put "`group'.r5"   = cond(`r5val'<., `r5val', `first')
			stat_put "`group'.r8"   = `last'
			stat_put "`group'.drop" = `first' - `last'
			stat_put "`group'.peak" = `pk'
			if `q1last' < . stat_put "`group'.q1_r8" = `q1last'
			if `q5last' < . stat_put "`group'.q5_r8" = `q5last'
		}
	end
