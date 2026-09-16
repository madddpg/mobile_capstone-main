const path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, "../../.env") });
const axios = require("axios");

async function sendBrevoEmail({ to, subject, htmlContent, textContent }) {
  const apiKey = process.env.BREVO_API_KEY;
  if (!apiKey) {
    throw new Error(
      "BREVO_API_KEY is missing. One-time codes cannot be sent, so " +
        "registration and password reset will both fail. Set it with " +
        "firebase functions:secrets:set BREVO_API_KEY, or in functions/.env."
    );
  }

  try {
    const response = await axios.post(
      "https://api.brevo.com/v3/smtp/email",
      {
        sender: {
          name: process.env.BREVO_SENDER_NAME || "iConstruct",
          // No personal address as a fallback. A one-time code arriving from
          // someone's Gmail looks like a phishing attempt, and it puts a
          // student's private address on every message the system sends.
          email: process.env.BREVO_SENDER_EMAIL || "no-reply@iconstruct.app",
        },
        to: [{ email: to }],
        subject,
        htmlContent,
        textContent,
      },
      {
        headers: {
          "api-key": apiKey,
          "Content-Type": "application/json",
          Accept: "application/json",
        },
      }
    );

    return response.data;
  } catch (error) {
    console.error("Brevo send error message:", error.message);
    console.error("Brevo response status:", error.response?.status);
    console.error("Brevo response data:", error.response?.data);
    throw new Error(
      error.response?.data?.message ||
        error.message ||
        "Failed to send email."
    );
  }
}

const {
  otpEmail,
  welcomeEmail,
  passwordChangedEmail,
} = require("./emailTemplates");

function sendTemplate(to, message) {
  return sendBrevoEmail({
    to,
    subject: message.subject,
    htmlContent: message.html,
    textContent: message.text,
  });
}

/** [expiresMinutes] should be the server's own code lifetime. */
exports.sendOtpEmail = async (email, otp, expiresMinutes) => {
  return sendTemplate(
    email,
    otpEmail({ code: otp, purpose: "registration", expiresMinutes })
  );
};

exports.sendForgotPasswordEmail = async (email, otp, expiresMinutes) => {
  return sendTemplate(
    email,
    otpEmail({ code: otp, purpose: "password_reset", expiresMinutes })
  );
};

exports.sendWelcomeEmail = async (email) => {
  return sendTemplate(email, welcomeEmail());
};

exports.sendPasswordResetSuccessEmail = async (email) => {
  return sendTemplate(email, passwordChangedEmail({ changedAt: new Date() }));
};