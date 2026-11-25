/** The ECB's daily reference rates (docs/specs/bills.md, "Exchange rates"), free of Firebase. */

export interface Rates {
  base: "EUR";
  /** The day they were published for, yyyy-MM-dd. */
  date: string;
  /** Units per euro, as exact decimal text. */
  rates: Record<string, string>;
}

/** The ECB publishes about 30; far fewer means something is wrong with the answer. */
const minimumCount = 20;

/** Frankfurter's answer, or an error: a bad one must never replace good rates. */
export function parseRates(body: unknown): Rates {
  const { base, date, rates } = (body ?? {}) as { base?: unknown; date?: unknown; rates?: unknown };
  if (base !== "EUR") throw new Error(`Unexpected base: ${String(base)}`);
  if (typeof date !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(date)) throw new Error("Unexpected date");
  if (typeof rates !== "object" || rates === null) throw new Error("No rates");
  const parsed: Record<string, string> = {};
  for (const [code, rate] of Object.entries(rates)) {
    // The shortest text for a short decimal is that decimal, so nothing is lost here.
    const text = typeof rate === "number" ? String(rate) : "";
    if (!/^[A-Z]{3}$/.test(code) || !/^\d+(\.\d+)?$/.test(text) || Number(text) <= 0) {
      throw new Error(`Unexpected rate for ${code}`);
    }
    parsed[code] = text;
  }
  if (Object.keys(parsed).length < minimumCount) throw new Error("Too few rates");
  return { base, date, rates: parsed };
}
