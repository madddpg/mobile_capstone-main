"use strict";

/**
 * Transaction invoice tests.
 * Run with: node functions/test/transactionInvoice.test.js
 *
 * The trigger needs Firestore, so what is pinned here is the policy: when an
 * invoice is due, and what the message says.
 */

const assert = require("assert");
const {
  shouldIssueInvoice,
  buildInvoiceMessage,
  invoiceMessageId,
  invoicePreview,
  invoiceTotal,
  keptLines,
} = require("../src/services/transactionInvoice");

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

const post = { selectedQuotationId: "shop1", projectName: "Bathroom", ownerName: "Ana" };
const accepted = { status: "accepted", shopConfirmation: "pending" };
const confirmed = { status: "accepted", shopConfirmation: "confirmed" };

test("an invoice is due when the shop confirms the builder's accepted quotation", () => {
  assert.strictEqual(
    shouldIssueInvoice({ before: accepted, after: confirmed, post, quotationId: "shop1" }),
    true
  );
});

test("a partial acceptance confirmed by the shop gets an invoice too", () => {
  assert.strictEqual(
    shouldIssueInvoice({
      before: { status: "partially_accepted" },
      after: { status: "partially_accepted", shopConfirmation: "confirmed" },
      post,
      quotationId: "shop1",
    }),
    true
  );
});

test("no invoice until the shop confirms", () => {
  assert.strictEqual(
    shouldIssueInvoice({ before: { status: "submitted" }, after: accepted, post, quotationId: "shop1" }),
    false
  );
  assert.strictEqual(
    shouldIssueInvoice({
      before: accepted,
      after: { status: "accepted", shopConfirmation: "declined" },
      post,
      quotationId: "shop1",
    }),
    false
  );
});

test("an unrelated edit after confirmation does not issue a second invoice", () => {
  assert.strictEqual(
    shouldIssueInvoice({ before: confirmed, after: { ...confirmed, updatedAt: 2 }, post, quotationId: "shop1" }),
    false
  );
});

test("no invoice when the builder has not accepted this quotation", () => {
  assert.strictEqual(
    shouldIssueInvoice({
      before: { status: "submitted" },
      after: { status: "submitted", shopConfirmation: "confirmed" },
      post,
      quotationId: "shop1",
    }),
    false
  );
  assert.strictEqual(
    shouldIssueInvoice({ before: accepted, after: confirmed, post, quotationId: "shop2" }),
    false
  );
  assert.strictEqual(
    shouldIssueInvoice({ before: accepted, after: confirmed, post: null, quotationId: "shop1" }),
    false
  );
});

test("the total sums only the lines the builder kept", () => {
  const quotation = {
    items: [
      { name: "Primer", quantity: 2, unitPrice: 800 },
      { name: "Paint", quantity: 3, unitPrice: 350 },
      { name: "Dropped", quantity: 1, unitPrice: 999, accepted: false },
      { name: "Out", quantity: 1, unitPrice: 100, status: "out_of_stock" },
      { name: "No price", quantity: 4 },
    ],
  };
  assert.deepStrictEqual(keptLines(quotation).map((l) => l.name), ["Primer", "Paint"]);
  assert.strictEqual(invoiceTotal(quotation), 2650);
});

test("a stored acceptedTotal wins over the line sum", () => {
  assert.strictEqual(
    invoiceTotal({ acceptedTotal: 4050, items: [{ unitPrice: 1, quantity: 1 }] }),
    4050
  );
});

test("a lump-sum quotation with no lines uses the shop's total", () => {
  assert.strictEqual(invoiceTotal({ totalAmount: "1,250.50" }), 1250.5);
});

test("the message is shaped the way the chat card reads it", () => {
  const msg = buildInvoiceMessage({
    postId: "post9",
    quotationId: "shop1",
    quotation: { shopName: "GSHOP", items: [{ name: "Primer", quantity: 2, unitPrice: 800 }] },
    post,
    conversation: { builderName: "Ana Cruz" },
  });
  assert.strictEqual(msg.type, "quotation_invoice");
  assert.strictEqual(msg.senderRole, "system");
  assert.strictEqual(msg.acceptedTotal, 1600);
  assert.strictEqual(msg.projectId, "post9");
  assert.strictEqual(msg.quotationSnapshot.shopName, "GSHOP");
  assert.strictEqual(msg.quotationSnapshot.builderName, "Ana Cruz");
  assert.strictEqual(msg.quotationSnapshot.projectTitle, "Bathroom");
  assert.strictEqual(msg.quotationSnapshot.items.length, 1);
  assert.ok(msg.text.startsWith("[OFFICIAL_TRANSACTION_INVOICE]"));
  assert.ok(msg.text.includes("₱1,600.00"));
});

test("one message id per quotation", () => {
  assert.strictEqual(invoiceMessageId("shop1"), "invoice_shop1");
});

test("the chat list preview reads plainly", () => {
  assert.strictEqual(invoicePreview(4050), "Official quotation issued: ₱4,050.00");
});

console.log(`\n${passed} passed, ${failed} failed`);
if (failed > 0) process.exit(1);
