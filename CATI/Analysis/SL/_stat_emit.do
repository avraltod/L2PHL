* CATI/Analysis/SL/_stat_emit.do
* Accumulate stats and write a FLAT JSON object keyed by dotted paths.
* build_story.py un-flattens dotted keys into nested form on load.
*
* Usage:
*   stat_open "path.json"
*   stat_put  "fies.mod_sev_r1" = r(mean)
*   stat_arr  "charts.food_trend"  41 31 26.8 21.5 18.2
*   stat_obj  "charts.sev_macro"   NCR 66.3  Luzon 60.0
*   stat_close
*
* JSON quoting: Stata has no \" string escape, so real double-quotes come from
* char(34) ($SE_q), and every fragment that carries a quote is built and written
* with compound double-quotes  `"..."'  (including the final file write).

cap program drop stat_open
program define stat_open
    global SE_PATH `"`1'"'
    global SE_BODY ""
    global SE_KEYS ""
    global SE_q = char(34)
end

cap program drop _se_guard          /* fail on duplicate key */
program define _se_guard
    args key
    if strpos(" $SE_KEYS ", " `key' ") {
        di as error "stat_emit: duplicate key `key'"
        exit 459
    }
    global SE_KEYS "$SE_KEYS `key'"
end

cap program drop _se_append
program define _se_append
    args frag
    if `"$SE_BODY"' == "" global SE_BODY `"`frag'"'
    else global SE_BODY `"$SE_BODY,`frag'"'
end

cap program drop stat_put
program define stat_put
    * syntax: stat_put "key" = expr
    gettoken key 0 : 0
    gettoken eq  0 : 0           /* the '=' */
    local val = `0'
    if "`val'" == "." {
        di as error "stat_emit: missing value for `key'"
        exit 459
    }
    _se_guard "`key'"
    _se_append `"${SE_q}`key'${SE_q}:`val'"'
end

cap program drop stat_arr
program define stat_arr
    gettoken key 0 : 0
    local arr ""
    foreach v of local 0 {
        if "`arr'" == "" local arr "`v'"
        else local arr "`arr',`v'"
    }
    _se_guard "`key'"
    _se_append `"${SE_q}`key'${SE_q}:[`arr']"'
end

cap program drop stat_obj
program define stat_obj
    gettoken key 0 : 0
    local obj ""
    while `"`0'"' != "" {
        gettoken lab 0 : 0
        gettoken val 0 : 0
        local pair `"${SE_q}`lab'${SE_q}:`val'"'
        if `"`obj'"' == "" local obj `"`pair'"'
        else local obj `"`obj',`pair'"'
    }
    _se_guard "`key'"
    _se_append `"${SE_q}`key'${SE_q}:{`obj'}"'
end

cap program drop stat_close
program define stat_close
    tempname fh
    file open `fh' using `"$SE_PATH"', write replace text
    file write `fh' `"{$SE_BODY}"' _n
    file close `fh'
    di as result "stat_emit: wrote $SE_PATH"
end
