"""Parse a `| ID | Label | Value |` markdown table into {ID: value}."""


def _num(s):
    try:
        f = float(s.replace(",", ""))
    except ValueError:
        return s
    return int(f) if f.is_integer() else f


def parse_md(text):
    out = {}
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if len(cells) < 3:
            continue                                # not a data row
        # First cell = ID, last = Value. The label (middle) may itself contain a
        # '|' (e.g. "broad (a1|a2) rate"); values are numeric, so first/last is robust.
        key, val = cells[0], cells[-1]
        if key == "ID" or set(key) <= set(":-"):    # header row or |:---| separator
            continue
        if key in out:
            raise ValueError(f"md_parser: duplicate ID {key!r}")
        out[key] = _num(val)
    return out
