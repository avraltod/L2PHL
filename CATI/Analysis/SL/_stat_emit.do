* CATI/Analysis/SL/_stat_emit.do
* Accumulate stats and write nested JSON. Keys are dotted paths.
* Usage: stat_open "path.json" ; stat_put "a.b" = expr ; stat_arr "k" v1 v2 ;
*        stat_obj "k" lab1 v1 lab2 v2 ; stat_close
cap program drop stat_open
program define stat_open
    global _SE_PATH `"`1'"'
    global _SE_BODY ""
    global _SE_KEYS ""
end

cap program drop _se_guard
program define _se_guard          /* fail on duplicate key */
    args key
    if strpos(" $_SE_KEYS ", " `key' ") {
        di as error "stat_emit: duplicate key `key'"
        exit 459
    }
    global _SE_KEYS "$_SE_KEYS `key'"
end

cap program drop _se_append
program define _se_append
    args frag
    if "$_SE_BODY" == "" global _SE_BODY `"`frag'"'
    else global _SE_BODY `"$_SE_BODY,`frag'"'
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
    _se_append `"\"`key'\":`val'"'
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
    _se_append `"\"`key'\":[`arr']"'
end

cap program drop stat_obj
program define stat_obj
    gettoken key 0 : 0
    local obj ""
    while "`0'" != "" {
        gettoken lab 0 : 0
        gettoken val 0 : 0
        local pair `"\"`lab'\":`val'"'
        if "`obj'" == "" local obj `"`pair'"'
        else local obj `"`obj',`pair'"'
    }
    _se_guard "`key'"
    _se_append `"\"`key'\":{`obj'}"'
end

* Nesting dotted keys purely in Stata is verbose, so write a FLAT JSON object
* keyed by the dotted strings; build_story.py un-flattens on load (Task 9).
cap program drop stat_close
program define stat_close
    tempname fh
    file open `fh' using "$_SE_PATH", write replace text
    file write `fh' "{$_SE_BODY}" _n
    file close `fh'
    di as result "stat_emit: wrote $_SE_PATH"
end
