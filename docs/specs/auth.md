# Sign-in & account

**Status:** Built

## Summary

Sign in with Apple is the only way in, and it's required at first launch. There's no
anonymous or guest mode in the app itself. Signing in is followed by onboarding until
the user has a profile.

## Decisions

- **Sign in with Apple only, required up front** (Sept 2026). We considered
  anonymous-first and rejected it: one identity per person, and no account-linking edge
  cases.
- **Phone numbers aren't an auth provider.** They were deferred because of SMS cost,
  SIM-swap risk and App Review guideline 5.1.1.

## Signing in

1. The user taps Sign in with Apple. The request uses a random nonce
   (`AppleSignInNonce`) and asks for the name.
2. The Apple credential signs in to Firebase Auth.
3. Apple shares the user's name **only on the very first authorization**. It's saved to
   the Firebase Auth profile (`displayName`) during the same sign-in. Its only use is to
   prefill onboarding's name field. The public name lives on the Firestore profile.
4. The sign-in button keeps spinning while the profile check runs
   (`AuthSession.isLoadingProfile`). There's no separate loading screen.

## Session states

`AuthSession` combines the Auth user with a live listener on `users/{uid}`:

| State | Meaning | Shown |
| --- | --- | --- |
| `loading` | Auth or the profile hasn't answered yet | Launch splash, or the current screen stays up |
| `signedOut` | No Auth user | Sign-in screen |
| `needsOnboarding` | Signed in, no profile on the server | Onboarding |
| `signedIn(user, profile)` | Signed in with a profile | Home |

### Rules

- **"Needs onboarding" means the server has no `users/{uid}` document.** Firebase's
  `isNewUser` flag isn't used, because it's lost if the app dies mid-onboarding.
- A **cache-only miss doesn't count as missing**. On a fresh install the cache is empty,
  which proves nothing. A cache miss triggers one `getDocument(source: .server)`.
  Offline, that read fails fast instead of waiting forever.
- A **cached profile needs no server**: a signed-in user with a cached profile goes
  straight to home, even offline.
- **The profile listener can fail** (offline with nothing cached, or the server refuses).
  That doesn't change `state`; it sets `profileSync = .failed`. The root then shows
  `ProfileSyncFailedSheet` over whatever is on screen. The sheet can't be dismissed: the
  user either retries or signs out. Retrying keeps the last known state while it runs.
- Repeated auth events for the same user don't restart the profile listener.

## Signing out

Signs out of Firebase Auth. Home's navigation is reset, so the next user doesn't land
on the previous user's pushed pages.

## Deleting the account

Required by App Review. Started from the account page.

0. **Planned, once groups exist:** if the user still owes money in any squabble, show
   what they owe and to whom first. This is a warning only, never a block, because App
   Review requires that deletion is always possible. Their place in each group becomes an
   anonymous "Deleted member" (see [Groups](groups.md#account-deletion)).
1. The user confirms with Sign in with Apple again (a fresh authorization code).
2. **Re-authenticate** the Firebase user with that credential.
3. **Revoke the Apple token** (`revokeToken(withAuthorizationCode:)`). This has to come
   before the delete because it needs the user signed in. If Apple refuses, nothing has
   been deleted yet, and the user sees "Apple wouldn't let us unlink your account, so
   nothing was deleted."
4. **Delete the Firebase Auth user.** This is the app's only data step.
5. The `deleteUserData` Cloud Function then wipes all of the user's data server-side,
   retrying until it succeeds. See [Data & sync](data-and-sync.md#account-deletion).

Because of this order, a failure anywhere leaves either the whole account or none of it.

**Console setup:** revocation needs the Apple provider's Services ID, Team ID, Key ID and
`.p8` key configured in Firebase (the "code flow"). Without them it fails with "code flow
is not enabled". That once stranded a user who was signed in but had no profile, which is
why revocation now runs first.
