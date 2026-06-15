# Architecture

## Monorepo Structure

The repository contains two native apps and a shared Swift package.

```
TimeLog/
├── TimeLog.xcworkspace          ← Xcode entry point
├── Timelog.xcodeproj            ← iOS app
├── TimelogMac.xcodeproj         ← macOS app
├── TimelogCore/                 ← shared Swift Package
│   └── Sources/
│       ├── TimelogCore/         ← models, VM, stores, helpers
│       └── TimelogSync/         ← RestSyncService + SSEClient (iOS + macOS)
├── Timelog/                     ← iOS Views
├── TimelogMac/                  ← macOS Views
└── server/                      ← Vercel middleware (Node.js/TypeScript)
    └── api/
        ├── pull.ts              ← GET  /api/pull
        ├── sync.ts              ← POST /api/sync
        └── events.ts            ← GET  /api/events  (SSE — Change Stream)
```

## Application Layers

```mermaid
graph TD
    subgraph iOS["iOS App (Timelog)"]
        iViews["iOS Views\nSwiftUI"]
        iSplash["SplashView"]
    end

    subgraph macOS["macOS App (TimelogMac)"]
        mViews["macOS Views\nSwiftUI"]
        mMenu["MenuBarExtra"]
    end

    subgraph Core["TimelogCore (Swift Package)"]
        Models["Models\nClient · Project\nTimeEntry · ActiveSession"]
        VM["TimerViewModel"]
        Store["SettingsStore"]
        Helpers["KeychainHelper\nNotificationManager"]
        Ext["Extensions\nColor+Hex · Int+Duration"]
    end

    subgraph Sync["TimelogSync (Swift Package)"]
        RestSvc["RestSyncService\n(iOS + macOS — URLSession → Vercel)"]
        SSESvc["SSEClient\n(real-time Change Stream events)"]
    end

    subgraph Infra["Infrastructure"]
        SD[("SwiftData\nlocal SQLite")]
        KCH[("Keychain")]
        UNS["UNUserNotificationCenter"]
        MDB[("MongoDB Atlas")]
        VCL["Vercel Functions\nGET /api/pull · POST /api/sync · GET /api/events"]
    end

    iViews --> Core
    iViews --> Sync
    mViews --> Core
    mViews --> Sync
    mMenu --> Core

    VM --> UNS
    VM -.->|"iOS only"| LiveActivity["ActivityKit\nLive Activity"]
    Store --> UNS
    Helpers --> KCH
    Models --> SD

    RestSvc --> KCH
    RestSvc --> VCL
    VCL -->|"upsert"| MDB
    VCL -->|"SSE events"| SSESvc
    MDB -->|"Change Stream"| VCL
```

## Architectural Rules

| Rule | Rationale |
|------|-----------|
| Business logic only in `TimelogCore` | Apps contain exclusively Views |
| Everything `public` in TimelogCore | Visible from both apps |
| One `ModelContainer` per app | Avoids SwiftData conflicts; on macOS it is `static let` shared between WindowGroup and MenuBarExtra |
| Both platforms use `RestSyncService` | Single unified sync implementation; no direct MongoDB access from clients; real-time via SSE Change Streams |
| `#if os(iOS)` for ActivityKit and UIKit haptics | Do not use `#if targetEnvironment(macCatalyst)` — the project does not use Catalyst |
| `deletedAt: Date?` on Client, Project, TimeEntry | Soft delete: deleted records are marked but not removed from the database until sync has propagated them to all devices. `ActiveSession` has no `deletedAt` because it is always converted to a `TimeEntry` on stop. |

## Package Dependencies

```mermaid
graph LR
    TimelogCore["TimelogCore"]
    TimelogSync["TimelogSync"]

    TimelogSync --> TimelogCore
```

## Entry Points by Platform

### iOS — `TimelogApp.swift`
```
App
 └─ ModelContainer (Client, Project, TimeEntry, ActiveSession)
     └─ ZStack
         ├─ ContentView
         │   ├─ TabBar: Today · Clients · Timer · Settings
         │   ├─ RestSyncSetup (modifier — pull on launch, push debounced 2s)
         │   └─ SyncFlashOverlay (modifier — green flash + haptic on sync)
         └─ SplashView (fades after initial animation)
```

### macOS — `TimelogMacApp.swift`
```
App
 ├─ static ModelContainer (shared)
 ├─ WindowGroup "main"
 │   └─ MainMacView
 │       ├─ NavigationSplitView: Today · Clients · Tracking · Settings
 │       └─ RestSyncSetup (modifier — pull on launch, SSE listener, push debounced 2s)
 ├─ MenuBarExtra
 │   └─ MenuBarView (window style)
 │       └─ MenuBarStatusLabel (shows timer if running)
 └─ Settings (⌘,)
     └─ MacSettingsView
```
