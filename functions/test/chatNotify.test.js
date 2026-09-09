"use strict";

/**
 * Chat notification routing tests.
 * Run with: node functions/test/chatNotify.test.js
 *
 * Picking the wrong participant would push a person's own message back at
 * them, so the routing is worth pinning even though the trigger itself needs
 * Firestore.
 */

const assert = require("assert");
const {
  recipientFor,
  previewFor,
  senderLabelFor,
} = require("../src/services/chatNotify");

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

const conv = {
  builderId: "builder-1",
  shopId: "shop-1",
  shopName: "Calamba Builders Hardware",
  builderName: "Ahmad",
};

console.log("\nrecipientFor — who gets told");

test("a builder's message notifies the shop", () => {
  const r = recipientFor(conv, { senderId: "builder-1", senderRole: "builder" });
  assert.deepStrictEqual(r, { uid: "shop-1", audience: "shop" });
});

test("a shop's message notifies the builder", () => {
  const r = recipientFor(conv, { senderId: "shop-1", senderRole: "shop" });
  assert.deepStrictEqual(r, { uid: "builder-1", audience: "builder" });
});

test("a thread storing the builder under userId still routes", () => {
  // Web-created threads set userId rather than builderId.
  const alt = { userId: "builder-2", shopId: "shop-1" };
  const r = recipientFor(alt, { senderId: "shop-1", senderRole: "shop" });
  assert.strictEqual(r.uid, "builder-2");
});

test("a system message notifies nobody", () => {
  assert.strictEqual(
    recipientFor(conv, { senderId: "builder-1", senderRole: "system" }),
    null
  );
});

test("a sender who is in neither seat notifies nobody", () => {
  // An outsider writing into a thread must not cause a push to either party.
  assert.strictEqual(
    recipientFor(conv, { senderId: "stranger", senderRole: "builder" }),
    null
  );
});

test("a thread missing a participant notifies nobody", () => {
  assert.strictEqual(
    recipientFor({ shopId: "shop-1" }, { senderId: "shop-1" }),
    null
  );
});

test("a message with no sender notifies nobody", () => {
  assert.strictEqual(recipientFor(conv, { senderRole: "shop" }), null);
});

console.log("\npreviewFor — what the push says");

test("plain text is used as written", () => {
  assert.strictEqual(previewFor({ text: "Is the cement in stock?" }),
    "Is the cement in stock?");
});

test("a long message is trimmed with an ellipsis", () => {
  const long = "x".repeat(300);
  const out = previewFor({ text: long });
  assert.strictEqual(out.length, 120);
  assert.ok(out.endsWith("…"));
});

test("a photo with no caption still says something", () => {
  // An empty push body reads as broken rather than as an attachment.
  assert.strictEqual(
    previewFor({ text: "", attachment: { url: "https://x", kind: "image" } }),
    "Sent a photo"
  );
});

test("a document with no caption says attachment", () => {
  assert.strictEqual(
    previewFor({ text: "", attachment: { url: "https://x", kind: "file" } }),
    "Sent an attachment"
  );
});

test("a caption wins over the attachment wording", () => {
  assert.strictEqual(
    previewFor({ text: "here is the wall", attachment: { url: "https://x", kind: "image" } }),
    "here is the wall"
  );
});

test("an empty message still produces a body", () => {
  assert.strictEqual(previewFor({}), "Sent a message");
});

console.log("\nsenderLabelFor — who it says it is from");

test("the builder sees the shop's name", () => {
  assert.strictEqual(senderLabelFor(conv, "builder"), "Calamba Builders Hardware");
});

test("the shop sees the builder's name", () => {
  assert.strictEqual(senderLabelFor(conv, "shop"), "Ahmad");
});

test("a missing name falls back to something readable", () => {
  assert.strictEqual(senderLabelFor({}, "builder"), "A hardware shop");
  assert.strictEqual(senderLabelFor({}, "shop"), "A builder");
});

console.log(`\n${passed} passed, ${failed} failed\n`);
process.exit(failed === 0 ? 0 : 1);
