# Testing with several people

**Status:** Draft. Not built; parked by choice (Nov 2026). Recommended before bills, since
nearly everything about bills involves at least two people.

## Summary

Development has one phone and one Apple Account, and won't use other people's accounts or
phone numbers. Features with several members are to be tested with **fake people on a local
Firebase emulator**, one simulator per person.

## Plan

1. **Firebase emulator + a debug-only "Sign in as…" list** with a small fixed cast. Debug
   builds switch between local and live; the code is compiled out of Release. The emulator is
   a local tool (it needs Java), so it adds no Firebase product or SDK to the app.
2. **A seed script** with scenarios: a new squabble, a busy chat, someone deep in debt, a
   deleted member.
3. **Security rules tests** against the same emulator, with the dev-only npm package
   `@firebase/rules-unit-testing`.
4. **The real phone on the live project** for what needs Apple: sign-in, account deletion,
   camera, haptics, opening real invite links.
5. **TestFlight** with a few real users before release.

Not covered by the emulator: real invite links between two phones, and push notifications
(once they exist).

## Not checked on a real device yet

- Opening an invite link with the `squabble-club.web.app` address into the app.

## Open questions

- Go-ahead to build it.
- OK for the dev-only npm package (without it, skip step 3).
