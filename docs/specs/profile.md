# Profile

**Status:** Built

## Summary

Every user has a **public profile** made of a display name, a unique handle and an
avatar. Any signed-in user can read it. Payment details and preferences are private and
stored separately (see [Payment details](payment-details.md) and [Home](home.md)).

## Display names

- Free-form and **not unique**.
- Trimmed; 1–50 characters (`UserProfile.validDisplayName`). The security rules allow up
  to 100 to leave room for how emoji are counted, and only stop abuse.
- Can be changed any time from the account page.
- There's **no search by display name**: Firestore can't do full-text search.

## Handles

- **Unique**, written `@handle`. A handle is the only exact way to find someone.
- `a–z 0–9 _`, 3–32 characters, **stored lowercased** so `@Pal` and `@pal` can't be two
  different people. A leading `@` in input is ignored.
- Uniqueness is enforced by a lock document, `handles/{handle}` → `{ uid }`. It's claimed
  in the same transaction as the profile, and the rules check both directions: the
  profile must point at a handle this user holds, and the handle must point at a profile
  that names it.
- **Handles can't be changed after onboarding.** Changing one would mean releasing one
  lock and claiming another in a transaction. A handle is only released when the account
  is deleted.
- The handle appears as a Code 128 barcode on the membership card. That spot is reserved
  for a QR invite code once invite links exist.

## Avatars

Three kinds, stored in `users/{uid}.avatar`:

| Kind | Stored | Notes |
| --- | --- | --- |
| `persona` | persona id + colour | A joke character with a slogan, drawn on a coloured disc. The art ships in the app, so only the id is stored. |
| `photo` | Storage path + download URL | 512 px square JPEG, under 1 MB, at `avatars/{uid}/{random}.jpg` |
| `preset` | colour | The plain bird. **No longer offered**; kept for old profiles and as the fallback. |

### Rules

- **Personas are only for getting started.** After onboarding, the only avatar change is
  a photo. Removing the photo falls back to a *random* persona, not the previous one.
- **Unknown or unreadable avatars** show the bird on `AvatarColor.default(for: uid)`, a
  colour derived from a stable hash of the uid that's the same on every device.
- **Persona ids are checked by shape** in the rules (`[a-zA-Z0-9]{1,40}`), not against a
  list. New personas therefore ship without a rules deploy, and older app versions show
  the bird for ids they don't know.
- **Raw values are stored, so never rename one.** Persona names describe the character,
  never the real person who may have inspired it (public repo).
- The colour palette must have at least as many colours as there are personas, so every
  onboarding tile can have its own.
- **Photo changes sweep old uploads.** After the server accepts a new avatar, every other
  file under `avatars/{uid}/` is deleted (`AvatarStore.deleteAll(for:keeping:)`). This
  happens only after the server accepts it, so a rejected change never points at a
  deleted photo. A failed sweep is cleaned up by the next change or by account deletion.

## Editing (account page)

Edits go through `ProfileEditor`.

| Change | Behaviour |
| --- | --- |
| Rename | Written to the local cache straight away and synced later, so it works offline |
| New photo | Needs a connection (upload). Waits for the server and shows an error if the change is rejected |
| Remove photo | Instant (random persona), works offline; the old photo is deleted once the server has the change |
| Payment details | Written to the local cache straight away; see [Payment details](payment-details.md) |
| Home currency | See [Home](home.md#home-currency) |
| Handle | Not editable |

**Planned:** once groups exist, a profile edit must also update the user's entry in
every group's `members` map (see [Groups](groups.md#denormalized-member-data)).

## Membership card

The account page shows the profile as a "Squabble Club" card with the ID photo (avatar),
name, handle barcode, member-since date (from `createdAt`) and the first payment method
("Send money to"). A user without a payment method gets a joke "Valid until" line instead.
