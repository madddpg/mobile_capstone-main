/// Client resend wait. Must stay at least as long as the Cloud Function
/// cooldown (`OTP_REQUEST_COOLDOWN_MS` in functions/index.js) so the UI
/// does not invite extra Brevo calls that the server will reject.
const int otpResendCooldownSeconds = 60;
