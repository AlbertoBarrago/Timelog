# Changelog

All notable changes to this project will be documented in this file.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

---

## [1.5.5] — 2026-06-17

### Fixed
- **macOS app name** — `CFBundleName` and `CFBundleDisplayName` are now set explicitly to "Timelog" in `Info.plist`. Previously the Dock hover label and app menu showed "TimelogMac" because both keys fell back to `$(TARGET_NAME)`.

---

## [1.5.4] — 2026-06-17

### Fixed
- **Sync: session duplication after push** — when the server assigned a new ObjectId to a pushed session (sent with empty `_id`), subsequent pulls created a duplicate local session instead of updating the existing one. The pull now matches server sessions to local orphans by `startDate` proximity and adopts the server ID in place.
- **Sync: pull now always follows push** — previously a pull-after-push only happened if an SSE event arrived during the push window. Now every push unconditionally triggers a pull, ensuring server-assigned IDs are written back into local SwiftData records.
- **Sync: `isUserEditing` flag now set on stop-session forms** — `RestSyncService.isUserEditing` existed but was never set, so SSE-triggered pulls could overwrite form data while the user was editing duration or notes. Both `StopSessionSheet` (iOS) and `StopSessionMacView` (macOS) now set the flag on appear/disappear.

---

## [1.5.4] — 2026-06-16

### Fixed
- **Stats refresh consistency** — the Stats / Insights views on iOS and macOS now recompute analytics when entry content changes, not only when the number of entries changes. Updates to duration, label, project, or client are reflected immediately.
- **Dropped analytics recomputes** — overlapping recompute requests are now coalesced so the latest state is always published, avoiding stale charts after rapid edits.
- **Stats responsiveness** — heavy analytics computation now runs off the main actor before publishing results back to the UI.
- **Sync race causing disappearing data** — `pullAll` no longer hard-deletes local clients, projects, or entries while a push is pending. This closes the most dangerous race where a just-saved item could disappear before the server snapshot caught up.
- **iOS editing sync safety** — iOS now defers incoming sync pulls while a modal sheet is open, matching the existing macOS protection against editing under live remote changes.
- **Content-only sync detection** — automatic sync triggers now use a content fingerprint instead of raw collection counts, so edits that do not change record counts still produce a push on both iOS and macOS.
- **Immediate push for new manual entries** — creating a new entry from Quick Log on iOS now triggers an immediate sync instead of waiting for count-based observation and debounce timing.

### Tests
- **Behavioral insights coverage** — added tests for analytics refresh token invalidation and coalesced recompute behaviour to lock in the Stats fixes.

---

## [1.5.3] — 2026-06-15

---

## [1.5.2] — 2026-06-15

---

## [1.5.1] — 2026-06-15

### Removed
- **Widgets (iOS & macOS)** — the WidgetKit extension has been removed from both platforms. The widget suffered from persistent known issues: data not refreshing after app changes, the extension showing stale/dark-cached content across builds, and a macOS-specific path mismatch between the non-sandboxed app and the sandboxed widget container that prevented snapshot delivery even after applying the `FileManager.containerURL` workaround. Rather than carry broken surface area into the App Store release, the feature has been cut entirely. If reintroduced in a future version it will be built from scratch using App Intents and a shared SwiftData container via App Group.

---

## [1.5.0] — 2026-06-15

### Added
- **Stats tab (iOS) / Stats sidebar (macOS)** — new analytics module "Behavioral Insights" with six engines that reveal work patterns from existing time entries.
  - **Focus Score** — daily score (0-100) based on session depth, deep work ratio, short-session penalties, and label-switching frequency. Shown as a 7-day bar chart.
  - **Weekly Review** — total hours, best day, most active label/client, longest session, trend vs previous week, and a deterministic improvement tip.
  - **Peak Hours** — average session length by hour of day (bar chart), highlighting when you work most effectively.
  - **Label Breakdown** — horizontal bar chart ranking labels by total time, with formatted duration annotations.
  - **Time Leaks** — identifies labels/clients where time spent this week exceeds the 28-day baseline by more than 20%.
  - **Work Fingerprint** — classifies your working style as Builder, Maker, Coordinator, Explorer, or Balanced based on session depth, client variety, and label diversity.
- **`BehavioralInsightsService`** — `@Observable` orchestrator that exposes all engine results; computes off the main thread via `async/await`.
- **Unit tests** — `BehavioralInsightsTests` covers all six engines with Swift Testing (`@Suite`/`@Test`/`#expect`), deterministic UTC calendar, edge cases, and boundary values.

