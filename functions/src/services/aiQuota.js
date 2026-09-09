"use strict";

/**
 * Per-account daily cap on the AI endpoints.
 *
 * Both AI callables previously checked only that the caller was signed in.
 * One account could therefore call Gemini without limit, on the project's key,
 * and the only spend control was the scope guard refusing off-topic prompts —
 * which reduces cost but does not bound it.
 *
 * The counter lives in Firestore rather than in memory because Cloud Functions
 * scale to many instances and a per-instance counter would let the limit be
 * multiplied by the number of running instances.
 */

const { HttpsError } = require("firebase-functions/v2/https");

/** Calls per account per day, across both AI endpoints combined. */
const DAILY_LIMIT = 40;

const COLLECTION = "ai_usage";

/**
 * The day a request belongs to, in Philippine time.
 *
 * Using UTC would roll the allowance over mid-afternoon locally, which is the
 * middle of a working day for the builders this serves.
 */
function manilaDayKey(now = new Date()) {
  const manila = new Date(now.getTime() + 8 * 60 * 60 * 1000);
  return manila.toISOString().slice(0, 10);
}

/**
 * Records one AI call for a user and refuses once past the daily allowance.
 *
 * Runs as a transaction so two requests arriving together cannot both read the
 * same count and each believe there is room.
 *
 * Throws `resource-exhausted` when the allowance is spent. A failure to read
 * the counter is deliberately allowed through: losing the ability to consult
 * because a counter write failed is worse than one uncounted call.
 */
async function consumeAiCall(db, uid, { limit = DAILY_LIMIT } = {}) {
  if (!uid) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }

  const ref = db.collection(COLLECTION).doc(uid);
  const day = manilaDayKey();

  try {
    return await db.runTransaction(async (txn) => {
      const snap = await txn.get(ref);
      const data = snap.exists ? snap.data() || {} : {};

      // A stored day that is not today means the allowance has rolled over,
      // so the count starts again rather than accumulating forever.
      const used = data.day === day && typeof data.count === "number"
        ? data.count
        : 0;

      if (used >= limit) {
        throw new HttpsError(
          "resource-exhausted",
          `You have used the AI planner ${limit} times today. ` +
            "It resets tomorrow — the renovation templates are still available."
        );
      }

      txn.set(ref, { day, count: used + 1, updatedAt: new Date() }, { merge: true });
      return { used: used + 1, limit, remaining: limit - used - 1 };
    });
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    // Counter unavailable. Let the call through rather than taking the feature
    // down over bookkeeping.
    return { used: 0, limit, remaining: limit, uncounted: true };
  }
}

module.exports = { consumeAiCall, manilaDayKey, DAILY_LIMIT };
