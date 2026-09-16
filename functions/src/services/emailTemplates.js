"use strict";

/**
 * Content for every email iConstruct sends: the two one-time codes, the
 * welcome message and the password-changed notice.
 *
 * Email clients are much stricter than browsers. Gmail drops <style> blocks
 * in some views and never shows images embedded in the message, Outlook on
 * Windows lays pages out with Word's engine, and many inboxes hide remote
 * images until the reader allows them. So the layout is nested tables with
 * inline styles, the brand is set in text rather than a logo image, and every
 * message carries a plain-text version for clients that show no HTML at all.
 */

const BRAND = {
  navy: "#1E3042",
  cream: "#EDE4D4",
  creamLight: "#F6F1E7",
  steel: "#648DB6",
  textDark: "#1F2933",
  textMuted: "#5C6F84",
  warningBg: "#FFF4D6",
  warningText: "#7A4A00",
};

const FONT = "'Segoe UI', Roboto, Helvetica, Arial, sans-serif";
const MONO = "Consolas, 'SFMono-Regular', 'Liberation Mono', Menlo, monospace";

const FOOTER_TEXT = "iConstruct · Region IV-A CALABARZON";

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function heading(text) {
  return `<h1 style="margin:0;font-family:${FONT};font-size:22px;line-height:30px;font-weight:700;color:${BRAND.textDark};">${escapeHtml(text)}</h1>`;
}

/** A paragraph of already-escaped HTML. */
function paragraph(html, { muted = false, size = 15, top = 0 } = {}) {
  const lineHeight = Math.round(size * 1.55);
  const color = muted ? BRAND.textMuted : BRAND.textDark;
  return `<p style="margin:${top}px 0 0;font-family:${FONT};font-size:${size}px;line-height:${lineHeight}px;color:${color};">${html}</p>`;
}

/** A tinted notice box, for the warning every sensitive email carries. */
function notice(html) {
  return `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:${BRAND.warningBg};border-radius:10px;">
<tr><td style="padding:12px 14px;font-family:${FONT};font-size:13px;line-height:20px;color:${BRAND.warningText};">${html}</td></tr>
</table>`;
}

/**
 * Wraps a message body in the shared shell: brand band, white card, footer.
 *
 * [preheader] is the preview line an inbox shows beside the subject. It is
 * hidden inside the message itself.
 */
function layout({ title, preheader, bodyRows }) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light">
<meta name="supported-color-schemes" content="light">
<title>${escapeHtml(title)}</title>
</head>
<body style="margin:0;padding:0;background-color:${BRAND.cream};">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;mso-hide:all;">${escapeHtml(preheader)}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:${BRAND.cream};">
<tr><td align="center" style="padding:32px 16px;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:520px;background-color:#FFFFFF;border-radius:16px;overflow:hidden;">
<tr><td style="background-color:${BRAND.navy};padding:22px 28px;">
<div style="font-family:${FONT};font-size:22px;line-height:28px;font-weight:700;color:#FFFFFF;">i<span style="color:${BRAND.cream};">Construct</span></div>
<div style="font-family:${FONT};font-size:12px;line-height:18px;color:${BRAND.steel};">Material planning &amp; canvassing</div>
</td></tr>
${bodyRows}
<tr><td style="padding:18px 28px 24px;border-top:1px solid ${BRAND.cream};">
${paragraph("You received this because this email address was used on iConstruct. This mailbox is not monitored, so replies are not read.", { muted: true, size: 12 })}
${paragraph(escapeHtml(FOOTER_TEXT), { muted: true, size: 12, top: 8 })}
</td></tr>
</table>
</td></tr>
</table>
</body>
</html>`;
}

const OTP_PURPOSES = {
  registration: {
    subject: "Your iConstruct verification code",
    title: "Verify your email",
    lead: "Enter this code in the iConstruct app to finish creating your account.",
    ignore:
      "If you did not try to sign up, you can ignore this email. No account is created without this code.",
  },
  password_reset: {
    subject: "Your iConstruct password reset code",
    title: "Reset your password",
    lead: "Enter this code in the iConstruct app to choose a new password.",
    ignore:
      "If you did not ask to reset your password, ignore this email. Your password stays the same unless this code is used.",
  },
};

const NEVER_SHARE =
  "iConstruct staff and hardware shops will never ask for this code, by email, chat or phone.";

/**
 * A one-time code email.
 *
 * [purpose] is `registration` or `password_reset`; anything else is treated
 * as registration. [expiresMinutes] should come from the same setting that
 * expires the code on the server, so the email never promises longer than
 * the code actually lasts.
 */
function otpEmail({ code, purpose = "registration", expiresMinutes = 5 }) {
  const copy = OTP_PURPOSES[purpose] || OTP_PURPOSES.registration;
  const digits = String(code ?? "").replace(/\D/g, "");
  const minutes = Math.max(1, Math.round(Number(expiresMinutes) || 5));
  const expiry = `This code expires in ${minutes} ${minutes === 1 ? "minute" : "minutes"}.`;

  // The code stays one unbroken run of digits so it copies cleanly. The
  // spacing is visual only, and the extra left padding balances the trailing
  // letter-spacing after the last digit.
  const bodyRows = `
