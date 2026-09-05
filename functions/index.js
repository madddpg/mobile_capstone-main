const crypto = require("crypto");
const logger = require("firebase-functions/logger");
const { onCall, HttpsError, onRequest } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { setGlobalOptions } = require("firebase-functions/v2");
const { defineSecret } = require("firebase-functions/params");
const { Timestamp } = require("firebase-admin/firestore");

const admin = require("./firebaseAdmin");

// Apply production scale defaults
setGlobalOptions({
  region: "us-central1",
  maxInstances: 10,
  concurrency: 80,
  timeoutSeconds: 120
});

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");

const {
  ICONSTRUCT_SYSTEM_SCOPE,
  resolveGeminiKey,
  callGeminiJson,
  callOpenAiJson,
  runMaterialConsult,
} = require("./src/services/iconstructAi");

const { app: apiApp } = require("./api");

// Deploy as an Express-wrapped Cloud Function
exports.api = onRequest({ cors: true }, apiApp);

const db = admin.firestore();
const auth = admin.auth();

const OTP_TTL_MS = 5 * 60 * 1000;
const OTP_REQUEST_COOLDOWN_MS = 60 * 1000;
const OTP_MAX_SENDS_PER_HOUR = 5;
const OTP_MAX_SENDS_PER_DAY = 10;
const OTP_MAX_SENDS_PER_IP_PER_HOUR = 10;
const OTP_MAX_SENDS_PER_IP_PER_DAY = 30;
const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;
const MAX_ATTEMPTS = 5;
const VERIFIED_REGISTRATION_WINDOW_MS = 15 * 60 * 1000;
const OTP_COLLECTION = "email_otp";
const OTP_IP_LIMIT_COLLECTION = "otp_send_ip";

// Registration/OTP must work before a builder has an App Check token.
const publicAuthCallable = {
  enforceAppCheck: false,
  consumeAppCheckToken: false,
};


function abort(code, message) {
  throw new HttpsError(code, message, { userMessage: message });
}

function readEmail(request) {
  const email = String(request.data?.email || "").trim().toLowerCase();

  if (!email) {
    abort("invalid-argument", "Email is required.");
  }

  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    abort("invalid-argument", "Enter a valid email address.");
  }

  return email;
}

function readOtp(request) {
  const otp = String(request.data?.otp ?? "").replace(/\D/g, "").trim();

  if (!/^\d{6}$/.test(otp)) {
    abort("invalid-argument", "Enter the 6-digit OTP code.");
  }

  return otp;
}

function readVerificationToken(request) {
  const verificationToken = String(request.data?.verificationToken || "").trim();

  if (!verificationToken) {
    throw new HttpsError(
      "failed-precondition",
      "Verify the OTP before finishing registration."
    );
  }

  return verificationToken;
}

function generateOtp() {
  return String(crypto.randomInt(100000, 1000000));
}

function hashVerificationToken(token) {
  return crypto.createHash("sha256").update(token).digest("hex");
}

function rollingWindow(data, now, countKey, startKey, windowMs) {
  const start = data?.[startKey]?.toMillis?.() || 0;
  if (!start || now - start >= windowMs) {
    return { count: 0, start: now };
  }
  return { count: Number(data?.[countKey] || 0), start };
}

function clientIpHash(request) {
  const forwarded = request.rawRequest?.headers?.["x-forwarded-for"];
  const raw =
    (typeof forwarded === "string" && forwarded.split(",")[0].trim()) ||
    request.rawRequest?.ip ||
    request.rawRequest?.socket?.remoteAddress ||
    "";
  if (!raw || raw === "unknown") return null;
  return crypto.createHash("sha256").update(raw).digest("hex").slice(0, 32);
}

