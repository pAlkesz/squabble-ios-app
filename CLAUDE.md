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

- **UI:** SwiftUI (no UIKit unless wrapping legacy components)
- **Backend:** Firebase (`firebase-ios-sdk` via SPM). See "Backend — Firebase" below.
  - Database: Cloud Firestore (offline persistence on)
  - Auth: Firebase Auth
  - Files: Cloud Storage for Firebase (avatars only; project is on the Blaze plan)
  - Telemetry: Crashlytics (crashes + non-fatals), Analytics
- **Networking:** async/await with Alamofire — for non-Firebase HTTP only (the AI
  service). Firebase traffic goes through the Firebase SDK, never hand-rolled REST.
- **Persistence:** Firestore's local cache for anything that syncs; SwiftData only for
  device-local state that never leaves the phone (see "Local data" below).
- **DI:** Factory pattern via FactoryKit
- **Testing:** Swift Testing framework for unit tests

(Dependencies are aspirational until actually added via SPM — add them when the first
real use lands, not before, and note why in the PR. Added so far: `firebase-ios-sdk`
(products Analytics, Auth, Crashlytics, Firestore, Storage), `Factory` (product `FactoryKit`).)

## Backend — Firebase

Chosen over Supabase (Sept 2026) for offline-out-of-the-box Firestore, free
Crashlytics, and a free tier that never auto-pauses. Trade-offs accepted: heavy
ObjC-based SDK, NoSQL modeling, `Sendable` friction under Swift 6.

- **Products in use:** Firestore, Auth, Storage, Crashlytics, Analytics. Don't pull in
  other Firebase products (Functions, Remote Config, Messaging, Phone Auth…) without
  checking first — each one is an SPM product and a config decision. Linking a new
  product means adding it to the target in `project.pbxproj` (a sanctioned hand-edit).
- **No REST layer.** The app talks to Firestore directly through the SDK, with security
  rules as the access control — a Cloud Functions API would lose the offline cache and
  live listeners, and wouldn't make reads cheaper. Functions are for background
  triggers later (invite-link joins, reminder pushes, server-side cleanup), not for
  reads. Design documents around screens instead of joining: denormalize small,
  rarely-changing fields and embed what's always read together.
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
  console, and account deletion needs the Sign in with Apple `.p8` key configured there
  so `revokeToken(withAuthorizationCode:)` works — App Review requires deletion.
  - Apple hands over the user's name **once**, on the first authorization; it's stored
    on the Firebase Auth profile (`displayName`) in the same sign-in call, and is only
    used to prefill onboarding. The public name lives on the Firestore profile.
  - `AuthSession` (`Feature/Auth/Model`) is the app-wide `@Observable` state, created
    in the root view and shared via `.environment`. Views never touch `FirebaseAuth`.
    Its `state` combines the auth user with the profile listener: `loading`,
    `signedOut`, `needsOnboarding`, `profileUnavailable`, `signedIn(user, profile)`.
  - **"Needs onboarding" = no `users/{uid}` doc on the server**, never Firebase's
    `isNewUser` (lost if the app dies mid-onboarding). A cache-only miss on a fresh
    install is ignored until the server answers.
  - **Account deletion** order: re-authenticate with Apple → delete avatars → delete
    Firestore profile data → revoke the Apple token and delete the Auth user. Anything
    new stored per user must be added to this cleanup.

### Firestore data model

```
users/{uid}                      public profile — any signed-in user can read
  displayName, handle, avatar: {kind: preset, preset} | {kind: photo, path, url},
  createdAt, updatedAt
users/{uid}/private/payment      owner-only: { methods: [ {id, kind: bankAccount, iban, holderName}
                                               | {id, kind: link, provider, username} ] }
handles/{handle}                 { uid } — uniqueness lock, claimed in the same
                                 transaction as the profile (rules enforce both ways)
avatars/{uid}/{random}.jpg       Storage: 512px square JPEG, < 1 MB
```

Planned, not built yet — bills always belong to a group (a one-off dinner is a small
group):

```
groups/{groupId}                 name, currency, createdBy, createdAt,
  memberIds: [uid]               ← rules + "my groups" query (array-contains)
  members: { memberId: { uid?, displayName, avatar, payment? } }
                                 ← guests without the app have no uid; payment details
                                   are copied here so group-mates can read them
groups/{gid}/bills/{billId}      title, currency, totalMinor, paidBy, items (embedded),
                                 shares: { memberId: amountMinor }
groups/{gid}/settlements/{id}    from, to, amountMinor, currency, createdAt
groups/{gid}/reminders/{id}
```

