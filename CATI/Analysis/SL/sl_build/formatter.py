# CATI/Analysis/SL/sl_build/formatter.py
"""Render a raw stat value as a display string per a data-fmt token."""

# Note: round() uses banker's rounding (round-half-to-even), so 40.5 -> 40.


def _comma(n):
    return f"{int(round(n)):,}"


def fmt(value, spec):
    if spec == "raw":
        return str(value)
    if spec == "int":
        return str(int(round(float(value))))
    if spec == "intcomma":
        return _comma(float(value))
    if spec == "pct0":
        return f"{int(round(float(value)))}%"
    if spec == "pct1":
        return f"{float(value):.1f}%"
    if spec == "millions1":
        return f"{float(value) / 1_000_000:.1f}M"
    if spec == "peso":
        return f"₱{_comma(float(value))}"
    if spec == "ppt":
        return str(int(round(float(value))))
    raise ValueError(f"unknown data-fmt: {spec!r}")
