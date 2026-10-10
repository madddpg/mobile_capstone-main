/**
 * Firestore security rules regression tests for iConstruct.
 *
 * Requires the Firestore emulator:
 *   firebase emulators:exec --only firestore "node --test test/rules/firestore.rules.test.mjs"
 *
 * Or with deps installed at repo root:
 *   npm run test:rules
 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import test from 'node:test';
import assert from 'node:assert/strict';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

const __dirname = dirname(fileURLToPath(import.meta.url));
const rules = readFileSync(join(__dirname, '../../firestore.rules'), 'utf8');

let env;

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'iconstruct-rules-test',
    firestore: { rules, host: '127.0.0.1', port: 8080 },
  });
});

test.after(async () => {
  await env?.cleanup();
});

test.beforeEach(async () => {
  await env.clearFirestore();
});

function authed(uid) {
  return env.authenticatedContext(uid).firestore();
}

test('shop cannot forge a rival shop quotation', async () => {
  const admin = env.authenticatedContext('builder-1').firestore();
  // Seed post + approved shop via rules-bypassing admin context.
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc('projectPosts/post-1').set({
      userId: 'builder-1',
      projectName: 'Bath',
      materials: [],
      status: 'open',
      quotationCount: 0,
    });
    await db.doc('shops/shop-a').set({ status: 'approved', name: 'A' });
    await db.doc('shops/shop-b').set({ status: 'approved', name: 'B' });
  });

  const shopB = authed('shop-b');
  await assertFails(
    shopB.doc('projectPosts/post-1/quotations/shop-a').set({
      shopId: 'shop-a',
      postId: 'post-1',
      estimatedTotal: 1,
      status: 'submitted',
    }),
  );
});

test('approved shop can submit its own quotation', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc('projectPosts/post-1').set({
      userId: 'builder-1',
      projectName: 'Bath',
      materials: [],
      status: 'open',
      quotationCount: 0,
    });
    await db.doc('shops/shop-a').set({ status: 'approved', name: 'A' });
  });

  // The payload insertQuotation() writes, which the create rule checks.
  const shopA = authed('shop-a');
  await assertSucceeds(
    shopA.doc('projectPosts/post-1/quotations/shop-a').set({
      shopId: 'shop-a',
      projectId: 'post-1',
      amount: 1200,
      status: 'pending',
      items: [],
    }),
  );
});

test('shop cannot self-approve', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc('shops/shop-a').set({
      status: 'pending',
      name: 'A',
    });
  });

  const shopA = authed('shop-a');
  await assertFails(
    shopA.doc('shops/shop-a').update({ status: 'approved' }),
  );
});

test('clients cannot create notifications for other users', async () => {
  const attacker = authed('attacker');
  await assertFails(
    attacker.doc('notifications/n1').set({
      recipientId: 'victim',
      type: 'new_quotation',
      isRead: false,
      title: 'Fake',
    }),
  );
});

test('builder can mark own notification read only', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc('notifications/n1').set({
      recipientId: 'builder-1',
      type: 'new_quotation',
      isRead: false,
      title: 'New bid',
      postId: 'post-1',
    });
  });

  const builder = authed('builder-1');
  await assertSucceeds(
    builder.doc('notifications/n1').update({ isRead: true }),
  );
  await assertFails(
    builder.doc('notifications/n1').update({
      isRead: true,
      title: 'hijacked',
    }),
  );
});

test('unrelated builder cannot read another builder post', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc('projectPosts/post-1').set({
      userId: 'builder-1',
      projectName: 'Bath',
      materials: ['tiles'],
      status: 'open',
      quotationCount: 0,
    });
  });

  const stranger = authed('builder-2');
  await assertFails(stranger.doc('projectPosts/post-1').get());
});

test('builder can accept a quote with only status and acceptedAt', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc('projectPosts/post-1').set({
      userId: 'builder-1',
      projectName: 'Roof',
      materials: [],
      status: 'open',
      quotationCount: 1,
    });
    await db.doc('projectPosts/post-1/quotations/shop-a').set({
      shopId: 'shop-a',
      postId: 'post-1',
      projectId: 'post-1',
      userId: 'builder-1',
      estimatedTotal: 100,
      status: 'submitted',
    });
  });

  const builder = authed('builder-1');
  await assertSucceeds(
    builder.doc('projectPosts/post-1/quotations/shop-a').update({
      status: 'accepted',
      acceptedAt: new Date(),
    }),
  );
});

test('builder cannot accept a quote with extra keys', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc('projectPosts/post-1').set({
      userId: 'builder-1',
      projectName: 'Roof',
      materials: [],
      status: 'open',
      quotationCount: 1,
    });
    await db.doc('projectPosts/post-1/quotations/shop-a').set({
      shopId: 'shop-a',
      postId: 'post-1',
      projectId: 'post-1',
      userId: 'builder-1',
      estimatedTotal: 100,
      status: 'submitted',
    });
  });

  const builder = authed('builder-1');
  await assertFails(
    builder.doc('projectPosts/post-1/quotations/shop-a').update({
      status: 'accepted',
      acceptedAt: new Date(),
      acceptedBy: 'builder-1',
      updatedAt: new Date(),
    }),
  );
});

test('builder can accept a quote when the post stores uid on builderId', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc('projectPosts/post-1').set({
      builderId: 'builder-1',
      projectName: 'Roof',
      materials: [],
      status: 'open',
      quotationCount: 1,
    });
    await db.doc('projectPosts/post-1/quotations/shop-a').set({
      shopId: 'shop-a',
      postId: 'post-1',
      projectId: 'post-1',
      estimatedTotal: 100,
      status: 'submitted',
    });
  });

  const builder = authed('builder-1');
  await assertSucceeds(
    builder.doc('projectPosts/post-1/quotations/shop-a').update({
      status: 'accepted',
      acceptedAt: new Date(),
    }),
  );
});

test('builder can create a conversation after accepting a quote', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc('projectPosts/post-1').set({
      userId: 'builder-1',
      projectName: 'Roof',
      materials: [],
      status: 'offer_accepted',
      quotationCount: 1,
    });
    await db.doc('projectPosts/post-1/quotations/shop-a').set({
      shopId: 'shop-a',
      postId: 'post-1',
      projectId: 'post-1',
      userId: 'builder-1',
      estimatedTotal: 100,
      status: 'accepted',
    });
  });

  const builder = authed('builder-1');
  await assertSucceeds(
    builder.doc('conversations/post-1_shop-a').set({
      projectId: 'post-1',
      quotationId: 'shop-a',
      shopId: 'shop-a',
      shopName: 'GIShop',
      builderId: 'builder-1',
      userId: 'builder-1',
      builderName: 'Builder',
      projectTitle: 'Roof',
      status: 'open',
      lastMessage: 'Quote accepted',
    }),
  );
  await assertSucceeds(
    builder.doc('conversations/post-1_shop-a/messages/m1').set({
      senderId: 'builder-1',
      senderRole: 'builder',
      text: 'Hello',
      createdAt: new Date(),
    }),
  );
});


// ── Shop confirmation (shopConfirmation: pending / confirmed / declined) ──
//
// After the builder accepts, the shop answers from the web dashboard. Chat
// waits for that answer: a thread cannot be opened, nor a message sent, until
// the shop has confirmed. A quotation from before confirmations existed has
// no field and counts as confirmed.

async function seedAccepted({ status = 'accepted', shopConfirmation } = {}) {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc('projectPosts/post-1').set({
      userId: 'builder-1',
      projectName: 'Roof',
      materials: [],
      status: 'offer_accepted',
      quotationCount: 1,
    });
    await db.doc('shops/shop-a').set({ status: 'approved', name: 'A' });
    await db.doc('shops/shop-b').set({ status: 'approved', name: 'B' });
    const quote = {
      shopId: 'shop-a',
      projectId: 'post-1',
      userId: 'builder-1',
      amount: 100,
      status,
      items: [],
    };
    if (shopConfirmation !== undefined) quote.shopConfirmation = shopConfirmation;
    await db.doc('projectPosts/post-1/quotations/q1').set(quote);
  });
}

const QUOTE = 'projectPosts/post-1/quotations/q1';
const THREAD = 'conversations/post-1_shop-a';
const MESSAGE_1 = THREAD + '/messages/m1';
const MESSAGE_2 = THREAD + '/messages/m2';

function thread() {
  return {
    projectId: 'post-1',
    quotationId: 'q1',
    shopId: 'shop-a',
    shopName: 'A',
    builderId: 'builder-1',
    userId: 'builder-1',
    builderName: 'Builder',
    projectTitle: 'Roof',
    status: 'open',
    lastMessage: 'Quote accepted',
  };
}

function message(uid, role) {
  return { senderId: uid, senderRole: role, text: 'Hello', createdAt: new Date() };
}

/** The thread as the web Function creates it, bypassing the rules. */
async function seedThread() {
  await env.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc(THREAD).set(thread());
  });
}

