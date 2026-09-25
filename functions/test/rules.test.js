"use strict";

/**
 * Security rules tests, run against the Firestore emulator.
 *
 * These cover the rules changed this week. Every serious problem found in the
 * audit lived in this layer, including one introduced while fixing the others,
 * and none of it was covered by anything: the unit tests all exercise pure
 * logic and pass regardless of what the rules say.
 *
 * Both directions are tested deliberately. Asserting only that the bad writes
 * fail is how a ruleset that blocks everything ships green, so each denial is
 * paired with the legitimate write it must not have broken.
 *
 * Run with:
 *   firebase emulators:exec --only firestore "node test/rules.test.js"
 *
 * Needs Java 21 or above for the emulator.
 */

const fs = require("fs");
const path = require("path");
const assert = require("assert");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");

const BUILDER = "builder-uid";
const OTHER_BUILDER = "other-builder-uid";
const SHOP = "shop-uid";
const POST = "post-1";

let passed = 0;
let failed = 0;
let testEnv;

async function test(name, fn) {
  try {
    await testEnv.clearFirestore();
    await seed();
    await fn();
    passed++;
    console.log("  ok   " + name);
  } catch (err) {
    failed++;
    console.log("  FAIL " + name);
    console.log("       " + (err && err.message ? err.message : err));
  }
}

/** Baseline data every test starts from, written with rules disabled. */
async function seed() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();

    // shopIsApproved() reads this document, so it has to exist.
    await db.doc(`shops/${SHOP}`).set({
      uid: SHOP,
      shopName: "Calamba Builders Hardware",
      status: "approved",
      subscriptionStatus: "active",
    });

    await db.doc(`projectPosts/${POST}`).set({
      userId: BUILDER,
      projectName: "Bathroom Renovation",
      projectId: "saved-1",
      materials: [{ name: "Portland Cement", quantity: 8 }],
      status: "open",
      quotationCount: 1,
    });

    // Quotation documents are keyed by shop id, which the create rule enforces.
    await db.doc(`projectPosts/${POST}/quotations/${SHOP}`).set({
      shopId: SHOP,
      postId: POST,
      status: "submitted",
      estimatedTotal: 5000,
      items: [
        { name: "Portland Cement", unitPrice: 260, quantity: 8 },
        { name: "Floor Tiles", subtotal: 2920 },
      ],
    });
  });
}

const asBuilder = () => testEnv.authenticatedContext(BUILDER).firestore();
const asShop = () => testEnv.authenticatedContext(SHOP).firestore();