async function consumeIpSendSlot(ipHash, now) {
  if (!ipHash) return;
  const ref = db.collection(OTP_IP_LIMIT_COLLECTION).doc(ipHash);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data() || {};
    const hour = rollingWindow(
      data,
      now,
      "send_count_hour",
      "hour_window_start",
      HOUR_MS
    );
    if (hour.count >= OTP_MAX_SENDS_PER_IP_PER_HOUR) {
      throw new HttpsError(
        "resource-exhausted",
        "Too many codes requested from this device. Try again in an hour."
      );
    }
    const day = rollingWindow(
      data,
      now,
      "send_count_day",
      "day_window_start",
      DAY_MS
    );
    if (day.count >= OTP_MAX_SENDS_PER_IP_PER_DAY) {
      throw new HttpsError(
        "resource-exhausted",
        "Daily code limit reached. Try again tomorrow."
      );
    }
    tx.set(
      ref,
      {
        last_request_time: Timestamp.fromMillis(now),
        send_count_hour: hour.count + 1,
        hour_window_start: Timestamp.fromMillis(hour.start),
        send_count_day: day.count + 1,
        day_window_start: Timestamp.fromMillis(day.start),
      },
      { merge: true }
    );
  });
}

exports.sendEmailOtp = onCall(publicAuthCallable, async (request) => {
  const email = readEmail(request);
  const now = Date.now();
  const nowTimestamp = Timestamp.fromMillis(now);
  const docRef = db.collection(OTP_COLLECTION).doc(email);
  const otp = generateOtp();

  logger.info("Generating email OTP", { email });

  await consumeIpSendSlot(clientIpHash(request), now);

  await db.runTransaction(async (tx) => {
    const existingDoc = await tx.get(docRef);
    const existingData = existingDoc.data() || {};
    const lastRequestTime = existingData.last_request_time?.toMillis?.() || 0;

    if (lastRequestTime && now - lastRequestTime < OTP_REQUEST_COOLDOWN_MS) {
      const waitSec = Math.ceil(
        (OTP_REQUEST_COOLDOWN_MS - (now - lastRequestTime)) / 1000
      );
      logger.warn("OTP requested too soon", { email, waitSec });
      throw new HttpsError(
        "resource-exhausted",
        `Please wait ${waitSec} seconds before requesting another code.`
      );
    }

    const hour = rollingWindow(
      existingData,
      now,
      "send_count_hour",
      "hour_window_start",
      HOUR_MS
    );
    if (hour.count >= OTP_MAX_SENDS_PER_HOUR) {
      logger.warn("OTP hourly cap reached", { email, count: hour.count });
      throw new HttpsError(
        "resource-exhausted",
        "Too many codes sent to this email. Try again in an hour."
      );
    }

    const day = rollingWindow(
      existingData,
      now,
      "send_count_day",
      "day_window_start",
      DAY_MS
    );
    if (day.count >= OTP_MAX_SENDS_PER_DAY) {
      logger.warn("OTP daily cap reached", { email, count: day.count });
      throw new HttpsError(
        "resource-exhausted",
        "Daily code limit reached. Try again tomorrow."
      );
    }

    tx.set(
      docRef,
      {
        email,
        otp_code: otp,
        created_at: nowTimestamp,
        expires_at: Timestamp.fromMillis(now + OTP_TTL_MS),
        attempt_count: 0,
        last_request_time: nowTimestamp,
        send_count_hour: hour.count + 1,
        hour_window_start: Timestamp.fromMillis(hour.start),
        send_count_day: day.count + 1,
        day_window_start: Timestamp.fromMillis(day.start),
        verification_token_hash: admin.firestore.FieldValue.delete(),
        verified_at: admin.firestore.FieldValue.delete(),
        verification_expires_at: admin.firestore.FieldValue.delete(),
      },
      { merge: true }
    );
  });

  const { sendOtpEmail, sendForgotPasswordEmail } = require("./src/services/brevoService");

  try {
    if (request.data?.purpose === "password_reset") {
      await sendForgotPasswordEmail(email, otp);
    } else {
      await sendOtpEmail(email, otp);
    }
    logger.info("OTP email sent via Brevo", { email });
  } catch (error) {
    logger.error("Failed to send OTP email", { email, error });
    // Keep last_request_time and send counters so a Brevo error cannot be
    // used to hammer the third-party mail API.
    throw new HttpsError(
      "internal",
      "Could not send the verification code. Wait a minute and try again."
    );
  }

  return {
    success: true,
    message: "Verification code sent to your email.",
  };
});

