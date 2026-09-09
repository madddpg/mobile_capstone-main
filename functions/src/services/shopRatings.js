"use strict";

/**
 * Aggregates builder ratings onto the shop document.
 *
 * The average has to be computed with the Admin SDK rather than by the app:
 * builders cannot write to a shop document, and a client that could set its own
 * supplier's score would make the rating worthless. Recomputing from the raw
 * ratings after every write also keeps the figure correct when a rating is
 * edited or withdrawn, which an incremental counter would not.
 */

/**
 * Mean of the given star values, rounded to two decimals.
 *
 * Anything outside one to five is dropped rather than clamped: a value that far
 * out means something wrote a bad document, and averaging it in would quietly
 * move a real shop's score.
 */
function summarise(starValues) {
  const valid = starValues.filter(
    (n) => typeof n === "number" && Number.isFinite(n) && n >= 1 && n <= 5
  );
  if (valid.length === 0) return { rating: 0, ratingCount: 0 };

  const total = valid.reduce((sum, n) => sum + n, 0);
  return {
    rating: Math.round((total / valid.length) * 100) / 100,
    ratingCount: valid.length,
  };
}

/**
 * Reads every rating for a shop and writes the summary back onto it.
 *
 * A shop realistically collects tens of ratings, not thousands, so reading the
 * subcollection is cheaper and simpler than maintaining a running total that
 * can drift out of step with the documents it claims to describe.
 */
async function recomputeShopRating(db, shopId) {
  const snap = await db
    .collection("shops")
    .doc(shopId)
    .collection("ratings")
    .get();

  const stars = snap.docs.map((d) => {
    const value = (d.data() || {}).stars;
    return typeof value === "number" ? value : Number(value);
  });

  const summary = summarise(stars);

  await db.collection("shops").doc(shopId).set(
    {
      rating: summary.rating,
      ratingCount: summary.ratingCount,
      ratingUpdatedAt: new Date(),
    },
    { merge: true }
  );

  return summary;
}

module.exports = { summarise, recomputeShopRating };
