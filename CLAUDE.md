# CLAUDE.md — Squabble

Native iOS bill splitter that uses AI to figure out who owes what, then helps you
deliver the bad news. Personal project, deliberately a playful meme app — lighthearted
in tone, but the code stays clean and the split math must be exact (real money).

The name plays on **squab** (a young bird — hence the bird logo) and the **squabble**
that splitting a bill always seems to start.

This is a **primarily agent-coded app** — the goal is the least amount of hand-written
human code possible. Claude does the implementation; keep the codebase coherent,
well-structured, and easy for the next agent session to pick up.

## Project Overview

- SwiftUI app, universal (iPhone + iPad).
- Display name: **Squabble** (`INFOPLIST_KEY_CFBundleDisplayName`). Target / product /
  module name and the Xcode-generated type prefix are all `squabble` (lowercase, as
  Xcode generated it — e.g. `struct squabbleApp`; don't rename it).
- Minimum deployment target: **iOS 26.0** (`IPHONEOS_DEPLOYMENT_TARGET = 26.0`).
- **Orientation:** iPhone is portrait only; iPad supports all orientations.
- Language: **Swift 6** (`SWIFT_VERSION = 6.0`) — full strict concurrency.
- Architecture: **Model-View (MV)**. See "Architecture" below — no ViewModels.
- Package manager: **Swift Package Manager** only (no CocoaPods, no Carthage).
- Xcode 26.6. Bundle ID `com.palkesz.squabble` (tests: `.squabbleTests`,
  `.squabbleUITests`).
- Xcode project uses **file-system-synchronized groups** — add/move/delete files and
  folders on disk and the target picks them up automatically. Don't hand-edit
  `project.pbxproj` unless a change genuinely can't be done any other way (e.g. a
  build-membership exception), and call it out when you do.

## Tech Stack

- **UI:** SwiftUI (no UIKit unless wrapping legacy components, or where SwiftUI genuinely
  can't do the job; keep it behind a SwiftUI-facing API)
- **Backend:** Firebase (`firebase-ios-sdk` via SPM). See "Backend — Firebase" below.
  - Database: Cloud Firestore (offline persistence on)
  - Auth: Firebase Auth
  - Files: Cloud Storage for Firebase (avatars only; project is on the Blaze plan)
  - Telemetry: Crashlytics (crashes + non-fatals), Analytics
  - Server: Cloud Functions (TypeScript, `functions/`) for server-side work only, never reads
- **Networking:** async/await with Alamofire — for non-Firebase HTTP only (the AI
  service). Firebase traffic goes through the Firebase SDK, never hand-rolled REST.
- **Persistence:** Firestore's local cache for anything that syncs; SwiftData only for
  device-local state that never leaves the phone (see "Local data" below).
- **DI:** Factory pattern via FactoryKit
- **Testing:** Swift Testing framework for unit tests

(Dependencies are aspirational until actually added via SPM — add them when the first
real use lands, not before, and note why in the PR. Added so far: `firebase-ios-sdk`
(products Analytics, Auth, Crashlytics, Firestore, Functions, Storage), `Factory` (product `FactoryKit`).)

## Backend — Firebase

Chosen over Supabase (Sept 2026) for offline-out-of-the-box Firestore, free
Crashlytics, and a free tier that never auto-pauses. Trade-offs accepted: heavy
ObjC-based SDK, NoSQL modeling, `Sendable` friction under Swift 6.

- **Products in use:** Firestore, Auth, Storage, Crashlytics, Analytics, Cloud Functions
  (server-side only, approved Nov 2026; the app calls the invite callables through the
  `FirebaseFunctions` SDK), and Hosting (approved Nov 2026: `hosting/` serves the
  universal-link `apple-app-site-association` and the "get the app" page for invite links on
  `squabble-club.web.app`, plus `squabble-9c1df.web.app` for older links; deploy with `firebase deploy --only hosting`; the app's
  Associated Domains entitlement names both). Don't pull in other Firebase products (Remote
  Config, Messaging, Phone Auth…) without checking first — each one is an SPM product and a config decision. Linking a new
  product means adding it to the target in `project.pbxproj` (a sanctioned hand-edit).
- **No REST layer.** The app talks to Firestore directly through the SDK, with security
  rules as the access control — a Cloud Functions API would lose the offline cache and
  live listeners, and wouldn't make reads cheaper. Functions do server-side work only:
  background triggers (cleanup, people lists, reminder pushes), a daily exchange-rate job,
  and the `joinGroup` callable for invite links (planned list in
  `docs/specs/data-and-sync.md`), never reads. Design documents around screens instead of joining: denormalize small,
  rarely-changing fields and embed what's always read together.
