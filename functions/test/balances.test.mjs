import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { test } from "node:test";

const { computeBalances, sameBalances } = createRequire(import.meta.url)("../lib/balances.js");
const members = new Set(["anna", "bela", "cili"]);
const bill = (id, more = {}) => ({
  id,
  data: { currency: "EUR", totalMinor: 1000, paidBy: "anna", shares: { anna: 334, bela: 333, cili: 333 }, ...more },
});
const compute = (...bills) => computeBalances(bills, "EUR", members);

test("the payer is owed what the others had", () => {
  assert.deepEqual(compute(bill("a")).balances, { anna: 666, bela: -333, cili: -333 });
});
test("paying without sharing", () => {
  assert.deepEqual(compute(bill("a", { shares: { bela: 1000 } })).balances, { anna: 1000, bela: -1000 });
});
test("bills cancel out, and zeros are left out", () => {
  const result = compute(bill("a", { shares: { bela: 1000 } }), bill("b", { paidBy: "bela", shares: { anna: 1000 } }));
  assert.deepEqual(result.balances, {});
});
test("deleted bills count for nothing", () => {
  assert.deepEqual(compute(bill("a", { deletedAt: {} })), { balances: {}, invalid: [], involved: [] });
});
for (const [name, more] of Object.entries({
  "shares that don't add up": { shares: { bela: 999 } },
  "a negative share": { shares: { bela: 1001, cili: -1 } },
  "a fractional share": { shares: { bela: 999.5, cili: 0.5 } },
  "a stranger's share": { shares: { dora: 1000 } },
  "a stranger paying": { paidBy: "dora" },
  "another currency": { currency: "USD" },
  "no total": { totalMinor: 0, shares: {} },
  "a huge total": { totalMinor: 2e12, shares: { bela: 2e12 } },
  "no shares": { shares: null },
})) {
  test(`skips a bill with ${name}, keeping the rest`, () => {
    const result = compute(bill("bad", more), bill("good", { shares: { bela: 1000 } }));
    assert.deepEqual(result, { balances: { anna: 1000, bela: -1000 }, invalid: ["bad"], involved: ["anna", "bela"] });
  });
}
test("comparing", () => {
  assert.ok(sameBalances({ a: 1 }, { a: 1 }));
  assert.ok(!sameBalances({ a: 1 }, { a: 2 }));
  assert.ok(!sameBalances({ a: 1 }, {}));
});

test("who's involved: payers and anyone with a share, in bills that count", () => {
  assert.deepEqual(compute(bill("a", { shares: { bela: 1000 } })).involved, ["anna", "bela"]);
  // Cancelled out to zero, still involved: that's what settled up means.
  const evened = compute(bill("a", { shares: { bela: 1000 } }), bill("b", { paidBy: "bela", shares: { anna: 1000 } }));
  assert.deepEqual(evened.involved, ["anna", "bela"]);
  assert.deepEqual(compute(bill("a", { deletedAt: 1 }), bill("b", { totalMinor: 5 })).involved, []);
  assert.deepEqual(compute(bill("a", { shares: { anna: 1000, cili: 0 } })).involved, ["anna"]);
});
