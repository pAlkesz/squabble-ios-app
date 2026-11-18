# Data & sync

**Status:** Built for the profile layer and the first part of groups. The rest of
groups and bills are in [Groups](groups.md) and [Bills](bills.md).

## Principles

- **The app talks to Firestore directly through the SDK.** The security rules are the
  access control. There's no REST layer: a Cloud Functions API would lose the offline
  cache and live listeners, and wouldn't make reads any cheaper.
- **Cloud Functions do server-side work, never reads.** That covers background triggers
  (data cleanup, the people lists, reminder pushes), one scheduled job (exchange rates)
  and one callable (`joinGroup`, for invite links, where a non-member needs the server
  to vouch for them).
- **Documents are shaped around screens.** Small, rarely-changing fields are
  denormalized, and whatever is always read together is embedded.
- **Reads cost money.** Use one listener per screen on a scoped query, cache reads where
  staleness is fine, and never re-query a whole collection to refresh a list.

## Functions

| Function | Kind | Status |
| --- | --- | --- |
| `deleteUserData` | Auth `onDelete` trigger | Built |
| `joinGroup` | Callable | Planned ([Groups](groups.md#joining-with-an-invite-link)) |
| People sync | Firestore triggers on groups and users | Planned ([People](people.md#keeping-it-up-to-date-cloud-functions)) |
| Exchange rates | Scheduled, daily | Planned ([Bills](bills.md#exchange-rates)) |

## Current layout

```
users/{uid}                      public profile; any signed-in user can read it
  displayName, handle, avatar, createdAt, updatedAt
users/{uid}/private/payment      owner-only: { methods: [...] } (max 5)
users/{uid}/private/preferences  owner-only: { homeCurrency? }
handles/{handle}                 { uid }: the uniqueness lock
groups/{groupId}                 a squabble; current members can read it (see groups.md)
avatars/{uid}/{random}.jpg       Storage: square JPEG, < 1 MB
```

The rules are in `firestore.rules` and `storage.rules`. Any change to this layout changes
the rules and this spec in the same commit.

### Rules summary

| Path | Read | Write |
| --- | --- | --- |
| `users/{uid}` | any signed-in user | owner only; shape-checked; must point at a handle the owner holds |
| `users/{uid}/private/*` | owner | owner; `payment` = `methods` list ≤ 5, `preferences` = optional 3-letter code |
| `handles/{h}` | any signed-in user | create: own uid, valid handle, profile names it. Delete: owner. **Never updated.** |
| `groups/{id}` | current members (`memberIds`) | create: creator first, ≤ 50 members, valid own entry. Update: a member's own entry only, not while archived |
| `avatars/{uid}/*` | any signed-in user | owner; `.jpg`, `image/jpeg`, < 1 MB |

## Offline behaviour

- Firestore persistence stays on. **Writes go to the local cache immediately** and sync
  later. The UI never blocks on the network.
- Where "not sent yet" matters (e.g. a reminder that hasn't reached anyone), the UI shows
  it using `metadata.hasPendingWrites`.

**What needs a connection:**

- Onboarding's save (handle uniqueness)
- The live handle check
- Photo upload
- The first "does this user have a profile?" check when nothing is cached
- Account deletion

## Money

- Firestore has no decimal type. **Amounts are stored as integer minor units (`Int64`)
  plus an ISO currency code** and converted to `Decimal` at the model boundary.
- **Never `Double`/`Float` for money.** The one exception is display heuristics that
  never change an amount, like the [balance mood](home.md#balance-mood).
- Every split must add back up to the exact total. See [Bills](bills.md#splitting).

## Account deletion

The app deletes only the Firebase Auth user (see [Sign-in](auth.md#deleting-the-account)).
Then the `deleteUserData` Cloud Function (first-generation `auth.user().onDelete`, retries
on, Admin SDK so the rules don't apply) deletes:

- every `handles/*` document whose `uid` matches. It's found by owner rather than through
  the profile, so a retry after the profile is gone still releases the handle.
- `users/{uid}` and all its subcollections (recursive delete)
- everything under `avatars/{uid}/` in Storage

Every step is safe to repeat. **Anything new stored per user must be added to this
function.**

For groups (built Nov 2026), it also, for every group the user is a current member of:

- removes the uid from `memberIds`
- replaces the user's entry in `members` with `{ deleted: true }`
- hands `createdBy` on to the earliest-joined member (ties go by `memberIds` order)
- deletes the group if nobody is left

**Planned:** it will also delete every `people` document about the user from other
users' lists.

See [Groups](groups.md#account-deletion) and [People](people.md).

## Telemetry

Handled errors go to Crashlytics, and events go to Analytics, through the `Core/Logging`
facade only (`AppLog`). Features never import Firebase.