- **Cloud Functions** live in `functions/` (TypeScript, Node 22, `firebase-functions` +
  `firebase-admin`; `node_modules/` and the compiled `lib/` are gitignored). Deploy with
  `firebase deploy --only functions` — Claude deploys them itself, like the rules. Functions:
  the invite callables (`createInvite`, `resetInvite`, `previewInvite`, `joinGroup`, also
  first-generation, as the same service account) and `deleteUserData`, a first-generation `auth.user().onDelete` trigger (the
  newer API has no Auth delete trigger) with retries on, running as the Firebase Admin SDK
  service account (the project has no default Compute Engine account), which wipes `users/{uid}` and its
  subcollections, the user's `handles/` lock and `avatars/{uid}/`. Admin SDK, so the
  security rules don't apply to it.
- **Security rules** live in the repo: `firestore.rules`, `storage.rules`, wired up by
  `firebase.json`. Deploy with `firebase deploy --only firestore:rules,storage`
  (`.firebaserc` is gitignored — run `firebase use --add` once). Any change to the data
  layout changes the rules in the same commit.
- **Config file:** `squabble/Resources/GoogleService-Info.plist`. It is **gitignored**
  (public repo; the key is bundle-ID-restricted but there's no reason to publish it).
  With file-system-synchronized groups, dropping it in `Resources/` is enough for the
  target to pick it up. Per-environment plists (dev/prod) are out of scope for now.
- **Bootstrap:** `FirebaseApp.configure()` runs once at launch from `squabbleApp`
  (an `AppDelegate` adaptor is acceptable here — it's the one sanctioned UIKit spot).
- **Isolation:** Firebase types never leak into views or feature models. Each feature's
  `Data/` layer exposes a protocol-typed repository (registered in FactoryKit) whose
  Firestore implementation lives in the same folder; domain models are plain `Codable`
  structs mapped to/from Firestore documents. This keeps views testable with fakes and
  contains the Swift 6 `Sendable` warnings to the adapter layer.
- **Offline:** Firestore persistence stays enabled (the iOS default). Writes are
  fire-and-forget against the local cache and sync later; UI must not block on network
  and should reflect `metadata.hasPendingWrites` where "not yet sent" matters
  (e.g. a reminder that hasn't actually reached anyone).
- **Reads cost money:** Firestore bills per document read. Prefer one listener per
  screen on a scoped query, use `.getDocuments(source: .cache)` where staleness is
  fine, and never re-query a whole collection to refresh a list.
- **Money in Firestore:** there is no decimal type. Store amounts as **integer minor
  units** (`Int64` cents) plus an ISO currency code; convert to `Decimal` at the model
  boundary. Never store `Double` amounts.
- **Auth:** Sign in with Apple only, required at first launch (decided Sept 2026 over
  anonymous-first: one identity, no account-linking edge cases). Entitlement lives in
  `squabble/squabble.entitlements`. The Apple provider must be enabled in the Firebase
  console, and account deletion needs the Apple provider's Services ID, Team ID, Key ID and
  `.p8` private key configured there (Firebase calls it the code flow) so
  `revokeToken(withAuthorizationCode:)` works — App Review requires deletion.
  - Apple hands over the user's name **once**, on the first authorization; it's stored
    on the Firebase Auth profile (`displayName`) in the same sign-in call, and is only
    used to prefill onboarding. The public name lives on the Firestore profile.
  - `AuthSession` (`Feature/Auth/Model`) is the app-wide `@Observable` state, created
    in the root view and shared via `.environment`. Views never touch `FirebaseAuth`.
    Its `state` combines the auth user with the profile listener: `loading`,
    `signedOut`, `needsOnboarding`, `signedIn(user, profile)`. A listener failure
    doesn't change `state`; it sets `profileSync` to `.failed`, and the root shows
    `ProfileSyncFailedSheet` (undismissable: retry or sign out) over whatever is up.
  - **"Needs onboarding" = no `users/{uid}` doc on the server**, never Firebase's
    `isNewUser` (lost if the app dies mid-onboarding). A cache-only miss triggers one
    `getDocument(source: .server)`, because offline the listener would wait silently
    forever; that read fails fast, which surfaces as the error sheet. A cached
    profile needs no server: signed in + cached profile goes straight home offline.
  - **Account deletion** (Nov 2026): the app re-authenticates with Apple → revokes the Apple
    token → deletes the Auth user, and nothing else; the `deleteUserData` Cloud Function then
    wipes the user's data server-side, retrying until it succeeds. So a failure anywhere in
    the app leaves the whole account or none of it. Revocation goes before the delete because
    it needs the user signed in (it once ran after the data was gone, failed with "code flow
    is not enabled" for want of the console's Services ID/key, and stranded a signed-in user
    with no profile). Anything new stored per user must be added to `deleteUserData`.

### Firestore data model

```
users/{uid}                      public profile — any signed-in user can read
  displayName, handle, avatar: {kind: preset, preset} | {kind: persona, persona, color}
                                 | {kind: photo, path, url},
  createdAt, updatedAt
users/{uid}/private/payment      owner-only: { methods: [ {id, kind: bankAccount, iban, holderName}
                                               | {id, kind: link, provider, username} ] }
users/{uid}/private/preferences  owner-only: { homeCurrency? } — no field means "follow the
                                 device's region"; only written once the user picks one
handles/{handle}                 { uid } — uniqueness lock, claimed in the same
                                 transaction as the profile (rules enforce both ways)
avatars/{uid}/{random}.jpg       Storage: 512px square JPEG, < 1 MB
```

Groups are partly built (create, list, own-entry sync); bills and the rest are planned.
Bills always belong to a group (a one-off dinner is a small group):

```
groups/{groupId}                 name, currency, createdBy, createdAt,
  memberIds: [uid]               ← rules + "my groups" query (array-contains)
  members: { uid: { displayName, handle, avatar, payment?, ... } }
                                 ← members are always app users (no guests, Nov 2026);
                                   payment details are copied here so group-mates can
                                   read them. Full plan: docs/specs/groups.md
groups/{gid}/bills/{billId}      title, currency, totalMinor, paidBy, items (embedded),
                                 shares: { memberId: amountMinor }
groups/{gid}/settlements/{id}    from, to, amountMinor, currency, createdAt
groups/{gid}/reminders/{id}
```

Profile and payment edits reach groups through `GroupsStore`, which rewrites the user's own
entry in any group where it differs (the rules allow a member to edit only their own).

### Profiles, handles and payment details

- **Display names are free-form and not unique; handles are unique** (`a–z 0–9 _`,
  3–32, stored lowercase). Friends find each other by exact handle lookup and — later —
  invite links / QR codes. No display-name search (Firestore can't full-text search).
  Phone numbers / contact matching were considered and deferred (SMS cost, SIM-swap
  risk if linked as an auth provider, App Review 5.1.1).
- **Payment details:** bank accounts (stored as an IBAN, mod-97 validated, with holder
  name — the field also takes a Hungarian domestic account number, checked with its own
  9-7-3-1 check digits and converted exactly; Hungarian readers see that domestic format)
  and payment links for
  an allow-list of providers (Revolut, PayPal, Wise). Links are stored as
  provider + username and rebuilt, never as free-form URLs, so a profile can't point
  people at an arbitrary site. Never store card numbers. IBANs are GDPR personal data:
  owner-only in Firestore, shared into groups later, deleted with the account, and
  declared as "Financial Info" on the App Store privacy label.
- **Avatars:** a **persona** (`AvatarPersona`, a joke character with a slogan like
  "Money is no object") on a coloured disc (`AvatarColor`), or a photo. The plain bird
  (`Avatar.preset`) is no longer offered — it stays for profiles that already have it and
  as the fallback. Onboarding preselects a random persona; every tile gets its own colour
  from a shuffled palette, and the chosen colour is stored with the avatar. Persona art ships in the asset
  catalog as **transparent PNGs** (the app draws the disc), so only the id is stored.
  The figure must **bleed off the bottom edge** of the square: a body that ends inside the
  frame shows its straight cut line through the circle mask. Crop art that stops short.
  An unreadable avatar falls back to the bird on `AvatarColor.default(for: uid)`. Rules check the id's shape, not a list, and an app that doesn't know an id
  shows the default bird — so new personas need no rules deploy. Raw values are stored:
  never rename one. Ten personas; case names and asset files describe
  the persona, never the real person who may have inspired it, since the repo is public. Photos are cropped/resized on device by `AvatarImageProcessor`
  (ImageIO, no UIKit) before upload.
- **Crashlytics:** Release builds use `DEBUG_INFORMATION_FORMAT = dwarf-with-dsym` and
  a dSYM upload run-script build phase (`upload-symbols` from the SPM checkout) — this
  is a legitimate `project.pbxproj` hand-edit; call it out. Log handled errors with
  `Crashlytics.record(error:)` via the `Core/Logging` facade, never directly from
  features. Verify with a real TestFlight test crash after any Xcode major bump —
  Xcode 26 + Firebase 12.7 had a known release-build reporting gap.
- **Analytics:** log events through the `Core/Logging` facade too, so features don't
  import Firebase. Keep event names in one enum.

### Local data

- Anything that syncs (bills, participants, splits, reminders) lives in Firestore and
  is read through its offline cache — **don't mirror it into SwiftData**; two sources
  of truth is where these apps rot.
- SwiftData is reserved for purely on-device state (drafts before first save,
  user preferences that shouldn't roam, cached AI results). Add it only when such a
  need actually appears.

## Architecture — Model-View, no ViewModels

- **No ViewModels. No `ObservableObject`.** Presentation logic lives in the SwiftUI
  view, with private helper methods / computed properties on the view for anything
  non-trivial.
- When a view's logic gets genuinely complex, **extract it into plain
  helpers** — free functions, `struct`s, or small classes — that are independently
  testable. Keep them next to the feature that uses them.
- **Models** are value types where possible and own domain logic (the split algorithm,
  rounding, totals). `@Observable` for reference-type model/state objects that views
  observe; `@State` / `@Bindable` to hold and bind them.
- Side-effecting collaborators (network, persistence, AI service) are protocol-typed
  and injected via FactoryKit, so views/models take an abstraction, not a concrete type.

## Coding Standards

- Prefer value types (structs) over reference types.
- Use the `@Observable` macro, not `ObservableObject`.
- No comments unless to explain something that is not obvious. Explain *why*, not *what*.
- Mark everything with appropriate access control (default to `private` / `internal`;
  widen only when needed).
- No force unwrapping (`!`) or force `try!` in production code — use `guard let` /
  `if let` / typed throws.
- One primary type per file; filename matches the type.
- **Money:** never `Double`/`Float` for currency. Use `Decimal` (or integer minor
  units) with explicit rounding. Every split must sum back to the exact total — assign
  leftover cents deterministically.

## Localization

- Supported languages: **English (`en`, primary / source)** and **Hungarian (`hu`)**.
- Every user-facing string must be localized — no bare literals in `Text`, alerts,
  accessibility labels, etc. Add each new string to the String Catalog with a `hu`
  translation in the same change; don't leave `hu` stale.
- Mechanism: a **String Catalog** at `squabble/Resources/Localizable.xcstrings`
  (`LOCALIZATION_PREFERS_STRING_CATALOGS = YES`, `SWIFT_EMIT_LOC_STRINGS = YES`).
  SwiftUI `Text("...")` with a literal is auto-extracted; for interpolated or
  non-View strings use `String(localized:)`.
- `hu` is registered in the project's `knownRegions`. Keep the tone in Hungarian
  too — playful and a little passive-aggressive, not a dry literal translation.
- Format numbers/currency/dates with locale-aware APIs
  (`Decimal.formatted(.currency(code:))`, `Date.FormatStyle`), never hand-built strings.

## Branding

- **Single theme.** The app is locked to **dark** appearance for everyone
  (`INFOPLIST_KEY_UIUserInterfaceStyle = Dark`; switched from light-only in Sept 2026).
  No light mode — don't add light-appearance variants to colors, assets, or the icon,
  and don't write `colorScheme`-dependent UI.
- **Never a plain black screen.** Dark here means deep green, not black. A full-screen
  surface uses `SquabbleBackdrop`; anything else should at least sit on a backdrop
  color rather than the system default. Exception: onboarding's `OnboardingBackdrop`
  fades a traffic-light colour into black — red, then amber, then green reaching further
  down each step — as a progress cue. Home tints its backdrop by the balance (below), so
  in the red the deep end is a maroon rather than green — still never black.
- **One corner radius:** every row, card, list group and input field uses
  `SquabbleMetrics.cornerRadius` (28 pt). That's what iOS 27's own grouped lists draw
  (measured Nov 2026), and SwiftUI can't change theirs, so custom surfaces match it. Never
  hardcode a radius for these; props (membership card, payment slip, stamp, ID photo)
  keep their own.
- **Primary buttons** are solid white capsules with dark text (`.squabblePrimary`),
  matching the Sign in with Apple button; sheet actions use `SquabbleGlassButton`.
- **Accent color** (`AccentColor` asset, drives `.tint`): one universal value,
  `#129955` — the classic green sampled from the app icon's background.
  - It's the single brand color — use `Color.accentColor` / `.tint`, don't scatter
    ad-hoc greens. Exception: a large **fill** that can sit behind a sheet (the launch
    splash) uses the asset symbol `Color.accent` instead — iOS greys out and thins the
    tint behind a presented sheet, which turns `accentColor` fills see-through.
    Additional named colors go in the asset catalog as single
    universal values, never hardcoded `Color(red:…)` in views.
  - Contrast note: on the dark backdrop `#129955` clears AA for body text (~5.7:1 on
    near-black), so it works as a text/link color here — unlike on white, where it was
    only ~3.7:1 and had to stay a fill.
- **Named colors in the catalog** (all single universal values):
  - `BackdropTop` `#4FDD97`, `BackdropHigh` `#13924F`, `BackdropMid` `#0A3A23`,
    `BackdropDeep` `#06180F` — the four rows of `SquabbleBackdrop`'s mesh, bright at
    the top of the screen down to deep green at the bottom.
  - `BalanceNeutral*`, `BalancePale*`, `BalanceAmber*`, `BalanceRed*` (each `Top`/`High`/
    `Mid`/`Deep`, mirroring the four `Backdrop*` rows) — home's balance moods: petrol
    `#1A6670` at zero, pale green, amber `#C25E14`, red `#B3261E` (the `High` values).
    The brand `Backdrop*` set is the fully-owed end.
  - `QuietTop` `#874E63`, `QuietMid` `#5D3846`, `QuietDeep` `#1F1219` — `QuietBackdrop`, the wavy
    plum behind money pages without a balance (the squabbles list).
  - `ReceiptPaper` `#F4F0E4`, `ReceiptInk` `#271814` — prop-receipt paper and its ink.
  - `Squabble<Name>Top` / `Squabble<Name>Bottom` (in `SquabbleArt/`) — the two stops of each
    squabble picture gradient (`SquabbleBackground`: mint, sky, peach, lilac, sunrise,
    bubblegum, teal, dusk, sand, storm). Their own palette, not the avatar colours.
  - `ButtonDisabledFill` `#4D4C4F`, `ButtonDisabledLabel` `#000000` — the primary button's
    disabled capsule: an opaque grey with black text, sampled from Revolut's.
  - `OnboardingRed` `#E4502E`, `OnboardingAmber` `#F5BC2F` — the first two onboarding
    steps' backdrop colours (the third is the accent).
  - `SlipPaper` `#F2E2A0`, `SlipPrint` `#8C6414` — the payment step's prop payment slip
    (a nod to the Hungarian yellow postal cheque) and its pre-printed form ink; the
    details on it are "typed" in `ReceiptInk`. Deliberately a different prop from the
    welcome receipt.
  - `AvatarLagoon` `#1E8FB3`, `AvatarCoral` `#E4674E`, `AvatarMustard` `#D9A21B`,
    `AvatarPlum` `#8A4FB0`, `AvatarTangerine` `#E8862A`, `AvatarRose` `#D6457F`,
    `AvatarIndigo` `#4C5BD4`, `AvatarOlive` `#7A9A2C`, `AvatarSlate` `#5B7083`,
    `AvatarCocoa` `#8B5A3C` — avatar discs (`AvatarColor`; meadow is the accent). One per
    onboarding tile, so the palette must stay at least as long as the persona list.
- **Logo:** final — a flat, angular **paper-cut seabird** (a nod to "squab") holding
  a small curled **receipt** in its beak, white on the green field above. Shipped
  as `squabble/Resources/Assets.xcassets/AppIcon.appiconset/icon.png` — a single
  1024×1024 image used for every appearance; deliberately no dark/tinted variants.
  Superseded concepts (split receipt, hand-drawn/geometric bird explorations) are in
  `design/logo-concept.svg` for reference only.

## App Store

- Primary category: **Finance** (`LSApplicationCategoryType = public.app-category.finance`).
  Secondary: Utilities. The joke framing is marketing copy, not a category — bill
  splitters are found under Finance.

## File Structure

```
squabble/
  Resources/            Assets.xcassets, Localizable.xcstrings, fonts, Lottie, etc.
  Sources/
    squabbleApp.swift   @main entry point
    Core/               Shared, cross-feature code:
      UI/               Components/, Extensions/, Util/  (reusable views, view helpers)
      Firebase/         FirebaseApp bootstrap, Firestore codec helpers, Auth session
      Networking/       Alamofire client for the AI service, request/response models
      Persistence/      SwiftData container, model schema (device-local state only)
      DI/               FactoryKit container & registrations
      Logging/          Facade over Crashlytics + Analytics; features log here only
    Feature/            One folder per feature module. Each feature holds, as needed:
      <Feature>/
        UI/             Screens and feature-local views
        Model/          Feature domain models
        Data/           Protocol-typed repositories + their Firestore implementations
        Util/           Feature-local helpers
```

`functions/` at the repo root holds the Cloud Functions (TypeScript sources in `src/`).

Empty folders aren't committed (git doesn't track them) — create each folder when the
first real file for it lands, following the layout above. The app target folder is
`squabble/`; tests live in `squabbleTests/` and `squabbleUITests/` at the repo root.

`ContentView` is the root router: it owns `AuthSession` and switches between
`OnboardingFlowView` and `HomeView` on its state. There is **no loading screen**: at
launch the splash bird waits for the answer, and afterwards the current screen stays up
while the next one is worked out (the sign-in button keeps spinning through the profile
check via `AuthSession.isLoadingProfile`).
`OnboardingFlowView` is one native `NavigationStack`: `SignInView` is the root and
`OnboardingView` is pushed on top once signed in, with no way back (no back button, no
swipe) — a signed-in user without a profile has nowhere to go on sign-in. It stays mounted
while the profile loads after sign-in, so onboarding arrives as a push, not a screen swap.
`OnboardingView` is **one screen with a pager** (name + handle → avatar → payment): an
offset row of pages driven only by the buttons (no swipe, so the handle can't be skipped),
not a paging `ScrollView`, whose content doesn't get the keyboard's safe area. The
traffic-light `OnboardingBackdrop`, the progress segments (nav bar principal slot) and the
white Continue button (`safeAreaBar`, `.squabblePrimary`) stay put; only pages slide.
Nothing is written until the last page. Display names cap at 50 characters, handles at 32.
The two roots are separate navigation stacks, so there's no push between them:
`ContentView` cross-fades them (explicit `.opacity` transitions in a `ZStack`, switched with
`withAnimation` — an implicit `.animation(value:)` on a `Group` didn't animate the swap).
When the state goes from `needsOnboarding` to `signedIn` — onboarding just saved the profile,
never a returning user — the root overlays `MembershipWelcomeView`, laid out like an onboarding
page: an `OnboardingHeading` ("Welcome to the club"), the new membership card sliding up and
getting an "APPROVED" stamp (heavy haptic), and a "Let's squabble" button — it stays until
tapped. On tap everything fades while a copy of the card's ID photo flies onto home's toolbar
avatar, shrinking and rounding into it. Home reports the avatar's on-screen frame and hides it
while the welcome is up (`MembershipWelcomeHandoff`: `\.reportAvatarFrame`,
`\.isMembershipWelcomeShowing`), so the photo lands exactly on it and the overlay is removed
without a visible swap. Kept full screen rather than a sheet: a sheet slides away on dismiss,
which would fight the photo's flight. It waits ~0.5 s first so home mounts underneath before
anything moves; Reduce Motion skips the motion and the flight.
`ContentView` applies the launch splash (`launchSplash(isContentReady:onReadyForContent:)`):
the bird plays its intro, then holds still and calls back — only then does the root mount
its first screen, so that main-thread stall lands while nothing moves — and flies off
once the screen is ready. Never mount heavy UI under the splash mid-animation; it
stutters on a device even when the simulator looks smooth.

### Current state (Sept 2026)

- **Done:** launch splash, Firebase bootstrap, Sign in with Apple (sign in / out /
  delete), and the welcome screen — `SquabbleBackdrop` gradient, the tappable bird as
  hero, and the prop receipt that prints itself. First-run **onboarding**
  (`Feature/Onboarding`): display name + unique handle → avatar (a persona, or a photo
  from the library or camera via a glass "add photo" tile) →
  optional payment methods, saved in one transaction; `Feature/Profile` holds the
  models, Firestore/Storage adapters and shared views (`AvatarView`,
  `PaymentMethodEditor`). Account deletion: the app deletes the Auth user, a Cloud Function
  wipes profile data and avatars.
- **Home, in progress:** `HomeView` follows a Revolut-style layout on `SquabbleBackdrop`,
  one `NavigationStack` and **no tab bar** (decided Oct 2026: squabbles are pushed from
  home like conversations; add a `TabView` only once there are 3+ peer destinations).
  The avatar, a glass search pill and a `+` for a new squabble are real **toolbar items**
  (search and `+` have no destination yet). Below them `TotalBalanceView`, the net of
  everything owed either way, labelled "Total · <code>"; it's a fixed 0 until groups
  exist. Totals will be **converted into one home currency** (for now the locale's).
- **Balance backdrop:** `BalanceMood` (`Feature/Home/Model`) turns the total into a signed
  intensity (−1…1) and a `BackdropPalette` for `SquabbleBackdrop` — hue says which way the
  money flows, saturation how much. Petrol at zero (deliberately not a Revolut-ish royal
  blue/indigo); pale green → brand green when owed, amber → red when owing. Log scale,
  full strength at ~€250, pale green fully in at ~€6 but amber already at ~€1 (the
  petrol–amber midpoint is a muddy khaki, so debts rush through it); amounts are judged in rough euro
  terms via a small per-currency table, to be replaced by real rates when totals convert.
  The sheet's blurred background uses the same palette. `SquabbleBackdrop`'s drift is
  driven by a `TimelineView` clock, not a repeating animation, so an animated palette
  change can't cancel it. A bright fade always stands for a balance: a squabble's pages use
  `SquabbleMoodBackdrop` (`CornerGlowBackdrop`, its own balance), the squabbles list, which has
  none, `QuietBackdrop` (table in `docs/specs/home.md`). Debug builds: long-press the total, or
  a squabble's name in its bar, to get a balance slider.
- **Account page:** the borderless 40 pt avatar (toolbar glass hidden) **pushes**
  `AccountView` onto home's stack (decided Oct 2026; it was a sheet, but the photo picker
  and payment editor then stacked a sheet on a sheet). Home registers every `AccountPage`
  destination and gives each pushed page its own backdrop — a shared one behind the stack
  would show both pages overlapping mid-push. Account pages use `ProfileBackdrop` — the dark half of
  the brand ramp with a faint glow behind the card — not the balance mood or the bright
  `SquabbleBackdrop` (tried avatar-tinted backdrops, a mugshot height chart, a dark-brown
  "desk" and charcoal, Oct–Nov 2026 — dropped). The profile shows as a `MembershipCard`: a "Squabble
  Club" prop card in `ReceiptPaper`/`ReceiptInk` with a green band, square ID photo (the
  avatar menu), member-since date (`UserProfile.memberSince`, from `createdAt`), the first payment
  method ("Send money to"; a joke "Valid until" line without one) and the handle as a
  Code 128 barcode — the slot a real QR code takes once invite links exist.
  Before settling on a sheet we prototyped a Revolut-style zoom out of the avatar every way we
  could (custom SwiftUI overlay, SwiftUI/UIKit zoom transitions as full screen, push and
  sheet). Findings worth keeping:
  - iOS's curved "button morphs into the sheet" zoom only happens from a SwiftUI toolbar
    item that shows its own glass, and that glass always pads its content (a ring around an
    avatar). With the glass hidden, or a plain view as source, it falls back to a generic
    zoom that lands as a square card. `matchedTransitionSource` only accepts rounded-rect
    clip shapes.
  - Measuring a view inside a `NavigationStack` that something is scaling feeds the scale
    back into the measurement: read such frames once, never continuously (a continuous
    read hung the app on device), and keep them out of SwiftUI state.
  - Toolbar buttons ignore `.tint` — style their labels directly.
- **Account editing** (`Feature/Account`): tapping the avatar opens a `Menu` (library /
  camera / remove photo), not another sheet. After onboarding the only avatar change is a
  photo: removing one falls back to a random persona, and every change sweeps older uploads
  (`AvatarStore.deleteAll(for:keeping:)`). Display name, payment details and home currency
  are pages pushed after it on home's stack. Edits go through `ProfileEditor` and are
  fire-and-forget writes to the local cache; the handle can't be changed.
- **Home currency:** `PreferencesStore` (owned by `HomeView`, passed to the account sheet
  via the environment) listens to `private/preferences`. Unset means
  `Locale.current.currency` (the phone's Region, not its language), resolved at read time
  so a move abroad updates the default. Nothing converts yet — it only relabels the total.
  The picker lists `Locale.commonISOCurrencyCodes`, each with a round flag from
  `Assets.xcassets/Flags` (SVGs copied from MIT-licensed circle-flags; notice in
  `THIRD_PARTY_NOTICES.md`), named by lowercase region code. Only flags a currency maps to
  ship; a test fails if one is missing. A currency's country is the region its code starts
  with (HUF → HU, EUR → EU), else the only region using it; shared ones show a banknote.
  Search is the system `.searchable` (navigation-bar drawer). Two iOS 27 quirks, found by
  recording the simulator during an XCUITest and slit-scanning the frames: tapping cancel
  animated the `List` update inside UIKit's cancel animation (list dropped ~180 pt, then
  snapped back, with or without typed text) — fixed by never animating the list's updates; and the drawer's glass
  only appears once the push finishes — a system bug (bar items set after the push lands
  late), left as is. A custom glass field avoided both but was dropped to stay native.
- **Squabbles, in progress** (`Feature/Groups`, spec `docs/specs/groups.md`): `+` on home
  zooms open the "Create squabble" sheet (`navigationTransition(.zoom)` from the toolbar
  item): a circular picture (photo, or a drawing — `SquabbleArtwork`, transparent PNGs in
  `Assets.xcassets/SquabbleArt` framed like personas — on a `SquabbleBackground` gradient), a name with preset
  chips, and a currency. No people at creation (like Revolut), so they're added from the
  squabble later. Home lists the user's squabbles in a Revolut-style `HomeTile` (title inside the card, rows
  without chevrons; a title chevron and "See all" push the full list), showing the 3 most
  recently active, from one `array-contains` listener in `GroupsStore`, sorted on the
  device. Rows push `SquabbleView` (Revolut-style: name and subtitle in the bar, picture on
  the right opening `SquabbleInfoView` with the members, "Add a bill" at the bottom) through
  `HomeRoute`; pushed views navigate with `NavigationLink(value: HomeRoute)`. The squabble page is a
  chat (`Feature/Chat`, spec `docs/specs/chat.md`): `ChatStore` per page (latest 50 live, older
  pages on scroll), bubbles with `SquabbleMetrics.bubbleCornerRadius`, long-press menu with a
  reaction palette, and `ChatComposer` with Add a bill at its left (disabled until bills). Invites: the shortened link with a QR symbol (`SquabbleInviteLink`,
  opening `SquabbleInviteSheet`,
  from the info page and the empty squabble), universal links on `squabble-club.web.app` caught
  by `ContentView.onOpenURL` into `InviteInbox`, joined through `JoinSquabbleSheet`. Not yet:
  adding people by handle, leaving, archive/delete,
  editing.
- Scrolling screens opt into `.scrollEdgeEffectStyle(.soft, for: .top)`: iOS 26's soft
  fade under the bar, which iOS 27 no longer applies by default. Add it to every new
  scrolling page.
- **Placeholder:** search on home has no destination.
- **Not started:** bills — capture, AI parsing, the split algorithm, settlements,
  reminders.

### Screen conventions worth knowing

- **Entrance animations on the root must wait for the splash.** `launchSplash`
  publishes `\.isLaunchSplashFinished` through the environment; anything that animates
  on appear (like the receipt unfurl) has to gate on it or it plays unseen behind the
  splash.
- **Posing the logo:** when animating `SquabLogoPiece`s, move the whole view rather
  than the `body` piece — shifting `body` on its own tears the silhouette away from the
  wing and tail. See `WelcomeBirdView`.
- **The welcome receipt is a prop.** Its amounts are fixed to EUR rather than the
  reader's currency — a deliberate exception to the locale-currency rule, because a
  fictional restaurant bill in the user's own money reads as real (and "4 HUF nachos"
  reads as broken). Real money everywhere else follows the rule.

## Common Commands

Build (Debug, simulator):

```bash
xcodebuild build -project squabble.xcodeproj -scheme squabble \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

Test (unit + UI):

```bash
xcodebuild test -project squabble.xcodeproj -scheme squabble \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

To see the app running, prefer the iOS Simulator tooling (attach the live panel, build,
launch) over describing manual steps.

## Tone

- **User-facing copy** (button labels, reminder messages, empty states): lean into the
  joke — petty, a little passive-aggressive, self-aware. Kind, never mean.
- **Code, commits, docs:** professional and clear.

## Specs

Product behaviour and business rules (sign-in, onboarding, profiles, payment details,
balances, groups, people, bills and splitting) are specified in [`docs/specs/`](docs/specs/),
indexed by [`docs/README.md`](docs/README.md). This file keeps project conventions; the
specs say what the app does.

- Read the relevant spec before changing a feature, and **update it in the same commit**
  as the behaviour change.
- A new feature starts as a *Draft* spec with its open questions; settle them with the
  user before building, then mark it *Built*.

## Working Agreements for Claude

- **Committing is pre-authorized** — commit changes as you go, at natural checkpoints,
  without stopping to ask. Use concise messages ending with the
  `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>` trailer. Keep commits
  focused; don't bundle unrelated changes.
- Push to `origin/main` once the working tree builds and is in a good state.
- Don't add third-party dependencies without checking first.
- Keep secrets out of the repo. AI-service / API keys go in a gitignored xcconfig or
  environment, never committed. `Secrets.plist`, `GoogleService-Info.plist`, `.env`,
  `*.xcconfig.local` are already gitignored.
- After code changes, build (and run tests if logic changed) before reporting done.
- This is a public repo — assume anything committed is world-readable.
