# People

**Status:** Draft. Not built. Depends on [Groups](groups.md).

## Summary

A list of **people you've squabbled with before**, so that adding someone to a new
squabble, or finding someone, doesn't mean typing their handle every time. It isn't a
social network: there are no friend requests, followers or feeds.

## Decisions (Nov 2026)

- **No guests exist** (see [Groups](groups.md#decisions-nov-2026)), so everyone in the
  list is a real user with a uid. No matching people by name.
- **No hiding in v1.** The list only shows people you already share a squabble with. Add
  hiding later if it's wanted.
- New people arrive by **exact handle** or an **invite link**. Contact matching stays
  deferred (see [Profile](profile.md#handles)).

## Where it shows up

- **New squabble → add members:** people first, then handle lookup, then an invite link.
  This is the main use.
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

- **Source:** every `members` entry in any group the user belongs to (including archived
  groups), excluding the user themselves and **deleted members**. Former members of a
  group (those with `leftAt`) still count.
- **Dedup:** by uid. The displayed name and avatar come from the most recently updated
  group.
- **Order:** most recent shared activity first (the group's `updatedAt`), then by name.
- **Search:** local filter on display name and handle, ignoring case and diacritics. If
  the query is a valid handle that isn't in the list, also offer an exact
  `handles/{handle}` lookup in the same results.
- **Privacy:** only people the user already shares a group with are listed, using data
  already visible to them. Nothing new is exposed.

## Open questions

1. **Approach A vs. B:** confirm A for v1.
