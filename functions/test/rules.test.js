"use strict";

/**
 * Security rules tests for the shared Firestore and Storage rules, run
 * against the emulators.
 *
 * The web shop dashboard and the builder app share one Firebase project and
 * so one ruleset: deploying a copy that suits only one app breaks the other.
 * Every legitimate write here is shaped like what that app really stores —
 * the dashboard's quotations have a random id, `projectId`, `amount` and
 * status "pending" — so a rule change that breaks either app fails here
 * before it reaches production.
 *
 * Both directions are tested deliberately. Asserting only that the bad writes
 * fail is how a ruleset that blocks everything ships green, so each denial is
 * paired with the legitimate write it must not have broken.
 *
 * Run with:
 *   firebase emulators:exec --only firestore,storage "node test/rules.test.js"
 *
 * Needs Java 21 or above for the emulators.
 */

const fs = require("fs");
const path = require("path");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const firebase = require("firebase/compat/app");

const BUILDER = "builder-uid";
const OTHER_BUILDER = "other-builder-uid";
const SHOP = "shop-uid";
const SHOP_NAME = "Calamba Builders Hardware";
const SHOP_2 = "shop-2-uid";
const SHOP_2_NAME = "Lipa Construction Supply";
const POST = "post-1";
// The dashboard files quotations under random ids, not under the shop's uid.
const QUOTE = "q7Hs2kXbL0pWm3";
const CONV = `${POST}_${SHOP}`;

let passed = 0;
let failed = 0;
let skipped = 0;

// Protections from the full merge that the web dashboard has not yet agreed
// to. Off by default so the suite matches the rules deployed today; run with
// PROPOSED_RULES=1 against the proposed merged rules to check them.
const RUN_PROPOSED = process.env.PROPOSED_RULES === "1";

async function proposed(name, fn) {
  if (!RUN_PROPOSED) {
    skipped++;
    return;
  }
  return test(name, fn);
}
let testEnv;

const ts = () => firebase.firestore.FieldValue.serverTimestamp();

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

/** A quotation as the dashboard's insertQuotation() writes it. */
function dashboardQuote(changes = {}) {
  return {
    shopId: SHOP,
    shopName: SHOP_NAME,
    projectId: POST,
    projectTitle: "Bathroom Renovation",
    builderId: BUILDER,
    amount: 5000,
    status: "pending",
    note: "",
    quotedCount: 2,
    declinedCount: 0,
    substitutedCount: 1,
    items: [
      { productName: "Portland Cement", qty: 8, price: 260, subtotal: 2080 },
      {
        productName: "laway",
        requestedName: "Tile Adhesive (25 kg)",
        status: "substituted",
        qty: 2,
        price: 1460,
        subtotal: 2920,
      },
    ],
    ...changes,
  };
}

/** Baseline data every test starts from, written with rules disabled. */
async function seed() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();

    for (const [uid, shopName] of [[SHOP, SHOP_NAME], [SHOP_2, SHOP_2_NAME]]) {
      await db.doc(`shops/${uid}`).set({
        uid,
        shopName,
        email: `${uid}@example.com`,
        status: "approved",
        subscriptionPlan: "basic",
        subscriptionStatus: "active",
        documents: [],
      });
    }

    await db.doc(`projectPosts/${POST}`).set({
      postId: POST,
      userId: BUILDER,
      builderId: BUILDER,
      projectName: "Bathroom Renovation",
      projectId: "saved-1",
      ownerName: "Cups Cuddles",
      materials: [
        { name: "Portland Cement", quantity: 8 },
        { name: "Tile Adhesive (25 kg)", quantity: 2 },
      ],
      status: "has_quotations",
      quotationCount: 1,
    });

    await db.doc(`projectPosts/${POST}/quotations/${QUOTE}`).set(dashboardQuote());
    await db.doc(`users/${BUILDER}/saved_projects/saved-1`).set({ status: "receiving quotations" });
  });
}