const verifyEmailOtp = onCall(publicAuthCallable, async (request) => {
  const email = readEmail(request);
  const otp = readOtp(request);
  const docRef = db.collection(OTP_COLLECTION).doc(email);
  const doc = await docRef.get();

  logger.info("verifyEmailOtp invoked", {
    email,
    otpLength: otp.length,
    hasStoredCode: doc.exists,
  });

  if (!doc.exists) {
    logger.warn("OTP verification requested without stored code", { email });
    throw new HttpsError(
      "not-found",
      "No verification code was found for this email. Request a new code."
    );
  }

  const data = doc.data();
  const expiresAt = data.expires_at?.toMillis?.() || 0;
  const attemptCount = Number(data.attempt_count || 0);

  if (Date.now() > expiresAt) {
    await docRef.delete();
    logger.warn("Expired OTP attempted", { email });
    throw new HttpsError(
      "deadline-exceeded",
      "This code has expired. Please request a new one."
    );
  }

  if (attemptCount >= MAX_ATTEMPTS) {
    await docRef.delete();
    logger.warn("OTP attempts exceeded", { email, attemptCount });
    throw new HttpsError(
      "resource-exhausted",
      "Too many incorrect attempts. Please request a new code."
    );
  }

  const storedOtp = String(data.otp_code ?? "").replace(/\D/g, "").trim();
  if (storedOtp !== otp) {
    await docRef.set({ attempt_count: attemptCount + 1 }, { merge: true });
    logger.warn("Incorrect OTP submitted", {
      email,
      attemptCount: attemptCount + 1,
      storedType: typeof data.otp_code,
    });
    abort("invalid-argument", "Incorrect OTP code.");
  }

  const verificationToken = crypto.randomBytes(32).toString("hex");
  const verificationTokenHash = hashVerificationToken(verificationToken);
  const verifiedAt = Timestamp.now();

  await docRef.set(
    {
      email,
      created_at: data.created_at || verifiedAt,
      expires_at: data.expires_at,
      last_request_time: data.last_request_time || verifiedAt,
      attempt_count: 0,
      otp_code: admin.firestore.FieldValue.delete(),
      verified_at: verifiedAt,
      verification_expires_at: Timestamp.fromMillis(
        Date.now() + VERIFIED_REGISTRATION_WINDOW_MS
      ),
      verification_token_hash: verificationTokenHash,
    },
    { merge: true }
  );

  // Mark the account verified server-side. The client is signed out during
  // verification, so it cannot write users/{uid} itself under security rules.
  try {
    const userRecord = await auth.getUserByEmail(email);
    await auth.updateUser(userRecord.uid, { emailVerified: true });
    await db.collection("users").doc(userRecord.uid).set(
      { isVerified: true, verified_at: verifiedAt },
      { merge: true }
    );
    logger.info("Account marked verified", { uid: userRecord.uid });
  } catch (error) {
    // A reset-password OTP can run before an account exists; that is not fatal.
    if (error.code !== "auth/user-not-found") {
      logger.error("Failed to mark account verified", error);
    }
  }

  logger.info("OTP verified successfully", { email });

  return {
    success: true,
    message: "Email verified. You can finish registration now.",
    verificationToken,
  };
});

// Production already has an older HTTP `verifyEmailOtp` (nodejs24). Do not
// re-export that name as a callable or deploy will collide. The builder app
// calls this unique name instead.
exports.confirmBuilderEmailOtp = verifyEmailOtp;

