/** A group's balances from its bills (docs/specs/bills.md, "Balances"), free of Firebase. */

export interface BillData {
  currency?: unknown;
  totalMinor?: unknown;
  paidBy?: unknown;
  shares?: unknown;
  deletedAt?: unknown;
}

export interface BalancesResult {
  /** Minor units by uid; members at zero are left out. Always adds up to zero. */
  balances: Record<string, number>;
  /** Bills that can't be trusted, so count for nothing. */
  invalid: string[];
}

/**
 * The security rules can't add up a map, so a tampered app could store shares that don't
 * match their total. Such a bill is skipped whole, which keeps the sum at zero.
 */
export function computeBalances(
  bills: { id: string; data: BillData }[],
  currency: string,
  memberIds: ReadonlySet<string>,
): BalancesResult {
  const totals = new Map<string, number>();
  const invalid: string[] = [];
  for (const { id, data } of bills) {
    if (data.deletedAt) continue;
    const effect = effectOf(data, currency, memberIds);
    if (!effect) {
      invalid.push(id);
      continue;
    }
    for (const [uid, amount] of effect) totals.set(uid, (totals.get(uid) ?? 0) + amount);
  }
  const balances: Record<string, number> = {};
  for (const [uid, amount] of totals) if (amount !== 0) balances[uid] = amount;
  return { balances, invalid };
}

function effectOf(bill: BillData, currency: string, memberIds: ReadonlySet<string>): Map<string, number> | null {
  const { totalMinor, paidBy, shares } = bill;
  if (bill.currency !== currency) return null;
  if (!isAmount(totalMinor) || totalMinor === 0) return null;
  if (typeof paidBy !== "string" || !memberIds.has(paidBy)) return null;
  if (typeof shares !== "object" || shares === null) return null;
  const effect = new Map<string, number>([[paidBy, totalMinor]]);
  let sum = 0;
  for (const [uid, share] of Object.entries(shares)) {
    if (!memberIds.has(uid) || !isAmount(share)) return null;
    sum += share;
    effect.set(uid, (effect.get(uid) ?? 0) - share);
  }
  return sum === totalMinor ? effect : null;
}

/** The rules' limit too. Well inside what a double holds exactly, even summed over bills. */
const maxAmount = 1_000_000_000_000;

function isAmount(value: unknown): value is number {
  return Number.isSafeInteger(value) && (value as number) >= 0 && (value as number) <= maxAmount;
}

export function sameBalances(a: Record<string, number>, b: Record<string, number>): boolean {
  const keys = Object.keys(a);
  return keys.length === Object.keys(b).length && keys.every((key) => a[key] === b[key]);
}