const asBuilder = () => testEnv.authenticatedContext(BUILDER).firestore();
const asOtherBuilder = () => testEnv.authenticatedContext(OTHER_BUILDER).firestore();
const asShop = () => testEnv.authenticatedContext(SHOP).firestore();
const asShop2 = () => testEnv.authenticatedContext(SHOP_2).firestore();
const asGuest = () => testEnv.unauthenticatedContext().firestore();
const quote = (db) => db.doc(`projectPosts/${POST}/quotations/${QUOTE}`);

/** Puts the estimate in the state after the builder chose this shop. */
async function markSelected(status = "partially_accepted") {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc(`projectPosts/${POST}/quotations/${QUOTE}`).update({ status });
    await db.doc(`projectPosts/${POST}`).update({
      selectedQuotationId: QUOTE,
      selectedShopId: SHOP,
      selectedShopName: SHOP_NAME,
      status: "offer_accepted",
    });
  });
}

/** A chat thread as either app leaves it, with the quotation accepted. */
async function seedConversation() {
  await markSelected("accepted");
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`conversations/${CONV}`).set({
      projectId: POST,
      quotationId: QUOTE,
      shopId: SHOP,
      shopName: SHOP_NAME,
      builderId: BUILDER,
      builderName: "Cups Cuddles",
      projectTitle: "Bathroom Renovation",
      status: "open",
      lastMessage: "Quote accepted",
      lastSenderId: "",
    });
  });
}