<tr><td style="padding:28px 28px 4px;">
${heading(copy.title)}
${paragraph(escapeHtml(copy.lead), { top: 8 })}
</td></tr>
<tr><td align="center" style="padding:18px 28px 0;">
<table role="presentation" cellpadding="0" cellspacing="0" border="0" style="background-color:${BRAND.creamLight};border:1px solid ${BRAND.cream};border-radius:12px;">
<tr><td align="center" style="padding:16px 14px 16px 24px;font-family:${MONO};font-size:34px;line-height:40px;font-weight:700;letter-spacing:10px;color:${BRAND.navy};">${escapeHtml(digits)}</td></tr>
</table>
${paragraph(escapeHtml(expiry), { muted: true, size: 13, top: 10 })}
</td></tr>
<tr><td style="padding:20px 28px 24px;">
${notice(`<strong>Keep this code to yourself.</strong> ${escapeHtml(NEVER_SHARE)}`)}
${paragraph(escapeHtml(copy.ignore), { muted: true, size: 13, top: 14 })}
</td></tr>`;

  const text = [
    copy.title,
    "",
    copy.lead,
    "",
    `Your code: ${digits}`,
    expiry,
    "",
    `Keep this code to yourself. ${NEVER_SHARE}`,
    "",
    copy.ignore,
    "",
    FOOTER_TEXT,
  ].join("\n");

  return {
    subject: copy.subject,
    html: layout({
      title: copy.subject,
      preheader: `${copy.lead} ${expiry}`,
      bodyRows,
    }),
    text,
  };
}

const WELCOME_STEPS = [
  [
    "Plan your materials",
    "Start from a renovation template or describe the job to the AI planner. Quantities are worked out from your area.",
  ],
  [
    "Ask shops for prices",
    "Post your material list and hardware shops in CALABARZON send you quotations.",
  ],
  [
    "Compare and choose",
    "See the quotations side by side, take all or part of an offer, then message the shop.",
  ],
];

function stepRow(number, title, detail) {
  return `<tr><td style="padding:0 28px 14px;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
<tr>
<td width="30" valign="top" style="padding-top:2px;">
<div style="width:26px;height:26px;border-radius:13px;background-color:${BRAND.navy};font-family:${FONT};font-size:13px;line-height:26px;font-weight:700;text-align:center;color:#FFFFFF;">${number}</div>
</td>
<td valign="top" style="padding-left:12px;">
<div style="font-family:${FONT};font-size:15px;line-height:22px;font-weight:700;color:${BRAND.textDark};">${escapeHtml(title)}</div>
<div style="font-family:${FONT};font-size:14px;line-height:21px;color:${BRAND.textMuted};">${escapeHtml(detail)}</div>
</td>
</tr>
</table>
</td></tr>`;
}

/** Sent once registration is complete. */
function welcomeEmail() {
  const subject = "Welcome to iConstruct";
  const lead =
    "Your account is ready. Here is how builders use iConstruct to plan and buy renovation materials.";
  const closing =
    "Quantities and prices in the app are for planning. Confirm final prices, stock and delivery with the shop before you buy.";

  const bodyRows = `
<tr><td style="padding:28px 28px 18px;">
${heading("Welcome to iConstruct")}
${paragraph(escapeHtml(lead), { top: 8 })}
</td></tr>
${WELCOME_STEPS.map(([title, detail], i) => stepRow(i + 1, title, detail)).join("\n")}
<tr><td style="padding:4px 28px 24px;">
${paragraph("Open the iConstruct app to start your first estimate.", { top: 0 })}
${paragraph(escapeHtml(closing), { muted: true, size: 13, top: 10 })}
</td></tr>`;

  const text = [
    "Welcome to iConstruct",
    "",
    lead,
    "",
    ...WELCOME_STEPS.map(([title, detail], i) => `${i + 1}. ${title}: ${detail}`),
    "",
    "Open the iConstruct app to start your first estimate.",
    "",
    closing,
    "",
    FOOTER_TEXT,
  ].join("\n");

  return {
    subject,
    html: layout({ title: subject, preheader: lead, bodyRows }),
    text,
  };
}

/** Manila time, the way a builder in the region would read it. */
function formatManilaTime(date) {
  return new Intl.DateTimeFormat("en-PH", {
    dateStyle: "long",
    timeStyle: "short",
    timeZone: "Asia/Manila",
  }).format(date);
}

/** Sent after a password reset completes. */
function passwordChangedEmail({ changedAt = new Date() } = {}) {
  const subject = "Your iConstruct password was changed";
  const when = formatManilaTime(changedAt);
  const lead = `The password for your iConstruct account was changed on ${when} (Philippine time).`;
  const notMe =
    "Someone else may be able to read your email. Secure your email account first, then open the iConstruct app and use Forgot Password on the sign-in screen to set a new password.";

  const bodyRows = `
<tr><td style="padding:28px 28px 4px;">
${heading("Your password was changed")}
${paragraph(escapeHtml(lead), { top: 8 })}
${paragraph("If this was you, there is nothing else to do.", { muted: true, size: 14, top: 8 })}
</td></tr>
<tr><td style="padding:16px 28px 24px;">
${notice(`<strong>Didn't change it?</strong> ${escapeHtml(notMe)}`)}
</td></tr>`;

  const text = [
    "Your password was changed",
    "",
    lead,
    "If this was you, there is nothing else to do.",
    "",
    `Didn't change it? ${notMe}`,
    "",
    FOOTER_TEXT,
  ].join("\n");

  return {
    subject,
    html: layout({ title: subject, preheader: lead, bodyRows }),
    text,
  };
}

module.exports = {
  otpEmail,
  welcomeEmail,
  passwordChangedEmail,
  escapeHtml,
  formatManilaTime,
};
