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
- **Networking:** async/await with Alamofire
- **Persistence:** SwiftData
- **DI:** Factory pattern via FactoryKit
- **Testing:** Swift Testing framework for unit tests

(Dependencies are aspirational until actually added via SPM — add them when the first
real use lands, not before, and note why in the PR.)

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

- **Accent color** (`AccentColor` asset, drives `.tint`): a warm red.
  - Light: `#E23D4C`  ·  Dark: `#FF5B67`
  - It's the single brand color — use `Color.accentColor` / `.tint`, don't scatter
    ad-hoc reds. Additional named colors go in the asset catalog with light + dark
    variants, never hardcoded `Color(red:…)` in views.
  - Note: the current chosen logo sits on a **green** field, so the accent red may
    get revisited once the icon is final — don't over-invest in red-specific UI yet.
- **Logo direction:** a flat, angular **paper-cut seabird** (gull / tern — a nod to
  "squab") holding a small curled **receipt** in its beak, white on a green
  background. Superseded concept (split receipt) is still in `design/logo-concept.svg`
  for reference. Final `AppIcon` PNGs (1024 + dark + tinted) and the finalized vector
  are still to be produced.

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
      Networking/       Alamofire client, request/response models
      Persistence/      SwiftData container, model schema
      DI/               FactoryKit container & registrations
      Logging/
    Feature/            One folder per feature module. Each feature holds, as needed:
      <Feature>/
        UI/             Screens and feature-local views
        Model/          Feature domain models
        Data/           Repositories / data sources for the feature
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
  environment, never committed. `Secrets.plist`, `.env`, `*.xcconfig.local` are already
  gitignored.
- After code changes, build (and run tests if logic changed) before reporting done.
- This is a public repo — assume anything committed is world-readable.