async function run() {
  testEnv = await initializeTestEnvironment({
    projectId: "demo-iconstruct",
    firestore: {
      rules: fs.readFileSync(process.env.FIRESTORE_RULES || path.resolve(__dirname, "../../firestore.rules"), "utf8"),
    },
    storage: {
      rules: fs.readFileSync(process.env.STORAGE_RULES || path.resolve(__dirname, "../../storage.rules"), "utf8"),
    },
  });

  // ── Quotations: the dashboard sends them ─────────────────────────────────

  console.log("\nquotations — the dashboard's real submission still works");

  const newQuote = (db) => db.collection(`projectPosts/${POST}/quotations`).doc();

  await test("an approved shop can send a quotation the way the dashboard does", async () => {
    // The legitimate path. If this fails, no shop can quote at all.
    await assertSucceeds(
      newQuote(asShop2()).set(
        dashboardQuote({ shopId: SHOP_2, shopName: SHOP_2_NAME, createdAt: ts(), updatedAt: ts() })
      )
    );
  });

  await test("the shop can bump the estimate's quotation count", async () => {
    await assertSucceeds(
      asShop2().doc(`projectPosts/${POST}`).update({ quotationCount: 2, updatedAt: ts() })
    );
  });

  await proposed("a quotation cannot arrive already accepted", async () => {
    await assertFails(
      newQuote(asShop2()).set(dashboardQuote({ shopId: SHOP_2, status: "accepted" }))
    );
  });

  await proposed("a quotation cannot arrive with an accepted total", async () => {
    await assertFails(
      newQuote(asShop2()).set(dashboardQuote({ shopId: SHOP_2, acceptedTotal: 4200 }))
    );
  });

  await test("a shop cannot send a quotation in another shop's name", async () => {
    await assertFails(newQuote(asShop2()).set(dashboardQuote()));
  });

  await proposed("a shop cannot quote an estimate that does not exist", async () => {
    await assertFails(
      asShop2()
        .collection("projectPosts/no-such-post/quotations")
        .doc()
        .set(dashboardQuote({ shopId: SHOP_2, projectId: "no-such-post" }))
    );
  });

  await proposed("a shop cannot file a quotation under the wrong estimate", async () => {
    await assertFails(
      newQuote(asShop2()).set(dashboardQuote({ shopId: SHOP_2, projectId: "post-9" }))
    );
  });

  await proposed("a shop cannot quote after the builder chose a supplier", async () => {
    await markSelected();
    await assertFails(newQuote(asShop2()).set(dashboardQuote({ shopId: SHOP_2 })));
  });

  await proposed("a shop cannot write a quotation outside a project post", async () => {
    // The dashboard's collection-group rule used to allow this anywhere a
    // collection happened to be called "quotations".
    await assertFails(
      asShop2().doc(`conversations/c-1/quotations/x`).set(dashboardQuote({ shopId: SHOP_2 }))
    );
  });

  console.log("\nquotations — a sent offer is the shop's word, the decision the builder's");

  await test("a shop cannot edit its quotation after sending it", async () => {
    await assertFails(quote(asShop()).update({ amount: 4800 }));
  });

  await test("a shop cannot declare its own quotation accepted", async () => {
    await assertFails(quote(asShop()).update({ status: "accepted" }));
  });

  await test("a shop cannot mark its own offer rejected", async () => {
    await assertFails(quote(asShop()).update({ status: "rejected" }));
  });

  await test("a shop cannot write the builder's accepted total", async () => {
    await assertFails(quote(asShop()).update({ acceptedTotal: 5000 }));
  });

  await test("a shop can withdraw an offer the builder has not decided on", async () => {
    await assertSucceeds(quote(asShop()).delete());
  });

  await proposed("a shop can withdraw an offer a cancellation reopened", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await quote(ctx.firestore()).update({ status: "submitted" });
    });
    await assertSucceeds(quote(asShop()).delete());
  });

  await test("a shop cannot delete a quotation the builder accepted", async () => {
    await markSelected("accepted");
    await assertFails(quote(asShop()).delete());
  });

  // ── Quotations: the app decides them ─────────────────────────────────────

  console.log("\nquotations — the builder app's acceptance works on real quotations");

  const keptLines = [
    { productName: "Portland Cement", qty: 8, price: 260, subtotal: 2080, accepted: true },
    {
      productName: "laway",
      requestedName: "Tile Adhesive (25 kg)",
      status: "substituted",
      qty: 2,
      price: 1460,
      subtotal: 2920,
      accepted: false,
    },
  ];

  await test("a builder can accept a dashboard quotation line by line", async () => {
    // The app's acceptQuotation transaction. Real quotations carry `amount`
    // and no `estimatedTotal`; a rule that compared estimatedTotal refused
    // every one of them.
    const db = asBuilder();
    const batch = db.batch();
    batch.update(quote(db), {
      status: "partially_accepted",
      acceptedAt: ts(),
      items: keptLines,
      acceptedTotal: 2080,
    });
    batch.update(db.doc(`projectPosts/${POST}`), {
      selectedQuotationId: QUOTE,
      selectedShopId: SHOP,
      selectedShopName: SHOP_NAME,
      status: "offer_accepted",
      acceptedAt: ts(),
      updatedAt: ts(),
    });
    batch.update(db.doc(`users/${BUILDER}/saved_projects/saved-1`), { status: "supplier selected" });
    await assertSucceeds(batch.commit());
  });

  await test("a builder can turn down the other open offers", async () => {
    await assertSucceeds(quote(asBuilder()).update({ status: "rejected", acceptedAt: ts() }));
  });

  await test("a builder cannot change a shop's prices while accepting", async () => {
    await assertFails(quote(asBuilder()).update({ status: "accepted", amount: 1 }));
  });

  await proposed("a builder cannot drop lines from the quotation", async () => {
    await assertFails(
      quote(asBuilder()).update({ status: "partially_accepted", items: [keptLines[0]] })
    );
  });

  await test("a builder cannot accept someone else's quotation", async () => {
    await assertFails(quote(asOtherBuilder()).update({ status: "accepted" }));
  });

  // ── Estimates ────────────────────────────────────────────────────────────

  console.log("\nprojectPosts — the estimate is pinned once quoting starts");

  await test("a builder can post an estimate the way the app does", async () => {
    await assertSucceeds(
      asBuilder().doc("projectPosts/post-2").set({
        postId: "post-2",
        userId: BUILDER,
        builderId: BUILDER,
        projectId: "saved-2",
        projectName: "Kitchen Renovation",
        ownerName: "Cups Cuddles",
        materials: [{ name: "Floor Tiles", quantity: 40 }],
        materialsCount: 1,
        totalAreaSqm: 12,
        budget: "medium",
        coverage: "full",
        renovationTypes: ["cosmetic"],
        status: "open",
        quotationCount: 0,
        postedAt: ts(),
        updatedAt: ts(),
      })
    );
  });

  await proposed("an approved shop cannot create a project post", async () => {
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

  await proposed("a builder cannot change materials after a shop has quoted", async () => {
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

  await proposed("a builder cannot add a price to their own estimate", async () => {
    await assertFails(asBuilder().doc(`projectPosts/${POST}`).update({ estimatedTotal: 1 }));
  });

  await proposed("a builder cannot select a shop that never quoted", async () => {
    await assertFails(
      asBuilder().doc(`projectPosts/${POST}`).update({
        selectedShopId: "some-other-shop",
        selectedQuotationId: QUOTE,
      })
    );
  });

  await test("a builder can link a re-canvass of the lines they did not take", async () => {
    await markSelected();
    await assertSucceeds(
      asBuilder().doc(`projectPosts/${POST}`).update({
        remainderPostId: "post-2",
        remainderQuotationId: QUOTE,
        updatedAt: ts(),
      })
    );
  });

  await test("a shop cannot change an estimate beyond its quotation count", async () => {
    await assertFails(asShop().doc(`projectPosts/${POST}`).update({ status: "closed" }));
  });

  await proposed("a builder can read the cancellation record, and nobody can write it", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(`projectPosts/${POST}/events/e1`).set({ type: "supplier_cancelled" });
    });
    await assertSucceeds(asBuilder().doc(`projectPosts/${POST}/events/e1`).get());
    await assertFails(asBuilder().doc(`projectPosts/${POST}/events/e2`).set({ type: "fake" }));
  });

  // ── Chat ─────────────────────────────────────────────────────────────────

  console.log("\nconversations — chat opens once the builder buys from the shop");

  async function openChatAfter(status) {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await quote(ctx.firestore()).update({ status });
    });
    return asBuilder().doc(`conversations/${CONV}`).set({
      projectId: POST,
      quotationId: QUOTE,
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
    await assertSucceeds(openChatAfter("partially_accepted"));
  });

  await test("chat does not open while the quotation is still pending", async () => {
    await assertFails(openChatAfter("pending"));
  });

  await test("chat does not open with a shop the builder turned down", async () => {
    await assertFails(openChatAfter("rejected"));
  });

  await test("a builder can use a thread the dashboard's function created", async () => {
    // onQuotationAccepted creates the thread with builderId only. The app has
    // to read it and write in it rather than create it a second time.
    await seedConversation();
    await assertSucceeds(asBuilder().doc(`conversations/${CONV}`).get());
  });

  console.log("\nmessages — both apps' message shapes");

  const messages = (db) => db.collection(`conversations/${CONV}/messages`);

  await test("a builder can send text", async () => {
    await seedConversation();
    await assertSucceeds(
      messages(asBuilder()).add({ senderId: BUILDER, senderRole: "builder", text: "Hi", createdAt: ts() })
    );
  });

  await test("a builder can send a photo or file from the app", async () => {
    // Refused by the dashboard's rules before the merge, which had no
    // attachment field.
    await seedConversation();
    await assertSucceeds(
      messages(asBuilder()).add({
        senderId: BUILDER,
        senderRole: "builder",
        text: "",
        attachment: {
          url: "https://firebasestorage.googleapis.com/v0/b/x/o/chat_attachments%2Fa.pdf",
          name: "receipt.pdf",
          kind: "file",
          sizeBytes: 20480,
        },
        createdAt: ts(),
      })
    );
  });

  await test("a shop can send a picture from the dashboard", async () => {
    // Text left empty, as the dashboard sends a photo with no caption.
    await seedConversation();
    await assertSucceeds(
      messages(asShop()).add({
        senderId: SHOP,
        senderRole: "shop",
        text: "",
        imageUrl: "https://firebasestorage.googleapis.com/v0/b/x/o/chat_images%2Fa.jpg",
        createdAt: ts(),
      })
    );
  });

  await test("an empty message is refused", async () => {
    await seedConversation();
    await assertFails(messages(asShop()).add({ senderId: SHOP, senderRole: "shop", text: "" }));
  });

  await test("a picture link must be https", async () => {
    await seedConversation();
    await assertFails(
      messages(asShop()).add({ senderId: SHOP, senderRole: "shop", imageUrl: "http://evil.example/a.jpg" })
    );
  });

  await test("an oversized attachment is refused", async () => {
    await seedConversation();
    await assertFails(
      messages(asBuilder()).add({
        senderId: BUILDER,
        senderRole: "builder",
        attachment: { url: "https://x/a", name: "a.pdf", kind: "file", sizeBytes: 50 * 1024 * 1024 },
      })
    );
  });

  await test("nobody can send as someone else", async () => {
    await seedConversation();
    await assertFails(messages(asShop()).add({ senderId: BUILDER, senderRole: "builder", text: "Hi" }));
  });

  await test("an outsider cannot read or write the thread", async () => {
    await seedConversation();
    await assertFails(messages(asShop2()).get());
    await assertFails(messages(asShop2()).add({ senderId: SHOP_2, senderRole: "shop", text: "Hi" }));
  });

  console.log("\nread markers — both apps' kinds");

  await test("the app can mark a thread read (readAt)", async () => {
    // Refused by the dashboard's rules before the merge, so the app's unread
    // badges never cleared.
    await seedConversation();
    await assertSucceeds(
      asBuilder().doc(`conversations/${CONV}`).set({ readAt: { [BUILDER]: ts() } }, { merge: true })
    );
  });

  await test("the dashboard can mark a thread read (shopLastReadAt)", async () => {
    await seedConversation();
    await assertSucceeds(asShop().doc(`conversations/${CONV}`).update({ shopLastReadAt: ts() }));
  });

  await test("a participant cannot reassign the thread to another shop", async () => {
    await seedConversation();
    await assertFails(asBuilder().doc(`conversations/${CONV}`).update({ shopId: SHOP_2 }));
  });

  // ── Shops and ratings ────────────────────────────────────────────────────

  console.log("\nshops — profile edits, not approval, billing, identity or rating");

  await test("a shop owner can still edit their storefront", async () => {
    await assertSucceeds(asShop().doc(`shops/${SHOP}`).update({ address: "J.P. Rizal St., Calamba" }));
  });

  for (const field of ["rating", "ratingCount", "averageRating", "reviewCount"]) {
    await proposed(`a shop owner cannot write ${field} on their own shop`, async () => {
      await assertFails(asShop().doc(`shops/${SHOP}`).update({ [field]: 5 }));
    });
  }

  for (const field of ["email", "documents", "subscriptionPlan", "status"]) {
    await test(`a shop owner cannot change their own ${field}`, async () => {
      await assertFails(asShop().doc(`shops/${SHOP}`).update({ [field]: "changed" }));
    });
  }

  await test("a shop owner cannot store more than 30 device tokens", async () => {
    await assertFails(
      asShop().doc(`shops/${SHOP}`).update({ fcmTokens: Array.from({ length: 31 }, (_, i) => `t${i}`) })
    );
  });

  const NEW_SHOP = "new-shop-uid";
  const newShopDoc = () => testEnv.authenticatedContext(NEW_SHOP).firestore().doc(`shops/${NEW_SHOP}`);

  await test("a new shop can still register", async () => {
    await assertSucceeds(
      newShopDoc().set({ uid: NEW_SHOP, shopName: "Tanauan Hardware", subscriptionPlan: "basic", status: "pending" })
    );
  });

  await proposed("a new shop cannot register with a rating already set", async () => {
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

  console.log("\nratings — only from a builder who bought from the shop");

  const rating = (db, shopId = SHOP) => db.doc(`shops/${shopId}/ratings/${BUILDER}`);
  const ratingData = (shopId = SHOP) => ({
    builderId: BUILDER,
    shopId,
    stars: 5,
    comment: "Delivered on time.",
    postId: POST,
    updatedAt: ts(),
  });

  await test("a builder can rate the shop they selected", async () => {
    await markSelected();
    await assertSucceeds(rating(asBuilder()).set(ratingData(), { merge: true }));
  });

  await test("a builder cannot rate a shop they did not select", async () => {
    await markSelected();
    await assertFails(rating(asBuilder(), SHOP_2).set(ratingData(SHOP_2)));
  });

  await test("a shop cannot rate itself", async () => {
    await markSelected();
    await assertFails(asShop().doc(`shops/${SHOP}/ratings/${SHOP}`).set({ ...ratingData(), builderId: SHOP }));
  });

  // ── Dashboard-only collections ───────────────────────────────────────────

  console.log("\nweb-only collections still work");

  await test("a visitor can send a Contact Us message", async () => {
    await assertSucceeds(
      asGuest().collection("contactMessages").add({
        name: "Ana",
        email: "ana@example.com",
        subject: "Question",
        message: "How do I register my shop?",
        status: "new",
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      })
    );
  });

  await test("a shop can file a GCash payment for review", async () => {
    await assertSucceeds(
      asShop().collection("subscriptionPayments").add({
        shopId: SHOP,
        status: "pending",
        planName: "Pro",
        referenceNumber: "1234567890",
      })
    );
  });

  await test("a shop cannot file a payment already confirmed", async () => {
    await assertFails(
      asShop().collection("subscriptionPayments").add({ shopId: SHOP, status: "confirmed", planName: "Pro" })
    );
  });

  await test("nobody can read or write the AI usage counters", async () => {
    await assertFails(asBuilder().doc(`ai_usage/${BUILDER}`).get());
    await assertFails(asBuilder().doc(`ai_usage/${BUILDER}`).set({ calls: 0 }));
  });

  // ── Storage ──────────────────────────────────────────────────────────────

  console.log("\nstorage — each app's folders");

  const bytes = new Uint8Array([1, 2, 3, 4]);
  const put = (uid, filePath, contentType, data = bytes) =>
    testEnv.authenticatedContext(uid).storage().ref(filePath).put(data, { contentType });
  const big = new Uint8Array(11 * 1024 * 1024);

  await test("the app can upload a chat document", async () => {
    await assertSucceeds(put(BUILDER, `chat_attachments/${CONV}/1_receipt.pdf`, "application/pdf"));
  });

  await test("the app cannot upload a program as a chat attachment", async () => {
    await assertFails(put(BUILDER, `chat_attachments/${CONV}/1_x.exe`, "application/x-msdownload"));
  });

  await test("the app cannot upload a chat attachment over 10 MB", async () => {
    await assertFails(put(BUILDER, `chat_attachments/${CONV}/1_big.jpg`, "image/jpeg", big));
  });

  await test("the dashboard can upload a chat picture", async () => {
    await assertSucceeds(put(SHOP, `chat_images/${CONV}/1.jpg`, "image/jpeg"));
  });

  await test("the dashboard's chat pictures must be images", async () => {
    await assertFails(put(SHOP, `chat_images/${CONV}/1.pdf`, "application/pdf"));
  });

  await test("a shop can upload its product images", async () => {
    await assertSucceeds(put(SHOP, `products/${SHOP}/cement.jpg`, "image/jpeg"));
  });

  await test("a shop cannot upload into another shop's products", async () => {
    await assertFails(put(SHOP, `products/${SHOP_2}/cement.jpg`, "image/jpeg"));
  });

  await test("a shop can upload its registration documents", async () => {
    await assertSucceeds(put(SHOP, `shop-documents/${SHOP}/permit.pdf`, "application/pdf"));
  });

  await test("only the shop itself can read its registration documents", async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.storage().ref(`shop-documents/${SHOP}/permit.pdf`).put(bytes, { contentType: "application/pdf" });
    });
    await assertFails(testEnv.authenticatedContext(BUILDER).storage().ref(`shop-documents/${SHOP}/permit.pdf`).getMetadata());
  });

  await test("a user can upload their own profile photo", async () => {
    await assertSucceeds(put(BUILDER, `user_profile_images/${BUILDER}/1.jpg`, "image/jpeg"));
  });

  await test("a user cannot upload someone else's profile photo", async () => {
    await assertFails(put(BUILDER, `user_profile_images/${SHOP}/1.jpg`, "image/jpeg"));
  });

  await test("nothing else in the bucket is writable", async () => {
    await assertFails(put(BUILDER, `anything/else.jpg`, "image/jpeg"));
  });

  await testEnv.cleanup();

  console.log(`\n${passed} passed, ${failed} failed, ${skipped} proposed (skipped)\n`);
  process.exit(failed === 0 ? 0 : 1);
}

run().catch((err) => {
  console.error("Rules test harness failed to start:", err);
  process.exit(1);
});
