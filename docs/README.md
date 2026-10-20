# Timelog — Technical Documentation

Time tracking app for iOS and macOS. All data lives locally on the device.

## Index

| File | Contents |
|------|----------|
| [01-architecture.md](01-architecture.md) | Monorepo structure, layers, dependencies |
| [02-data-model.md](02-data-model.md) | SwiftData entities, relationships, persistence |
| [03-flows.md](03-flows.md) | Tracking, Pomodoro, Notifications, Live Activity |
| [build-compatibility.md](build-compatibility.md) | Development toolchain, app deployment targets, build checks and older Xcode limitations |
| [audit/performance-stability-baseline.md](audit/performance-stability-baseline.md) | Frozen-scope performance and stability audit baseline |
| [audit/release-readiness-checklist.md](audit/release-readiness-checklist.md) | Release readiness checklist for profiling, stability, security, accessibility and docs |

## Stack

| Layer | Technology |
|-------|------------|
| UI | SwiftUI |
| State | `@Observable` (Swift 5.9+) |
| Local persistence | SwiftData |
| Notifications | UNUserNotificationCenter |
| Live Activity | ActivityKit (iOS only) |
| Auto-update | Sparkle (macOS) — EdDSA-signed DMG, `appcast.xml` on GitHub Releases |

## Requirements

- Apps: iOS 26+ / macOS 26.4+ (current deployment targets).
- Development toolchain: Xcode 27.1; compatibility with older Xcode versions is not guaranteed.
- TimelogCore package: Swift tools 6.0, iOS 17+ / macOS 14+. These package minimums do not describe the app requirements.

See [build compatibility](build-compatibility.md) for verification details.
