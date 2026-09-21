# Timelog — Project Context for Claude

## What this project is

Two native SwiftUI time tracking apps (iOS + macOS) sharing a local Swift package (`TimelogCore`). Business logic lives in the package; apps contain only Views.

## Monorepo structure

```
TimeLog/
├── TimeLog.xcworkspace        ← always open this, not individual .xcodeproj files
├── Timelog.xcodeproj          ← iOS app
├── TimelogMac.xcodeproj       ← native macOS app
├── TimelogCore/               ← shared local Swift Package
│   └── Sources/TimelogCore/
│       ├── Models/            ← Client, Project, TimeEntry, ActiveSession
│       ├── ViewModels/        ← TimerViewModel
│       ├── Stores/            ← SettingsStore
│       ├── Helpers/           ← NotificationManager, HistoryHeatmap
│       └── Extensions/        ← Color+Hex, Int+Duration
├── Timelog/                   ← iOS sources (Views only)
└── TimelogMac/                ← macOS sources (Views only)
```

## Core rules

- **Business logic → TimelogCore.** Models, stores, helpers, ViewModels live in the package. Apps contain only Views.
- **Public types.** Everything in TimelogCore needs `public` on class/struct/enum, properties, inits and methods.
- **Platforms.** `#if os(iOS)` for ActivityKit and UIKit haptics. `#if os(macOS)` for AppKit. Never use `#if targetEnvironment(macCatalyst)` — the iOS project is pure iOS, no Catalyst.
- **Single ModelContainer** in the macOS app (`TimelogMacApp`), shared between WindowGroup and MenuBarExtra via `static let container`.

## iOS app (`Timelog.xcodeproj`)

- Target: iPhone + iPad, iOS 17+
- No Mac Catalyst
- Tab order: Today → Clients → Timer → Settings

## macOS app (`TimelogMac.xcodeproj`)

- Target: native macOS 14+
- `MenuBarExtra` → system menu bar icon (always visible)
- `WindowGroup` → main window with `NavigationSplitView` (sidebar: Today / Clients / Tracking / Settings)
- `Settings` scene → accessible via `⌘,`
- Toolbar items in detail views, **not** on the `NavigationSplitView` root
- `columnVisibility` as `@State` (not `.constant`) to allow sidebar toggle
- **"About"** always means the native `NSApplication.orderFrontStandardAboutPanel` panel — never an in-app settings view

## Package TimelogCore

- `Package.swift`: platforms `.iOS(.v17)`, `.macOS(.v14)`
- Everything `public` — if you add a new type remember to add `public init()`
- Conditional compilation for platform-specific code:
  - ActivityKit → `#if os(iOS) && !targetEnvironment(macCatalyst)`
  - UIKit haptics → `#if os(iOS)` (on the function signature too, not just the body)
  - AppKit → `#if canImport(AppKit) && !targetEnvironment(macCatalyst)`

## SwiftUI / Swift conventions

- For ternary expressions returning different `ButtonStyle` types, use `@ViewBuilder` to avoid type-inference errors
- Always reference `modelContext` via `@Environment` — never assume it is in scope
- When querying related objects from a `@State`-held model, use a separate `@Query` filtered by `persistentModelID` rather than accessing the relationship directly (SwiftData relationships on `@State` objects are not always reactive)
- Verify multi-platform targeting (iOS + macOS) when creating new Xcode targets or files
- **SwiftData safety**: always call `try? context.save()` explicitly after mutations; never assume auto-save will fire before app termination

## Git

- The two `.xcodeproj` files and `TimelogCore/` are all in the same repo and should be committed together when they change together
- Never push without asking the user first

## App Store / publication quality

This project targets App Store publication. Always respect:

- **Accessibility**: every interactive element must have a meaningful `.accessibilityLabel`; never use colour alone to communicate state
- **Localisation**: use `String(localized:)` or `LocalizedStringKey` for all UI strings; no hardcoded mixed Italian/English strings
- **Privacy**: no user data in logs, no analytics without consent, connection strings never in plain text in code
- **Security**: credentials only in Keychain, never in `UserDefaults` or `@AppStorage`
- **Performance**: no SwiftData fetches in view `body` — use `@Query`; heavy operations in async `Task`
- **Crash safety**: `try!` and `fatalError` only for programming errors (e.g. ModelContainer init); never for user data or network
- **Native macOS UI**: use `LabeledContent`, `Form.grouped`, toolbar items, `NavigationSplitView` — do not port iOS patterns to macOS
- **Native iOS UI**: use sheets, swipe actions, `TabView` — do not port macOS patterns to iOS
- **Versioning**: `CFBundleShortVersionString` (marketing) and `CFBundleVersion` (build) must be consistent across all targets

## Tech stack

- SwiftUI + SwiftData + `@Observable`
- `UNUserNotificationCenter` for daily reminders, open session alerts, Pomodoro phase end
- `ActivityKit` for iOS Live Activity
- `MenuBarExtra` for macOS menu bar
