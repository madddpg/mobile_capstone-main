"use strict";

/**
 * Rating aggregation tests. Run with: node functions/test/shopRatings.test.js
 */

const assert = require("assert");
const { summarise } = require("../src/services/shopRatings");

let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    passed++;
    console.log("  ok   " + name);
  } catch (err) {
    failed++;
    console.log("  FAIL " + name);
    console.log("       " + err.message);
  }
}

console.log("\nsummarise — the average shown on a shop card");

test("averages whole scores", () => {
  assert.deepStrictEqual(summarise([5, 4, 3]), { rating: 4, ratingCount: 3 });
});

test("rounds to two decimals", () => {
  // 10/3 is 3.3333..., which must not be written to the document in full.
  assert.deepStrictEqual(summarise([4, 3, 3]), {
    rating: 3.33,
    ratingCount: 3,
  });
});

test("a single rating is that rating", () => {
  assert.deepStrictEqual(summarise([5]), { rating: 5, ratingCount: 1 });
});

test("no ratings leaves the shop unrated rather than at zero stars", () => {
  assert.deepStrictEqual(summarise([]), { rating: 0, ratingCount: 0 });
});

test("out-of-range values are dropped, not clamped", () => {
  // Clamping a stray 0 or 9 to the scale would quietly move a real score.
  // Only the two valid entries should count here.
  assert.deepStrictEqual(summarise([5, 0, 9, 3]), {
    rating: 4,
    ratingCount: 2,
  });
});

test("non-numeric entries are ignored", () => {
  assert.deepStrictEqual(summarise([4, null, undefined, NaN, "5", 2]), {
    rating: 3,
    ratingCount: 2,
  });
});

test("a set of only invalid values reads as unrated", () => {
  assert.deepStrictEqual(summarise([0, 7, null]), {
    rating: 0,
    ratingCount: 0,
  });
});

test("the boundaries one and five are both kept", () => {
  assert.deepStrictEqual(summarise([1, 5]), { rating: 3, ratingCount: 2 });
});

console.log(`\n${passed} passed, ${failed} failed\n`);
process.exit(failed === 0 ? 0 : 1);