exports.finalizeEmailOtpRegistration = onCall(publicAuthCallable, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }

  const email = readEmail(request);
  const verificationToken = readVerificationToken(request);
  const userRecord = await auth.getUser(request.auth.uid);
  const signedInEmail = String(userRecord.email || "").trim().toLowerCase();

  if (signedInEmail !== email) {
    throw new HttpsError(
      "permission-denied",
      "The signed-in account email does not match the verified email."
    );
  }

  if (userRecord.emailVerified) {
    return {
      success: true,
      message: "Email already verified.",
    };
  }

  const docRef = db.collection(OTP_COLLECTION).doc(email);
  const doc = await docRef.get();

  if (!doc.exists) {
    throw new HttpsError(
      "failed-precondition",
      "Verify the OTP before finishing registration."
    );
  }

  const data = doc.data();
  const verificationExpiresAt = data.verification_expires_at?.toMillis?.() || 0;

  if (!data.verification_token_hash || Date.now() > verificationExpiresAt) {
    await docRef.delete();
    throw new HttpsError(
      "failed-precondition",
      "Your verification session expired. Request a new OTP and verify again."
    );
  }

  if (hashVerificationToken(verificationToken) !== data.verification_token_hash) {
    throw new HttpsError(
      "permission-denied",
      "The verification proof is invalid. Verify the OTP again."
    );
  }

  await auth.updateUser(request.auth.uid, { emailVerified: true });
  await docRef.delete();

  try {
    const { sendWelcomeEmail } = require("./src/services/brevoService");
    await sendWelcomeEmail(email);
  } catch (emailErr) {
    logger.error("Failed to send welcome email", { email, error: emailErr });
  }

  logger.info("Registration email marked verified", {
    email,
    uid: request.auth.uid,
  });

  return {
    success: true,
    message: "Email verified successfully.",
  };
});

exports.resetPasswordWithToken = onCall(publicAuthCallable, async (request) => {
  const email = readEmail(request);
  const verificationToken = readVerificationToken(request);
  const newPassword = String(request.data?.newPassword || "").trim();

  if (newPassword.length < 6) {
    throw new HttpsError(
      "invalid-argument",
      "Password must be at least 6 characters."
    );
  }

  const docRef = db.collection(OTP_COLLECTION).doc(email);
  const doc = await docRef.get();

  if (!doc.exists) {
    throw new HttpsError(
      "not-found",
      "No verification found. Please verify your email first."
    );
  }

  const data = doc.data();
  const verificationExpiresAt = data.verification_expires_at?.toMillis?.() || 0;

  if (!data.verification_token_hash || Date.now() > verificationExpiresAt) {
    await docRef.delete();
    throw new HttpsError(
      "failed-precondition",
      "Your verification session has expired. Please verify again."
    );
  }

  if (hashVerificationToken(verificationToken) !== data.verification_token_hash) {
    throw new HttpsError(
      "permission-denied",
      "Invalid verification token. Please verify your email again."
    );
  }

  try {
    const userRecord = await auth.getUserByEmail(email);
    await auth.updateUser(userRecord.uid, { password: newPassword });
    await docRef.delete();

    try {
      const { sendPasswordResetSuccessEmail } = require("./src/services/brevoService");
      await sendPasswordResetSuccessEmail(email);
    } catch (emailErr) {
      logger.error("Failed to send password reset success email", {
        email,
        error: emailErr,
      });
    }

    logger.info("Password reset successfully", { email });
    return { success: true, message: "Password reset successfully." };
  } catch (e) {
    if (e.code === "auth/user-not-found") {
      throw new HttpsError(
        "not-found",
        "No account found with this email address."
      );
    }
    logger.error("Failed to reset password", { email, error: e });
    throw new HttpsError(
      "internal",
      "Failed to reset password. Please try again."
    );
  }
});

