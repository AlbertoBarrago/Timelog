# Performance and Stability Baseline

Date: 2026-06-20
Branch: `audit-performance-stability-docs`
Scope: no new product features; this baseline is for performance, stability, clean code, and release readiness.

## Current Verification

| Check | Command | Result | Notes |
|-------|---------|--------|-------|
| Package tests | `cd TimelogCore && swift test` | Pass | 55 Swift Testing tests passed. |
| iOS unit tests | `xcodebuild test -workspace TimeLog.xcworkspace -scheme Timelog -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -only-testing:TimelogTests` | Pass | App unit test target passed after fixing stale imports and timer phase assumptions. |
| macOS build | `xcodebuild build -workspace TimeLog.xcworkspace -scheme TimelogMac -destination platform=macOS` | Pass | Debug build succeeded. |
| iOS build | `xcodebuild build -workspace TimeLog.xcworkspace -scheme Timelog -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'` | Pass | Debug simulator build succeeded. |
| iOS build command sanity | `... name=iPhone 16` | Not reproducible locally | This machine has no `iPhone 16` simulator; use an available destination from `xcodebuild -list`. |
| Full iOS test scheme | `xcodebuild test ...` | Needs follow-up | Unit tests ran; UI tests launched, but the command hung while Xcode finalized coverage/log records after one unit test failure in the first run. Re-run after UI test plan cleanup. |

## Profiling Plan

Record each profile on a clean Debug build first, then repeat on Release when the flow is stable. Keep one trace per platform and scenario.

| Scenario | Platform | Tool | What to Measure | Release Gate |
|----------|----------|------|-----------------|--------------|
| Cold launch | iOS, macOS | Instruments Time Profiler | Main-thread work before first usable screen, SwiftData container setup, initial `pullAll(into:)` impact | No visible launch stall attributable to sync or large fetches. |
| Timer start, pause, reset | iOS, macOS | Time Profiler, Allocations | Timer tick cost, Live Activity updates, notification scheduling, object churn | One-second timer updates stay cheap and do not accumulate retained objects. |
| Today view with active sessions | iOS, macOS | Time Profiler, SwiftUI instrument | Re-render frequency, elapsed ticker cost, active session row updates | Rows update without causing full-screen expensive recomposition. |
| History and charts | iOS, macOS | Time Profiler, Allocations | Entry grouping, chart aggregation, heatmap generation | Large history datasets remain responsive during navigation and date changes. |
| Sync push | iOS, macOS | Network, Time Profiler | Payload encode time, request count after debounce, main actor occupancy | One local mutation burst produces one debounced push unless another mutation arrives during push. |
| Sync pull | iOS, macOS | Network, Time Profiler, Allocations | Decode time, SwiftData merge cost, delete reconciliation, save time | Pull does not freeze UI and does not wipe pending local mutations. |
| SSE reconnect | iOS, macOS | Network, Energy Log | Reconnect cadence, idle energy, duplicate pulls | Backoff caps at 30 s and no tight reconnect loop appears. |
| macOS sleep/wake | macOS | Energy Log, Console | SSE recovery, active session elapsed correctness | Wake resumes a sane sync state without duplicated sessions. |
| Offline/online transition | iOS, macOS | Network Link Conditioner, Console | Error state, queued push behavior, next successful sync | No data loss; `lastError` clears after successful sync. |

## Initial Findings

### High

- A local ignored secret file exists at `Timelog/SyncConfig.local`. It is not tracked by git, but it contains an API key in clear text in the working tree. If this value has been shared outside the machine, rotate it on the server. Keep this file gitignored and never include it in screenshots, logs, or support bundles.

### Medium

- Root `README.md` was stale around sync architecture. It still described macOS as using direct MongoDB/MongoKitten, while the current code and `docs/04-sync.md` use `RestSyncService` plus SSE on both iOS and macOS.
- UI localization is only partially enforced at source level. Many SwiftUI string literals rely on automatic extraction or existing `.xcstrings`; before App Store submission, run Xcode string catalog validation for both targets and verify missing translations.
- Many user data mutations use `try? context.save()`. This matches the project rule requiring explicit saves, but swallowed save failures reduce diagnosability. For release hardening, destructive and sync-adjacent writes should surface failures in UI or sync state.
- iOS app tests had stale scaffolding: one test imported the old `TimeLog2` module, one file missed `Foundation`, and Pomodoro progress tests assumed `.work` despite `TimerViewModel` restoring persisted phase from `UserDefaults`. These are fixed in this branch.

### Low

- The repo has strong package-level coverage for core analytics and model helpers, but no automated sync reconciliation tests for `RestSyncService`.
- The current terminal baseline validates builds and package tests, not runtime UI behavior, memory graph, or energy usage. Instruments traces are still required before calling performance work complete.
- The full iOS test scheme still needs a clean UI-test run; current reliable command is `-only-testing:TimelogTests`.

## Stability Hotspots To Profile First

1. `RestSyncService.pullAll(into:)`: fetches all local objects, decodes full snapshots, merges, deletes missing remote records, and saves on the main actor.
2. `RestSyncService.push(...)`: encodes all clients, projects, entries, and sessions on each push, not just changed records.
3. `SSEClient.loop(url:apiKey:)`: long-lived stream with reconnect backoff; verify idle energy and duplicate pull behavior.
4. History and insights views: chart data is derived from queried entries and should be profiled with realistic dataset sizes.
5. Timer restoration: `TimerViewModel.restoreState()` resumes ticking after suspension; verify launch behavior for long-running timers and elapsed Pomodoro phases.

## Manual Test Matrix

| Flow | Expected Result |
|------|-----------------|
| Start a session on iOS, see it on macOS | One active session appears on both platforms after push/SSE/pull. |
| Stop and log a session on macOS | iOS removes active session and shows the logged entry. |
| Delete an entry while another device receives SSE | Deleted entry does not reappear after pending push completes. |
| Edit client/project labels while macOS form is open | SSE pull is deferred until editing ends. |
| Kill app while timer is running | Relaunch restores elapsed time and ticking loop. |
| Network unavailable during push | Error state is visible, local data remains intact, next online sync succeeds. |
| Server sends repeated SSE changes | Pulls do not overlap in a way that causes UI stalls or stale state. |

## Next Engineering Actions

1. Add focused sync tests around pending push, deferred pull, orphan session adoption, and server-missing hard deletes.
2. Add lightweight instrumentation around sync duration and payload sizes, without logging user content.
3. Replace swallowed save failures in destructive flows with user-visible error handling.
4. Profile `pullAll(into:)` with realistic datasets and decide whether full-snapshot sync is still acceptable for App Store scale.
5. Run Accessibility Inspector on all primary flows and fix missing labels in actionable controls.
