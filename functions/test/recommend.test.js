"use strict";

/**
 * Recommend-mode tests.
 * Run with: node functions/test/recommend.test.js
 *
 * The model call needs an API key, so these pin what happens around it: how
 * each renovation type is described to the model, and what is kept from its
 * answer before the builder sees it.
 */

const assert = require("assert");
const {
  renovationTypeLine,
  sanitizeRecommendations,
} = require("../src/services/iconstructAi");

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

test("each renovation type is described as itself", () => {
  assert.match(renovationTypeLine("Cosmetic"), /^Cosmetic/);
  assert.match(renovationTypeLine("Structural"), /^Structural/);
  assert.match(renovationTypeLine("Functional"), /^Functional/);
});

test("cosmetic work is told to leave structure out", () => {
  assert.match(renovationTypeLine("Cosmetic"), /no CHB, rebar/);
});

test("labels saved before the three types map across", () => {
  assert.match(renovationTypeLine("Extension"), /^Structural/);
  assert.match(renovationTypeLine("Full Renovation"), /^Cosmetic/);
  assert.match(renovationTypeLine(""), /not set/);
});

test("blank and repeated names are dropped", () => {
  const out = sanitizeRecommendations([
    { name: "Tile adhesive (25 kg)", reason: "Sets the floor tiles" },
    { name: "  " },
    { name: "tile adhesive (25 kg)", reason: "again" },
    null,
  ]);
  assert.strictEqual(out.length, 1);
  assert.strictEqual(out[0].reason, "Sets the floor tiles");
});

test("nothing about price reaches the builder", () => {
  const out = sanitizeRecommendations([
    { name: "Tile grout (2 kg)", reason: "About ₱150 a pack" },
    { name: "Paint worth PHP 900" },
  ]);
  assert.strictEqual(out.length, 1);
  assert.strictEqual(out[0].name, "Tile grout (2 kg)");
  assert.strictEqual(out[0].reason, "");
});

test("a plain list of names is accepted", () => {
  const out = sanitizeRecommendations(["PPR pipe 1/2\"", "Teflon tape"]);
  assert.deepStrictEqual(
    out.map((m) => m.name),
    ["PPR pipe 1/2\"", "Teflon tape"]
  );
});

test("the list stops at fifteen", () => {
  const many = Array.from({ length: 30 }, (_, i) => ({ name: `Material ${i}` }));
  assert.strictEqual(sanitizeRecommendations(many).length, 15);
});

test("an answer without a list gives an empty one", () => {
  assert.deepStrictEqual(sanitizeRecommendations(undefined), []);
  assert.deepStrictEqual(sanitizeRecommendations({ name: "x" }), []);
});

console.log(`\n${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
