# Onboarding

**Status:** Built

## Summary

A signed-in user with no profile goes through three pages: **name + handle → avatar →
payment details**. Nothing is saved until the last page. Then the profile, the handle
claim and the payment details are written in a single transaction.

## Flow

- Onboarding is pushed on top of the sign-in screen, with **no way back**. A signed-in
  user without a profile has nothing to do on the sign-in screen.
- Only the buttons move between pages; there's no swiping, so the handle check can't be
  skipped.
- The draft (`OnboardingDraft`) holds everything entered so far, in memory only.

## Page 1: name and handle

- **Display name** is prefilled from Apple's name if Apple sent one. It's trimmed, can't
  be empty, and is capped at **50 characters** (`UserProfile.maxDisplayNameLength`).
  Input past the cap is dropped as the user types.
- **The handle follows the name** (`Handle.suggestion(from:)`: diacritics folded,
  lowercased, spaces/`-`/`.` turned into `_`) until the user edits the handle
  themselves. From then on it stays as typed.
- **Handle rules** (see [Profile](profile.md#handles)): `a–z 0–9 _`, 3–32 characters,
  lowercased, and a leading `@` is ignored.
- **Availability is checked live** (`HandleAvailabilityChecker`), debounced by about
  400 ms:
  - Invalid input and offline are settled locally, without asking the server.
  - Otherwise the server is asked whether `handles/{handle}` is free, or already belongs
    to this user.
  - **Only a server-confirmed "available" lets the user continue.** This page is where
    the handle gets settled, not the final save.
- **Suggestions:** when online, up to a few free alternatives are offered, built from the
  name with fixed patterns (`name`, `name2`, `name_pays`, `the_name`, `name_owed`,
  `name3`; see `HandleSuggestions`). The patterns are fixed rather than random, so the
  same name always gets the same suggestions. A failed lookup just means one fewer
  suggestion.

## Page 2: avatar

- Choices: one of the **personas**, each on its own colour, or a **photo** (from the
  library or camera).
- Each tile gets a colour from a shuffled palette, so no two tiles share a colour while
  there are enough colours to go round.
- **A random persona is preselected**, so a user who skips past this page still gets a
  character.
- A picked photo is prepared on the device (512 px square JPEG) and selected straight
  away. It stays in the draft if the user switches to a persona and back.
- The plain bird (`Avatar.preset`) is no longer offered here.

## Page 3: payment details

Optional. Up to 5 methods, validated as described in
[Payment details](payment-details.md).

## Saving

1. If the chosen avatar is a photo, upload it first. The upload is remembered, so a retry
   after a failed save doesn't upload it twice.
2. In one Firestore transaction:
   - read `handles/{handle}`; if another user holds it, fail with `handleTaken`
   - claim the handle (`{ uid }`) unless this user already holds it
   - write `users/{uid}` (with server timestamps `createdAt`/`updatedAt`)
   - write `users/{uid}/private/payment`
3. **This needs a connection.** Handle uniqueness can't be settled from the local cache.

**On failure:**

- *Handle taken* (someone grabbed it since the check): the user goes back to page 1 with
  the handle marked as taken and an error shown.
- *Anything else:* an error is shown and the user stays where they are, so they can retry.

## After onboarding

The session state goes from `needsOnboarding` to `signedIn`. Only in that transition,
never for a returning user, the **membership welcome** overlays home: the new membership
card slides up and gets an "APPROVED" stamp, and the user taps "Let's squabble" to enter
home.
