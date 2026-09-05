const path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, "../../.env") });
const axios = require("axios");

async function sendBrevoEmail({ to, subject, htmlContent, textContent }) {
  const apiKey = process.env.BREVO_API_KEY;
  if (!apiKey) {
    throw new Error("BREVO_API_KEY is missing in process.env");
  }

  try {
    const response = await axios.post(
      "https://api.brevo.com/v3/smtp/email",
      {
        sender: {
          name: process.env.BREVO_SENDER_NAME || "iConstruct",
          email: process.env.BREVO_SENDER_EMAIL || "ahmadpaguta2005@gmail.com",
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

exports.sendOtpEmail = async (email, otp) => {
  return sendBrevoEmail({
    to: email,
    subject: "Your iConstruct OTP Code",
    htmlContent: `<p>Your OTP code is <b>${otp}</b></p>`,
    textContent: `Your OTP code is ${otp}`,
  });
};

exports.sendForgotPasswordEmail = async (email, otp) => {
  return sendBrevoEmail({
    to: email,
    subject: "Reset your iConstruct password",
    htmlContent: `<p>Your password reset code is <b>${otp}</b></p>`,
    textContent: `Your password reset code is ${otp}`,
  });
};

exports.sendWelcomeEmail = async (email) => {
  return sendBrevoEmail({
    to: email,
    subject: "Welcome to iConstruct!",
    htmlContent: `<p>Welcome to iConstruct! We're glad to have you.</p>`,
    textContent: `Welcome to iConstruct! We're glad to have you.`,
  });
};

exports.sendPasswordResetSuccessEmail = async (email) => {
  return sendBrevoEmail({
    to: email,
    subject: "Password Reset Successful",
    htmlContent: `<p>Your iConstruct password has been reset successfully.</p>`,
    textContent: `Your iConstruct password has been reset successfully.`,
  });
};