# Groups (squabbles)

**Status:** Partly built (Nov 2026).

- **Built:** creating a squabble (picture, name with presets, currency), home's tile and
  the full list, the squabble page (an empty "ready" state) and its info page (members),
  joining by invite link or QR code (sharing, reset, the join sheet), keeping your own entry
  current, the rules for all of
  that, and the account-deletion cleanup.
- **Not built yet:** adding people by handle or from People, leaving and removing, archive/delete, rename, and changing the picture
  or currency. Until adding people lands, a new squabble holds only its creator.

In code a squabble is `SquabbleGroup` (`Feature/Groups`), because `Group` is taken by
SwiftUI.

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
  name, currency, image, createdBy, createdAt, updatedAt
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
- **Whoever adds you can't copy your payment details**, because they're owner-only. Your
  entry starts without them, and your own app fills them in.
- **Each member keeps their own entry current** (`GroupsStore` + `OwnEntrySync`).
  Whenever home's group list, the user's profile or their payment details change, the
  app compares the user's entry in each group with their profile and rewrites only the
  entries that differ. This one mechanism covers profile edits, payment edits and newly
  added members. The rules let a member edit only their own entry, and never its
  `joinedAt`.
- Archived squabbles are skipped (read-only), and the sync doesn't bump `updatedAt`, so
  a rename doesn't reshuffle anyone's home list.
- A stale copy is acceptable: it's only a display name or avatar, and it heals the next
  time that member opens the app.

## Creating a squabble

**People aren't part of creating** (Nov 2026, like Revolut): the sheet asks only for a
picture, a name and a currency, and the squabble starts with its creator alone. People
are added afterwards from the squabble.

1. Tap `+` on home. The "Create squabble" sheet zooms out of the button.
2. **Picture** (optional; a big circle at the top, the same crop as everywhere else):
   - a photo from the library or camera (prepared on the device as a 512 px square JPEG)
   - or a **drawing** (`SquabbleArtwork`, playful takes on the `person.3` symbol: the trio
     and the suits so far, more coming) on a **gradient background** (`SquabbleBackground`, ten of them).
     A random one is preselected.
3. **Name**, 1–50 characters, **not unique**. Preset chips under the field fill in a name
   (the emoji only decorates the chip): Trip 🏝️, Flat 🛋️, Dinner 🍝, Party 🎉, Family 👨‍👩‍👧,
   Us two 💑 (`SquabblePreset`). A chip shows as selected while the field holds its
   name. Tapping one leaves the picture alone.
4. **Squabble currency**, defaulting to the home currency.
5. Tap **Squabble Up** (the white button at the bottom; a nod to the song).
   - Without a photo, it's a single document write, so it works offline.
   - With a photo, the photo is uploaded first, which needs a connection. Offline, the
     app says so before trying, and the user can remove the photo to create the squabble
     straight away.
6. **Cancelling** (✕): an untouched sheet closes straight away, by ✕ or a swipe down. Once
   anything is entered, swiping no longer closes it (too easy to do by accident while
   typing or scrolling) and ✕ asks before discarding.

## Squabble pages

Laid out like Revolut's group pages (Nov 2026):

- **List** (`SquabbleListView`, from home's tile title or "See all"): a `+` in the bar
  that zooms the create sheet out of itself, and every squabble in one card, most recently active first. Each row has a 56 pt picture, the name, "N members
  · CODE" and, on the right on the name's line, when it was last active (`ActivityDate`: the time today, the
  weekday within the last week, then the date, with the year only for earlier years).
- **Squabble** (`SquabbleView`): the name in the bar with a subtitle ("No bills yet"), the
  picture on the right of the bar, and **Add a bill** pinned at the bottom (disabled until
  bills exist). With no bills, the middle says "Your squabble is ready", with a joke line
  about being alone or about the member count and a card of what to do next.
- **Info** (`SquabbleInfoView`, from the picture in the bar): the picture, name and
  currency, and the members with "You" and "Started it" tags. Editing, inviting and
  leaving will go here.

Adding people (planned, from the info page):

- **People you've squabbled with before** (see [People](people.md))
- **Exact handle lookup** (`handles/{handle}` → `users/{uid}`;
  `ProfileRepository.profile(forHandle:)` already exists)
- **Invite link** for anyone else, shared via the share sheet or a QR code

## Picture

- Stored on the group as `image`: `{kind: artwork, artwork, background}` or
  `{kind: photo, path, url}`. Squabbles made before drawings (Nov 2026) have
  `{kind: emoji, emoji, color}`, which is still shown but no longer offered or allowed by
  the rules.
