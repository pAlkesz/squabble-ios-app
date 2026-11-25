# Testing with several people

**Status:** Built (Nov 2026): the local emulator, its fake people, "Sign in as", and security
rules tests.

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
a deleted member. Cili is deep in debt there.

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

## Security rules tests

`npm test` in `emulator/` (once `npm install` has been run there, and with `start.sh` stopped,
as both use the same ports) tests `firestore.rules` and `storage.rules` against the emulator.

- **Every rules change comes with tests**, for what's allowed and what's refused.
- Checked by removing each Firestore condition in turn (Nov 2026): a test fails for every one
  except the type checks that a later line already implies.
- Packages (dev-only, never in the app or the functions): `@firebase/rules-unit-testing` and
  `firebase`, the JS SDK it requires. npm reports `@grpc/grpc-js` advisories in the latter with
  no fixed version (Nov 2026); accepted, since it only talks to this Mac.

## Open questions

None.