test('shop can confirm or decline a quotation the builder accepted', async () => {
  await seedAccepted({ shopConfirmation: 'pending' });
  const shopA = authed('shop-a');
  await assertSucceeds(
    shopA.doc(QUOTE).update({ shopConfirmation: 'confirmed', updatedAt: new Date() }),
  );
  await assertSucceeds(shopA.doc(QUOTE).update({ shopConfirmation: 'declined' }));
});

test('shop can confirm a partially accepted quotation', async () => {
  await seedAccepted({ status: 'partially_accepted', shopConfirmation: 'pending' });
  await assertSucceeds(
    authed('shop-a').doc(QUOTE).update({ shopConfirmation: 'confirmed' }),
  );
});

test('shop cannot confirm a quotation the builder has not accepted', async () => {
  await seedAccepted({ status: 'pending' });
  await assertFails(
    authed('shop-a').doc(QUOTE).update({ shopConfirmation: 'confirmed' }),
  );
});

test('shop confirmation can be confirmed or declined, nothing else', async () => {
  await seedAccepted({ shopConfirmation: 'pending' });
  const shopA = authed('shop-a');
  await assertFails(shopA.doc(QUOTE).update({ shopConfirmation: 'pending' }));
  await assertFails(shopA.doc(QUOTE).update({ shopConfirmation: 'maybe' }));
});

