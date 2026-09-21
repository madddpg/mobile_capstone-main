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
  cleanWorkItems,
  sanitizeWorkPicks,
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

// ── Work items ──────────────────────────────────────────────────────────

test("the work list from the app keeps only well-formed items", () => {
  const out = cleanWorkItems([
    { id: "retile_floor", label: "Retile the floor", kind: "Cosmetic" },
    { id: "retile_floor", label: "again" },
    { id: "Drop Table", label: "not an id" },
    { label: "no id" },
    null,
  ]);
  assert.deepStrictEqual(out.map((w) => w.id), ["retile_floor"]);
});

test("the work list stops at forty", () => {
  const many = Array.from({ length: 60 }, (_, i) => ({ id: `item_${i}` }));
  assert.strictEqual(cleanWorkItems(many).length, 40);
});

test("no work list means the materials answer, as before", () => {
  assert.deepStrictEqual(cleanWorkItems(undefined), []);
});

test("only work the app offered can be picked", () => {
  const out = sanitizeWorkPicks(
    [
      { id: "retile_floor", reason: "Old tiles are cracked" },
      { id: "install_jacuzzi", reason: "Invented" },
      { id: "retile_floor", reason: "again" },
      "repaint",
    ],
    ["retile_floor", "repaint"]
  );
  assert.deepStrictEqual(
    out.map((p) => p.id),
    ["retile_floor", "repaint"]
  );
  assert.strictEqual(out[0].reason, "Old tiles are cracked");
});

test("nothing about price reaches the builder in a work reason", () => {
  const out = sanitizeWorkPicks(
    [{ id: "repaint", reason: "Costs about ₱2,000" }],
    ["repaint"]
  );
  assert.strictEqual(out[0].reason, "");
});

test("an answer without picks gives an empty list", () => {
  assert.deepStrictEqual(sanitizeWorkPicks(undefined, ["repaint"]), []);
});

console.log(`\n${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
