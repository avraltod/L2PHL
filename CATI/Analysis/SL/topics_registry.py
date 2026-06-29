"""The 9 storyline themes (single-file tabbed story). 'nav' = short masthead-tab
label; 'indicators' = the series each live topic embeds; 'live' topics become
chapters, pending ones show as disabled tabs."""
TOPICS = [
  {"slug":"recovery","nav":"Recovery","title":"Recovery is measurable","modules":"Food · Shocks",
   "headline":"Food stress 41% → 21%","accent":"#00A651","live":True,
   "indicators":["food_insecurity","any_shock"]},
  {"slug":"vulnerability","nav":"Vulnerability","title":"Vulnerability hasn't moved","modules":"Finance · Employment · Shocks",
   "headline":"~2% can cover an emergency","accent":"#CE1126","live":False,"indicators":[]},
  {"slug":"digital","nav":"Digital","title":"The digital shift","modules":"Finance",
   "headline":"Mobile money → 55%","accent":"#009FDA","live":True,
   "indicators":["mobile_money","bank_account"]},
  {"slug":"work","nav":"Work","title":"Work without security","modules":"Employment",
   "headline":"~80% have no contract","accent":"#002244","live":True,"indicators":["no_contract"]},
  {"slug":"lifelines","nav":"Lifelines","title":"Lifelines","modules":"Migration · Finance",
   "headline":"24% got a Dec remittance","accent":"#FCD116","live":False,"indicators":[]},
  {"slug":"mideast","nav":"Middle East","title":"The Middle East crisis","modules":"Views",
   "headline":"~92% concerned (R6–R8)","accent":"#CE1126","live":True,"indicators":["me_concern","me_impact"]},
  {"slug":"uneven","nav":"Uneven","title":"Uneven recovery","modules":"ALL · by income & region",
   "headline":"The equity lens","accent":"#009FDA","live":False,"indicators":[]},
  {"slug":"health","nav":"Health","title":"Health under pressure","modules":"Health · Shocks",
   "headline":"Coverage & out-of-pocket","accent":"#002244","live":False,"indicators":[]},
  {"slug":"mood","nav":"Mood","title":"The national mood","modules":"Views",
   "headline":"Satisfaction 2.85/5 · AI worry","accent":"#FCD116","live":False,"indicators":[]},
]
