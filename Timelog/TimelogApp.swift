import SwiftUI
import SwiftData
import TimelogCore
import TimelogSync
import UIKit
import UserNotifications

private struct RestSyncSetup: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Environment(SettingsStore.self) private var settings
    @Query private var clients:  [Client]
    @Query private var projects: [Project]
    @Query private var entries:  [TimeEntry]
    @Query private var sessions: [ActiveSession]
    @State private var isPulling = false

    func body(content: Content) -> some View {
        content
            .onAppear { setup() }
            .onChange(of: clients.count)  { _, _ in if !isPulling { RestSyncService.shared.triggerSync() } }
            .onChange(of: projects.count) { _, _ in if !isPulling { RestSyncService.shared.triggerSync() } }
            .onChange(of: entries.count)  { _, _ in if !isPulling { RestSyncService.shared.triggerSync() } }
            .onChange(of: sessions.count) { _, _ in if !isPulling { RestSyncService.shared.triggerSync() } }
    }

    private func setup() {
        RestSyncService.shared.userId = settings.userId
        RestSyncService.shared.loadConfigFromFile()
        let container = modelContext.container
        RestSyncService.shared.setDataProvider { [container] in
            let ctx = container.mainContext
            return (
                (try? ctx.fetch(FetchDescriptor<Client>())) ?? [],
                (try? ctx.fetch(FetchDescriptor<Project>())) ?? [],
                (try? ctx.fetch(FetchDescriptor<TimeEntry>())) ?? [],
                (try? ctx.fetch(FetchDescriptor<ActiveSession>())) ?? []
            )
        }
        guard RestSyncService.shared.isConfigured else { return }
        Task {
            isPulling = true
            try? await RestSyncService.shared.pullAll(into: modelContext)
            isPulling = false
        }
    }
}

// MARK: - Widget pending start handler

private struct PendingStartModifier: ViewModifier {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SettingsStore.self) private var settings
    @Query(filter: #Predicate<Project> { $0.deletedAt == nil }) private var allProjects: [Project]

    func body(content: Content) -> some View {
        content.onChange(of: scenePhase) { _, phase in
            if phase == .active { handlePendingStart() }
        }
    }

    private func handlePendingStart() {
        guard let mongoId = WidgetSnapshotStore.consumePendingStart() else { return }
        guard let project = allProjects.first(where: { $0.mongoId == mongoId }) else { return }
        let session = ActiveSession(
            client: project.client,
            project: project,
            userId: settings.userId
        )
        context.insert(session)
        NotificationManager.shared.scheduleSessionOverdue(
            id: session.notificationID,
            clientName: project.client?.name ?? "a project",
            projectName: project.name,
            startDate: session.startDate,
            endHour: settings.trackingEndHour,
            endMinute: settings.trackingEndMinute
        )
        try? context.save()
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
                UINotificationFeedbackGenerator().notificationOccurred(.success)
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
                    .modifier(PendingStartModifier())

                if showSplash {
                    SplashView(isShowing: $showSplash)
                }
            }
            .environment(settings)
            .environment(timerVM)
        }
        .modelContainer(for: [Client.self, Project.self, TimeEntry.self, ActiveSession.self])
    }
}
