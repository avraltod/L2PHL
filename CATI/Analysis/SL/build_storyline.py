"""Assemble the single-file, tabbed CATI panel story (l2phl_cati_story.html) — a
sibling of the CAPI baseline story: sticky masthead nav, hero cover, one chapter
per live topic (each with its own interactive R1-R8 breakdown chart), epilogue."""
import argparse, json, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from build_story import inject            # reuse the data-stat injector
from series import load_series
from topics_registry import TOPICS

OUTNAME = "l2phl_cati_story.html"
CHARTJS = '<script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.js"></script>'
FONT = ('<link rel="preconnect" href="https://fonts.googleapis.com">'
        '<link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;700;900'
        '&family=Source+Serif+4:opsz,wght@8..60,300;8..60,400;8..60,600'
        '&family=IBM+Plex+Mono:wght@400;500&display=swap" rel="stylesheet">')

PH_FLAG = ('<svg viewBox="0 0 900 450" width="38" height="19" role="img" aria-label="Philippines" '
           'style="flex-shrink:0;border-radius:2px;box-shadow:0 0 0 1px rgba(255,255,255,.2)">'
           '<rect width="900" height="225" fill="#0038A8"/><rect y="225" width="900" height="225" fill="#CE1126"/>'
           '<polygon points="0,0 433,225 0,450" fill="#FFF"/>'
           '<circle cx="120" cy="225" r="32" fill="none" stroke="#FCD116" stroke-width="7"/></svg>')

HERO = """<section class="hero">
  <div class="hero-inner">
    <div>
      <p class="hero-eye">Philippines 2025–2026</p>
      <div style="font-family:var(--mono);font-size:12px;letter-spacing:.12em;text-transform:uppercase;color:#FFFFFF;margin-bottom:18px;border:1px solid rgba(255,255,255,.7);display:inline-block;padding:6px 16px;border-radius:4px;background:rgba(0,159,218,.25);font-weight:600;">L2Phl Monthly Phone Survey · Nov 2025 – Jun 2026</div>
      <h1 class="hero-hed">Listening to the Philippines:<br><em>Monthly Phone Survey</em></h1>
      <p class="hero-deck">An eight-round phone panel that follows the baseline households month by month, tracking food security, shocks, finance, and how Filipino households are faring through 2025 and 2026.</p>
      <p class="hero-src">Listening to the Philippines (L2Phl) · CATI Panel · Rounds 1–8</p>
    </div>
    <div class="hero-kpis">
      <div class="hkpi r"><div class="hkpi-n">2,470</div><div class="hkpi-l">Households tracked</div></div>
      <div class="hkpi b"><div class="hkpi-n">8</div><div class="hkpi-l">Monthly rounds</div></div>
      <div class="hkpi g"><div class="hkpi-n">18</div><div class="hkpi-l">Regions</div></div>
    </div>
  </div>
  <div class="scroll-hint">scroll to explore</div>
</section>"""

EPILOGUE = """<section class="epi">
  <h2 class="epi-hed">"Recovery is measurable. Vulnerability is not gone."</h2>
  <p class="epi-body">Across eight monthly rounds, food stress halved and shocks collapsed, yet the gains were uneven and, by Round 8, fragile. Mobile money reached half of households while formal banking lagged. The phone panel shows a recovery that is real, unequal, and unfinished.</p>
  <div class="epi-nums">
    <div class="epi-n"><div class="epi-n-val" style="color:var(--green);">41→21%</div><div class="epi-n-lbl">Food insecurity R1→R8</div></div>
    <div class="epi-n"><div class="epi-n-val" style="color:#40B4E5;">2,470</div><div class="epi-n-lbl">Households</div></div>
    <div class="epi-n"><div class="epi-n-val" style="color:var(--gold);">8</div><div class="epi-n-lbl">Monthly rounds</div></div>
    <div class="epi-n"><div class="epi-n-val" style="color:#009FDA;">55%</div><div class="epi-n-lbl">Mobile money R8</div></div>
  </div>
  <p class="epi-meta">L2Phl · Listening to the Philippines · CATI Monthly Phone Survey · Nov 2025 – Jun 2026</p>
</section>"""

def _read(p):
    with open(p, encoding="utf-8") as f: return f.read()

def _engine_inline():
    js = _read(os.path.join(HERE,"storyline.js"))
    js = re.sub(r'^export\s+', '', js, flags=re.M)
    js = re.sub(r'^import\s+.*$', '', js, flags=re.M)
    return "/* scrollytelling engine */\n" + js

