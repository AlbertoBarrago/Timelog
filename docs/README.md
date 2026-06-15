# Timelog — Technical Documentation

Time tracking app for iOS and macOS with MongoDB Atlas synchronisation.

## Index

| File | Contents |
|------|----------|
| [01-architecture.md](01-architecture.md) | Monorepo structure, layers, dependencies |
| [02-data-model.md](02-data-model.md) | SwiftData entities, relationships, persistence |
| [03-flows.md](03-flows.md) | Tracking, Pomodoro, Notifications, Live Activity |
| [04-sync.md](04-sync.md) | Sync architecture, RestSyncService, SSEClient, upsert strategy |
| [05-self-hosting.md](05-self-hosting.md) | Self-hosting guide: Atlas setup, Vercel deploy, user migration |

## Stack

| Layer | Technology |
|-------|------------|
| UI | SwiftUI |
| State | `@Observable` (Swift 5.9+) |
| Local persistence | SwiftData |
| Cloud sync | Vercel REST API + SSE (`RestSyncService` + `SSEClient`, iOS + macOS) |
| Credentials | Keychain |
| Notifications | UNUserNotificationCenter |
| Live Activity | ActivityKit (iOS only) |
| Auto-update | Sparkle (macOS) — EdDSA-signed DMG, `appcast.xml` on GitHub Releases |

## Requirements

- iOS 17+ / macOS 14+
- Xcode 16+
- Swift 6.0
- MongoDB Atlas account (optional, macOS sync only)
