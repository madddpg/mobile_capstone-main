"use strict";

/**
 * Recomputes every shop's rating summary from its actual builder ratings.
 *
 * Before the security rules were tightened, a shop owner could write the
 * rating fields on their own shop document, and the Cloud Function only
 * recalculates a shop when a builder rates it. A score a shop gave itself
 * would therefore stand until its next genuine rating. Run this once after
 * deploying the rules. It replaces every summary with what the shop's rating
 * documents support, and removes the alternative field names that nothing
 * reads any more.
 *
 * Usage (Application Default Credentials):
 *   set GOOGLE_APPLICATION_CREDENTIALS=path\\to\\serviceAccount.json
 *   node functions/scripts/recompute_shop_ratings.js --project <firebase-project-id> --dry-run
 *   node functions/scripts/recompute_shop_ratings.js --project <firebase-project-id>
 *
 * --dry-run prints what would change and writes nothing.
 */

const admin = require("firebase-admin");
const { summarise } = require("../src/services/shopRatings");

/** Spellings the app once fell back to. Nothing should read them now. */
const LEGACY_FIELDS = [
  "averageRating",
  "ratingAverage",
  "ratingsCount",
  "reviewCount",
];

function parseArgs(argv) {
  const args = { projectId: null, dryRun: false };
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === "--project") args.projectId = argv[i + 1] || null;
    if (argv[i] === "--dry-run") args.dryRun = true;
  }
  return args;
}

async function main() {
  const { projectId, dryRun } = parseArgs(process.argv.slice(2));
  admin.initializeApp(projectId ? { projectId } : undefined);
  const db = admin.firestore();
  const { FieldValue } = admin.firestore;

  const shops = await db.collection("shops").get();
  let changed = 0;

  for (const shopDoc of shops.docs) {
    const data = shopDoc.data() || {};
    const ratings = await shopDoc.ref.collection("ratings").get();
    const summary = summarise(
      ratings.docs.map((d) => {
        const value = (d.data() || {}).stars;
        return typeof value === "number" ? value : Number(value);
      })
    );

    const legacy = LEGACY_FIELDS.filter((field) => field in data);
    const alreadyRight =
      data.rating === summary.rating &&
      data.ratingCount === summary.ratingCount &&
      legacy.length === 0;
    if (alreadyRight) continue;

    changed += 1;
    console.log(
      `${dryRun ? "[dry-run] " : ""}${shopDoc.id} (${data.shopName || "unnamed"}): ` +
        `${data.rating ?? "-"} from ${data.ratingCount ?? "-"} -> ` +
        `${summary.rating} from ${summary.ratingCount}` +
        (legacy.length ? `, removing ${legacy.join(", ")}` : "")
    );
    if (dryRun) continue;

    const update = {
      rating: summary.rating,
      ratingCount: summary.ratingCount,
      ratingUpdatedAt: FieldValue.serverTimestamp(),
    };
    for (const field of legacy) update[field] = FieldValue.delete();
    await shopDoc.ref.update(update);
  }

  console.log(
    `${shops.size} shops checked, ${changed} ${dryRun ? "would change" : "updated"}.`
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
