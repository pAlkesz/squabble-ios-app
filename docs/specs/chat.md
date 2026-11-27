# Squabble chat

**Status:** Partly built (Nov 2026). Built: text messages, day headers, runs, replies,
reactions, copy, delete, report, the composer, paging, rules and account-deletion cleanup.
Bill entries, their details sheet, Add a bill, and the standing in the bar.
Not built: settlement entries, system lines, and reactions and replies on bills.

## Summary

Every squabble's page is a **chat timeline**, like Revolut's group page: messages from
members, and every bill, settlement and membership event as an entry in the same stream,
newest at the bottom. The composer sits at the bottom.

## Timeline

- **Entries, oldest at the top:** text messages, GIFs, bills, settlements, and system
  lines ("Anna joined", "Pál started the squabble"). Day separators ("Today", "Tue",
  "Sep 30") break it up.
- **Own messages on the right**, others on the left with the author's avatar; consecutive
  entries from one author (messages and the bills they added, same day, at most 5 minutes
  apart) group together into a run: the avatar and a curled tail (`ChatBubbleShape`, as in
  Revolut's chat) on the last bubble only, the name on the first message, and again on a
  message right after a bill, since the card doesn't say who added it. A deleted bill
  breaks a run (Nov 2026).
- **Bill entries** are cards (`BillCard`), on the right when the user added them: a pill with
  the user's side of it ("You owe Anna", "You're owed", "You're not in this one"), that amount
  large, "<payer> paid <total> · <title>", the avatars of everyone sharing it, and the time.
  A deleted bill is one quiet line saying who deleted it.
- **Settlement entries:** "Marked as paid" pill, the amount large, "To <name>".
- **Empty:** the ready state ("Your squabble is ready", the invite link, next steps).
- The bar shows the name and, under it, the user's standing ("You're settled up", "You
  owe 12 €", "You're owed 30 €").

## Interactions

- **Long press on a message:** `ChatMessageMenu`, our own rather than the system context
  menu, which can't hold a large, separate emoji bar (Nov 2026). The page blurs; the message
  stays where it was (moved only as far as it takes to fit): the menu draws an exact copy of
  it, name, tail and reaction pill included, never faded or scaled, and the original is hidden
  in the list meanwhile, so only one is ever visible; on closing the original comes back first, under
  the copy, and the menu goes a moment later, so no frame shows neither (the blur covers the bar and the composer,
  so the original itself can't sit above it). When the menu needs room, the copy glides from
  the original to where it fits and back onto wherever the original is when it closes, a large reaction bar sits above it
  (❤️ 😂 😮 😢 🙄 👍, yours highlighted, and a **+** that opens `EmojiPickerSheet`: every
  emoji in Unicode's groups, no skin tones, searchable by English name, from the bundled
  `Emoji.json` generated from Unicode's emoji-test.txt; the emoji keyboard was tried first and
  dropped for a sheet) and the actions below it, laid out like an iOS menu (symbol first, no dividers): **Reply**,
  **Copy** (once the menu has closed, a "Copied to clipboard" toast on glass floats up above
  the composer for two seconds and is announced to VoiceOver; `SquabbleToast`), **Delete** (own messages, confirmed: "Message deleted" stays in place) or
  **Report** (others' messages: opens `ChatReportSheet`, below). The bar and the actions are separate pieces of
  Liquid Glass, and grow out of the message's edge as they fade in, shrinking back into it
  before whatever was chosen happens (Reduce Motion: fades only). Tapping outside closes it; VoiceOver reaches it
  through a "React or reply" action. Bills have no long press yet.
- **Tap a bill or settlement:** a sheet with its details (items, who owes what, edits
  history), **Edit** and **Delete** (any member, per [Bills](bills.md)).
- **Tap a message:** nothing.
- **Reactions:** one emoji per person per entry; choosing your own again in the long-press
  menu removes it, once the menu has closed (so the copy still matches the message). A pill
  coming or going pops in, and the rows around it make room smoothly; the animation sits on
  the scroll view, so the shift the bottom-pinned list makes above a growing row is animated too. Message times are `.caption`, bills' too. Shown as one dark pill (`ReactionChip`, opaque so it reads over the
  bubble) on the bubble's bottom-right corner whoever wrote it, as in Messenger: the three
  most common emoji, then the total when there's more than one, overlapping only the
  bubble's bottom padding, with the same faint ring whoever reacted. The room it needs is left
  below the row, so the author's avatar stays level with the bubble. Tapping the pill opens
  `ChatReactionsSheet`: who reacted with what, yours first, and tapping yours takes it back
  (Nov 2026).
- **Replies** quote the original (author and up to 120 characters), laid out like Messenger's
  (Nov 2026, `ChatReplyHeader`): above the reply a "↩ Anna replied to Béla" line ("You
  replied to …", "… replied to you", "… replied to themselves", "You replied to yourself"),
  then the quote as a faded bubble the reply overlaps; the reply keeps its usual colour, cutting
  the quote away beneath it, and doesn't repeat the author's name inside, as the line says it.
  Tapping the quote scrolls to the original if it's loaded. A reply being written shows above the field with a ✕.

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
  timeline merges them on the device by `createdAt` (`ChatEntry.merged`), showing only as far
  back as both have been loaded, so nothing turns up later in the middle. Their reactions live on the bill or
  settlement document in the same `reactions` map.
- **Reads cost money:** one listener per collection on the **latest 50** entries;
  older ones load in pages of 50 with `getDocuments` as the user scrolls up (`ChatStore`).
  Messages the live page moves past stay on screen. If it jumps ahead with a possible gap
  (a long time offline), the timeline starts over from it. Only the server can say where a
  chat begins, never the cache. A page loads once the scroll settles near the top, and the
  list stays on the message it was on.
- **A squabble just created** may not have reached the server when its page opens, so the rules
  refuse its chat and bills. Until it has (`SquabbleGroup.isAwaitingServer`), that isn't a
  failure: the page shows as empty, and starts listening again once it's there.
- **An empty cache isn't an empty chat** (Nov 2026): when the squabble has a `lastActivity`
  but the phone's cache answers with nothing (it hasn't seen those messages yet), the page
  waits for the server rather than flash the "ready" state, for at most
  `ChatStore.serverPatience` (2 s), after which it shows what the cache has (offline).
- **A chat opens already at the bottom**, without scrolling there (Nov 2026): the list isn't
  mounted until both feeds have loaded, and catching up from the cache to the server jumps.
  Only new entries while live, or your own, scroll in.
- **Sending bumps the squabble's `updatedAt`** in the same batch (Nov 2026), so "most
  recently active" includes chat, and sets its `lastActivity` for the squabble lists
  ([groups.md](groups.md)). It costs one write, and a group read per listening member,
  per message.
- **Tapping anywhere above the composer puts the keyboard away**, as does scrolling. The
  focus change is deferred out of the tap's own update; made inside it, the page snapped
  down while the keyboard was still sliding away. The
  empty "ready" state is a plain centred view (a scroll view only when it can't fit): one
  sized to the screen snapped to the keyboard instead of riding up with it.
- `reports/{id}`: `{ groupId, messageId, authorId, text, reason, reportedBy, createdAt }`,
  create-only for members of that squabble; nobody reads it from the app. `reason` is a
  `ChatReportReason` raw value (`harassment`, `hate`, `scam`, `spam`, `sexual`, `violence`,
  `other`), required and checked by the rules; never rename one.
- **Rules:** members read; a member creates messages as themselves; only the author
  soft-deletes; any member edits only their own key in `reactions`; nothing while the
  squabble is archived.
- **Account deletion:** `deleteUserData` deletes the reports the user filed, and removes the
  copied `text` from reports about their messages (those stay). It blanks the user's message texts and drops their
  reactions; the messages stay, shown from "Deleted member", so replies still make sense. A
  squabble whose `lastActivity` quotes their message says "deleted a message" instead.

## Moderation

Chat is user-generated content, so App Review (guideline 1.2) wants a way to **report**
content and to keep away from abusive users.

- **Report** (built Nov 2026): from the long-press menu on someone else's message,
  `ChatReportSheet` asks what's wrong with it: Harassment or bullying, Hate speech, Scam or
  fraud, Spam, Sexual content, Violence or threats, Something else. Send report stays
  disabled until one is picked; nothing is written before it. It writes one `reports`
  document (offline too, synced later) and, once the sheet is gone, a "Reported" toast
  shows. The author is never told, and nobody is notified: reports are read in the Firebase
  console. Reporting the same message twice files two reports.
- **Planned:** leaving the squabble (and blocking, if App Review asks for more).

## Open questions

None at the product level.
