import assert from "node:assert";
import { availableBreakdowns, seriesFor, clampRound, sliceTo, PALETTE } from "../storyline.js";

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