---

## [1.4.10] — 2026-06-15

---

## [1.4.9] — 2026-06-15

---

## [1.4.8] — 2026-06-14

---

## [1.4.7] — 2026-06-12

### Added
- **Update badge on menu bar icon** — a small orange dot appears on the menu bar icon when a new version is available on GitHub. `VersionChecker` polls `api.github.com/repos/AlbertoBarrago/Timelog/releases/latest` on launch and every hour; uses semantic version comparison so patch/minor/major bumps are all detected correctly.

### Fixed
- **Ghost sessions after quick-stop from Clients view** — stopping one or more sessions via the ▶/■ button in the Clients/Projects view (both iOS and macOS) did not trigger a sync push. On macOS the `dataFingerprint` observer is blind to compensating changes (−N sessions + N entries = same sum), so the server was never notified; the next SSE event or foreground transition re-pulled the old sessions and re-created them locally. Both `autoStop` implementations now call `triggerSyncNow()` after saving, matching the behaviour of the stop sheets.

---

## [1.4.6] — 2026-06-12

### Fixed
- **Parallel sessions deleted by concurrent sync pull** — starting two sessions in quick succession from the Clients view could cause one session to disappear immediately. A `pullAll` triggered by an SSE event or a scene-phase transition (app returning to foreground) ran before the debounced push had sent the new sessions to the server; because the sessions had a `mongoId` but were absent from the server response, they were incorrectly deleted. `pullAll` now skips session deletion while a push is pending (`hasPendingPush = true`).

---

## [1.4.5] — 2026-06-12

### Fixed
- **Sparkle update notifications not appearing** — `SUScheduledCheckInterval` was unset, so Sparkle used the default 24-hour interval. As a menu bar app that runs continuously, users could wait up to a day before seeing a new-version banner. Interval reduced to 3600 s (1 hour).

---

## [1.4.4] — 2026-06-12

---

## [1.4.3] — 2026-06-12

### Changed
- **Timer face position** — the stopwatch/Pomodoro display is nudged 14 pt upward inside the ring for better visual balance.

---

## [1.4.2] — 2026-06-12

### Fixed
- **Editing an existing entry not synced** — modifying a time entry (duration, notes, client, project…) on iOS or macOS was never pushed to the server because the sync observers only watched the record *count*. The local change was therefore overwritten by the next SSE-triggered pull, restoring the old value. Both `QuickLogSheet` (iOS) and `QuickLogMacView` (macOS) now call `triggerSync()` immediately after saving an edit.

---

## [1.4.1] — 2026-06-12

### Fixed
- **macOS widget not updating** — `WidgetSnapshotStore` now uses `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)` instead of `UserDefaults(suiteName:)` to read/write the shared snapshot. On macOS, `UserDefaults(suiteName:)` in a non-sandboxed app writes to `~/Library/Preferences/` rather than the App Group container, so the sandboxed widget extension was reading from a different file. Both now use the same `today_widget_snapshot.json` in the Group Container.
- **macOS widget stale after restart** — `AppDelegate.applicationDidFinishLaunching` now rebuilds and saves the widget snapshot from SwiftData at app launch, so the widget reflects current data even when the window or menu bar has not been interacted with yet.
- **Widget not refreshing on session stop** — added `onStop` callbacks to `StopSessionSheet` (iOS) and `StopSessionMacView` (macOS) so stopping a session immediately triggers a snapshot update and `WidgetCenter.reloadTimelines`, without waiting for the next `onChange` cycle.
- **iOS widget extension** — replaced `TimelogWidgetExtension` (which included unused Live Activity scaffolding) with the new `TimelogWidget` target (widget-only, cleaner entitlements).
- **macOS large widget black background** — `containerBackground` now uses `Color(nsColor: .windowBackgroundColor)` on macOS; the `.systemLarge` family has been removed from the macOS widget (only small/medium are supported).

---

## [1.4.0] — 2026-06-11

