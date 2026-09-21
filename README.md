<p align="center">
  <img src="Timelog/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="120" alt="Timelog icon" />
</p>

<h1 align="center">Timelog</h1>

<p align="center">
  A lightweight time-tracking app for iOS and native macOS, built with SwiftUI and SwiftData.<br/>
  All data stays on your device — no cloud, no account, no subscription.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-17%2B-black?style=flat-square&logo=apple" />
  <img src="https://img.shields.io/badge/macOS-14%2B-black?style=flat-square&logo=apple" />
  <img src="https://img.shields.io/badge/Swift-5.10-orange?style=flat-square&logo=swift" />
  <img src="https://img.shields.io/badge/SwiftData-✓-blue?style=flat-square" />
  <img src="https://img.shields.io/badge/Sparkle-auto--update-purple?style=flat-square" />
  <img src="https://img.shields.io/badge/Localization-EN%20%7C%20IT-green?style=flat-square" />
</p>

---

## Screenshots

<p align="center">
  <img src="docs/screenshots/Today.png" width="48%" alt="Today — active sessions and daily entries" />
  <img src="docs/screenshots/Timer.png" width="48%" alt="Timer — Stopwatch and Pomodoro" />
</p>
<p align="center">
  <img src="docs/screenshots/History.png" width="80%" alt="History — weekly bar chart and daily entries grouped by client" />
</p>
<p align="center">
  <img src="docs/screenshots/Clients.png" width="48%" alt="Clients — manage clients and projects" />
</p>

---

## Apps

| App | Platform | Description |
|-----|----------|-------------|
| **Timelog** (iOS) | iPhone / iPad | Full-featured mobile app with Live Activity and splash screen |
| **TimelogMac** (macOS) | macOS 14+ | Native menu bar app with full window management |

Both apps share business logic via **TimelogCore**, a local Swift Package in the same repo.

---

## iOS Features

| Tab | Description |
|-----|-------------|
| **Today** | Log time manually or start real-time sessions; live daily total |
| **Clients** | Manage clients (color coded) and their projects; archive when done |
| **Timer** | Stopwatch or Pomodoro with ring progress and lock-screen notification |
| **Settings** | Pomodoro intervals, daily reminders, smart tracking config |
| **Language** | English and Italian — follows the system locale automatically |
| **Nickname** | Picked on first launch and stamped on every record |

### Smart Tracking
Tap ▶ to start a session when you begin working. Stop it when done — duration is logged automatically. Multiple sessions can run simultaneously. Forgot to stop? You get a notification at your configured end-of-day time.

### Live Activity (iOS)
Active sessions and the running timer appear on the lock screen and in the Dynamic Island — no need to open the app.

---

## macOS Features

- **Menu bar icon** — always visible; shows live elapsed time while timer is running
- **Today view** — active sessions with live ticker, today's entries, context menus
- **Clients & Projects** — `NavigationSplitView` with macOS `Table`, inline create/edit forms
- **Timer** — full Pomodoro / stopwatch window, Space to start/pause
- **Auto-updates via Sparkle** — one-click in-app updates, EdDSA-signed DMG; "Check for Updates…" in the app menu. No Apple Developer ID required
- **Settings window** — Pomodoro config, smart tracking end-of-day threshold (`⌘,`)
- **Localization** — English and Italian; system locale followed automatically

---

## Repo Structure

```
TimeLog/
├── Timelog.xcodeproj           # iOS app project
├── TimelogMac.xcodeproj        # macOS app project
├── TimelogCore/                # Shared Swift Package
│   └── Sources/
│       └── TimelogCore/        # Models, VM, Stores, Helpers, Extensions
├── Timelog/                    # iOS app sources (Views only)
├── TimelogMac/                 # macOS app sources (Views only)
└── docs/
    └── audit/                  # Performance, stability, release readiness
```

---

## Requirements

| App | Requirement |
|-----|-------------|
| iOS | Xcode 16+, iOS 17+, physical device for Live Activity |
| macOS | Xcode 16+, macOS 14+ |

---

## Getting Started

```bash
git clone https://github.com/AlbertoBarrago/Timelog.git
cd Timelog
```

**iOS:** open `Timelog.xcodeproj`, select the `Timelog` scheme, run on device or simulator.

**macOS:** open `TimelogMac.xcodeproj`, select the `TimelogMac` scheme, run.

---

## Architecture

- **TimelogCore** — shared `@Observable` models and business logic, public API, iOS 17+ / macOS 14+
- **MVVM** — `TimerViewModel` lives at app level, injected via SwiftUI environment
- **SwiftData** — single `ModelContainer` shared across all scenes
- **ActivityKit** — Live Activities managed by `TimerViewModel` (iOS only, compile-guarded)
- **UserNotifications** — daily reminders, session overdue alerts, Pomodoro phase-end

---

## Testing

```bash
# Unit tests del package (no Xcode required)
(cd TimelogCore && swift test)

# Local macOS app run with tests, build, launch, and log streaming
scripts/run-local-mac.sh
```

Per i test che richiedono l'app bundle (Keychain, Notifications), usa **⌘U** in Xcode sul scheme `Timelog`.

| Target | Suite | Runner |
|--------|-------|--------|
| `TimelogCoreTests` | `Int.formattedDuration`, `Color+Hex`, `Client`, `ActiveSession` | `swift test` |
| `TimelogTests` | `KeychainHelper`, `SettingsStore`, `TimerViewModel` | Xcode ⌘U |

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

---

## Contributing

1. Branch off `main`
2. Keep one feature per PR

---
