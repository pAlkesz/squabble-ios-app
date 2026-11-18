# People

**Status:** Draft. Not built. Depends on [Groups](groups.md). All product questions
settled (Nov 2026).

## Summary

A list of **people you've squabbled with before**, so that adding someone to a new
squabble, or finding someone, doesn't mean typing their handle every time. It isn't a
social network: there are no friend requests, followers or feeds.

## Decisions (Nov 2026)

- **A list kept up by the server** (approach B below). Each user's list is maintained by
  Cloud Functions, so **people stay on it after you leave every squabble you shared**,
  and it can be sorted by recency.
- **No guests exist** (see [Groups](groups.md#decisions-nov-2026)), so everyone in the
  list is a real user with a uid. No matching people by name.
- **No hiding in v1.** Add it later if it's wanted.
- New people arrive by **exact handle** or an **invite link**. Contact matching stays
  deferred (see [Profile](profile.md#handles)).

## Where it shows up

- **New squabble → add members:** people first, then handle lookup, then an invite link.
  This is the main use.
- **Home search:** results across squabbles and people.
- **Later:** a person's page (shared squabbles, net balance with them) and the "friend
  leaderboard" on the roadmap.

## Data model

```
users/{uid}/people/{otherUid}
  uid                    ← the other user's uid, repeated so collection-group queries can find it
  displayName, handle, avatar
  firstSharedAt          ← when you first became members of the same squabble
  lastSharedAt           ← the last time you became members of the same squabble
```

**Rules:** only the owner can read it. **Nobody writes it from the app**: only Cloud
Functions (Admin SDK) do.

## Keeping it up to date (Cloud Functions)

| Trigger | Does |
| --- | --- |
| A group's `memberIds` gains uids | For each new member *N* and each existing member *M*, write `users/M/people/N` and `users/N/people/M`, setting `lastSharedAt` (and `firstSharedAt` if new) |
| A user's profile (`users/{uid}`) changes name, handle or avatar | Update every `people` document about them (collection-group query on `uid`) |
| A user's account is deleted (`deleteUserData`) | Delete every `people` document about them (collection-group query on `uid`). Their own `people` list goes with `users/{uid}` |

- **Leaving a group removes nobody from anyone's list.** That's the point of a server-kept
  list.
- **Cost:** someone joining a squabble of *n* members takes 2*n* writes (at most about
  100). A profile edit takes one write per person who has that user in their list.
- All triggers are safe to repeat (they set values, they don't count), so retries are
  harmless.

## Behaviour in the app

- **One listener** on `users/{uid}/people`, ordered by `lastSharedAt` (most recent
  first). It works offline from the cache.
- **Search:** a local filter on display name and handle, ignoring case and diacritics.
  If the query is a valid handle that isn't in the list, also offer an exact
  `handles/{handle}` lookup in the same results.
- Behind a protocol-typed `PeopleRepository`, like the other data layers.
- **Privacy:** only people you've shared a squabble with are listed, using profile fields
  that are already public. Nothing new is exposed.

## Open questions

None at the product level.
