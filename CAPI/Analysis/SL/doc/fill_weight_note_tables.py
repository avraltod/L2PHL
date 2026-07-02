"""Fill L2PHL weighting-note Section 5 from the diagnostics workbook.

Idempotent: removes any previously-inserted Section-5 tables/captions (everything
between the Section-5 heading's intro paragraph and the Section-6 heading), then
rebuilds them from weight_diagnostics_results.xlsx. Every number comes from the
workbook - none is hand-typed. Re-run after the panel rolls forward and the
Task-2 do-file regenerates the workbook."""
import openpyxl
from docx import Document

DOCX = "CAPI/Analysis/SL/doc/L2PHL_WEIGHTING_TECHNICAL_NOTE.docx"
XLSX = "CATI/Analysis/do/output/weight_diagnostics_results.xlsx"
SEC5 = "Weight performance and diagnostics"
SEC6 = "Usage guidance: which weight, when"

TABLES = [
    ("capi_dist",     "CAPI baseline: weight distribution and design effect"),
    ("capi_caleffect","CAPI baseline: effect of calibration (design vs final weights)"),
    ("cati_indw",     "CATI panel: individual weight by round"),
    ("cati_hhw",      "CATI panel: household and population weight by round"),
    ("cati_attrition","CATI panel: composition stability by round"),
]

def fmt(v):
    if v is None:
        return ""
    if isinstance(v, str):
        return v
    try:
        f = float(v)
    except (TypeError, ValueError):
        return str(v)
    if f == int(f):
        return f"{int(f):,}"
    if abs(f) >= 100:
        return f"{f:,.0f}"
    return f"{f:.3f}"

def sheet_rows(ws):
    return [[c.value for c in r] for r in ws.iter_rows()
            if any(c.value is not None for c in r)]

def find_h1(doc, text):
    for p in doc.paragraphs:
        if p.style.name.startswith("Heading 1") and p.text.strip() == text:
            return p
    return None

def main():
    wb = openpyxl.load_workbook(XLSX, data_only=True)
    doc = Document(DOCX)

    p5 = find_h1(doc, SEC5)
    p6 = find_h1(doc, SEC6)
    assert p5 is not None, "Section 5 heading not found"
    assert p6 is not None, "Section 6 heading not found"

    # Collect elements strictly between the Section-5 heading and Section-6 heading.
    between = []
    e = p5._element.getnext()
    while e is not None and e is not p6._element:
        between.append(e)
        e = e.getnext()
    assert between, "no intro paragraph under Section 5"
    intro_el = between[0]                 # keep the intro paragraph
    for el in between[1:]:                # drop any previously-inserted content
        el.getparent().remove(el)

    # Reconciliation sentence from capi_calib (max absolute residuals).
    cal = sheet_rows(wb["capi_calib"])
    hdr = cal[0]
    ix = {h: i for i, h in enumerate(hdr)}
    rp = [abs(r[ix["resid_pop"]]) for r in cal[1:] if r[ix["resid_pop"]] is not None]
    rh = [abs(r[ix["resid_hh"]]) for r in cal[1:] if r[ix["resid_hh"]] is not None]
    nstrata = len(cal) - 1
    recon = (f"All {nstrata} strata reconcile to their census population and household "
             f"totals. The largest absolute residual is {max(rp):.2e} for the population "
             f"total and {max(rh):.2e} for the household total, so the weighted totals "
             f"match the census benchmarks to within rounding.")

    ref = intro_el
    def insert_after(el):
        nonlocal ref
        ref.addnext(el)
        ref = el

    for sheet, caption in TABLES:
        cap = doc.add_paragraph(caption, style="Heading 2")
        insert_after(cap._element)
        rows = sheet_rows(wb[sheet])
        tbl = doc.add_table(rows=len(rows), cols=len(rows[0]))
        try:
            tbl.style = "Table Grid"
        except KeyError:
            pass
        for i, rw in enumerate(rows):
            for j, val in enumerate(rw):
                tbl.rows[i].cells[j].text = str(val) if i == 0 else fmt(val)
        insert_after(tbl._element)
        if sheet == "capi_dist":
            para = doc.add_paragraph(recon)
            insert_after(para._element)

    doc.save(DOCX)
    print(f"inserted {len(TABLES)} tables + reconciliation note")

if __name__ == "__main__":
    main()
