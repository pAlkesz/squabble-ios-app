import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { test } from "node:test";

const { parseRates } = createRequire(import.meta.url)("../lib/rates.js");
const many = Object.fromEntries(Array.from({ length: 25 }, (_, i) => [`A${String.fromCharCode(65 + i)}X`, 1.5]));
const answer = (more = {}) => ({ amount: 1, base: "EUR", date: "2026-11-25", rates: { ...many, HUF: 373.44, IDR: 20055.72 }, ...more });

test("rates are kept as exact text", () => {
  const { date, base, rates } = parseRates(answer());
  assert.equal(date, "2026-11-25");
  assert.equal(base, "EUR");
  assert.equal(rates.HUF, "373.44");
  assert.equal(rates.IDR, "20055.72");
});
for (const [name, body] of Object.entries({
  nothing: null,
  "an error message": { message: "not found" },
  "another base": answer({ base: "USD" }),
  "no date": answer({ date: undefined }),
  "no rates": answer({ rates: null }),
  "too few rates": answer({ rates: { HUF: 373.44 } }),
  "a zero": answer({ rates: { ...many, HUF: 0 } }),
  "a negative rate": answer({ rates: { ...many, HUF: -1 } }),
  "text for a rate": answer({ rates: { ...many, HUF: "373.44" } }),
  "a strange code": answer({ rates: { ...many, "forint!": 1 } }),
  "a rate too small to write out": answer({ rates: { ...many, HUF: 1e-9 } }),
})) {
  test(`refuses ${name}`, () => assert.throws(() => parseRates(body)));
}