exports.onProjectPostCreated = onDocumentCreated("projectPosts/{postId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return null;

  const postData = snapshot.data();
  const postId = event.params.postId;
  console.log("🔥 Triggered postId:", postId);

  try {
    const shopsSnapshot = await db.collection("shops")
      .where("status", "==", "approved")
      .get();

    console.log("Approved shops count:", shopsSnapshot.size);

    if (shopsSnapshot.empty) {
      console.log(`No approved shops found for post ${postId}`);
      return null;
    }

    let allTokens = [];
    const batch = db.batch();
    let notificationCount = 0;

    const title = "New Project Opportunity";
    const message = `A ${postData.projectType || "project"} project is now open for quotation.`;

    shopsSnapshot.forEach((shopDoc) => {
      const shopDocId = shopDoc.id;
      const shopData = shopDoc.data();
      const shopUid = shopData.uid || shopDocId;

      // Correctly extract ALL tokens from fcmTokens (array)
      const tokens = shopData.fcmTokens || [];
      if (Array.isArray(tokens)) {
        tokens.forEach(token => {
          if (token && typeof token === "string" && token.trim() !== "") {
            allTokens.push(token.trim());
          }
        });
      }

      const notificationRef = db.collection("notifications").doc();

      batch.set(notificationRef, {
        type: "new_project_post",
        postId,
        recipientId: shopUid,
        recipientShopDocId: shopDocId,
        recipientType: "shop",
        title,
        message,
        isRead: false,
        createdAt: Timestamp.now(),
      });

      notificationCount++;
    });

    console.log("📦 Collected tokens:", allTokens.length);

    await batch.commit();

    console.log(`Created ${notificationCount} shop notifications for post ${postId}.`);

    // Remove duplicates to prevent sending duplicate notifications
    allTokens = [...new Set(allTokens)];
    console.log("Collected tokens:", allTokens.length);

    if (allTokens.length > 0) {
      const CHUNK_SIZE = 500;
      let successCount = 0;
      let failureCount = 0;

      for (let i = 0; i < allTokens.length; i += CHUNK_SIZE) {
        const chunk = allTokens.slice(i, i + CHUNK_SIZE);

        const response = await admin.messaging().sendEachForMulticast({
          notification: {
            title,
            body: message,
          },
          data: {
            type: "new_project_post",
            postId: String(postId),
            projectName: String(postData.projectName || ""),
            projectType: String(postData.projectType || ""),
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          tokens: chunk,
        });

        successCount += response.successCount;
        failureCount += response.failureCount;
      }

      console.log("FCM Success:", successCount);
      console.log("FCM Failures:", failureCount);
    } else {
      console.log("No FCM tokens found for approved shops");
    }

    return null;
  } catch (error) {
    console.error("Error processing new project post:", error);
    return null;
  }
});

// Planning/canvassing lifecycle statuses stored on users/{uid}/saved_projects.
const SAVED_PROJECT_STAGES = [
  "draft",
  "planning",
  "waiting for quotations",
  "receiving quotations",
  "supplier selected",
  "completed",
];

const STAGE_RECEIVING_QUOTATIONS = 3;
const STAGE_SUPPLIER_SELECTED = 4;

const LEGACY_STAGE_ALIASES = {
  "": 0,
  ready: 1,
  posted: 2,
  open: 2,
  has_quotations: 3,
  offer_accepted: 4,
  awarded: 4,
};

function savedProjectStage(status) {
  const value = String(status || "").toLowerCase().trim();
  const index = SAVED_PROJECT_STAGES.indexOf(value);
  if (index >= 0) return index;
  const alias = LEGACY_STAGE_ALIASES[value];
  return typeof alias === "number" ? alias : 0;
}

/**
 * Moves a builder's saved estimate forward, never backwards, and never past a
 * cycle the builder already marked complete.
 */
async function advanceSavedProject(userId, projectId, targetStage, extra = {}) {
  if (!userId || !projectId) return;

  const savedRef = db
    .collection("users")
    .doc(userId)
    .collection("saved_projects")
    .doc(projectId);

  const savedSnap = await savedRef.get();
  if (!savedSnap.exists) return;

  const currentStage = savedProjectStage(savedSnap.data().status);
  if (currentStage >= SAVED_PROJECT_STAGES.length - 1) return;
  if (currentStage >= targetStage) return;

  await savedRef.update({
    status: SAVED_PROJECT_STAGES[targetStage],
    updatedAt: Timestamp.now(),
    ...extra,
  });
}

/**
 * Recounts submitted quotations so the builder's tracking view and the bidding
 * board agree, even when a shop client forgets to bump the counter.
 */
