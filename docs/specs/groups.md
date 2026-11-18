# Groups (squabbles)

**Status:** Draft. Not built. All product questions settled (Nov 2026); ready to
implement.

## Summary

A **squabble** is a group of people who share bills: a trip, a flat, or a single dinner.
**Every bill belongs to a squabble.** A one-off dinner is just a small squabble. In code
and in Firestore it's called a *group*; in the UI it's a *squabble*.

## Decisions (Nov 2026)

- **Bills always belong to a group.** There are no free-floating bills between two people.
- **Accounts only: no guests.** Every member is a Squabble user with a uid. Someone
  without the app is invited with a link and joins once they've signed up. This was
  chosen over name-only guests and over "pending" placeholders, because every member then
  has a profile and payment details, reminders always reach a real person, and
  [People](people.md) never has to match people by name. The cost is accepted: a dinner
  with a friend can't be recorded until they join.
- **Invite links are part of v1.** Without guests, they're the only way to bring in
  someone new.
- **Users already on Squabble are added directly** (from People or by exact handle), with
  no accept step. Someone added against their will can leave, as long as they're settled.
- **Invite links work until they're reset.** Each squabble has one reusable link, which
  any member can share. Joining goes through a **callable Cloud Function**, which checks
  the code server-side.
- **Leaving or being removed is allowed only when settled.** The member's balance in that
  squabble must be zero, so totals never break. Bills they were part of stay unchanged.
  **The app enforces this check, not the server.** A tampered app could skip it, but the
  bills stay intact either way, so no money record is lost.
- **Only the creator can remove other members.** Any member can remove themselves.
- **The creator role passes on.** If the creator leaves or deletes their account, the
  member who joined earliest becomes the creator. A squabble always has someone in charge.
- **The creator can delete or archive a squabble at any time, even with open balances.**
  With open balances, a warning lists who owes whom and asks for confirmation.
- **Archiving makes the squabble read-only for everyone** and moves it out of home's main
  list. Its balances stay visible and **still count** towards everyone's home total, so
  archiving can't hide a debt. **Archiving can be undone:** the creator can reopen the
  squabble.
- **Deleting a squabble** removes it and all its bills for everyone. This wipes open
  debts, which is why there's a confirmation step.
- **When a member deletes their account**, their entry stays as an anonymous **"Deleted
  member"**, so every bill and balance still adds up. Their name, handle, avatar and
  payment details are removed. Before deleting, the app warns users about what they still
  owe and to whom, but doesn't block them (App Review requires that deletion is always
  possible).
- **The currency can change at any time.** Stored amounts are never rewritten: each bill
  keeps the currency it was entered in, and the group's currency is the one its balances
  are *shown and settled* in, converted at current rates. See "Currency" below.
- **At most 50 members** per squabble. The members map lives in one document.

## Data model (planned)

```
groups/{groupId}
  name, currency, createdBy, createdAt, updatedAt
  archivedAt?                            ← set by the creator; read-only for everyone
  inviteCode                             ← current invite code; reset by the creator
  memberIds: [uid]                       ← current members; drives the rules + home query
  members: {
    uid: { displayName, handle, avatar, payment?, joinedAt, leftAt?, deleted? }
  }                                      ← former and deleted members stay for history
groups/{gid}/bills/{billId}              see bills.md
groups/{gid}/settlements/{id}            see bills.md
groups/{gid}/reminders/{id}              see bills.md
```

- `memberIds` holds **current** members only. Leaving removes the uid from `memberIds`
  but keeps the entry in `members` (with `leftAt`), so old bills can still show who was
  involved.
- A deleted account's entry keeps its uid key with `deleted: true` and nothing else
  personal. The app shows it as "Deleted member".
- At most 50 entries in `memberIds`.

### Denormalized member data

- When users join, their current `displayName`, `handle`, `avatar` and payment methods
  are copied into `members[uid]`.
