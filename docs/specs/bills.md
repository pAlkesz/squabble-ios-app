# Bills & splitting

**Status:** Draft. Not built. Depends on [Groups](groups.md).

## Summary

A **bill** records that someone paid for something and how it's split among the members
of a squabble. Balances, settle-up suggestions and reminders are all computed from bills
and settlements. Bills are first entered by hand; AI receipt parsing comes later and fills
in the same form.

## Decided so far

- **Money is exact.** Amounts are integer minor units (`Int64`) plus an ISO currency code
  in Firestore, and `Decimal` in models. Never `Double`.
- **Every split adds up to the exact total.** Leftover cents are assigned
  **deterministically**, so the same input always gives the same shares on every device.
- Items are **embedded** in the bill document (they're always read with it).
- Order of building: manual bills and the split algorithm → AI parsing → settlements →
  reminders.

## Data model (planned)

```
groups/{gid}/bills/{billId}
  title, currency, totalMinor, paidBy: memberId, createdBy, createdAt, updatedAt
  items: [ { id, name, amountMinor, sharedBy: [memberId] } ]   ← optional, itemized bills
  shares: { memberId: amountMinor }                            ← the result; sums to totalMinor
groups/{gid}/settlements/{id}
  from: memberId, to: memberId, amountMinor, currency, createdAt
groups/{gid}/reminders/{id}
  to: memberId, message, createdBy, createdAt
```

`shares` is stored, not recomputed on read, so balances never shift if the algorithm
changes later.

## Splitting

### Modes (proposed)

- **Equally** among the selected members.
- **Exact amounts:** the user enters each share, and they must add up to the total.
- **By item:** each item is split equally among the people who had it. Tax and tip are
  spread proportionally to each person's item subtotal.
- (Later) by shares / percentages.

### Leftover cents rule (proposed)

When an amount doesn't divide evenly:

1. Give everyone the rounded-down share (towards zero) in minor units.
2. Hand out the remaining minor units **one each**, ordered by the largest fractional
   remainder first. Ties are broken by a stable member order (e.g. the order of the
   members in the bill, then memberId).
3. Check: the shares add up exactly to `totalMinor`.

Example: €10.00 between 3 people → 334, 333, 333 cents.

### Currency precision

Minor units follow the currency's exponent (EUR 2, JPY 0), never a fixed 100. HUF is
the awkward case: ISO says 2 decimals, but there are no fillér coins and cash rounds to
5 Ft. This is an open question (below).

## Balances

- A member's balance in a group = what they paid − their shares + settlements paid −
  settlements received. It's computed per original currency, then converted into the
  group's currency for display (see [Groups](groups.md#currency)).
- The balances in a group add up to zero.
- **Settle-up suggestions:** keep the number of transfers small (greedy: the largest
  debtor pays the largest creditor). Proposed, not decided.
- **Home total:** the user's net across all groups, converted into the home currency. This
  needs exchange rates (see open questions).

## Reminders

- A generated message to someone who owes the user, with adjustable pettiness. The tone
  is playful and passive-aggressive, never mean.
- A reminder written offline shows as "not sent yet" until it syncs
  (`hasPendingWrites`).

## Open questions

1. **Who can edit or delete a bill:** its creator, the payer, or any member?
2. **Multiple payers** on one bill: needed, or split it into two bills?
3. **Bills in a different currency** from the group's: allowed at entry? Storage already
   supports it: bills keep their own currency, and balances are converted for display
   (see [Groups](groups.md#currency)).
4. **Exchange rates for the home total:** where do they come from, and how often are they
   refreshed?
5. **Settlements:** recorded by the payer only, or confirmed by the receiver?
6. **HUF precision:** split to whole forints (0 decimals) even though ISO says 2?
7. **Rounding direction for negative amounts** (refunds, discounts): confirm that the
   rule above holds for them too.
