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
  - Telemetry: Crashlytics (crashes + non-fatals), Analytics
- **Networking:** async/await with Alamofire — for non-Firebase HTTP only (the AI
  service). Firebase traffic goes through the Firebase SDK, never hand-rolled REST.
- **Persistence:** Firestore's local cache for anything that syncs; SwiftData only for
  device-local state that never leaves the phone (see "Local data" below).
- **DI:** Factory pattern via FactoryKit
- **Testing:** Swift Testing framework for unit tests

(Dependencies are aspirational until actually added via SPM — add them when the first
real use lands, not before, and note why in the PR. Firebase is added as soon as the
`GoogleService-Info.plist` lands.)

## Backend — Firebase

Chosen over Supabase (Sept 2026) for offline-out-of-the-box Firestore, free
Crashlytics, and a free tier that never auto-pauses. Trade-offs accepted: heavy
ObjC-based SDK, NoSQL modeling, `Sendable` friction under Swift 6.

- **Products in use:** Firestore, Auth, Crashlytics, Analytics. Don't pull in other
  Firebase products (Functions, Storage, Remote Config, Messaging…) without checking
  first — each one is an SPM product and a config decision.
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
- **Auth:** anonymous sign-in on first launch so the app works with zero friction;
  upgrade/link to Sign in with Apple when an account is actually needed (sharing a
  bill across devices).
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

- **Single theme.** The app is locked to light appearance for everyone
  (`INFOPLIST_KEY_UIUserInterfaceStyle = Light`). No dark mode for now — don't add
  dark-appearance variants to colors, assets, or the icon, and don't write
  `colorScheme`-dependent UI.
- **Accent color** (`AccentColor` asset, drives `.tint`): one universal value,
  `#129955` — the classic green sampled from the app icon's background.
  - It's the single brand color — use `Color.accentColor` / `.tint`, don't scatter
    ad-hoc greens. Additional named colors go in the asset catalog as single
    universal values, never hardcoded `Color(red:…)` in views.
  - Contrast note: `#129955` is fine for filled buttons, icons, and large/bold text
    on white, but borderline for small body text as a link color — prefer it as a
    fill (button background, selected state) over small colored text on white.
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

Current state: `Sources/squabbleApp.swift` and `Sources/Feature/Root/ContentView.swift`
(the placeholder root view). Everything else is still to be built.

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
