# Squabble docs

Specs describe **what the app does and the rules it follows**: business logic, data,
edge cases and decisions. They don't cover how screens look or how the code is laid out.
Design, branding and code conventions stay in [`CLAUDE.md`](../CLAUDE.md).

## Specs

| Spec | Status | Covers |
| --- | --- | --- |
| [Sign-in & account](specs/auth.md) | Built | Sign in with Apple, session states, sign out, account deletion |
| [Onboarding](specs/onboarding.md) | Built | First-run profile creation: name, handle, avatar, payment details |
| [Profile](specs/profile.md) | Built | Display names, handles, avatars, editing after onboarding |
| [Payment details](specs/payment-details.md) | Built | Bank accounts (IBAN / Hungarian account number), payment links |
| [Home & balance](specs/home.md) | Partly built | Total balance, balance mood, home currency |
| [Data & sync](specs/data-and-sync.md) | Built | Firestore layout, security rules, offline behaviour, money storage, data deletion |
| [Groups (squabbles)](specs/groups.md) | Draft | Creating squabbles, members, invites, archiving |
| [People](specs/people.md) | Draft | Finding people you've squabbled with before |
| [Bills & splitting](specs/bills.md) | Draft | Bills, the split algorithm, settlements, reminders |

**Status:** *Built* means the spec describes shipped behaviour. *Draft* means the
feature isn't built yet; the spec holds the current plan and its open questions.

## Working with specs

- **Update the spec in the same commit as the behaviour change.** A spec that disagrees
  with the code is a bug in one of them.
- **New features start as a draft spec.** Settle the open questions there before
  building, then flip the status to *Built* when it ships.
- **Record decisions with a date and the reason**, especially when an alternative was
  rejected, so the question doesn't get reopened later.
- **Keep it to rules, not code.** Name the type that owns a rule so it can be found
  (e.g. `Handle`, `BalanceMood`), but don't copy implementations.
- This is a public repo: no secrets, no real people's details.
