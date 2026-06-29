// CATI/Analysis/SL/storyline.js — shared scrollytelling + interactive-chart engine.
// Pure helpers are ESM-exported for tests; DOM wiring runs only in a browser.
export const PALETTE = ["#002244","#009FDA","#00A651","#CE1126","#FCD116","#40B4E5","#7E57C2"];
const BD_LABEL = {quintile:"Income quintile", region:"Region", urbrur:"Urban/rural", sexage:"Sex/age"};

export function availableBreakdowns(entry){
  const out=["overall"];
  for(const k of Object.keys(entry)) if(k.startsWith("by_")) out.push(k.slice(3));
  return out;
}
export function seriesFor(entry, breakdown){
  if(breakdown==="overall") return {Overall: entry.overall};
  return entry["by_"+breakdown] || {Overall: entry.overall};
}
export function clampRound(r,n){ return Math.max(1, Math.min(r,n)); }
export function sliceTo(arr,maxRound){ return arr.slice(0, maxRound); }
// Reconstruct nested per-indicator series from the flat dotted #sl-series JSON.
// Keys: series.<name>.{rounds|overall|label|unit} (3 parts) or
//       series.<name>.by_<bd>.<level> (4+ parts; level may contain spaces/parens).
export function parseSeries(flat){
  const S={};
  for(const k in flat){
    if(!k.startsWith("series.")) continue;
    const p=k.split(".");
    const name=p[1]; S[name]=S[name]||{};
    if(p.length===3){ S[name][p[2]]=flat[k]; }
    else { const leaf=p[2], level=p.slice(3).join("."); (S[name][leaf]=S[name][leaf]||{})[level]=flat[k]; }
  }
  return S;
}

// ---- DOM wiring (browser only) ----
function isBrowser(){ return typeof document!=="undefined" && typeof window!=="undefined"; }
function buildDatasets(entry, breakdown, maxRound){
  const groups = seriesFor(entry, breakdown);
  return Object.entries(groups).map(([name,arr],i)=>({
    label:name, data:sliceTo(arr,maxRound), borderColor:PALETTE[i%PALETTE.length],
    backgroundColor:"transparent", borderWidth:2.5, tension:.25, pointRadius:2
  }));
}
function initStoryline(){
  if(!isBrowser()) return;
  const seriesEl=document.getElementById("sl-series");
  if(!seriesEl) return;
  const SERIES=parseSeries(JSON.parse(seriesEl.textContent));
  // One interactive chart per chapter (each .sl-chart cbox), scoped to that
  // chapter's beats so multiple charts coexist in the single-file story.
  document.querySelectorAll(".sl-chart").forEach(card => initChart(card, SERIES));
  // baseline-style scroll reveal: .rev -> .vis (the baseline's CSS sets .rev{opacity:0})
  const revObs=new IntersectionObserver(es=>es.forEach(e=>{ if(e.isIntersecting){
    e.target.classList.add("vis"); revObs.unobserve(e.target); }}),{threshold:.15});
  document.querySelectorAll(".rev").forEach(el=>revObs.observe(el));
}
function initChart(card, SERIES){
  const ctx=card.querySelector("canvas"); if(!ctx) return;
  const title=card.querySelector("h3");
  const chips=card.querySelector(".chips-bd");
  const scrub=card.querySelector('input[type=range]');
  const scope=card.closest("[data-chapter]") || document;   // beats belonging to THIS chapter only
  let state={indicator:null, breakdown:"overall", maxRound:8};
  let chart=null;
  function render(){
    const e=SERIES[state.indicator]; if(!e) return;
    if(title) title.textContent=e.label||state.indicator;
    state.maxRound=clampRound(state.maxRound, e.rounds.length);
    const labels=sliceTo(e.rounds.map(r=>"R"+r), state.maxRound);
    const datasets=buildDatasets(e, state.breakdown, state.maxRound);
    // format by the indicator's unit: "pct" -> "%" (0-based); anything else -> a /5 score axis
    const unit=(e.unit||"pct"), suf=(unit==="pct"?"%":""), ymax=(unit==="pct"?undefined:5);
    if(chart) chart.destroy();
    chart=new Chart(ctx,{type:"line",data:{labels,datasets},
      options:{responsive:true,maintainAspectRatio:false,
        scales:{x:{grid:{display:false}},y:{beginAtZero:true,max:ymax,ticks:{callback:v=>v+suf}}},
        plugins:{legend:{display:datasets.length>1,position:"bottom",labels:{boxWidth:10,font:{size:10}}},
                 tooltip:{callbacks:{label:c=>`${c.dataset.label} · R${c.dataIndex+1}: ${c.parsed.y}${suf}`}}}}});
    if(chips){ const avail=availableBreakdowns(e);
      chips.querySelectorAll(".chip").forEach(ch=>{
        const bd=ch.dataset.bd; ch.disabled=!avail.includes(bd); ch.classList.toggle("on",bd===state.breakdown);});
    }
  }
  if(chips) chips.addEventListener("click",ev=>{ const ch=ev.target.closest(".chip"); if(!ch||ch.disabled) return;
    state.breakdown=ch.dataset.bd; render(); });
  if(scrub) scrub.addEventListener("input",()=>{ state.maxRound=+scrub.value; render(); });
  const io=new IntersectionObserver(es=>es.forEach(e=>{ if(e.isIntersecting){
    const b=e.target.dataset; if(b.indicator) state.indicator=b.indicator;
    if(b.breakdown) state.breakdown=b.breakdown; if(b.round) state.maxRound=+b.round; render(); }}),{threshold:.55});
  scope.querySelectorAll("[data-indicator]").forEach(b=>io.observe(b));
  const first=scope.querySelector("[data-indicator]"); if(first){ const b=first.dataset;
    state.indicator=b.indicator; state.breakdown=b.breakdown||"overall"; state.maxRound=+(b.round||8); render(); }
}
if(isBrowser()) window.addEventListener("DOMContentLoaded", initStoryline);