async function syncPostQuotationState(postId) {
  const postRef = db.collection("projectPosts").doc(postId);
  const postSnap = await postRef.get();
  if (!postSnap.exists) return null;

  const post = postSnap.data() || {};
  const quotations = await postRef.collection("quotations").get();
  const quotationCount = quotations.size;

  const updates = { quotationCount, updatedAt: Timestamp.now() };
  const closedStatuses = ["closed", "cancelled", "awarded", "offer_accepted"];
  const isClosed =
    post.selectedQuotationId != null ||
    closedStatuses.includes(String(post.status || "").toLowerCase());

  if (!isClosed && quotationCount > 0 && post.status !== "has_quotations") {
    updates.status = "has_quotations";
  }

  await postRef.update(updates);

  if (!isClosed && quotationCount > 0) {
    await advanceSavedProject(
      post.userId,
      post.projectId,
      STAGE_RECEIVING_QUOTATIONS
    );
  }

  return post;
}

exports.onQuotationSubmitted = onDocumentCreated("projectPosts/{postId}/quotations/{shopId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return;

  const quotation = snapshot.data() || {};
  const postId = event.params.postId;
  const shopId = event.params.shopId;

  let post = null;
  try {
    // Auto-advance the builder's estimate to "Receiving Quotations".
    post = await syncPostQuotationState(postId);
  } catch (error) {
    logger.error("Error syncing quotation state:", error);
  }

  // Prefer the post owner — shop payloads sometimes put the shop uid in userId.
  const userId = (post && post.userId) || quotation.userId;
  if (!userId) {
    logger.warn(`No builder userId for quotation on post ${postId}`);
    return null;
  }

  try {
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
      logger.warn(`Builder profile missing for ${userId}; skipping FCM`);
      return null;
    }

    const userData = userDoc.data() || {};
    const fcmTokens = Array.isArray(userData.fcmTokens)
      ? userData.fcmTokens.filter((t) => typeof t === "string" && t.trim() !== "")
      : [];

    const shopName = quotation.shopName || "A hardware shop";
    const total = quotation.estimatedTotal != null
      ? Number(quotation.estimatedTotal)
      : null;
    const totalLabel = Number.isFinite(total)
      ? `₱${total.toLocaleString("en-PH")}`
      : "a quoted total";

    const title = "New quotation received";
    const message = `${shopName} sent a quotation (${totalLabel}) for your material estimate.`;

    const notificationRef = db.collection("notifications").doc();
    await notificationRef.set({
      type: "new_quotation",
      postId: postId,
      shopId: shopId,
      recipientId: userId,
      title: title,
      message: message,
      isRead: false,
      createdAt: Timestamp.now(),
    });

    if (fcmTokens.length === 0) {
      logger.info(`No FCM tokens for builder ${userId}; in-app notification only`);
      return null;
    }

    const payload = {
      notification: { title, body: message },
      data: {
        postId: String(postId),
        shopId: String(shopId),
        notificationId: String(notificationRef.id),
        type: "new_quotation",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "iconstruct_bids",
          priority: "high",
          defaultSound: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
      tokens: fcmTokens,
    };

    const messagingResponse = await admin.messaging().sendEachForMulticast(payload);
    logger.info(
      `Quotation FCM sent to ${userId}. success=${messagingResponse.successCount} failure=${messagingResponse.failureCount}`
    );

    // Drop invalid tokens so future pushes stay reliable.
    const staleTokens = [];
    messagingResponse.responses.forEach((resp, idx) => {
      if (!resp.success) {
        const code = resp.error && resp.error.code;
        if (
          code === "messaging/registration-token-not-registered" ||
          code === "messaging/invalid-registration-token"
        ) {
          staleTokens.push(fcmTokens[idx]);
        }
      }
    });
    if (staleTokens.length > 0) {
      await db.collection("users").doc(userId).set({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...staleTokens),
      }, { merge: true });
      logger.info(`Removed ${staleTokens.length} stale FCM token(s) for ${userId}`);
    }
  } catch (error) {
    logger.error("Error processing new quotation:", error);
  }
});

/**
 * Mirrors bidding progress onto the builder's saved estimate so Project
 * Tracking reflects "Receiving Quotations" and "Supplier Selected" without the
 * app having to write it.
 */
