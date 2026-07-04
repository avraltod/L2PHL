"""Generate rows-only LaTeX table fragments for the weighting note from the
Stata diagnostics workbook (UKR/FIES house practice: esttab-style fragments
\\input into threeparttable floats defined in the main .tex).

Every number comes from weight_diagnostics_results.xlsx - none hand-typed.
Re-run after the diagnostics do-file regenerates the workbook.
"""
import openpyxl, os

XLSX = "CATI/Analysis/do/output/weight_diagnostics_results.xlsx"
OUT  = "CAPI/Analysis/SL/tex/tab"

# sheets rendered as data-row fragments (header/rules live in main.tex)
SHEETS = ["capi_dist", "capi_caleffect", "cati_indw", "cati_hhw",
          "cati_attrition", "attr_retention", "attr_bias"]

DROP_ROWS = {"attr_bias": {"employed"}}
P_COLS_BY_SHEET = {"attr_bias": {6}}   # 0-based col index of p_value in attr_bias

# pretty labels for the attr_bias first column and test column
CHAR = {"urban": "urban", "head_female": "female-headed",
        "fies_modsev": "food insecure (mod.+sev.)", "hhsize": "household size",
        "inc_quintile": "income quintile",
        "region(via stratum)": "geography (stratum)",
        "OVERALL": r"\textit{overall}"}
TEST = {"chi2": r"$\chi^2$", "ttest": r"$t$"}


def esc(s):
    return (str(s).replace("\\", r"\textbackslash{}")
            .replace("&", r"\&").replace("%", r"\%").replace("_", r"\_")
            .replace("#", r"\#"))


def fmt_num(v, three_dp=False):
    f = float(v)
    if three_dp:
        return f"{f:.3f}"
    if f == int(f):
        return f"{int(f):,}"
    if abs(f) >= 1000:
        return f"{f:,.0f}"
    if abs(f) >= 100:
        return f"{f:,.1f}"
    return f"{f:.2f}"


def cell(sheet, ci, val):
    if val is None:
        return ""
    if isinstance(val, str):
        if sheet == "attr_bias" and ci == 0 and val in CHAR:
            return CHAR[val]
        if sheet == "attr_bias" and val in TEST:
            return TEST[val]
        if val.strip() in ("39 strata",):   # geography stayer/attriter cells
            return "--"
        return esc(val)
    three = ci in P_COLS_BY_SHEET.get(sheet, set())
    return fmt_num(val, three_dp=three)


def rows(ws):
    return [[c.value for c in r] for r in ws.iter_rows()
            if any(c.value is not None for c in r)]


def main():
    wb = openpyxl.load_workbook(XLSX, data_only=True)
    os.makedirs(OUT, exist_ok=True)
    for sheet in SHEETS:
        data = rows(wb[sheet])[1:]          # drop header row (header is in main.tex)
        drop = DROP_ROWS.get(sheet, set())
        data = [r for r in data if str(r[0]) not in drop]
        rowstrs = [" & ".join(cell(sheet, j, v) for j, v in enumerate(r))
                   for r in data]
        with open(os.path.join(OUT, f"{sheet}.tex"), "w") as fh:
            # Rows joined by ' \\'; the LAST row is left bare (no trailing \\).
            # main.tex adds the closing \\ before \bottomrule - the UKR/FIES
            # esttab pattern that avoids a "Misplaced \noalign" at the file
            # boundary.
            fh.write(" \\\\\n".join(rowstrs) + "\n")
        print(f"wrote tab/{sheet}.tex  ({len(data)} rows)")


if __name__ == "__main__":
    main()