test('a shop confirming cannot touch status, items or acceptedTotal', async () => {
  await seedAccepted({ shopConfirmation: 'pending' });
  const shopA = authed('shop-a');
  await assertFails(
    shopA.doc(QUOTE).update({ shopConfirmation: 'confirmed', status: 'rejected' }),
  );
  await assertFails(
    shopA.doc(QUOTE).update({ shopConfirmation: 'confirmed', acceptedTotal: 1 }),
  );
  await assertFails(
    shopA.doc(QUOTE).update({ shopConfirmation: 'confirmed', items: [{ name: 'x' }] }),
  );
});

test('only the quoting shop, while approved, can answer', async () => {
  await seedAccepted({ shopConfirmation: 'pending' });
  await assertFails(
    authed('shop-b').doc(QUOTE).update({ shopConfirmation: 'confirmed' }),
  );
  await env.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc('shops/shop-a').update({ status: 'suspended' });
  });
  await assertFails(
    authed('shop-a').doc(QUOTE).update({ shopConfirmation: 'confirmed' }),
  );
});

test('the builder can never write shopConfirmation', async () => {
  await seedAccepted({ shopConfirmation: 'pending' });
  const builder = authed('builder-1');
  await assertFails(builder.doc(QUOTE).update({ shopConfirmation: 'confirmed' }));
  await assertFails(
    builder.doc(QUOTE).update({ status: 'accepted', shopConfirmation: 'confirmed' }),
  );
});

