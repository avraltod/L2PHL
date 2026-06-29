"""Insert/refresh QC data-quality badges in the storyline HTML (idempotent, drift-safe)."""
import re

_BADGE_RE = re.compile(r'<sup class="qc-caveat"[^>]*>.*?</sup>', re.DOTALL)
_SPAN_RE  = re.compile(r'<span\b[^>]*\bdata-stat="(?P<key>[^"]+)"[^>]*>.*?</span>', re.DOTALL)
_CSS = ('.qc-caveat{color:#c77d00;font-size:.7em;font-weight:700;cursor:help;'
        'margin-left:1px;text-decoration:none}')

def _esc(s):
    return (str(s) if s is not None else "").replace("&", "&amp;").replace('"', "&quot;") \
        .replace("<", "&lt;").replace(">", "&gt;")

def _strip_badges(html):
    return _BADGE_RE.sub("", html)

def apply_badges(html, caveats):
    """caveats: {stat_key: tooltip}. Idempotently (re)place a badge after each
    data-stat span whose key is a caveat. Returns the new html."""
    html = _strip_badges(html)
    added = [0]
    def add(m):
        span = m.group(0)
        tip = caveats.get(m.group("key"))
        if not tip:
            return span
        added[0] += 1
        return span + f'<sup class="qc-caveat" title="{_esc(tip)}">&#9888;</sup>'
    html = _SPAN_RE.sub(add, html)
    if added[0] and "qc-caveat{" not in html:
        html = html.replace("</style>", _CSS + "</style>", 1)
    return html
