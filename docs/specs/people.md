# People

**Status:** Draft. Not built. Depends on [Groups](groups.md).

## Summary

A list of **people you've squabbled with before**, so that adding someone to a new
squabble, or finding someone, doesn't mean typing their handle every time. It isn't a
social network: there are no friend requests, followers or feeds.

## Where it shows up

- **New squabble → add members:** recent people first, then handle lookup, then "add a
  guest". This is the main use.
- **Home search:** results across squabbles and people.
- **Later:** a person's page (shared squabbles, net balance with them) and the "friend
  leaderboard" on the roadmap.

## Approaches considered

| | How it works | Pros | Cons |
| --- | --- | --- | --- |
| **A. Derived from groups** | Everyone in the `members` maps of the user's groups, deduplicated by uid | No extra documents or reads (home already listens to the groups); works offline; nothing to keep in sync | People disappear when you leave every group you shared with them; data only as fresh as the copies in those groups |
| **B. Server-kept list** | `users/{uid}/people/{otherUid}`, maintained by a Cloud Function on group member changes (`lastSharedAt`, `sharedGroupCount`) | Persists after leaving groups; "recent" and "frequent" sorting for free | Extra writes; another thing for `deleteUserData`; deleting an account fans out to everyone's lists |
| **C. Explicit friends** | Friend requests / accept | Familiar | A whole social graph a bill splitter doesn't need |

**Recommendation:** start with **A**, behind a protocol-typed `PeopleRepository`, so it
can be swapped for **B** without changing any screens. Move to B only if "they vanished
from my list" or recency ranking turns out to matter.

## Behaviour (with approach A)

- **Source:** every member with a `uid` in any group the user belongs to, excluding the
  user themselves.
- **Dedup:** by uid. The displayed name and avatar come from the most recently updated
  group.
- **Order:** most recent shared activity first (the group's `updatedAt`), then by name.
- **Search:** local filter on display name and handle, ignoring case and diacritics. If
  the query is a valid handle that isn't in the list, also offer an exact
  `handles/{handle}` lookup in the same results.
- **Privacy:** only people the user already shares a group with are listed, using data
  already visible to them. Nothing new is exposed.

## Open questions

1. **Guests:** should they appear in the people list? They have no uid, so recognising
   the same guest across groups would mean guessing from names. Proposed: no, guests stay
   per-group, and the user can re-add one by name.
2. **Hiding someone** from the list: needed for v1?
3. **Do we need more** than "people from my groups + exact handle"? Contact matching was
   deferred (see [Profile](profile.md#handles)), and invite links / QR codes cover the
   "first time" case later.
