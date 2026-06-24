# CATI/Analysis/SL/sl_build/injector.py
"""Inject sl_stats values into the storyline HTML: the #sl-data chart block and
each data-stat span. Pure string mutation; returns (html, Report)."""
import json
import re
from dataclasses import dataclass, field

from .formatter import fmt
from .resolver import resolve, MissingKey


class InjectError(Exception):
    pass


@dataclass
class Report:
    used_stat_keys: set = field(default_factory=set)

# <span data-stat="KEY" data-fmt="FMT" ...> INNER </span>
_SPAN = re.compile(
    r'(<span\b[^>]*\bdata-stat="(?P<key>[^"]+)"[^>]*\bdata-fmt="(?P<fmt>[^"]+)"[^>]*>)'
    r'(?P<inner>.*?)(</span>)',
    re.DOTALL,
)
_SLDATA = re.compile(
    r'(<script id="sl-data" type="application/json">)(.*?)(</script>)',
    re.DOTALL,
)


def inject(html, data, chart_key):
    report = Report()

    chart_obj = data.get(chart_key, {})
    block = json.dumps(chart_obj, ensure_ascii=False)
    if not _SLDATA.search(html):
        raise InjectError('missing <script id="sl-data"> block')
    html = _SLDATA.sub(lambda m: m.group(1) + block + m.group(3), html, count=1)

    def _repl(m):
        key, spec = m.group("key"), m.group("fmt")
        try:
            value = resolve(data, key)
        except MissingKey:
            raise InjectError(f"data-stat key not in sl_stats.json: {key}")
        report.used_stat_keys.add(key)
        return m.group(1) + fmt(value, spec) + m.group(5)

    html = _SPAN.sub(_repl, html)
    return html, report