async function run() {
  testEnv = await initializeTestEnvironment({
    projectId: "demo-iconstruct",
    firestore: {
      rules: fs.readFileSync(
        path.resolve(__dirname, "../../firestore.rules"),
        "utf8"
      ),
    },
  });

  console.log("\nquotations — a shop may revise an offer, not a decision");

  await test("a shop can revise its own quotation while it is open", async () => {
    await assertSucceeds(
      asShop()
        .doc(`projectPosts/${POST}/quotations/${SHOP}`)
        .update({ estimatedTotal: 4800 })
    );
  });

  await test("a shop cannot change a quotation the builder accepted", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .doc(`projectPosts/${POST}/quotations/${SHOP}`)
        .update({ status: "accepted" });
    });
    // The whole point of the fix: after acceptance this is a record of what
    // was agreed, not an offer the counterparty can still edit.
    await assertFails(
      asShop()
        .doc(`projectPosts/${POST}/quotations/${SHOP}`)
        .update({ estimatedTotal: 9999 })
    );
  });

  await test("a shop cannot reopen lines on a partly accepted quotation", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .doc(`projectPosts/${POST}/quotations/${SHOP}`)
        .update({
          status: "partially_accepted",
          acceptedTotal: 2080,
          items: [
            { name: "Portland Cement", unitPrice: 260, quantity: 8, accepted: true },
            { name: "Floor Tiles", subtotal: 2920, accepted: false },
          ],
        });
    });
    await assertFails(
      asShop()
        .doc(`projectPosts/${POST}/quotations/${SHOP}`)
        .update({
          items: [
            { name: "Portland Cement", unitPrice: 260, quantity: 8, accepted: true },
            { name: "Floor Tiles", subtotal: 2920, accepted: true },
          ],
        })
    );
  });

  await test("a shop cannot declare its own quotation accepted", async () => {
    await assertFails(
      asShop()
        .doc(`projectPosts/${POST}/quotations/${SHOP}`)
        .update({ status: "accepted" })
    );
  });

  await test("a shop cannot write the builder's accepted total", async () => {
    await assertFails(
      asShop()
        .doc(`projectPosts/${POST}/quotations/${SHOP}`)
        .update({ acceptedTotal: 5000 })
    );
  });

  console.log("\nquotations — the builder's acceptance still works");

  await test("a builder can accept a quotation line by line", async () => {
    // The path the app actually takes. If this fails, per-line acceptance is
    // dead no matter how well the denials above hold.
    await assertSucceeds(
      asBuilder()
        .doc(`projectPosts/${POST}/quotations/${SHOP}`)
        .update({
          status: "partially_accepted",
          acceptedTotal: 2080,
          items: [
            { name: "Portland Cement", unitPrice: 260, quantity: 8, accepted: true },
            { name: "Floor Tiles", subtotal: 2920, accepted: false },
          ],
        })
    );
  });

  await test("a builder cannot accept someone else's quotation", async () => {
    await assertFails(
      testEnv
        .authenticatedContext(OTHER_BUILDER)
        .firestore()
        .doc(`projectPosts/${POST}/quotations/${SHOP}`)
        .update({ status: "accepted" })
    );
  });

  console.log("\nprojectPosts — the estimate is pinned once quoting starts");

  await test("a builder cannot change materials after a shop has quoted", async () => {
    // Otherwise a quotation ends up describing a list that no longer exists,
    // with neither side able to tell.
    await assertFails(
      asBuilder()
        .doc(`projectPosts/${POST}`)
        .update({ materials: [{ name: "Something else", quantity: 1 }] })
    );
  });

  await test("a builder can change materials before any shop has quoted", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(`projectPosts/${POST}`).update({ quotationCount: 0 });
    });
    await assertSucceeds(
      asBuilder()
        .doc(`projectPosts/${POST}`)
        .update({ materials: [{ name: "Something else", quantity: 1 }] })
    );
  });

  await test("a builder cannot add a price to their own estimate", async () => {
    await assertFails(
      asBuilder().doc(`projectPosts/${POST}`).update({ estimatedTotal: 1 })
    );
  });

  await test("a builder cannot select a shop that never quoted", async () => {
    await assertFails(
      asBuilder().doc(`projectPosts/${POST}`).update({
        selectedShopId: "some-other-shop",
        selectedQuotationId: "some-other-shop",
      })
    );
  });

  await test("a builder can select the shop whose quotation they accepted", async () => {
    // This is the clause I got wrong first time by assuming the document id is
    // always the shop id. It is verified through the quotation itself now.
    await assertSucceeds(
      asBuilder().doc(`projectPosts/${POST}`).update({
        selectedShopId: SHOP,
        selectedQuotationId: SHOP,
        status: "offer_accepted",
      })
    );
  });

  await test("a builder can link a re-canvass of the dropped lines after quoting", async () => {
    // Partial acceptance posts what was left as a new estimate and records
    // its id on the original, which already has a quotation on it.
    await assertSucceeds(
      asBuilder().doc(`projectPosts/${POST}`).update({ remainderPostId: "post-2" })
    );
  });

  console.log("\nprojectPosts — shops quote estimates, they do not raise them");

  await test("an approved shop cannot create a project post", async () => {
    // Closing the self-rating route: a shop that could post an estimate could
    // name itself the supplier on it and then rate itself.
    await assertFails(
      asShop().doc("projectPosts/shop-made-post").set({
        userId: SHOP,
        projectName: "Fake project",
        materials: [],
        status: "open",
        quotationCount: 0,
      })
    );
  });

  await test("a builder can still create a project post", async () => {
    await assertSucceeds(
      asBuilder().doc("projectPosts/post-2").set({
        userId: BUILDER,
        projectName: "Kitchen Renovation",
        materials: [{ name: "Floor Tiles", quantity: 40 }],
        status: "open",
        quotationCount: 0,
      })
    );
  });

  console.log("\nconversations — chat opens once the builder buys from the shop");

  /** Sets the quotation's status, then has the builder open the chat. */
  async function openChatAfter(status) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .doc(`projectPosts/${POST}/quotations/${SHOP}`)
        .update({ status });
    });
    return asBuilder().doc(`conversations/${POST}_${SHOP}`).set({
      projectId: POST,
      quotationId: SHOP,
      shopId: SHOP,
      builderId: BUILDER,
      userId: BUILDER,
      status: "open",
    });
  }

  await test("a builder can open chat with a shop they accepted in full", async () => {
    await assertSucceeds(openChatAfter("accepted"));
  });

  await test("a builder can open chat with a shop they accepted in part", async () => {
    // Keeping only some lines is still buying from the shop. This was denied,
    // so "Message shop" failed right after a partial acceptance.
    await assertSucceeds(openChatAfter("partially_accepted"));
  });

  await test("chat does not open while the quotation is still pending", async () => {
    await assertFails(openChatAfter("submitted"));
  });

  await test("chat does not open with a shop the builder turned down", async () => {
    await assertFails(openChatAfter("rejected"));
  });

  // The shop dashboard's onQuotationAccepted function creates the same thread
  // on acceptance, with builderId only. When it gets there first, the app must
  // be able to read that thread and use it: writing it again is refused as an
  // edit, which is how re-selecting a shop after a cancellation left the
  // builder with an error instead of the chat.
  await test("a builder can read and write in a thread the dashboard created", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.doc(`projectPosts/${POST}/quotations/${SHOP}`).update({ status: "accepted" });
      await db.doc(`conversations/${POST}_${SHOP}`).set({
        projectId: POST,
        quotationId: SHOP,
        shopId: SHOP,
        builderId: BUILDER,
        status: "open",
      });
    });
    const thread = asBuilder().doc(`conversations/${POST}_${SHOP}`);
    await assertSucceeds(thread.get());
    await assertSucceeds(
      thread.collection("messages").add({
        senderId: BUILDER,
        senderRole: "builder",
        text: "Hi, when can you deliver?",
      })
    );
  });

  console.log("\nquotations — a shop cannot fake one");

  const SHOP_2 = "shop-2-uid";
  const SHOP_2_NAME = "Lipa Construction Supply";
  const asShop2 = () => testEnv.authenticatedContext(SHOP_2).firestore();

  /** A second approved shop that has not quoted yet, plus optional post changes. */
  async function seedSecondShop(postChanges) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await db.doc(`shops/${SHOP_2}`).set({
        uid: SHOP_2,
        shopName: SHOP_2_NAME,
        status: "approved",
        subscriptionStatus: "active",
      });
      if (postChanges) await db.doc(`projectPosts/${POST}`).update(postChanges);
    });
  }

  /** What an honest shop sends, with any field replaced by [changes]. */
  function offer(changes = {}) {
    return {
      shopId: SHOP_2,
      postId: POST,
      shopName: SHOP_2_NAME,
      status: "submitted",
      estimatedTotal: 4200,
      items: [{ name: "Portland Cement", unitPrice: 255, quantity: 8 }],
      ...changes,
    };
  }

  const shop2Quote = () => asShop2().doc(`projectPosts/${POST}/quotations/${SHOP_2}`);

  await test("an approved shop can still send an honest quotation", async () => {
    // The legitimate path. If this fails, no shop can quote at all.
    await seedSecondShop();
    await assertSucceeds(shop2Quote().set(offer()));
  });

  await test("a quotation cannot arrive already accepted", async () => {
    await seedSecondShop();
    await assertFails(shop2Quote().set(offer({ status: "accepted" })));
  });

  await test("a quotation cannot arrive partly accepted", async () => {
    await seedSecondShop();
    await assertFails(
      shop2Quote().set(offer({ status: "partially_accepted", acceptedTotal: 2040 }))
    );
  });

  await test("an open quotation cannot carry an accepted total", async () => {
    await seedSecondShop();
    await assertFails(shop2Quote().set(offer({ acceptedTotal: 4200 })));
  });

  await test("a shop cannot file extra quotations under other ids", async () => {
    // One offer per shop per estimate. Extra documents flooded the builder
    // with pushes and inflated the quotation count.
    await seedSecondShop();
    await assertFails(
      asShop2().doc(`projectPosts/${POST}/quotations/fake-offer-1`).set(offer())
    );
  });

  await test("a shop cannot quote an estimate that does not exist", async () => {
    await seedSecondShop();
    await assertFails(
      asShop2()
        .doc(`projectPosts/no-such-post/quotations/${SHOP_2}`)
        .set(offer({ postId: "no-such-post" }))
    );
  });

  await test("a shop cannot quote after the builder chose a supplier", async () => {
    await seedSecondShop({
      selectedQuotationId: SHOP,
      selectedShopId: SHOP,
      status: "offer_accepted",
    });
    await assertFails(shop2Quote().set(offer()));
  });

  await test("a shop cannot quote under another shop's name", async () => {
    await seedSecondShop();
    await assertFails(
      shop2Quote().set(offer({ shopName: "Calamba Builders Hardware" }))
    );
  });

  await test("a shop cannot write a quotation outside a project post", async () => {
    // The dashboard's collection-group rule used to allow this anywhere a
    // collection happened to be called "quotations".
    await seedSecondShop();
    await assertFails(
      asShop2().doc(`conversations/c-1/quotations/${SHOP_2}`).set(offer())
    );
  });

  await test("a shop cannot mark its own offer rejected", async () => {
    await assertFails(
      asShop()
        .doc(`projectPosts/${POST}/quotations/${SHOP}`)
        .update({ status: "rejected" })
    );
  });

  await test("a shop cannot rename itself on an open offer", async () => {
    await seedSecondShop();
    await assertFails(
      asShop()
        .doc(`projectPosts/${POST}/quotations/${SHOP}`)
        .update({ shopName: SHOP_2_NAME })
    );
  });

  console.log("\nshops — a shop cannot set its own rating");

  await test("a shop owner can still edit their storefront", async () => {
    await assertSucceeds(
      asShop().doc(`shops/${SHOP}`).update({ address: "J.P. Rizal St., Calamba" })
    );
  });

  for (const field of ["rating", "ratingCount", "averageRating", "reviewCount"]) {
    await test(`a shop owner cannot write ${field} on their own shop`, async () => {
      await assertFails(asShop().doc(`shops/${SHOP}`).update({ [field]: 5 }));
    });
  }

  const NEW_SHOP = "new-shop-uid";
  const newShopDoc = () =>
    testEnv.authenticatedContext(NEW_SHOP).firestore().doc(`shops/${NEW_SHOP}`);

  await test("a new shop can still register", async () => {
    await assertSucceeds(
      newShopDoc().set({
        uid: NEW_SHOP,
        shopName: "Tanauan Hardware",
        subscriptionPlan: "basic",
        status: "pending",
      })
    );
  });

  await test("a new shop cannot register with a rating already set", async () => {
    await assertFails(
      newShopDoc().set({
        uid: NEW_SHOP,
        shopName: "Tanauan Hardware",
        subscriptionPlan: "basic",
        status: "pending",
        rating: 5,
        ratingCount: 120,
      })
    );
  });

  await testEnv.cleanup();

  console.log(`\n${passed} passed, ${failed} failed\n`);
  process.exit(failed === 0 ? 0 : 1);
}

run().catch((err) => {
  console.error("Rules test harness failed to start:", err);
  process.exit(1);
});
