# CATI/Analysis/SL/sl_build/injector.py
"""Inject sl_stats values into the storyline HTML: the #sl-data chart block and
each data-stat span. Pure string mutation; returns (html, Report).

Fail-loud is the contract — this powers a verification gate. A data-stat span
that cannot be bound must ERROR, never be silently skipped."""
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

# A full, well-formed span carrying data-stat (attribute order-independent).
_SPAN = re.compile(r'<span\b(?P<attrs>[^>]*\bdata-stat="[^"]+"[^>]*)>(?P<inner>.*?)</span>',
                   re.DOTALL)
# Any opening span that declares data-stat (to count and catch unbound ones).
_HAS_STAT = re.compile(r'<span\b[^>]*\bdata-stat="')
_SLDATA = re.compile(
    r'(<script id="sl-data" type="application/json">)(.*?)(</script>)',
    re.DOTALL,
)


def _attr(name, attrs):
    m = re.search(rf'\b{name}="([^"]+)"', attrs)
    return m.group(1) if m else None


def inject(html, data, chart_key):
    report = Report()

    if chart_key not in data:
        raise InjectError(f"chart-key not in sl_stats.json: {chart_key}")
    if not _SLDATA.search(html):
        raise InjectError('missing <script id="sl-data"> block')
    # Escape "</" so a chart string containing </script> can't close the block.
    block = json.dumps(data[chart_key], ensure_ascii=False).replace("</", "<\\/")
    html = _SLDATA.sub(lambda m: m.group(1) + block + m.group(3), html, count=1)

    matched = [0]

    def _repl(m):
        attrs = m.group("attrs")
        key = _attr("data-stat", attrs)
        spec = _attr("data-fmt", attrs)
        if spec is None:
            raise InjectError(f"data-stat span missing data-fmt: {key}")
        try:
            value = resolve(data, key)
        except MissingKey:
            raise InjectError(f"data-stat key not in sl_stats.json: {key}")
        try:
            shown = fmt(value, spec)
        except (ValueError, TypeError) as e:
            raise InjectError(f"cannot format {key} as {spec}: {e}")
        report.used_stat_keys.add(key)
        matched[0] += 1
        return f"<span{attrs}>{shown}</span>"

    html = _SPAN.sub(_repl, html)

    # Sweep: every data-stat span must have bound. A leftover (malformed tag,
    # nested span, unbalanced </span>) means a number would silently go stale.
    total = len(_HAS_STAT.findall(html))
    if total != matched[0]:
        raise InjectError(
            f"{total - matched[0]} data-stat span(s) did not bind "
            "(malformed tag, missing </span>, or nested span)")
    return html, report