- **Drawings replaced emojis** (Nov 2026). The backgrounds are a palette of their own,
  gradients rather than the avatar colours, so a squabble never looks like a person.
  Drawings ship as transparent 600 px PNGs in `Assets.xcassets/SquabbleArt`, framed to
  fill the disc with the figures running off its bottom, and only the id is stored.
  Framing: the figures are cropped from whatever space the source has around them and
  scaled to about 1.15–1.3× the disc's width (whichever puts the heads at a similar size
  to the others), with their base 4% below the disc so it never shows as a line. Ids are
  shape-checked by the rules, and an app that doesn't know one shows the first drawing on
  the stored background, so new drawings need no rules deploy. Never rename an id.
- **Always shown as a circle** (`SquabbleImageView`): on home's row, on the squabble
  page, and on the create sheet. What you see when choosing is exactly what everyone
  gets.
- Groups saved without an `image`, or with one this app can't read, show the first
  drawing on `SquabbleBackground.default(for: groupID)`.
- **Photos live at `groupImages/{uploader uid}/{random}.jpg`.** They're filed by
  uploader, not by squabble, so the Storage rules can check ownership without reading
  Firestore, and the upload can happen before the squabble exists.
  - A photo belongs to the squabble: deleting the uploader's account leaves it.
  - Deleting the squabble deletes it (done in `deleteUserData` when a squabble is left
    empty; the same goes for squabble deletion once that exists).

## Joining with an invite link

- **One link per squabble**, `https://<our domain>/join/<inviteCode>`. Any member can
  share it (share sheet or QR code). It keeps working until the creator **resets** it,
  which generates a new code and kills the old link.
- `inviteCode` is a random, unguessable string (at least 128 bits).
- **Universal links** use **Firebase Hosting on the project's `squabble-9c1df.web.app`**
  (Nov 2026: free, no domain to buy; Firebase Dynamic Links is shut down). Hosting serves
  `apple-app-site-association` for `/join/*` and a small "get the app" page for people
  without it. Moving to a custom domain later means keeping a redirect for old links.

**Sharing** (Nov 2026, like Revolut's): the info page and the empty squabble page show the
**link itself with a QR button** beside it, cut off at the end. Tapping the link opens the
system share sheet; the QR button fades in an **overlay** over the blurred page: a card with
a QR code of the link (the squabble's picture in its centre, so the code uses high error
correction), the squabble's name, a line on what the link does, and a white **Share link**
button. The QR code is drawn on the device (Core Image), so it works offline once the
squabble has a code. Without a code (offline before one exists) the row says **Invite
people** and opens the overlay, which can retry. The creator also gets **Reset link** in the
overlay (confirmed first; people already in stay in): the way to shut out a link that got
to the wrong people.

- `inviteCode` is minted by the server (`createInvite`, the first time any member opens
  a page showing the link), never by the app, so the rules never have to vouch for it. It's stored on
  the group (members see it offline from then on) and in `invites/{code}` → `groupId`,
  which only the functions read. `resetInvite` (creator only) replaces both.

**Flow:**

1. The recipient opens the link. Without the app they land on the "get the app" page;
   once installed they open the link again. Opened before signing in, the code waits
   (`InviteInbox`) through sign-in and onboarding, and shows once home is up (after the
   membership welcome).
2. The app shows the squabble's picture, name and member count (`previewInvite`), and the
   user taps **Join the squabble**. Someone already in gets **Open squabble**.
3. The app calls the **`joinGroup` callable function** with the code. It:
   - finds the group by `inviteCode`
   - refuses if the code is unknown/reset, the group is archived, or it already has
     50 members
   - otherwise adds the caller to `memberIds` and copies their profile and payment
     details into `members[uid]`, with the server's `joinedAt`, and bumps `updatedAt`
   - does nothing if the caller is already a member
4. Joining needs a connection. The app opens the squabble once home's listener has it.

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

## Rules

**Deployed (Nov 2026):** read, create, and updating your own entry. Everything else
below is planned and gets its rule along with its screen.

- At creation, the picture is shape-checked: a drawing id of the right shape on a known
  background,
  and a photo's path must be in the creator's own `groupImages/` folder.
- At creation, the rules check the shape of the creator's own entry only. Rules can't
  loop over the other entries; those are copies of public profiles, written by the
  creator, which the members then overwrite themselves.

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

None at the product level. Links last until the creator resets them (Nov 2026), unlike
Revolut's 72 hours: a squabble's link is shared in a group chat once and reused.
