# Groups (squabbles)

**Status:** Draft. Not built. Settle the open questions before implementing.

## Summary

A **squabble** is a group of people who share bills: a trip, a flat, or a single dinner.
**Every bill belongs to a squabble.** A one-off dinner is just a small squabble. In code
and in Firestore it's called a *group*; in the UI it's a *squabble*.

## Decided so far

- Bills always belong to a group. There are no free-floating bills between two people.
- Members can be **app users** (with a uid) or **guests** (a name only, for people
  without the app).
- Each group has one **currency**. Bills in it default to that currency.
- Home lists the user's groups with one listener: `groups` where
  `memberIds array-contains uid`.
- Member details (name, avatar, payment details) are **copied into the group** so
  group-mates can read them without reading each other's private documents.

## Data model (planned)

```
groups/{groupId}
  name, currency, createdBy, createdAt, updatedAt
  memberIds: [uid]                       ← app users only; drives the rules + home query
  members: {
    memberId: {                          ← memberId: the uid for app users, random id for guests
      uid?, displayName, handle?, avatar, payment?, joinedAt
    }
  }
groups/{gid}/bills/{billId}              see bills.md
groups/{gid}/settlements/{id}            see bills.md
groups/{gid}/reminders/{id}              see bills.md
```

### Denormalized member data

- When a user is added, their current `displayName`, `handle`, `avatar` and payment
  methods are copied into `members[uid]`.
- **Profile edits fan out on the client.** When users change their profile or payment
  details, the app also updates their own entry in every group they belong to. The rules
  let a member edit only their own entry.
- A stale copy is acceptable: it's only a display name or avatar, and it heals on the
  next edit.

## Creating a squabble

1. Tap `+` on home.
2. Enter a name, and pick a currency (defaults to the home currency).
3. Add members from three sources, in this order of prominence:
   - **People you've squabbled with before** (see [People](people.md))
   - **Exact handle lookup** (`handles/{handle}` → `users/{uid}`)
   - **Guest by name**
4. The creator is always a member.
5. Save. This is a single document write, so it works offline.

## Rules (planned)

- Read the group and its subcollections: only uids in `memberIds`.
- Create: the creator's uid must be in `memberIds`, and `createdBy == auth.uid`.
- Update by a member:
  - edit their own `members[uid]` entry
  - rename the group / change its currency (to decide)
  - add members
- Guests have no uid, so they can't read anything. They exist only as names inside the
  group.

## Open questions

1. **Adding app users:** can members add someone directly by handle, or does the other
   person have to accept (an invite)? Adding directly is simpler but lets anyone put you
   in a group. Invite links / QR codes are planned for later either way.
2. **Turning a guest into a user:** when a guest later installs the app, can they
   *claim* their guest entry (via an invite link) so the history moves to their uid?
3. **Leaving and removing members:** allowed only with a zero balance? What happens to
   their bills?
4. **Deleting a squabble:** who can do it, and is it allowed while balances are open?
5. **Account deletion:** what happens to the deleted user's entry in each group? One
   option is to keep it as a guest ("Deleted member") so the totals still add up, and
   strip the payment details and handle. This must go into `deleteUserData`.
6. **Changing the currency** after bills exist: forbid it, or only allow it while the
   group is empty?
7. **Group size limit:** the members map lives in one document, so a cap of about
   50 members is probably sensible.