exports.onProjectPostUpdated = onDocumentUpdated("projectPosts/{postId}", async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (!after) return null;

  const userId = after.userId;
  const projectId = after.projectId;
  if (!userId || !projectId) return null;

  try {
    if (after.selectedQuotationId && !(before && before.selectedQuotationId)) {
      await advanceSavedProject(userId, projectId, STAGE_SUPPLIER_SELECTED, {
        selectedShopName: after.selectedShopName || null,
        supplierSelectedAt: Timestamp.now(),
      });
      return null;
    }

    const quotationCount = Number(after.quotationCount || 0);
    if (!after.selectedQuotationId && quotationCount > 0) {
      await advanceSavedProject(userId, projectId, STAGE_RECEIVING_QUOTATIONS);
    }
  } catch (error) {
    logger.error("Error mirroring project post status:", error);
  }

  return null;
});

exports.consultAIMaterials = onCall(
  {
    secrets: [GEMINI_API_KEY],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be signed in to use the iConstruct AI consultant."
      );
    }
    return runMaterialConsult({
      ...(request.data || {}),
      geminiSecret: GEMINI_API_KEY,
    });
  }
);

exports.generateAIBOM = onCall(
  {
    secrets: [GEMINI_API_KEY],
  },
  async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in to use the AI Planner.");
  }

  // Backward-compatible consult path (deployed name already exists in production)
  if ((request.data || {}).mode === "consult") {
    return runMaterialConsult({
      ...(request.data || {}),
      geminiSecret: GEMINI_API_KEY,
    });
  }

  const {
    projectType = "General Renovation",
    style = "Standard",
    areaSqm = 0,
    budgetLevel = "Medium",
    additionalNotes = ""
  } = request.data || {};

  const userPrompt = `Create an essential Bill of Materials (BOM) for this iConstruct estimate ONLY.
Project type: ${projectType}
Style: ${style}
Area: ${areaSqm} square meters
Budget Level: ${budgetLevel}
Additional Requirements:
${additionalNotes}

Return JSON:
{
  "materials": [
    {
      "name": "specific material name",
      "quantity": 1,
      "unit": "pcs|bags|sqm|L|gal|set",
      "category": "string"
    }
  ]
}

Rules:
- Prefer materials the builder already selected when listed in Additional Requirements
- Only basic hardware-store essentials for planning / canvassing
- 6–12 items max
- No vague labels
- No labor, scheduling, or construction management items`;

  const geminiKey = resolveGeminiKey(GEMINI_API_KEY);
  if (geminiKey) {
    try {
      const parsed = await callGeminiJson(geminiKey, {
        system: ICONSTRUCT_SYSTEM_SCOPE,
        user: userPrompt,
        temperature: 0.2,
      });
      const materials = Array.isArray(parsed)
        ? parsed
        : Array.isArray(parsed?.materials)
          ? parsed.materials
          : null;
      if (!materials) {
        throw new Error("Expected materials array");
      }
      return { success: true, materials, provider: "gemini" };
    } catch (error) {
      logger.error("Gemini BOM failed, trying OpenAI fallback:", error);
    }
  } else {
    logger.error("GEMINI_API_KEY is not configured.");
  }

  const openaiKey = process.env.OPENAI_API_KEY;
  if (openaiKey && String(openaiKey).trim()) {
    try {
      const parsed = await callOpenAiJson(String(openaiKey).trim(), {
        system: ICONSTRUCT_SYSTEM_SCOPE,
        user: userPrompt,
        temperature: 0.2,
      });
      const materials = Array.isArray(parsed)
        ? parsed
        : Array.isArray(parsed?.materials)
          ? parsed.materials
          : null;
      if (!materials) {
        throw new Error("Expected materials array");
      }
      return { success: true, materials, provider: "openai" };
    } catch (error) {
      logger.error("OpenAI BOM failed:", error);
    }
  }

  throw new HttpsError(
    "internal",
    "AI service is currently unavailable. Set GEMINI_API_KEY or OPENAI_API_KEY."
  );
  }
);