# Prose binds to numbers DERIVED from the series. nn = non-null endpoints, so
# R5-start indicators (mobile_money/bank_account) get r5/r8.
_DERIVE_MAP = {"food_insecurity": "food", "any_shock": "shock",
               "mobile_money": "mm", "bank_account": "bank", "no_contract": "work",
               "me_concern": "mec", "me_impact": "mei",
               "life_satisfaction": "sat", "worse_off": "worse",
               "got_remit": "remit", "oop": "oop"}
def _derive_pointstats(series_path, indicators):
    nested = load_series(series_path)
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
                    "r8": round(nn[-1], 1), "drop": round(nn[0] - nn[-1], 1),
                    "peak": round(max(nn), 1)}
        # poorest/richest quintile endpoints (last non-null), for the equity synthesis
        bq = e.get("by_quintile") or {}
        lo = next((v for k, v in bq.items() if "poorest" in k.lower()), None)
        hi = next((v for k, v in bq.items() if "richest" in k.lower()), None)
        lonn = [x for x in (lo or []) if x is not None]
        hinn = [x for x in (hi or []) if x is not None]
        if lonn: out[grp]["q1_r8"] = round(lonn[-1], 1)
        if hinn: out[grp]["q5_r8"] = round(hinn[-1], 1)
    return out

def _series_for_story(indicators):
    """Embed only the live topics' indicator series."""
    flat = json.load(open(os.path.join(HERE,"sl_series.json"), encoding="utf-8"))
    keep = lambda k: k == "_meta" or any(k.startswith(f"series.{i}.") for i in indicators)
    return {k:v for k,v in flat.items() if keep(k)}

def _masthead(topics):
    tabs = []
    for t in topics:
        if t["live"]:
            tabs.append(f'<a href="#ch-{t["slug"]}">{t["nav"]}</a>')
        else:
            tabs.append(f'<span class="soon">{t["nav"]}</span>')
    return (f'<header class="mast"><div><div class="mast-logo" style="display:flex;align-items:center;gap:14px;">'
            f'{PH_FLAG}<span>Listening to the Philippines</span></div></div>'
            f'<nav class="mast-nav">{"".join(tabs)}</nav></header>')

def build_story(outdir, check=False):
    css  = _read(os.path.join(HERE,"storyline.css"))
    live = [t for t in TOPICS if t["live"]]
    all_inds = [i for t in live for i in t.get("indicators", [])]
    series = _series_for_story(all_inds)
    bind = _derive_pointstats(os.path.join(HERE,"sl_series.json"), all_inds)
    stats_path = os.path.join(HERE,"sl_stats.json")
    if os.path.exists(stats_path):
        bind.update(json.load(open(stats_path, encoding="utf-8")))
    chapters = []
    for i, t in enumerate(live, 1):
        frag = _read(os.path.join(HERE,"topics",f"{t['slug']}.html"))
        chapters.append(
            f'<div class="chap" id="ch-{t["slug"]}"><span class="chap-n">{i:02d}</span>'
            f'<span class="chap-r"></span><span class="chap-l">{t["title"]}</span></div>\n'
            f'<div data-chapter="{t["slug"]}">{frag}</div>')
    doc = f"""<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Listening to the Philippines — Monthly Phone Survey (CATI Panel R1–R8)</title>{FONT}{CHARTJS}
<style>{css}
.mast-nav .soon{{font-family:var(--mono);font-size:11px;letter-spacing:.1em;text-transform:uppercase;color:rgba(255,255,255,.32);padding:4px 10px;border:1px solid rgba(255,255,255,.13);border-radius:2px;}}
</style></head><body>
{_masthead(TOPICS)}
{HERO}
{''.join(chapters)}
{EPILOGUE}
<script id="sl-series" type="application/json">{json.dumps(series).replace('</','<\\/')}</script>
<script id="sl-data" type="application/json">{json.dumps(bind).replace('</','<\\/')}</script>
<script>{_engine_inline()}</script>
</body></html>"""
    built, _report = inject(doc, bind, "charts")
    out = os.path.join(outdir, OUTNAME)
    if check:
        prev = _read(out) if os.path.exists(out) else ""
        if prev != built:
            print("CHECK FAILED: drift: rebuild needed"); return 1
        print("CHECK OK"); return 0
    os.makedirs(outdir, exist_ok=True)
    with open(out, "w", encoding="utf-8") as f: f.write(built)
    print(f"Built {out}"); return 0

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--outdir", default=os.path.join(HERE,"html"))
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    sys.exit(build_story(a.outdir, a.check))

if __name__ == "__main__":
    main()