test('pending confirmation: no thread from the app, no messages in any thread', async () => {
  await seedAccepted({ shopConfirmation: 'pending' });
  const builder = authed('builder-1');
  await assertFails(builder.doc(THREAD).set(thread()));

  // A thread the web Function already created still cannot be written in.
  await seedThread();
  await assertFails(builder.doc(MESSAGE_1).set(message('builder-1', 'builder')));
  await assertFails(authed('shop-a').doc(MESSAGE_2).set(message('shop-a', 'shop')));
});

test('declined confirmation blocks the thread and its messages', async () => {
  await seedAccepted({ shopConfirmation: 'declined' });
  const builder = authed('builder-1');
  await assertFails(builder.doc(THREAD).set(thread()));
  await seedThread();
  await assertFails(builder.doc(MESSAGE_1).set(message('builder-1', 'builder')));
  await assertFails(authed('shop-a').doc(MESSAGE_2).set(message('shop-a', 'shop')));
});

test('confirmed: the builder opens the thread and both sides can write', async () => {
  await seedAccepted({ shopConfirmation: 'confirmed' });
  const builder = authed('builder-1');
  await assertSucceeds(builder.doc(THREAD).set(thread()));
  await assertSucceeds(builder.doc(MESSAGE_1).set(message('builder-1', 'builder')));
  await assertSucceeds(authed('shop-a').doc(MESSAGE_2).set(message('shop-a', 'shop')));
});

test('a thread created early opens for messages once the shop confirms', async () => {
  await seedAccepted({ shopConfirmation: 'pending' });
  await seedThread();
  const builder = authed('builder-1');
  await assertFails(builder.doc(MESSAGE_1).set(message('builder-1', 'builder')));

  await assertSucceeds(
    authed('shop-a').doc(QUOTE).update({ shopConfirmation: 'confirmed' }),
  );
  await assertSucceeds(builder.doc(MESSAGE_1).set(message('builder-1', 'builder')));
});

test('a quotation from before confirmations existed counts as confirmed', async () => {
  await seedAccepted();
  const builder = authed('builder-1');
  await assertSucceeds(builder.doc(THREAD).set(thread()));
  await assertSucceeds(builder.doc(MESSAGE_1).set(message('builder-1', 'builder')));
});

// ── User profiles (users/{uid}) ──────────────────────────────────────────
//
// A profile holds a name, email, photo and push tokens. Only its owner and
// admins may read it, by get as well as by list.

async function seedProfiles() {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc('users/builder-1').set({
      firstName: 'Juan',
      lastName: 'Dela Cruz',
      email: 'juan@example.com',
      fcmTokens: ['token-1'],
    });
    await db.doc('shops/shop-a').set({ status: 'approved', name: 'A' });
    await db.doc('admins/admin-1').set({ role: 'admin' });
  });
}

test('a builder can read their own profile', async () => {
  await seedProfiles();
  await assertSucceeds(authed('builder-1').doc('users/builder-1').get());
});

test('another builder cannot read a profile by uid', async () => {
  await seedProfiles();
  await assertFails(authed('builder-2').doc('users/builder-1').get());
});

test('a shop, even an approved one, cannot read a builder profile', async () => {
  await seedProfiles();
  await assertFails(authed('shop-a').doc('users/builder-1').get());
});

test('a signed-out visitor cannot read a profile', async () => {
  await seedProfiles();
  await assertFails(
    env.unauthenticatedContext().firestore().doc('users/builder-1').get(),
  );
});

test('an admin can read any profile', async () => {
  await seedProfiles();
  await assertSucceeds(authed('admin-1').doc('users/builder-1').get());
});