### Added
- **macOS auto-updates via Sparkle** — the Mac app now checks for updates automatically and offers one-click in-app updates (standard Sparkle UI, localised). New "Check for Updates…" item in the app menu. Updates are EdDSA-signed: the release pipeline signs the DMG with the `SPARKLE_ED_PRIVATE_KEY` repo secret and attaches a generated `appcast.xml` to each GitHub release; the app reads the feed from `releases/latest/download/appcast.xml`. No Apple Developer ID required — Sparkle's EdDSA signature guarantees update integrity. ⚠️ The EdDSA private key (Keychain + password manager backup) must never be lost: without it, existing installs can no longer auto-update.
- **macOS desktop widget** — new `TimelogMacWidgetExtension` target embedded in the Mac app: the Today widget (small/medium/large, with per-client breakdown) is now available on the macOS desktop and Notification Center. The widget implementation moved to `TimelogCore` and is shared between iOS and macOS; the menu bar scene keeps the shared snapshot up to date. The extension is sandboxed with the `group.me.albz.timelog` App Group (also added to the Mac app entitlements).
- **Widget: live ticking timer** — while a tracking session is running, the widget's status line shows a real-time counting timer (`Text(_, style: .timer)`, no timeline refresh needed) for the most recent active session, instead of a static minutes value.
- **Widget: medium, large and Lock Screen families** — the Today widget now supports `systemMedium` and `systemLarge` (with a per-client breakdown of today's time, colour-coded and sorted by minutes) plus the Lock Screen accessories `accessoryCircular` (compact total + tracking indicator), `accessoryRectangular` (total, last project, tracking state) and `accessoryInline`; all also appear in StandBy. The shared snapshot now carries an aggregated per-client breakdown (backward-compatible with previously serialized snapshots).
- **Confirmation when starting tracking from the clients view** — pressing ▶ on a project while other sessions are running no longer silently stops them: a dialog now offers "Start in parallel" (other sessions keep running) or "Stop others and start" (others are logged, with the new working-hours cap). With no active sessions the quick start remains immediate. Applies to both iOS and macOS.
- **Working-hours cap on forgotten sessions** — new `ActiveSession.cappedElapsedMinutes(endHour:endMinute:)` limits a stopped session to the first end-of-workday boundary after its start, so a session left running for days no longer produces 150-hour entries. Applied to quick-stop in the clients view (iOS + macOS) and to the duration prefill of both stop sheets; covered by 4 new unit tests.

### Changed
- **Heatmap hover, GitHub-style** — the cell under the pointer now shows a highlight ring, and the hover card is anchored to the cell on its left side (flipping right when there is no room) instead of floating under the cursor.
- **Timer says "Resume" when paused** — the play button (macOS timer view) and the accessibility labels (iOS timer, macOS menu bar) now read "Resume" instead of "Start" when a paused timer has accumulated time.

### Fixed
- **macOS: sidebar toggle disappearing** — changing the toolbar display mode via its context menu ("Icon and Text" / "Text Only") broke the `NavigationSplitView` toolbar layout, moving the sidebar toggle to the trailing edge. The window toolbar is now locked to icon-only and the display-mode entries are removed from the context menu on macOS 15+.

### Localisation
- **Notifications fully localised** — all Pomodoro, reminder and session-overdue notification texts (previously hardcoded mixed Italian/English in `NotificationManager`) now go through a new string catalog in the `TimelogCore` package (`defaultLocalization` + `Bundle.module`), with English source and Italian translations.
- **Widget extension localised** — new string catalog for the iOS widget ("Today", "Logged", "No entries today", …); removed two dead Xcode template files (`TimelogWidgetExtensionControl.swift`, `AppIntent.swift`) whose example App Intents could leak into the Shortcuts app.
- **Catalogs completed** — added the missing Italian translations in both app catalogs (22 keys on iOS including a proper plural rule for "%lld projects"; "Alert if no hours logged", "Reset & Pull…", "Sends a notification…", "Total" on macOS).

### Accessibility
- **Pomodoro progress indicators** (iOS dots, macOS capsules) now expose an `accessibilityLabel` announcing "N of M pomodoros completed" instead of communicating state by colour only.
- **macOS sync status dot** now announces sync state (in progress / error / synced) to VoiceOver.

---

## [1.3.2] — 2026-06-07

### Fixed
- **Missing `context.save()` after insert/delete** — `ClientsMacView` (new Client, new Project forms) and `SettingsView` / `MacSettingsView` (delete-all action) now call `try? context.save()` explicitly, preventing data loss on app termination before auto-save fires.
- **Dead `#if targetEnvironment(macCatalyst)` blocks removed** — four Catalyst toolbar guards in `ClientsView`, `SettingsView`, `HomeView`, `TimerView` are gone; the iOS project has no Catalyst target so the code was unreachable.
- **`UINotificationFeedbackGenerator` wrapped in `#if os(iOS)`** — prevents a theoretical build failure if the sync-flash modifier were ever compiled outside iOS.

### Changed
- **`OnboardingPage.title/body` use `LocalizedStringKey`** — titles and body text in the onboarding carousel are now properly resolved through the localisation system instead of being displayed verbatim.

### Accessibility
- Added `.accessibilityLabel` to 10 previously unlabelled interactive elements: Delete / Edit / Archive swipe buttons and "Show archived" toolbar button in `ClientsView`; Sync Now, Export, Show guide buttons in `SettingsView`; Get Started and Next buttons in `OnboardingView` / `UserSetupView`; calendar day-bar button in `HistoryMacView` (announces date and minutes tracked).

---

## [1.3.1] — 2026-06-04

### Added
- **GitHub-style activity heatmap (macOS)** — the History "Hours by project" section can now display a contribution-style grid of day cells coloured by each day's prevailing client, with opacity scaled by minutes logged (trailing ~17 weeks). Selectable via Settings → History → "History chart style" (Donut / Heatmap).
- **`HistoryHeatmap`** (`TimelogCore`) — pure, unit-tested aggregation that buckets entries into per-day cells with the dominant client; covered by `HistoryHeatmapTests`.

### Changed
- **`SettingsStore.historyChartStyle`** — new persisted preference (`history_chart_style`) replacing the previous `showHistory` flag.

### Removed
- **"Show History" toggle** — the option to hide the History tab (iOS) / sidebar item (macOS) added in 1.3.0 has been removed; History is always available.

---

## [1.3.0] — 2026-06-03

### Added
- **Real-time sync via Server-Sent Events** — both iOS and macOS now receive a `{ type: "change" }` event from `GET /api/events` within ~1 s of any remote change, triggering an immediate pull. Latency drops from up to 30 s (polling) to under 1 s in both directions.
- **`GET /api/events` server endpoint** — Vercel function that opens a MongoDB Change Stream on the entire `timelog` database and forwards events as SSE. Sends heartbeats every 25 s; closes cleanly on client disconnect.
- **`SSEClient`** (`TimelogSync`) — `@Observable @MainActor` class using `URLSession.bytes(for:)` async streaming. Parses SSE lines, fires `onChangeEvent` callback, reconnects with exponential backoff (1 s → 2 s → max 30 s).

### Changed
- **Unified sync architecture** — macOS now uses `RestSyncService` (same as iOS) instead of `MongoSyncService`. Both platforms push via `POST /api/sync` and pull via `GET /api/pull`; the server is the only component with a direct MongoDB connection.
- **`RestSyncService` extended for macOS** — `loadConfigFromFile()` on macOS reads `~/.config/timelog/sync.local` (key `URL` + `API_KEY`), same format as iOS `SyncConfig.local`. No manual input required.
- **Race-condition guard** — `hasPendingPush` flag in `RestSyncService` defers SSE-triggered pulls until any in-flight or queued push completes, preventing a server pull from restoring data the user just deleted locally.
- **`isUserEditing` on `RestSyncService`** — macOS `SyncGate` modifier now targets `RestSyncService`; SSE-triggered pulls are deferred while a modal form is open, same behaviour as before.
- **`willWipeDataNotification`** moved from `MongoSyncService` to `RestSyncService` (`RestSyncServiceWillWipeData`); macOS views updated.
- **macOS `RestSyncSetup` modifier** replaces `MongoSyncSetup`; polling loop removed entirely.
- **iOS `RestSyncSetup` modifier** — SSE stream started after initial pull on app launch; stopped on `.background` and restarted on `.active`.

### Removed
- **`MongoSyncService`** — macOS direct MongoDB sync service deleted entirely.
- **MongoKitten dependency** — removed from `TimelogCore/Package.swift`; macOS apps no longer connect directly to MongoDB Atlas.
- **30-second polling loop** — replaced by SSE push notifications.

### Fixed
- **Ghost session after stop (iOS sync)** — a session stopped on iOS could reappear on the next pull because the REST server never removed it. The push payload now carries the user's `userId` and `/api/sync` reconciles `active_sessions`, deleting that user's sessions absent from the payload.
- **Item reappears after delete** — a race where the 30-second macOS poll fired before the local delete was pushed to the server has been eliminated; SSE-triggered pulls are deferred until the push completes.
- **Deleted items not removed on other devices** — `RestSyncService.pullAll` now reconciles clients, projects, and entries against the server response: local records with a `mongoId` absent from the server are hard-deleted (matching the existing session reconciliation logic). Previously only sessions were reconciled; hard-deletes of clients/projects/entries were invisible to other devices until the next full reset.
- **Multi-user session data loss (macOS sync)** — `MongoSyncService` reconciled remote sessions with an unscoped `find()`, which could delete other users' active sessions on a shared cluster. The query is now scoped to the current `userId`.
- **Cross-user session leak (iOS pull)** — pulled sessions are now filtered by `userId` and stamped with the owner, matching how clients/projects/entries are handled.
- **Silent push failures (iOS sync)** — `RestSyncService` now validates the HTTP status of `POST /api/sync` and surfaces an error instead of reporting a successful sync.
- **Running timer froze after relaunch** — a timer that was running on termination now resumes its ticking loop on launch instead of displaying a frozen elapsed time.

### Security / Privacy
- **Removed verbose sync logging (iOS)** — `RestSyncService` no longer prints full pull responses (client/project/entry data) to the console.
- **Per-user pull scoping (server)** — `GET /api/pull` now filters by `userId` (legacy records with no `userId` remain visible), so a client no longer receives other users' data over the wire.
- **No direct database access from clients** — MongoDB Atlas credentials are no longer stored on device; both platforms authenticate to the Vercel middleware with an API key only.

### Docs
- `docs/04-mongodb-sync.md` renamed to `docs/04-sync.md` and fully rewritten for the unified SSE architecture.
- `docs/01-architecture.md`: updated diagrams and dependency graph (MongoKitten removed).
- `docs/SETUP_SYNC_SERVER.md`: macOS setup now uses `~/.config/timelog/sync.local`; MongoDB connection string section removed.
- `CLAUDE.md`: Package TimelogSync section updated.

---

## [1.2.6] — 2026-05-29

---

## [1.2.5] — 2026-05-29

---

## [1.2.4] — 2026-05-28

---

## [1.2.3] — 2026-05-28

---

## [1.2.2] — 2026-05-27

### Fixed
- **Release workflow** — CI now uses the pushed tag directly (`github.ref_name`) instead of computing a new version, preventing spurious tag creation on every push
- **`release.sh`** — uses `git tag -f` to overwrite an existing local tag if the script is re-run for the same version; prompts for confirmation before `git push`

---

## [1.2.1] — 2026-05-27

### Fixed
- **Entry notes not shown in Today view (macOS)** — notes are now displayed regardless of whether a project is associated with the entry
- **Widget non si aggiornava rapidamente dopo stop/start sessione** (iOS) — aggiunto `try? context.save()` in `StopSessionSheet` e `StartTrackingSheet`; la `@Query` di `HomeView` riceve dati aggiornati prima di scrivere lo snapshot su App Group UserDefaults
- **Sessione ancora attiva dopo stop + navigazione** (iOS + macOS) — stesso `context.save()` esplicito risolve il lag di autosave di SwiftData; aggiunto anche in `StartTrackingMacView`
- **Pomodoro si resettava aprendo il MenuBarExtra** (macOS) — `.onChange(of: vm.pomodoroEnabled)` in `CompactTimerRow` e `TimerView` ora usa `initial: false`; non scatta più alla prima render del popup
- **Stato timer perso al riavvio dell'app** (iOS + macOS) — `TimerViewModel` persiste `elapsed`, `isRunning`, `pomodoroEnabled`, `phase` e `completedPomodoros` in `UserDefaults`; al riavvio lo stato viene ripristinato e il drift temporale calcolato automaticamente se il timer era in corsa

### Added
- **Meeting-type labels on projects and time entries** — projects can be tagged as a meeting type; entries inherit the label for better reporting (#36)
- **Quick start/stop buttons on project lists** (iOS + macOS) — tap to start or stop a session directly from the project list without opening the full tracking sheet (#38)
- **Pomodoro toggles in iOS Settings** — enable/disable Pomodoro and configure intervals from the Settings tab; fixed stop-session duration being incorrect when Pomodoro was active
- **Idle alert when no active session is running** — notification fires at the configured end-of-day threshold if no session has been started that day (#37)
- **Localizzazione EN / IT** — infrastruttura `.xcstrings` (Xcode 15+) per iOS e macOS; ~130 chiavi iOS, ~127 chiavi macOS, tutte tradotte in italiano
- `it` aggiunto a `knownRegions` in entrambi i `.xcodeproj`
- **Discard sessione dal form di stop (macOS)** — bottone "Discard" con alert di conferma in `StopSessionMacView`; elimina la sessione senza creare entry
- **Toggle show/hide finestra principale (macOS)** — il bottone nel MenuBar cerca la finestra titolata esistente via `NSApp.windows` e la mostra/nasconde invece di aprirne una nuova

### Fixed
- **Stop sessione non funzionante nella main window macOS** — `onTapGesture` sulla riga veniva intercettato dalla `List`; sostituito con un `Button` esplicito in `ActiveSessionMacRow`, allineato al pattern già funzionante del MenuBar
- **Sessioni non stoppabili (sync)** — `MongoSyncService.push(sessions:)` ora cancella da MongoDB le sessioni eliminate localmente, evitando la ricreazione al prossimo `pullAll`
- **Tempo fermo nel main window macOS** — `TimelineView` dentro `List` non forzava il re-render delle celle; passare `context.date` come parametro `now` alle row view risolve il problema
- **Formato data con spazi extra in History (macOS)** — `DatePicker(.field)` produceva "16/  5/2026" per mesi singola cifra; migrato a `.stepperField` nativo macOS, frecce esterne e `moveDate` rimossi

### Changed
- `AppTab.title` (iOS) e `SidebarItem` label (macOS) migrati da `String` a `LocalizedStringKey`
- `PomodoroPhase.label` wrappato in `LocalizedStringKey` nei view (il tipo nel model resta `String` per `NotificationManager`)
- `DayPicker` / `DayPickerMac`: `Text(LocalizedStringKey(day.label))` per localizzare le abbreviazioni dei giorni
- `exportEmail()`: soggetto e intestazione usano `String(localized:)`
- **Sync pull — cleanup locale (macOS)** — `MongoSyncService.pullAll` ora elimina i record locali con `mongoId` non più presenti in remoto (clients, projects, entries, sessions); i record locali senza `mongoId` non vengono toccati
- **Sync gate centralizzato (macOS)** — `MongoSyncService.isUserEditing` blocca sync durante data-entry; 4 `onChange` separati unificati in `dataFingerprint`; nuovo modifier `syncGated` applicato a tutti i modal di editing

---

## [1.2.0] — 2026-05-16

### Added
- **Sync ActiveSession tra device** — sessioni attive sincronizzate via `MongoSyncService` (macOS) e `RestSyncService` (iOS); pull con replace strategy (remote è autoritativo); `dataProvider` include `sessions` in entrambe le app
- `ActiveSession.mongoId` — ID persistente generato all'`init` per l'upsert in sync
- **Avviso sessioni attive alla chiusura** — alert di conferma se ci sono sessioni di tracking aperte alla chiusura dell'app (iOS e macOS)
- `MongoSyncService.pullAll(into:)` — pull sync MongoDB → SwiftData all'avvio; upsert di client, project e time entry per `mongoId`; supporto multi-device e multi-utente (iOS stub no-op)
- `MongoSyncService.loadConnectionStringFromFile()` — legge `~/.config/timelog/mongo.local` all'avvio e salva in Keychain se vuoto; file mai committato
- Toast banner in-app al completamento della sync (push o pull)
- `docs/` con documentazione tecnica e diagrammi Mermaid: architettura, data model, user flows, MongoDB sync flow
- macOS History sidebar: grafico a barre settimanale (7 giorni, proporzionale, click per navigare) + voci raggruppate per cliente con subtotali
- iOS History sheet: date picker, totale per giorno, swipe-to-delete, tap-to-edit
- `WidgetSnapshotStore` in `TimelogCore` — scrive `TimelogWidgetSnapshot` su App Group `UserDefaults` per il widget
- Widget Today home-screen (sostituisce template Xcode): minuti loggati + attivi, ultimo cliente/progetto, indicatore di registrazione
- **Unit test suite** (`TimelogCoreTests`, `swift test`) — 5 suite CLI: `Int.formattedDuration` (10 casi), `Color+Hex`, `Client.newMongoId`, `ActiveSession` (elapsed, asTimeEntry), `WidgetSnapshot` (Codable, aggregazioni)
- **App target tests** (`TimelogTests`, ⌘U) — 3 suite con app bundle: `KeychainHelper`, `SettingsStore` (UserDefaults iniettabile), `TimerViewModel` (fasi pomodoro, displayTime, progress, reset)

### Fixed
- **Soft delete** su `Client`, `Project`, `TimeEntry` — campo `deletedAt: Date?`; pull ignora oggetti con `deletedAt != nil`; UI filtra correttamente
- `ModelContainer`: reset automatico su store corrotto — evita crash al lancio dopo update
- `ModelConfiguration` con nome esplicito `"TimelogMac"` — evita collisioni con `default.store` generico su macOS
- `pullAll`: save atomico dopo ogni upsert — risolve crash `model invalidated`
- `MongoSyncService`: ambiguità `'Project'` risolta qualificando come `TimelogCore.Project` (collisione con tipo MongoKitten dopo Xcode 26)
- `dataProvider` cattura `modelContainer` invece di `modelContext` — evita contesto stale con fetch vuoti
- iOS + macOS: sheet progetto si chiudeva prima del salvataggio — `dismiss()` chiamato prima di `context.insert()`
- macOS: doppio `client.projects.append(p)` rimosso — SwiftData gestisce già la relazione inversa
- iOS: secondo cliente non si salvava — unificati due `.sheet` modifier in un singolo enum `ClientSheet`
- macOS: crash `model instance was invalidated` su delete cliente — selezione ora usa `PersistentIdentifier`
- macOS: `client.projects` sostituito con `@Query` in `ProjectsMacView` — evita accesso a backing SwiftData invalidato
- macOS: spazio vuoto in cima a Projects e History view — radice `VStack` → `List`

### Changed
- macOS Settings: rimosso campo MongoDB connection string — gestito esclusivamente via `~/.config/timelog/mongo.local` + Keychain; rimane pulsante "Sync Now" e status
- macOS: input durata → `DurationPickerMac` — 6 bottoni rapidi (15m…2h) + input testo con stepper
- iOS + macOS: color picker cliente → griglia 12 swatches preset; `ColorPicker` nativo come fallback "Custom"
- `HomeView` refactored a singolo enum `activeSheet` — sostituisce quattro `@State` bool separati
- macOS sidebar include ora History tra Today e Clients
- `AppTab` enum estratto in `ToolbarOnlyNavigation.swift`

### Removed
- Modalità menu-bar-only (toggle nascondi Dock icon) — rimossa in attesa di implementazione stabile

---

## [1.1.0] — 2026-05-14 (Beta)

### Added
- **iOS sync via middleware** — `RestSyncService` su `URLSession` puro (zero dipendenze SPM): pull all'avvio, push debounced su ogni modifica. Credenziali caricate automaticamente da `SyncConfig.local` nel bundle (gitignored).
- **Server middleware** (`server/`) — due endpoint Vercel TypeScript: `GET /api/pull` e `POST /api/sync`, auth via `X-API-Key`, home con Swagger UI dark su `https://timelog-server.vercel.app`.
- **Splash screen iOS** — schermata di avvio minimal dark, orologio + "Timelog" + "Track your time.", animazione fade+scale in 1.5s.
- `docs/SETUP_SYNC_SERVER.md` — guida per configurare il sync su un nuovo Mac o device.

### Fixed
- Widget extension deployment target: 16.6 → 17.0 (allineato a `TimelogCore` iOS 17+).
- `ControlWidget` marcato `@available(iOS 18.0, *)` — compila su iOS 17.
- `@main struct TimelogApp` ripristinato dopo rimozione accidentale.
- `pullAll` usa delete per-oggetto invece di batch delete — `@Query` SwiftData ora si aggiorna correttamente dopo il pull.
- Relazioni `Project.client` e `client.projects` settate da entrambi i lati — i progetti appaiono correttamente sotto il loro cliente.
- `DNSClient` / MongoKitten escluso dal target iOS (`condition: .when(platforms: [.macOS])`) — fix build iOS.

### Changed
- iOS Settings: rimossi campi URL e API Key — un solo tasto **Sync Now** + status row.
- `MongoSyncService` rimane macOS-only; iOS usa `RestSyncService` via middleware.

---

## [0.2.0] — 2026-05-10

### Added
- Native macOS app (`TimelogMac`) with `MenuBarExtra` status bar icon
- `TimelogCore` local Swift Package — shared models, stores, VM, helpers, extensions (public API, iOS 17+ / macOS 14+)
- macOS main window: `NavigationSplitView` with Today, Clients, Timer, Settings sidebar
- macOS Today view: live active sessions, today entries, context menus, toolbar actions
- macOS Clients view: `HSplitView` clients → projects with macOS `Table`, inline create/edit sheets
- macOS Timer view: full Pomodoro / stopwatch with ring, Space shortcut
- macOS menu bar popover: compact timer controls, active sessions, today total, open-window button
- macOS Settings view: Pomodoro config, daily reminders, end-of-day threshold (`⌘,`)
- Single shared `ModelContainer` across all macOS scenes (menu bar + window see the same data)
- `MenuBarStatusLabel` extracted as a dedicated `View` struct for correct `@Observable` reactivity
- `CLAUDE.md` project context file for AI-assisted development sessions

### Changed
- **Monorepo**: `TimelogMac.xcodeproj` moved into the `TimeLog` repo alongside `Timelog.xcodeproj`
- iOS app no longer uses Mac Catalyst — pure iOS target, `#if targetEnvironment(macCatalyst)` guards removed
- All shared types migrated from inline iOS files to `TimelogCore` package (public access throughout)
- `TimerViewModel.start()` uses `RunLoop.main.add(timer, forMode: .common)` — timer no longer pauses during scroll
- `TimerView` ring frame moved onto `TimerRingView` itself — stopwatch mode no longer wastes vertical space
- `SettingsStore` properties auto-save via `didSet` — views no longer call `save()` manually
- `SettingsStore.load()` skips writes during startup via `isLoading` flag
- Removed placeholder Wethod API integration (URL + key fields) — `KeychainHelper` stays for future use

---

## [0.1.0] — 2026-05-10

### Added

#### Smart Tracking
- Real-time session tracker: start a session per project, stop it to auto-log a `TimeEntry`
- Multiple concurrent sessions supported
- Sessions survive app kill (elapsed computed from `startDate`, no Timer on the model)
- `ActiveSession` SwiftData model with live `hh:mm:ss` display via `TimelineView`
- Start Tracking sheet — pick client/project/notes, tap Start
- Stop Tracking sheet — pre-filled elapsed duration via Steppers (hours 0–23, minutes 0–59), fully editable
- Swipe-to-discard on active sessions (cancels notification, no entry logged)
- Today total card now includes running session time and ticks live every minute
- Today card icon switches to red `record.circle.fill` when a session is active

#### Reminders & Notifications
- Daily reminder: configurable time + day-of-week picker (M Tu W Th F Sa Su)
- Smart Tracking overdue alert: fires at configurable end-of-day if a session is still open
- Pomodoro phase-end notification when the screen is locked
- `NotificationManager` with separate `cancelAllReminders()` / `cancelAllSessions()` / `cancelPomodoroNotification()`

#### Haptics
- `.medium` impact on timer start
- `.light` impact on timer pause
- `.rigid` impact on timer reset
- `.success` notification feedback on session log

#### iOS Live Activity
- Lock screen banner and Dynamic Island showing timer phase, display time, and running state
- Updates every 5 seconds; ends on reset
- `NSSupportsLiveActivities` + `NSSupportsLiveActivitiesFrequentUpdates` in `Info.plist`
- Widget Extension (`TimelogWidgetExtensionExtension`) with `DynamicIsland` support

#### Onboarding
- 5-page first-run guide (Welcome → Manual Log → Smart Tracking → Reminders → Ready)
- Skippable at any time; re-openable from Settings → "Show guide again"
- Page-style `TabView` with dot indicators

### Changed
- Tab order: Today → Clients → Timer → Settings
- `TimerViewModel` hoisted to app-level `@Observable` environment
- Pomodoro settings in Settings immediately apply to the running `TimerViewModel`
- `ClientsView`: archived clients hidden by default; toolbar toggle to show/hide
- `QuickLogSheet`: `DatePicker` clamped to `...Date()` — no future entries
- `Project` delete rule changed from `.cascade` to `.nullify` — time entries survive project deletion
- `SettingsStore` midnight-safe load: uses `defaults.object != nil` check instead of `> 0`
- `KeychainHelper` returns `@discardableResult Bool`
- `Color+Hex.hex`: uses `resolvedColor(with:)` for reliable sRGB conversion
- `ActiveSession.elapsedMinutes` floor changed to `max(0,…)`
- Danger Zone deletes active sessions and cancels their notifications
- Day picker labels fixed: Tu / Th

### Fixed
- `Color+Hex.swift`: `NSColor(SwiftUI.Color)` unavailable on Mac Catalyst — guarded
- Widget extension: `platformFilter = ios` prevents Catalyst embed error
- App icon: added `AppIcon-512.png` (512×512) for macOS 1× slot
- `StopSessionSheet` minutes Picker replaced with Stepper — no mismatch on non-multiples-of-5 values
- `Timer` RunLoop mode changed to `.common` — no longer pauses during `List` scroll

---

## [0.0.1] — 2026-05-10

### Added
- Initial iOS app (iPhone + iPad)
- Today tab: daily time log with quick entry sheet, swipe-to-delete
- Timer tab: stopwatch mode and Pomodoro timer with animated ring progress
- Clients tab: client management with color coding, project sub-list, archive support
- Settings tab: Pomodoro intervals, weekly email export
- SwiftData persistence for `Client`, `Project`, `TimeEntry`
- `@Observable` MVVM architecture