- **Profile edits fan out on the client.** When users change their profile or payment
  details, the app also updates their own entry in every group they belong to. The rules
  let a member edit only their own entry.
- A stale copy is acceptable: it's only a display name or avatar, and it heals on the
  next edit.

## Creating a squabble

1. Tap `+` on home.
2. Enter a name, and pick a currency (defaults to the home currency).
3. Add members:
   - **People you've squabbled with before** (see [People](people.md))
   - **Exact handle lookup** (`handles/{handle}` → `users/{uid}`)
   - **Invite link** for anyone else: share it via the share sheet (or a QR code)
4. The creator is always a member.
5. Save. This is a single document write, so it works offline. Creating an invite link
   may need a connection, depending on how links are built.

## Joining with an invite link

- **One link per squabble**, `https://<our domain>/join/<inviteCode>`. Any member can
  share it (share sheet or QR code). It keeps working until the creator **resets** it,
  which generates a new code and kills the old link.
- `inviteCode` is a random, unguessable string (at least 128 bits).
- **Universal links** need an `apple-app-site-association` file on a domain we control.
  We'll serve it from Firebase Hosting. (Firebase Dynamic Links is shut down, so it
  isn't an option.)

**Flow:**

1. The recipient opens the link. Without the app, they install it, sign in and finish
   onboarding, and the link is then picked up again. If the code can't survive the
   install, they can open the link once more.
2. The app shows the squabble's name and member count, and the user confirms to join.
3. The app calls the **`joinGroup` callable function** with the code. It:
   - finds the group by `inviteCode`
   - refuses if the code is unknown/reset, the group is archived, or it already has
     50 members
   - otherwise adds the caller to `memberIds` and copies their profile and payment
     details into `members[uid]`
   - does nothing if the caller is already a member
4. Joining needs a connection.

Showing the name before joining also needs the server, since a non-member can't read
the group. The same function can answer a "preview" call with only the name and member
count.

## Currency

- Each bill stores its amounts in the currency it was entered in. **Stored amounts are
  never converted or rewritten.**
- The group's `currency` is its *display and settle-up* currency. Balances are summed per
  original currency, then converted into the group currency at current rates.
- Changing the group currency is therefore just a field update: every number on screen
  follows, and switching back gives back exactly what was there before. This avoids
  rewriting every bill, the rounding drift of repeated conversion, and conflicting edits
  from offline devices.
- The conversion uses the same exchange-rate source as the home total (see
  [Bills](bills.md#exchange-rates)).
- Groups whose bills all share one currency need no conversion at all.

## Rules (planned)

- **Read** the group and its subcollections: only uids in `memberIds`.
- **Create:** `createdBy == auth.uid`, the creator is in `memberIds`, and there are at
  most 50 members.
- **Update by a member** (not allowed while `archivedAt` is set):
  - edit their own `members[uid]` entry
  - add members (each added uid must exist)
  - remove themselves (the app checks they're settled)
  - rename the group / change its currency
- **Creator only:** set or clear `archivedAt`, reset `inviteCode`, remove other members,
  and delete the group.
- **No `inviteCode` reads for non-members.** Joining only happens through `joinGroup`,
  which runs as the Admin SDK, so the rules never let a non-member write.

## Creator succession

When the creator leaves or deletes their account, `createdBy` moves to the remaining
member with the earliest `joinedAt`:

- **Leaving:** the app makes this change in the same write that removes the creator.
- **Account deletion:** `deleteUserData` makes it.

If no members remain, the group is deleted.

## Account deletion

`deleteUserData` must also, for every group whose `memberIds` contains the uid:

- remove the uid from `memberIds`
- replace `members[uid]` with `{ deleted: true }`
- hand `createdBy` on if the user was the creator (see "Creator succession" above)

The Cloud Function runs with admin rights, so the security rules don't constrain it.
Before deletion, the app shows the user's open balances as a warning (see
[Sign-in](auth.md#deleting-the-account)).

## Open questions

None at the product level. Details like copy and screen layout get settled while
building.
