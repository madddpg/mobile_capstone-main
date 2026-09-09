"use strict";

/**
 * AI daily cap tests. Run with: node functions/test/aiQuota.test.js
 *
 * Uses a hand-rolled Firestore stand-in rather than the emulator, so the
 * counting rules can be pinned without a running Java runtime.
 */

const assert = require("assert");
const { consumeAiCall, manilaDayKey, DAILY_LIMIT } = require("../src/services/aiQuota");

let passed = 0;
let failed = 0;

function test(name, fn) {
  return Promise.resolve()
    .then(fn)
    .then(() => {
      passed++;
      console.log("  ok   " + name);
    })
    .catch((err) => {
      failed++;
      console.log("  FAIL " + name);
      console.log("       " + err.message);
    });
}

/** Minimal Firestore stand-in: one collection, one document, one transaction. */
function fakeDb(initial = null, { failTransaction = false } = {}) {
  const store = { doc: initial };
  return {
    store,
    collection() {
      return {
        doc() {
          return { __ref: true };
        },
      };
    },
    async runTransaction(fn) {
      if (failTransaction) throw new Error("firestore unavailable");
      return fn({
        async get() {
          return {
            exists: store.doc !== null,
            data: () => store.doc,
          };
        },
        set(_ref, value) {
          store.doc = { ...(store.doc || {}), ...value };
        },
      });
    },
  };
}

async function run() {
  console.log("\nmanilaDayKey — the allowance rolls over at local midnight");

  await test("a UTC afternoon is already the same Manila day", () => {
    // 2026-09-10 04:00 UTC is midday in Manila, still the 10th.
    assert.strictEqual(manilaDayKey(new Date("2026-09-10T04:00:00Z")), "2026-09-10");
  });

  await test("late UTC evening has already become the next Manila day", () => {
    // 2026-09-10 17:00 UTC is 01:00 on the 11th in Manila. Using UTC here
    // would reset the allowance in the middle of a working afternoon.
    assert.strictEqual(manilaDayKey(new Date("2026-09-10T17:00:00Z")), "2026-09-11");
  });

  console.log("\nconsumeAiCall — counting and refusing");

  await test("a first call starts the count at one", async () => {
    const db = fakeDb();
    const result = await consumeAiCall(db, "builder-1");
    assert.strictEqual(result.used, 1);
    assert.strictEqual(result.remaining, DAILY_LIMIT - 1);
    assert.strictEqual(db.store.doc.count, 1);
  });

  await test("a later call the same day increments", async () => {
    const db = fakeDb({ day: manilaDayKey(), count: 5 });
    const result = await consumeAiCall(db, "builder-1");
    assert.strictEqual(result.used, 6);
  });

  await test("yesterday's count does not carry over", async () => {
    // Without the day check an account would be permanently capped after one
    // heavy session.
    const db = fakeDb({ day: "2020-01-01", count: DAILY_LIMIT });
    const result = await consumeAiCall(db, "builder-1");
    assert.strictEqual(result.used, 1);
  });

  await test("the call is refused once the allowance is spent", async () => {
    const db = fakeDb({ day: manilaDayKey(), count: DAILY_LIMIT });
    await assert.rejects(
      () => consumeAiCall(db, "builder-1"),
      (err) => err.code === "resource-exhausted" || /resource-exhausted/.test(String(err))
    );
  });

  await test("the refusal points at the templates, not a dead end", async () => {
    const db = fakeDb({ day: manilaDayKey(), count: DAILY_LIMIT });
    try {
      await consumeAiCall(db, "builder-1");
      assert.fail("should have been refused");
    } catch (err) {
      assert.ok(/templates/i.test(err.message), "message should offer a way forward");
    }
  });

  await test("a custom limit is honoured", async () => {
    const db = fakeDb({ day: manilaDayKey(), count: 2 });
    await assert.rejects(() => consumeAiCall(db, "builder-1", { limit: 2 }));
  });

  await test("an unauthenticated caller is refused before any read", async () => {
    const db = fakeDb();
    await assert.rejects(() => consumeAiCall(db, null));
  });

  await test("a counter failure lets the call through rather than blocking it", async () => {
    // Losing the consultant because a bookkeeping write failed would be worse
    // than one uncounted call.
    const db = fakeDb(null, { failTransaction: true });
    const result = await consumeAiCall(db, "builder-1");
    assert.strictEqual(result.uncounted, true);
  });

  console.log(`\n${passed} passed, ${failed} failed\n`);
  process.exit(failed === 0 ? 0 : 1);
}

run();
