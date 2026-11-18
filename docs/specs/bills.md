# Bills & splitting

**Status:** Draft. Not built. Depends on [Groups](groups.md). Product questions settled
(Nov 2026).

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
- **One payer per bill in v1** (Nov 2026). If two people paid, enter two bills.
  `paidBy` stays a single member id for now; it can become a map later.
- **A bill can be in a different currency from its squabble's** (Nov 2026). The bill
  form has a currency picker, defaulting to the squabble's currency. Amounts are stored
  in the bill's own currency and converted only for display (see
  [Groups](groups.md#currency)).
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
  title, currency, totalMinor, paidBy: uid,
  createdBy, createdAt, updatedBy, updatedAt
  items: [ { id, name, amountMinor, sharedBy: [uid] } ]   ← optional, itemized bills
  shares: { uid: amountMinor }                            ← the result; sums to totalMinor
groups/{gid}/settlements/{id}
  from: uid, to: uid, amountMinor, currency, createdBy, createdAt
groups/{gid}/reminders/{id}
  to: uid, message, createdBy, createdAt
rates/latest                                              ← written only by the rates function
  base: "EUR", date, rates: { code: Decimal-as-string }
```

- `shares` is stored, not recomputed on read, so balances never shift if the algorithm
  changes later.
- Bills and settlements in an **archived** squabble are read-only (see
  [Groups](groups.md)).

## Splitting

### Modes

- **Equally** among the selected members.
- **Exact amounts:** the user enters each share, and they must add up to the total.
- **By item:** each item is split equally among the people who had it. Tax and tip are
  spread proportionally to each person's item subtotal.
- (Later) by shares / percentages.

### Leftover cents rule

When an amount doesn't divide evenly:

1. Work out each exact share as a `Decimal`.
2. Give everyone their share **truncated towards zero**, in minor units.
3. Hand out the remaining minor units **one each**, largest fractional remainder first.
   Ties are broken by member order: the order the members are listed in the bill, then
   by uid.
4. Check: the shares add up exactly to `totalMinor`.

**Negative amounts** (refunds, discounts) are split by size and then given back their
sign, so a refund's shares mirror the charge's exactly.

Example: €10.00 between 3 people → 334, 333, 333 cents.

### Currency precision

- Minor units follow the currency's ISO 4217 exponent (EUR 2, JPY 0), never a fixed 100.
- **Override: HUF uses 0 decimals.** ISO says 2, but there are no fillér coins and nobody
  writes them. Entry, splits, storage and display all use whole forints, and leftover
  forints are handed out by the rule above.
- Overrides live in one small table next to the money model. Add a currency there only
  when its subunit is genuinely unused.

## Exchange rates

- A **scheduled Cloud Function** fetches the ECB's reference rates once a day (via
  Frankfurter: free, no API key) and writes them to `rates/latest`.
- Any signed-in user can read `rates/latest`; nobody can write it from the app. Apps
  listen to that one document, so it's one cached read that works offline with the last
  rates.
- Rates are stored as decimal strings and converted with `Decimal`, and the converted
  result is rounded to the target currency's precision **only for display**. Converted
  amounts are never stored.
- The rates replace `BalanceMood`'s rough per-currency table (see
  [Home](home.md#balance-mood)).
- **Missing rates:** the ECB publishes about 30 currencies. A currency without a rate
  can't be converted. Totals then show that part separately in its own currency instead
  of guessing.

## Balances

- A member's balance in a group = what they paid − their shares + settlements paid −
  settlements received. It's computed per original currency, then converted into the
  group's currency for display (see [Groups](groups.md#currency)).
- The balances in a group add up to zero (per currency, before conversion).
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

None at the product level for manual bills, splitting, balances and settlements.
Reminder delivery and AI parsing get their own decisions when they're built.
