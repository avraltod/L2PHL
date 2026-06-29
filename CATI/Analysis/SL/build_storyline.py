"""Assemble self-contained CATI storyline pages (topics + hub) from templates + JSON."""
import argparse, json, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from build_story import inject            # reuse the data-stat injector
from series import load_series
from topics_registry import TOPICS

CHARTJS = '<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.js"></script>'
FONT = ('<link rel="preconnect" href="https://fonts.googleapis.com">'
        '<link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;700;900'
        '&family=Source+Serif+4:opsz,wght@8..60,300;8..60,400;8..60,600'
        '&family=IBM+Plex+Mono:wght@400;500&display=swap" rel="stylesheet">')

def _read(p):
    with open(p, encoding="utf-8") as f: return f.read()

def _engine_inline():
    """storyline.js minus ESM import/export so it runs as a plain inline script."""
    js = _read(os.path.join(HERE,"storyline.js"))
    js = re.sub(r'^export\s+', '', js, flags=re.M)          # drop 'export'
    js = re.sub(r'^import\s+.*$', '', js, flags=re.M)        # drop any imports
    return "/* scrollytelling engine */\n" + js

def _topic_indicators(slug):
    t = next((x for x in TOPICS if x["slug"] == slug), None)
    return (t or {}).get("indicators") or []

def _series_for_topic(slug):
    """Embed only the series THIS topic uses (its registry indicator list)."""
    path = os.path.join(HERE,"sl_series.json")
    flat = json.load(open(path, encoding="utf-8"))
    inds = _topic_indicators(slug)
    keep = lambda k: k == "_meta" or any(k.startswith(f"series.{i}.") for i in inds)
    return {k:v for k,v in flat.items() if keep(k)}

# Prose binds to numbers DERIVED from the series (single source of truth). nn = the
# non-null endpoints, so R5-start indicators (mobile_money/bank_account) get r5/r8.
_DERIVE_MAP = {"food_insecurity": "food", "any_shock": "shock",
               "mobile_money": "mm", "bank_account": "bank"}
def _derive_pointstats(series_path, indicators):
    nested = load_series(series_path)                 # {'series': {...}, '_meta': ...}
    out = {}
    for ind in indicators:
        grp = _DERIVE_MAP.get(ind)
        if not grp:
            continue
        e = nested.get("series", {}).get(ind)
        if not e:
            continue
        nn = [x for x in (e.get("overall") or []) if x is not None]
        if not nn:
            continue
        out[grp] = {"r1": round(nn[0], 1), "r5": round(nn[0], 1),
                    "r8": round(nn[-1], 1), "drop": round(nn[0] - nn[-1], 1)}
    return out

def build_topic(slug, outdir, check=False):
    frag = _read(os.path.join(HERE,"topics",f"{slug}.html"))
    css  = _read(os.path.join(HERE,"storyline.css"))
    series = _series_for_topic(slug)
    bind = _derive_pointstats(os.path.join(HERE,"sl_series.json"), _topic_indicators(slug))
    if os.path.exists(os.path.join(HERE,"sl_stats.json")):
        bind.update(json.load(open(os.path.join(HERE,"sl_stats.json"), encoding="utf-8")))
    doc = f"""<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>L2Phl CATI Panel — {slug}</title>{FONT}{CHARTJS}
<style>{css}</style></head><body>
<main class="storywrap">{frag}</main>
<script id="sl-series" type="application/json">{json.dumps(series).replace('</','<\\/')}</script>
<script id="sl-data" type="application/json">{json.dumps(bind).replace('</','<\\/')}</script>
<script>{_engine_inline()}</script>
</body></html>"""
    built, _report = inject(doc, bind, "charts")
    out = os.path.join(outdir, f"l2p_cati_{slug}.html")
    if check:
        prev = _read(out) if os.path.exists(out) else ""
        if prev != built:
            print("CHECK FAILED: drift: rebuild needed"); return 1
        print("CHECK OK"); return 0
    os.makedirs(outdir, exist_ok=True)
    with open(out,"w",encoding="utf-8") as f: f.write(built)
    print(f"Built {out}"); return 0

def build_hub(outdir, check=False):
    css = _read(os.path.join(HERE,"storyline.css"))
    cards=[]
    for t in TOPICS:
        cls = "tcard" if t["live"] else "tcard soon"
        inner = (f'<div class="t">{t["title"]}</div>'
                 f'<div class="m" style="color:{t["accent"]}">{t["modules"]}</div>'
                 f'<div class="h">{t["headline"]}</div>')
        cards.append(f'<a class="{cls}" style="border-top-color:{t["accent"]}" '
                     f'href="l2p_cati_{t["slug"]}.html">{inner}</a>' if t["live"]
                     else f'<div class="{cls}" style="border-top-color:{t["accent"]}">{inner}</div>')
    doc = f"""<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>L2Phl CATI Panel — Storylines</title>{FONT}<style>{css}</style></head><body>
<div class="hero"><div class="kicker">Listening to the Philippines · CATI Panel · Rounds 1–8</div>
<h1>Recovery is measurable. Vulnerability is not gone.</h1>
<p>Across eight monthly rounds, food stress halved and shocks collapsed, yet savings, secure work, and confidence barely moved.</p>
<div class="chips"><span>2,470 households</span><span>Nov 2025 → Jun 2026</span><span>18 regions</span></div></div>
<div class="storywrap"><div class="hubgrid">{''.join(cards)}</div></div></body></html>"""
    out = os.path.join(outdir,"l2p_cati_hub.html")
    if check:
        prev = _read(out) if os.path.exists(out) else ""
        print("CHECK OK" if prev==doc else "CHECK FAILED: drift: rebuild needed")
        return 0 if prev==doc else 1
    os.makedirs(outdir, exist_ok=True)
    with open(out,"w",encoding="utf-8") as f: f.write(doc)
    print(f"Built {out}"); return 0

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--topic"); ap.add_argument("--hub", action="store_true")
    ap.add_argument("--outdir", default=os.path.join(HERE,"html"))
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    rc = 0
    if a.topic: rc |= build_topic(a.topic, a.outdir, a.check)
    if a.hub:   rc |= build_hub(a.outdir, a.check)
    if not a.topic and not a.hub:
        for t in TOPICS:
            if t["live"]: rc |= build_topic(t["slug"], a.outdir, a.check)
        rc |= build_hub(a.outdir, a.check)
    sys.exit(rc)

if __name__ == "__main__":
    main()
