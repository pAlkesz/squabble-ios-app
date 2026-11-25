# Squabble chat

**Status:** Partly built (Nov 2026). Built: text messages, day headers, runs, replies,
reactions, copy, delete, report, the composer, paging, rules and account-deletion cleanup.
Not built: bill and settlement entries and their detail sheet (they need [Bills](bills.md)),
system lines, Add a bill (shown, disabled), and the standing in the bar.

## Summary

Every squabble's page is a **chat timeline**, like Revolut's group page: messages from
members, and every bill, settlement and membership event as an entry in the same stream,
newest at the bottom. The composer sits at the bottom.

## Timeline

- **Entries, oldest at the top:** text messages, GIFs, bills, settlements, and system
  lines ("Anna joined", "Pál started the squabble"). Day separators ("Today", "Tue",
  "Sep 30") break it up.
- **Own messages on the right**, others on the left with the author's avatar; consecutive
  messages from one author group together, the avatar shown on the last one and the name
  on the first.
- **Bill entries** are cards: a pill with the user's side of it ("You owe Anna", "Anna
  owes you", "You're not in this one"), the bill total large, "<payer> paid <amount> ·
  <title>" (with the converted amount when the bill is in another currency), the avatars
  of everyone sharing it, and the time.
- **Settlement entries:** "Marked as paid" pill, the amount large, "To <name>".
- **Empty:** the ready state ("Your squabble is ready", the invite link, next steps).
- The bar shows the name and, under it, the user's standing ("You're settled up", "You
  owe 12 €", "You're owed 30 €").

## Interactions

- **Long press on any entry:** a reaction row (❤️ 😂 😮 😢 🙄 👍, the system menu's
  palette; a full emoji picker can come later) and actions: **Reply**, **Copy** (text
  messages only), **Delete** (own messages, confirmed: "Message deleted" stays in place) or
  **Report** (others' messages, confirmed).
- **Tap a bill or settlement:** a sheet with its details (items, who owes what, edits
  history), **Edit** and **Delete** (any member, per [Bills](bills.md)).
- **Tap a message:** nothing.
- **Reactions:** one emoji per person per entry; tapping your own again removes it.
  Shown as small chips under the entry, with counts.
- **Replies** quote the original (author and up to 120 characters); tapping the quote
  scrolls to it if it's loaded. A reply being written shows above the field with a ✕.

## Decisions

- **Settle up goes at the right of the composer** (Nov 2026, planned with settlements): a
  small labelled button, shown only when there's something to settle and hidden while
  typing, so Send has the space.
- **Add a bill lives in the composer** (Nov 2026; on the left, leaving the right free for a
  future Settle up shortcut): a button at the left of the message
  field, like iMessage's `+`. Revolut stacks a full-width button above the field, which
  doubles the bottom bar; the bar at the top is the hardest place to reach for the app's
  main action.
- **No GIFs in v1** (Nov 2026). Emoji come with the system keyboard. GIFs (GIPHY's API,
  no SDK) can come later.
- **No push notifications in v1** (Nov 2026). They need Firebase Cloud Messaging and an
  APNs key; they'll come once, for messages and reminders together.

## Composer

- A text field ("Type a message…") with the system keyboard, emoji included, and the
  **Add a bill** button at its left.
- Messages are trimmed and capped at 2,000 characters; the field grows to five lines and
  the send button appears once there's text.
- Sending is a fire-and-forget write: the message shows straight away, marked "not sent
  yet" while `hasPendingWrites` (offline).

## Data model (planned)

```
groups/{gid}/messages/{messageId}
  authorId, createdAt,
  kind: text | gif,
  text?,                                   ← kind text
  gif?: { provider, id, url, width, height } ← kind gif, later; only the id and display URL
  replyTo?: { id, authorId, preview }       ← denormalized, so a reply never needs a read
  reactions: { uid: emoji }
  deletedAt?                               ← soft delete: shown as "Message deleted"
```

- Bills and settlements stay in their own collections (see [Bills](bills.md)); the
  timeline merges them on the device by `createdAt`. Their reactions live on the bill or
  settlement document in the same `reactions` map.
- **Reads cost money:** one listener per collection on the **latest 50** entries;
  older ones load in pages of 50 with `getDocuments` as the user scrolls up (`ChatStore`).
- `reports/{id}`: `{ groupId, messageId, authorId, text, reportedBy, createdAt }`,
  create-only for members of that squabble; nobody reads it from the app.
- **Rules:** members read; a member creates messages as themselves; only the author
  soft-deletes; any member edits only their own key in `reactions`; nothing while the
  squabble is archived.
- **Account deletion:** `deleteUserData` blanks the user's message texts and drops their
  reactions; the messages stay, shown from "Deleted member", so replies still make sense.

## Moderation

Chat is user-generated content, so App Review (guideline 1.2) wants a way to **report**
content and to keep away from abusive users. Planned: "Report" in the long-press menu
(writes to a `reports` collection only the developer reads), and leaving the squabble.

## Open questions

None at the product level.
