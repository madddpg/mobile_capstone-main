"use strict";

/**
 * Email template tests.
 * Run with: node functions/test/emailTemplates.test.js
 *
 * A code email that names the wrong purpose, promises the wrong expiry or
 * drops the warning is a support problem at best and a phishing aid at worst,
 * so the content is pinned here even though sending needs Brevo.
 */

const assert = require("assert");
const {
  otpEmail,
  welcomeEmail,
  passwordChangedEmail,
  escapeHtml,
  formatManilaTime,
} = require("../src/services/emailTemplates");

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

/** The hidden inbox preview line of a rendered email. */
function preheaderOf(html) {
  const match = html.match(/display:none[^>]*>([^<]*)</);
  return match ? match[1] : "";
}

console.log("\notpEmail — what the code email says");

test("a registration code asks the builder to verify their email", () => {
  const mail = otpEmail({ code: "482917", purpose: "registration" });
  assert.strictEqual(mail.subject, "Your iConstruct verification code");
  assert.ok(mail.html.includes("Verify your email"));
  assert.ok(mail.text.includes("finish creating your account"));
});

test("a reset code says it is for a new password", () => {
  const mail = otpEmail({ code: "482917", purpose: "password_reset" });
  assert.strictEqual(mail.subject, "Your iConstruct password reset code");
  assert.ok(mail.html.includes("Reset your password"));
  assert.ok(mail.text.includes("Your password stays the same"));
});

test("an unknown purpose falls back to registration", () => {
  assert.strictEqual(
    otpEmail({ code: "482917", purpose: "something" }).subject,
    "Your iConstruct verification code"
  );
});

test("the code appears as one unbroken run of digits", () => {
  const mail = otpEmail({ code: "48 29-17" });
  assert.ok(mail.html.includes(">482917<"), "html");
  assert.ok(mail.text.includes("Your code: 482917"), "text");
});

test("the expiry comes from the lifetime it is given", () => {
  assert.ok(otpEmail({ code: "1", expiresMinutes: 5 }).text.includes("expires in 5 minutes."));
  assert.ok(otpEmail({ code: "1", expiresMinutes: 1 }).text.includes("expires in 1 minute."));
  assert.ok(otpEmail({ code: "1", expiresMinutes: "junk" }).text.includes("expires in 5 minutes."));
});

test("both versions warn never to share the code", () => {
  const mail = otpEmail({ code: "482917" });
  for (const body of [mail.html, mail.text]) {
    assert.ok(body.includes("Keep this code to yourself"));
    assert.ok(body.includes("will never ask for this code"));
  }
});

test("the code stays out of the subject and the inbox preview", () => {
  // Both show on a locked phone's notification. The code belongs in the
  // opened message only.
  const mail = otpEmail({ code: "482917" });
  assert.ok(!mail.subject.includes("482917"), "subject");
  const preview = preheaderOf(mail.html);
  assert.ok(preview.length > 0, "preheader missing");
  assert.ok(!preview.includes("482917"), "preheader");
});

console.log("\nlayout — safe for email clients");

test("no email relies on images, style blocks or scripts", () => {
  // Blocked images, stripped <style> and no scripts are the norm in inboxes.
  const mails = [
    otpEmail({ code: "482917" }),
    welcomeEmail(),
    passwordChangedEmail({ changedAt: new Date("2026-09-14T02:30:00Z") }),
  ];
  for (const mail of mails) {
    assert.ok(!/<img/i.test(mail.html), `${mail.subject}: img`);
    assert.ok(!/<style/i.test(mail.html), `${mail.subject}: style`);
    assert.ok(!/<script/i.test(mail.html), `${mail.subject}: script`);
    assert.ok(mail.text.trim().length > 0, `${mail.subject}: text`);
  }
});

test("text is escaped before it goes into HTML", () => {
  assert.strictEqual(escapeHtml(`<b>"Tom & Jerry's"</b>`),
    "&lt;b&gt;&quot;Tom &amp; Jerry&#39;s&quot;&lt;/b&gt;");
});

console.log("\nwelcomeEmail and passwordChangedEmail");

test("the welcome email walks through the three steps", () => {
  const mail = welcomeEmail();
  for (const step of ["Plan your materials", "Ask shops for prices", "Compare and choose"]) {
    assert.ok(mail.html.includes(step), `html: ${step}`);
    assert.ok(mail.text.includes(step), `text: ${step}`);
  }
});

test("the password notice gives the time in Philippine time", () => {
  // 02:30 UTC is 10:30 in Manila.
  const when = formatManilaTime(new Date("2026-09-14T02:30:00Z"));
  assert.ok(when.includes("September 14, 2026"), when);
  assert.ok(when.includes("10:30"), when);

  const mail = passwordChangedEmail({ changedAt: new Date("2026-09-14T02:30:00Z") });
  assert.ok(mail.text.includes(when));
  assert.ok(mail.text.includes("Philippine time"));
});

test("the password notice says what to do if it was not you", () => {
  const mail = passwordChangedEmail();
  for (const body of [mail.html, mail.text]) {
    assert.ok(body.includes("change it?"), "asks whether it was them");
    assert.ok(body.includes("Forgot Password"), "says how to recover");
  }
});

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed === 0 ? 0 : 1);