When groups land, profile edits must also update the user's entry in each group's
`members` map (client-side fan-out; the rules allow a member to edit only their own).

### Profiles, handles and payment details

- **Display names are free-form and not unique; handles are unique** (`a–z 0–9 _`,
  3–20, stored lowercase). Friends find each other by exact handle lookup and — later —
  invite links / QR codes. No display-name search (Firestore can't full-text search).
  Phone numbers / contact matching were considered and deferred (SMS cost, SIM-swap
  risk if linked as an auth provider, App Review 5.1.1).
- **Payment details:** IBAN (mod-97 validated, with holder name) and payment links for
  an allow-list of providers (Revolut, PayPal, Wise). Links are stored as
  provider + username and rebuilt, never as free-form URLs, so a profile can't point
  people at an arbitrary site. Never store card numbers. IBANs are GDPR personal data:
  owner-only in Firestore, shared into groups later, deleted with the account, and
  declared as "Financial Info" on the App Store privacy label.
- **Avatars** default to the bird on a coloured disc (`AvatarPreset`, picked stably
  from the uid). Photos are cropped/resized on device by `AvatarImageProcessor`
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
  color rather than the system default.
- **Accent color** (`AccentColor` asset, drives `.tint`): one universal value,
  `#129955` — the classic green sampled from the app icon's background.
  - It's the single brand color — use `Color.accentColor` / `.tint`, don't scatter
    ad-hoc greens. Additional named colors go in the asset catalog as single
    universal values, never hardcoded `Color(red:…)` in views.
  - Contrast note: on the dark backdrop `#129955` clears AA for body text (~5.7:1 on
    near-black), so it works as a text/link color here — unlike on white, where it was
    only ~3.7:1 and had to stay a fill.
- **Named colors in the catalog** (all single universal values):
  - `BackdropTop` `#4FDD97`, `BackdropHigh` `#13924F`, `BackdropMid` `#0A3A23`,
    `BackdropDeep` `#06180F` — the four rows of `SquabbleBackdrop`'s mesh, bright at
    the top of the screen down to deep green at the bottom.
  - `ReceiptPaper` `#F4F0E4`, `ReceiptInk` `#271814` — prop-receipt paper and its ink.
  - `AvatarLagoon` `#1E8FB3`, `AvatarCoral` `#E4674E`, `AvatarMustard` `#D9A21B`,
    `AvatarPlum` `#8A4FB0` — preset avatar discs (the fifth, meadow, is the accent).
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

Empty folders aren't committed (git doesn't track them) — create each folder when the
first real file for it lands, following the layout above. The app target folder is
`squabble/`; tests live in `squabbleTests/` and `squabbleUITests/` at the repo root.

`ContentView` is the root router: it owns `AuthSession` and switches between
`OnboardingFlowView`, `ProfileUnavailableView` and `HomeView` on its state.
`OnboardingFlowView` is one native `NavigationStack`: `SignInView` is the root and each
onboarding step is pushed on top (system back button and swipe-back). Popping back to
sign-in signs out. It stays mounted while the profile loads after sign-in, so the first
step arrives as a push rather than a screen swap.
`squabbleApp` applies the launch splash.

### Current state (Sept 2026)

- **Done:** launch splash, Firebase bootstrap, Sign in with Apple (sign in / out /
  delete), and the welcome screen — `SquabbleBackdrop` gradient, the tappable bird as
  hero, and the prop receipt that prints itself. First-run **onboarding**
  (`Feature/Onboarding`): display name + unique handle → avatar (preset or photo) →
  optional payment methods, saved in one transaction; `Feature/Profile` holds the
  models, Firestore/Storage adapters and shared views (`AvatarView`,
  `PaymentMethodEditor`). Account deletion wipes profile data and avatars.
- **Placeholder:** `HomeView` is an empty state with an account button and nothing
  else; it renders on plain system black and does **not** use `SquabbleBackdrop` yet.
  `AccountView` is a stock `List` showing the profile, likewise unstyled — and there's
  no way to edit the profile or payment methods after onboarding yet. Both need the
  branding pass whenever real content lands — see "Never a plain black screen" above.
- **Not started:** groups and everything to do with bills — capture, AI parsing, the
  split algorithm, reminders, invite links.

### Screen conventions worth knowing

- **Entrance animations on the root must wait for the splash.** `launchSplash()`
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
