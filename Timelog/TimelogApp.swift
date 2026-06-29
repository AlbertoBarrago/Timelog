import SwiftUI
import SwiftData
import TimelogCore
import TimelogSync
import UIKit
import UserNotifications

private struct RestSyncSetup: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SettingsStore.self) private var settings
    @Query private var clients:  [Client]
    @Query private var projects: [Project]
    @Query private var entries:  [TimeEntry]
    @Query private var sessions: [ActiveSession]
    @Query private var dayReviews: [DayReview]
    @State private var isPulling = false

    func body(content: Content) -> some View {
        content
            .onAppear { setup() }
            .onDisappear { RestSyncService.shared.stopListening() }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    // Re-open SSE stream if it was dropped while in background, then
                    // do a catch-up pull for any changes missed while disconnected.
                    RestSyncService.shared.startListening()
                    pullLatest()
                case .background:
                    // iOS suspends network connections in the background — stop cleanly.
                    RestSyncService.shared.stopListening()
                default:
                    break
                }
            }
            .onChange(of: dataFingerprint) { _, _ in
                if !isPulling { RestSyncService.shared.triggerSync() }
            }
    }

    private func pullLatest() {
        guard RestSyncService.shared.isConfigured, !isPulling else { return }
        isPulling = true
        let ctx = modelContext
        Task {
            try? await RestSyncService.shared.pullAll(into: ctx)
            isPulling = false
        }
    }

    private func setup() {
        RestSyncService.shared.userId = settings.userId
        RestSyncService.shared.loadConfigFromFile()
        RestSyncService.shared.storedContext = modelContext
        let container = modelContext.container
        RestSyncService.shared.setDataProvider { [container] in
            let ctx = container.mainContext
            return (
                (try? ctx.fetch(FetchDescriptor<Client>())) ?? [],
                (try? ctx.fetch(FetchDescriptor<Project>())) ?? [],
                (try? ctx.fetch(FetchDescriptor<TimeEntry>())) ?? [],
                (try? ctx.fetch(FetchDescriptor<ActiveSession>())) ?? [],
                (try? ctx.fetch(FetchDescriptor<DayReview>())) ?? []
            )
        }
        guard RestSyncService.shared.isConfigured else { return }
        isPulling = true
        Task {
            try? await RestSyncService.shared.pullAll(into: modelContext)
            isPulling = false
            RestSyncService.shared.startListening()
        }
    }

    private var dataFingerprint: Int {
        SyncDataFingerprint.make(
            clients: clients,
            projects: projects,
            entries: entries,
            sessions: sessions,
            dayReviews: dayReviews
        )
    }
}


// MARK: - Sync flash overlay

private struct SyncFlashOverlay: ViewModifier {
    @State private var flash = false
    private var syncDate: Date? { RestSyncService.shared.lastSyncDate }

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.green.opacity(flash ? 0.18 : 0))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .animation(.easeOut(duration: 0.5), value: flash)
            )
            .onChange(of: RestSyncService.shared.lastSyncDate) { _, _ in
                #if os(iOS)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                #endif
                flash = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { flash = false }
            }
    }
}

private final class ForegroundNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }
}

private struct IdleAlertModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SettingsStore.self) private var settings
    @Query private var sessions: [ActiveSession]

    func body(content: Content) -> some View {
        content
            .onAppear { updateAlert() }
            .onChange(of: sessions.count) { _, _ in updateAlert() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { updateAlert() } }
            .onChange(of: settings.idleAlertEnabled) { _, _ in updateAlert() }
            .onChange(of: settings.idleAlertMinutes) { _, _ in updateAlert() }
    }

    private func updateAlert() {
        if !settings.idleAlertEnabled || !sessions.isEmpty {
            NotificationManager.shared.cancelIdleAlert()
        } else {
            NotificationManager.shared.scheduleIdleAlert(afterMinutes: settings.idleAlertMinutes)
        }
    }
}

private struct EndOfDayAlertModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SettingsStore.self) private var settings
    @Query(sort: \TimeEntry.date, order: .reverse) private var entries: [TimeEntry]

    func body(content: Content) -> some View {
        content
            .onAppear { updateAlert() }
            .onChange(of: entries.count) { _, _ in updateAlert() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { updateAlert() } }
            .onChange(of: settings.missingHoursAlertEnabled) { _, _ in updateAlert() }
            .onChange(of: settings.trackingEndHour) { _, _ in updateAlert() }
            .onChange(of: settings.trackingEndMinute) { _, _ in updateAlert() }
    }

    private func updateAlert() {
        guard settings.missingHoursAlertEnabled else {
            NotificationManager.shared.cancelMissingHoursAlert()
            return
        }
        let todayStart = Calendar.current.startOfDay(for: Date())
        let hasEntriesForToday = entries.contains { $0.date >= todayStart && $0.deletedAt == nil }
        if hasEntriesForToday {
            NotificationManager.shared.cancelMissingHoursAlert()
        } else {
            NotificationManager.shared.scheduleMissingHoursAlert(
                endHour: settings.trackingEndHour,
                endMinute: settings.trackingEndMinute
            )
        }
    }
}

@main
struct TimelogApp: App {
    @State private var settings  = SettingsStore()
    @State private var timerVM   = TimerViewModel()
    @State private var showSplash = true
    @State private var notificationDelegate = ForegroundNotificationDelegate()

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .onAppear {
                        UNUserNotificationCenter.current().delegate = notificationDelegate
                        timerVM.applySettings(settings)
                        NotificationManager.shared.requestPermission()
                        settings.applyReminders()
                    }
                    .modifier(RestSyncSetup())
                    .modifier(SyncFlashOverlay())
                    .modifier(IdleAlertModifier())
                    .modifier(EndOfDayAlertModifier())

                if showSplash {
                    SplashView(isShowing: $showSplash)
                }
            }
            .environment(settings)
            .environment(timerVM)
        }
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self, ActiveSession.self, DayReview.self])
    }
}
