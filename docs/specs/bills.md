# Bills & splitting

**Status:** Partly built (Nov 2026). Depends on [Groups](groups.md).

- **Built:** manual bills in the squabble's own currency (add, edit, delete, split equally or
  by exact amounts), their chat cards and details, balances kept by `updateBalances`, the
  rules, and balances on home, the squabbles list and the squabble page.
- **Not built yet:** other currencies (`frozen`, `chapter`, rates by day), items, settlements,
  settle-up suggestions, reactions and replies on bills, reminders, AI parsing. The rules
  refuse a bill in another currency until then.

## Summary

A **bill** records that someone paid for something and how it's split among the members
of a squabble. Balances, settle-up suggestions and reminders are all computed from bills
and settlements. Bills are first entered by hand; AI receipt parsing comes later and fills
in the same form.

## Decisions

- **Money is exact.** Amounts are integer minor units (`Int64`) plus an ISO currency code
  in Firestore, and `Decimal` in models. Never `Double`.
- **Every split adds up to the exact total.** Leftover cents are assigned
  **deterministically**, so the same input always gives the same shares on every device.
- Items are **embedded** in the bill document (they're always read with it).
- **Any member can edit or delete any bill** (Nov 2026), so anyone can fix a mistake.
  Every change records who made it (`updatedBy`), and the bill shows "edited by …", so
  edits are never silent.
- **Deleting keeps the bill** (Nov 2026), marked `deletedAt`: it counts for nothing, and the
  chat says who deleted it. A hard delete would wipe a debt without a trace.
- **A squabble with one member can have bills** (Nov 2026). They can be edited to include
  people once those join.
- **One payer per bill in v1** (Nov 2026). If two people paid, enter two bills.
  `paidBy` stays a single member id for now; it can become a map later.
- **A bill can be in a different currency from its squabble's** (Nov 2026). The bill
  form has a currency picker, defaulting to the squabble's currency. The original amounts
  are never rewritten; a converted copy in the squabble's currency is **frozen** at the
  rate of the bill's day (see "Exchange rates"). Converting at each day's current rate was
  rejected: a debt paid off in another currency would reopen when rates moved.
- **Balances are kept by a Cloud Function** on the group document (Nov 2026; see
  "Balances"). Rejected: the app adjusting them (rules can't check the sums) and adding up
  every bill on the phone (reads grow with history).
- **Exchange rates are the ECB's daily reference rates**, fetched by a scheduled Cloud
  Function (Nov 2026). See "Exchange rates" below.
- **Either side can record a settlement**, payer or receiver, and it counts right away,
  with no confirmation step (Nov 2026). Like bills, any member can delete a wrong one.
- **HUF is split in whole forints** (Nov 2026). See "Currency precision" below.
- Order of building: manual bills and the split algorithm → AI parsing → settlements →
  reminders.

## Data model (planned)

```
groups/{gid}/bills/{billId}
  title, date, currency, totalMinor, paidBy: uid, split: equally | exactly,
  createdBy, createdAt, updatedBy, updatedAt, deletedAt?
  items: [ { id, name, amountMinor, sharedBy: [uid] } ]   ← optional, itemized bills
  shares: { uid: amountMinor }                            ← the result; sums to totalMinor
  frozen?: { currency, rate, rateDate, totalMinor, shares } ← written only by the function
  chapter?                                                ← written only by the function
groups/{gid}/settlements/{id}
  from: uid, to: uid, amountMinor, currency, date, createdBy, createdAt
  frozen?: { currency, rate, rateDate, amountMinor }, chapter?   ← written only by the function
groups/{gid}/reminders/{id}
  to: uid, message, createdBy, createdAt
rates/latest, rates/{yyyy-MM-dd}                          ← written only by functions
  base: "EUR", date, rates: { code: Decimal-as-string }
```

- `shares` is stored, not recomputed on read, so balances never shift if the algorithm
  changes later.
- A total is above zero and at most 10^12 minor units (so sums stay exact on the server too);
  a title is 1–50 characters.
- The rules can't add up a map, so **`updateBalances` skips a bill whose shares don't match its
  total**, names someone who was never a member, or isn't in the group's currency.
- `date` is the day of the bill or payment, a calendar day defaulting to today and never
  in the future.
- `frozen` and `chapter` are never written by the app; the rules refuse them.
- With the balances, `updateBalances` stores **`involvedIds`**: everyone who paid or has a
  share above zero in a bill that counts (not deleted, not skipped), sorted. A member at zero
  in it is settled up; one who isn't has nothing to settle (Nov 2026).
- Bills and settlements in an **archived** squabble are read-only (see
  [Groups](groups.md)).

## Splitting

### Modes

- **Equally** among the selected members.
- **Exact amounts:** the user enters each share, and they must add up to the total.
- **By item:** each item is split equally among the people who had it. Tax and tip are
  spread proportionally to each person's item subtotal.
  - Tax and tip are whatever the total has beyond the items; a discount is the same thing,
    negative.
  - Someone whose subtotal is zero (or whose sign is opposite to the bill's) gets none of it.
    If nobody has a subtotal, it's split equally.
- (Later) by shares / percentages.

### Leftover cents rule

When an amount doesn't divide evenly:

1. Work out each exact share with integers, as a quotient and a remainder (`BillSplit`).
   Not `Decimal`, which can't hold a third exactly and could misjudge a tie.
2. Give everyone their share **truncated towards zero**, in minor units.
3. Hand out the remaining minor units **one each**, largest fractional remainder first.
   Ties are broken by the order the people are given in. **Equal splits rotate it by bill**
   (Nov 2026): sorted by uid, starting from a person picked by the bill's id, so leftovers
   don't always land on the same people yet every phone agrees. Always the list order, and
   the payer absorbing it, were rejected.
4. Check: the shares add up exactly to `totalMinor`.

**Negative amounts** (refunds, discounts) are split by size and then given back their
sign, so a refund's shares mirror the charge's exactly.

Example: €10.00 between 3 people → 334, 333, 333 cents.

### Currency precision

- Minor units follow the currency's ISO 4217 exponent (EUR 2, JPY 0), never a fixed 100.
- **Override: HUF uses 0 decimals.** ISO says 2, but there are no fillér coins and nobody
  writes them. Entry, splits, storage and display all use whole forints, and leftover
  forints are handed out by the rule above.
- ISO exponents and overrides live in one small table (`CurrencyPrecision`), not the
  system's: it has other exponents for some currencies, and the server must agree. Add a currency there only
  when its subunit is genuinely unused.

## Exchange rates

The ECB's daily reference rates, through Frankfurter (free, no API key, with historical
rates). Only Cloud Functions fetch them.

**Frozen conversions**

- When a bill or settlement is written, a function stores its amount in the squabble's
  currency in `frozen`. In the squabble's own currency the rate is 1 and no lookup is
  needed.
- The rate is the one for the **bill's day**: the latest published on or before `date`
  (weekends and holidays have none). `rateDate` records which, and is reused whenever the
  bill is edited or reconverted; only changing `date` picks a new one. So the numbers
  never drift, and changing the squabble's currency and back restores them exactly.
- The total is converted with exact decimal arithmetic and rounded to the target's
  precision, half away from zero. The shares are then split from the converted total in
  proportion to the original shares, by the leftover cents rule with ties broken by uid,
  so they add up exactly.
- Until `frozen` exists (offline, or the rates are unreachable and the function is
  retrying), the bill shows as "still converting". It counts only in a provisional
  balance, and only if it's in the squabble's currency.
- Settlements are always entered in the squabble's current currency. One written offline
  before a currency change is converted like a bill.
- **Missing rates:** the ECB publishes about 30 currencies. The bill form offers only
  currencies convertible into the squabble's, plus its own.
- `rates/{date}` caches the days looked up. The Swift and TypeScript money code share
  test vectors, including the HUF override.

**Display conversions**

- **Built (Nov 2026):** the scheduled `updateRates` function looks every six hours and writes
  `rates/latest` when there are newer rates (the ECB publishes once a working day). An answer
  that looks wrong is refused, so it never replaces good rates. Any signed-in user can read it; apps
  listen to that one document, which works offline with the last rates.
- It's used only for home's total and its mood, replacing `BalanceMood`'s rough table (see
  [Home](home.md#balance-mood)). Those results are never stored. A balance whose currency
  has no rate is shown separately instead of guessed.

## Balances

- A member's balance in a group = what they paid − their shares + settlements paid −
  settlements received, using the **frozen** amounts of the current chapter (see
  [Groups](groups.md#currency)).
- **Stored in `groups/{gid}.balances`** (`{ uid: amountMinor }`, in the group's currency).
  A function triggered by bill and settlement writes recomputes them from scratch in a
  transaction, rather than adding changes up, so retries and out-of-order events are
  harmless. The app can't write `balances`; it
  does bump the group's `updatedAt` in the same batch as any bill write, as messages do, and
  sets its `lastActivity` (added, edited or deleted, with the title).
  Members at zero are left out, and there's no `balances` until the first bill.
- The balances in a group add up to exactly zero.
- Home reads `balances` from its existing group listener. A provisional balance that
  includes the user's own unsynced bills is planned; until then a bill added offline changes
  balances once it syncs.
- **Settle-up suggestions:** keep the number of transfers small (greedy: the largest
  debtor pays the largest creditor).
- **Home total:** the user's net across all groups, archived ones included, converted into
  the home currency.

## Reminders

- A generated message to someone who owes the user, with adjustable pettiness. The tone
  is playful and passive-aggressive, never mean.
- A reminder written offline shows as "not sent yet" until it syncs
  (`hasPendingWrites`).
- How reminders are delivered (push notification, the share sheet, or both) is decided
  when reminders are built.

## Open questions

None at the product level (currencies and balance storage settled Nov 2026) for manual bills, splitting, balances and settlements.
Reminder delivery and AI parsing get their own decisions when they're built.
