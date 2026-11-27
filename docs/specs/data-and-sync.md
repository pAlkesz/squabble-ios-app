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
| `createInviteForNewGroup` | Firestore trigger on new groups | Built ([Groups](groups.md#joining-with-an-invite-link)) |
| `createInvite`, `resetInvite`, `previewInvite`, `joinGroup` | Callables | Built ([Groups](groups.md#joining-with-an-invite-link)) |
| People sync | Firestore triggers on groups and users | Planned ([People](people.md#keeping-it-up-to-date-cloud-functions)) |
| `updateRates` | Scheduled, every six hours | Built ([Bills](bills.md#exchange-rates)); rates by day planned |
| `updateBalances` | Firestore trigger on bills | Built ([Bills](bills.md#balances)); settlements and frozen conversions planned |
| `changeGroupCurrency` | Callable | Planned ([Groups](groups.md#currency)) |

## Current layout

```
users/{uid}                      public profile; any signed-in user can read it
  displayName, handle, avatar, createdAt, updatedAt
users/{uid}/private/payment      owner-only: { methods: [...] } (max 5)
users/{uid}/private/preferences  owner-only: { homeCurrency? }
handles/{handle}                 { uid }: the uniqueness lock
groups/{groupId}                 a squabble; current members can read it (see groups.md)
  inviteCode?                    written only by the invite functions
invites/{code}                   { groupId, createdAt }: only the invite functions touch it
groups/{groupId}/messages/{id}   chat messages (see chat.md)
groups/{groupId}/bills/{id}      bills (see bills.md)
reports/{id}                     reported messages and why; create-only, read by the developer
avatars/{uid}/{random}.jpg       Storage: square JPEG, < 1 MB
groupImages/{uid}/{random}.jpg   Storage: squabble photos, filed by uploader, < 1 MB
```

The rules are in `firestore.rules` and `storage.rules`. Any change to this layout changes
the rules and this spec in the same commit.

### Rules summary

| Path | Read | Write |
| --- | --- | --- |
| `users/{uid}` | any signed-in user | owner only; shape-checked; must point at a handle the owner holds |
| `users/{uid}/private/*` | owner | owner; `payment` = `methods` list ≤ 5, `preferences` = optional 3-letter code |
| `handles/{h}` | any signed-in user | create: own uid, valid handle, profile names it. Delete: owner. **Never updated.** |
| `groups/{id}` | current members (`memberIds`) | create: creator first, ≤ 50 members, valid own entry. Update: a member's own entry, or `updatedAt` to now; not while archived |
| `invites/{code}` | nobody | nobody (functions only) |
| `groups/{id}/messages/{m}` | current members | create: as yourself, text ≤ 4,000, no reactions. Update: your own reaction, or the author soft-deletes. Not while archived |
| `groups/{id}/bills/{b}` | current members | any member creates, edits or soft-deletes, as themselves; shape-checked. Not while archived |
| `reports/{id}` | nobody | create: members of the reported squabble, as themselves |
| `avatars/{uid}/*` | any signed-in user | owner; `.jpg`, `image/jpeg`, < 1 MB |
| `groupImages/{uid}/*` | any signed-in user | uploader; `.jpg`, `image/jpeg`, < 1 MB |

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

## Failure states

What happens when a load or a write fails (surveyed Nov 2026):

- **Handled:** the profile listener (`ProfileSyncFailedSheet`: retry or sign out); the
  chat ("Chat isn't loading"); one-off calls (invite preview and join, onboarding's save,
  the handle check, photo upload) show their own inline error or alert.
- **Fall back quietly, which is fine:** exchange rates (a rough table) and preferences (the
  phone's region currency).

**Planned, not built:**

- **Squabbles listener:** a failure is only logged, so home's tile never appears and
  nothing says why. Needs a failure state with retry, on home's tile and the list.
- **Chat:** the failure text needs a retry button.
- **Refused writes:** messages, bills and edits are written to the cache first; if the
  server's rules refuse one later, it silently disappears and is only logged. Decide how
  to tell the user (at least for bills).

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
- every `reports/*` document the user filed (`reportedBy`); reports about their messages
  (`authorId`) stay, with the copied `text` removed, as their messages are blanked

Every step is safe to repeat. **Anything new stored per user must be added to this
function.**

For groups (built Nov 2026), it also, for every group the user is a current member of:

- blanks the text of the user's chat messages (marking them deleted) and drops their
  reactions (built Nov 2026; see [Chat](chat.md))
- removes the uid from `memberIds`
- replaces the user's entry in `members` with `{ deleted: true }`
- hands `createdBy` on to the earliest-joined member (ties go by `memberIds` order)
- deletes the group (its messages, photo and invite included) if nobody is left

Squabble photos the user uploaded (`groupImages/{uid}/`) are **not** deleted with the
account: they belong to squabbles other people are still in.

**Planned:** it will also delete every `people` document about the user from other
users' lists.

See [Groups](groups.md#account-deletion) and [People](people.md).

## Telemetry

Handled errors go to Crashlytics, and events go to Analytics, through the `Core/Logging`
facade only (`AppLog`). Features never import Firebase.
