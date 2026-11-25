# Testing with several people

**Status:** Partly built (Nov 2026). Built: the local emulator, its fake people, and "Sign in
as". Not built: security rules tests.

## Summary

Development has one phone and one Apple Account, and won't use other people's accounts or
phone numbers. Features with several members are tested with **fake people on a local
Firebase emulator**, one simulator per person.

## Using it

1. `emulator/start.sh` starts Auth, Firestore, Functions and Storage on this Mac (needs Java,
   the Firebase CLI and `npm install` in `functions/`) and seeds them. The repo's own rules and
   functions run, so undeployed changes can be tried. Nothing is kept between runs;
   `node emulator/seed.mjs` resets it while running.
2. In a Debug simulator build, the **LIVE / LOCAL** capsule on the sign-in screen switches
   (quitting the app), and on LOCAL lists the people to sign in as. Or launch straight into it
   with `xcrun simctl launch <device> com.palkesz.squabble -useLocalEmulator YES`.
3. Invite links work too: `xcrun simctl openurl <device> https://squabble-club.web.app/join/<code>`
   (the app looks the code up in the emulator).

| Person | In |
| --- | --- |
| Anna | Flat (started it), Vienna weekend (started it), Ghosted dinner |
| Béla | Flat, Vienna weekend |
| Cili | Vienna weekend, Ghosted dinner (started it) |
| Dóra | Nothing, for joining: `local-flat`, `local-vienna`, `local-ghost` |
| Someone new | A fresh account without a profile, for onboarding |

Flat is brand new and empty; Vienna weekend has 130 messages (three pages); Ghosted dinner has
a deleted member. Someone deep in debt comes with bills.

## Rules

- **It can't reach live.** The project id is `demo-squabble`, which the emulators refuse to
  connect to anything real, and the app's Firebase options are made up (`LocalEmulator`).
  Sign-in and cache are separate from live's. Analytics and Crashlytics are off.
- **Debug simulator builds only**; the code is compiled out of everything else. Its few
  strings aren't localized.
- The fake people's password is in the repo on purpose: it opens nothing outside the emulator.
- Firestore's `useEmulator` leaves TLS on in this SDK (12.19), so the host is set through
  `settings` instead.

## Not covered

- What needs Apple: sign-in, account deletion (it re-authenticates with Apple), camera, haptics
  and real invite links. These are checked on the phone against live.
- Push notifications (once they exist).
- TestFlight with a few real users before release.

## Not checked on a real device yet

- Opening an invite link with the `squabble-club.web.app` address into the app.

## Open questions

- **Security rules tests** against the same emulator need the dev-only npm package
  `@firebase/rules-unit-testing`. OK to add it?
