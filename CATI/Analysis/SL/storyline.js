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
  const flat=JSON.parse(seriesEl.textContent);
  const SERIES={}; for(const k in flat){ if(k.startsWith("series.")){ const [, name, leaf]=k.split("."); (SERIES[name]=SERIES[name]||{})[leaf]=flat[k]; } }
  const card=document.getElementById("sl-chart"); if(!card) return;
  const ctx=card.querySelector("canvas"); const title=card.querySelector("h3");
  const chips=card.querySelector(".chips-bd"); const scrub=card.querySelector('input[type=range]');
  let state={indicator:null, breakdown:"overall", maxRound:8};
  let chart=null;
  function render(){
    const e=SERIES[state.indicator]; if(!e) return;
    title.textContent=e.label||state.indicator;
    state.maxRound=clampRound(state.maxRound, e.rounds.length);
    const labels=sliceTo(e.rounds.map(r=>"R"+r), state.maxRound);
    const datasets=buildDatasets(e, state.breakdown, state.maxRound);
    if(chart) chart.destroy();
    chart=new Chart(ctx,{type:"line",data:{labels,datasets},
      options:{responsive:true,maintainAspectRatio:false,
        scales:{x:{grid:{display:false}},y:{beginAtZero:true,ticks:{callback:v=>v+"%"}}},
        plugins:{legend:{display:datasets.length>1,position:"bottom",labels:{boxWidth:10,font:{size:10}}},
                 tooltip:{callbacks:{label:c=>`${c.dataset.label} · R${c.dataIndex+1}: ${c.parsed.y}%`}}}}});
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
  document.querySelectorAll("[data-indicator]").forEach(b=>io.observe(b));
  const first=document.querySelector("[data-indicator]"); if(first){ const b=first.dataset;
    state.indicator=b.indicator; state.breakdown=b.breakdown||"overall"; state.maxRound=+(b.round||8); render(); }
  // baseline-style scroll reveal: .rev -> .vis (the baseline's CSS sets .rev{opacity:0})
  const revObs=new IntersectionObserver(es=>es.forEach(e=>{ if(e.isIntersecting){
    e.target.classList.add("vis"); revObs.unobserve(e.target); }}),{threshold:.15});
  document.querySelectorAll(".rev").forEach(el=>revObs.observe(el));
}
if(isBrowser()) window.addEventListener("DOMContentLoaded", initStoryline);
