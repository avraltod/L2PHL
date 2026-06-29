import assert from "node:assert";
import { availableBreakdowns, seriesFor, clampRound, sliceTo, PALETTE, parseSeries } from "../storyline.js";

// parseSeries must rebuild nested breakdowns from the flat dotted keys, including
// 4-part keys whose level label contains spaces/parens (e.g. "Q1 (poorest)").
const flat = {
  "_meta": {},
  "series.food.rounds": [1,2,3,4,5,6,7,8],
  "series.food.overall": [41,31,26.8,21.5,19,22.8,20.5,21],
  "series.food.by_quintile.Q1 (poorest)": [55.9,50,45,40,38,40,30,26.5],
  "series.food.by_quintile.Q5 (richest)": [28.5,22,18,16,15,18,16,17.4],
  "series.food.by_region.NCR": [31,25,20,18,16,18,17,16.9],
};
const P = parseSeries(flat);
assert.deepStrictEqual(Object.keys(P), ["food"]);
assert.deepStrictEqual(Object.keys(P.food.by_quintile), ["Q1 (poorest)","Q5 (richest)"]);   // both levels kept, not collapsed
assert.strictEqual(P.food.by_quintile["Q1 (poorest)"][0], 55.9);
assert.deepStrictEqual(availableBreakdowns(P.food), ["overall","quintile","region"]);

const entry = {
  rounds:[1,2,3,4,5,6,7,8], overall:[41,31,26.8,21.5,18.2,17,16.4,18],
  by_quintile:{Poorest:[60,55,50,46,44,43,42,45], Richest:[20,15,12,10,9,8,8,9]},
  by_region:{NCR:[30,25,20,18,16,15,15,16]}
};

assert.deepStrictEqual(availableBreakdowns(entry), ["overall","quintile","region"]);
assert.deepStrictEqual(seriesFor(entry,"overall"), {Overall:[41,31,26.8,21.5,18.2,17,16.4,18]});
assert.deepStrictEqual(Object.keys(seriesFor(entry,"quintile")), ["Poorest","Richest"]);
assert.strictEqual(clampRound(99,8),8);
assert.strictEqual(clampRound(0,8),1);
assert.deepStrictEqual(sliceTo([1,2,3,4,5,6,7,8],4),[1,2,3,4]);
assert.ok(Array.isArray(PALETTE) && PALETTE.length>=5);
console.log("storyline engine: OK");
