# Timelog — Technical Documentation

Time tracking app for iOS and macOS. All data lives locally on the device.

## Index

| File | Contents |
|------|----------|
| [01-architecture.md](01-architecture.md) | Monorepo structure, layers, dependencies |
| [02-data-model.md](02-data-model.md) | SwiftData entities, relationships, persistence |
| [03-flows.md](03-flows.md) | Tracking, Pomodoro, Notifications, Live Activity |
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

- iOS 17+ / macOS 14+
- Xcode 16+
- Swift 6.0
