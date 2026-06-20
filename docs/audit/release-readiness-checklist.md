# Release Readiness Checklist

This checklist is for the frozen-scope phase. Do not add new product features here; close correctness, stability, performance, privacy, accessibility, and documentation gaps.

## Build and Test

- [x] `TimelogCore` package tests pass with `swift test`.
- [x] iOS Debug build passes on an available simulator.
- [x] macOS Debug build passes locally.
- [x] iOS app unit tests pass from `xcodebuild test -only-testing:TimelogTests`.
- [ ] iOS full test scheme, including UI tests, completes without hanging in Xcode log/coverage finalization.
- [ ] macOS smoke test run completed from a clean install state.
- [ ] Release configuration builds for iOS and macOS.

## Performance

- [ ] Cold launch profiled on iOS.
- [ ] Cold launch profiled on macOS.
- [ ] Timer start/pause/reset profiled.
- [ ] Today view profiled with multiple active sessions.
- [ ] History/charts profiled with a realistic data set.
- [ ] Sync push and pull profiled with realistic data size.
- [ ] SSE idle energy and reconnect behavior profiled.
- [ ] macOS sleep/wake flow profiled.

## SwiftData and Sync

- [x] Mutations call explicit `context.save()` in reviewed primary flows.
- [ ] Save failures in destructive flows are surfaced instead of silently swallowed.
- [ ] `RestSyncService` has tests for pending push and deferred pull behavior.
- [ ] `RestSyncService` has tests for orphan session adoption after server-generated IDs.
- [ ] Pull merge behavior verified with deleted clients, projects, entries, and sessions.
- [ ] Full-snapshot sync payload size measured.
- [ ] SSE-triggered pulls verified while macOS edit forms are open.

## Security and Privacy

- [x] `Timelog/SyncConfig.local` is gitignored.
- [ ] Current local API key rotated if it was ever exposed outside the machine.
- [ ] No credentials are stored in `UserDefaults` or `@AppStorage`.
- [ ] No user-entered notes, client names, or project names are logged.
- [ ] Server env vars are documented and not committed.
- [ ] Privacy manifests reviewed against actual API usage.

## Accessibility

- [ ] All icon-only buttons have meaningful accessibility labels.
- [ ] Swipe actions and context menu actions have clear labels.
- [ ] Charts expose useful accessibility summaries.
- [ ] Color-coded clients/projects are not communicated by color alone.
- [ ] Dynamic Type and larger accessibility text sizes reviewed on iOS.
- [ ] Keyboard navigation reviewed on macOS.

## Localization

- [ ] iOS string catalog has no missing production strings.
- [ ] macOS string catalog has no missing production strings.
- [ ] `TimelogCore` string catalog has no missing production strings.
- [ ] English and Italian terminology is consistent across iOS, macOS, and docs.
- [ ] Date, time, and duration formatting respects locale.

## Documentation

- [x] Sync architecture reflects REST + SSE on both platforms.
- [x] Profiling baseline exists.
- [x] Release readiness checklist exists.
- [ ] Setup docs tested from a clean machine.
- [ ] Self-hosting docs tested against a fresh Vercel project.
- [ ] App Store release procedure documented end to end.

## App Store Readiness

- [ ] Version and build numbers are consistent across targets.
- [ ] App icons and screenshots are current.
- [ ] macOS Sparkle update path verified.
- [ ] iOS Live Activity behavior verified on physical device.
- [ ] Notification permission flows reviewed on both platforms.
- [ ] No debug-only local config files are included in app archive.
