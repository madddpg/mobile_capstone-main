"use strict";

/**
 * Supplier-cancellation policy tests.
 * Run with: node functions/test/supplierSelection.test.js
 *
 * The transaction itself needs Firestore, so what is pinned here is the
 * policy around it: which reasons count, which quotations come back, and what
 * the shop is told.
 */

const assert = require("assert");
const {
  normalizeCancelReason,
  cancelReasonLabel,
  sanitizeCancelNote,
  restorableQuotationIds,
  reopenedPostStatus,
  reopenedProjectStatus,
  cancellationMessage,
} = require("../src/services/supplierSelection");

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

test("a reason has to be one the shop will understand", () => {
  assert.strictEqual(normalizeCancelReason("shop_unresponsive"), "shop_unresponsive");
  assert.strictEqual(normalizeCancelReason("  MISTAKE "), "mistake");
  assert.strictEqual(normalizeCancelReason("because i said so"), null);
  assert.strictEqual(normalizeCancelReason(""), null);
  assert.strictEqual(normalizeCancelReason(undefined), null);
});

test("every reason reads as a sentence, not a key", () => {
  assert.match(cancelReasonLabel("cannot_supply"), /could not supply/);
  assert.match(cancelReasonLabel("nonsense"), /No reason given/);
});

test("a note is trimmed and capped", () => {
  assert.strictEqual(sanitizeCancelNote("  they never replied  "), "they never replied");
  assert.strictEqual(sanitizeCancelNote(null), "");
  assert.strictEqual(sanitizeCancelNote("x".repeat(900)).length, 500);
});

test("the rejected siblings come back on the table", () => {
  const quotations = [
    { id: "shop-1", status: "cancelled" },
    { id: "shop-2", status: "rejected" },
    { id: "shop-3", status: "rejected" },
  ];
  assert.deepStrictEqual(restorableQuotationIds(quotations, "shop-1"), [
    "shop-2",
    "shop-3",
  ]);
});

test("the cancelled quotation is never restored to itself", () => {
  const quotations = [{ id: "shop-1", status: "rejected" }];
  assert.deepStrictEqual(restorableQuotationIds(quotations, "shop-1"), []);
});

test("a shop's own withdrawal is left alone", () => {
  const quotations = [
    { id: "shop-2", status: "withdrawn" },
    { id: "shop-3", status: "submitted" },
  ];
  assert.deepStrictEqual(restorableQuotationIds(quotations, "shop-1"), []);
});

test("an estimate with offers left reopens as one that has quotations", () => {
  assert.strictEqual(reopenedPostStatus(2), "has_quotations");
  assert.strictEqual(reopenedProjectStatus(2), "receiving quotations");
});

test("an estimate with nothing left waits for quotations again", () => {
  assert.strictEqual(reopenedPostStatus(0), "open");
  assert.strictEqual(reopenedProjectStatus(0), "waiting for quotations");
});

test("the shop is told which estimate and why", () => {
  const message = cancellationMessage({
    projectName: "Master Bathroom",
    reasonKey: "shop_unresponsive",
    note: "no reply for a week",
  });
  assert.match(message, /Master Bathroom/);
  assert.match(message, /stopped replying/);
  assert.match(message, /no reply for a week/);
});

test("a cancellation without a note still reads properly", () => {
  const message = cancellationMessage({ projectName: "", reasonKey: "mistake" });
  assert.match(message, /an estimate/);
  assert.ok(!message.includes("They added"));
});

console.log(`\n${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
