import SwiftUI
import SwiftData
import UserNotifications
import TimelogCore
import TimelogSync
import AppKit
import Sparkle

private struct RestSyncSetup: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var clients: [Client]
    @Query private var projects: [Project]
    @Query private var entries: [TimeEntry]
    @Query private var sessions: [ActiveSession]

    func body(content: Content) -> some View {
        content
            .onAppear {
                let container = modelContext.container
                RestSyncService.shared.loadConfigFromFile()
                RestSyncService.shared.storedContext = modelContext
                RestSyncService.shared.setDataProvider { [container] in
                    let ctx = container.mainContext
                    let clients  = (try? ctx.fetch(FetchDescriptor<Client>()))        ?? []
                    let projects = (try? ctx.fetch(FetchDescriptor<Project>()))       ?? []
                    let entries  = (try? ctx.fetch(FetchDescriptor<TimeEntry>()))     ?? []
                    let sessions = (try? ctx.fetch(FetchDescriptor<ActiveSession>())) ?? []
                    return (clients, projects, entries, sessions)
                }
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    RestSyncService.shared.triggerSync()
                    try? await RestSyncService.shared.pullAll(into: modelContext)
                }
                RestSyncService.shared.startListening()
            }
            .onDisappear {
                RestSyncService.shared.stopListening()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { try? await RestSyncService.shared.pullAll(into: modelContext) }
                }
            }
            .onChange(of: dataFingerprint) { _, _ in RestSyncService.shared.triggerSync() }
    }

    private var dataFingerprint: Int {
        SyncDataFingerprint.make(
            clients: clients,
            projects: projects,
            entries: entries,
            sessions: sessions
        )
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

final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var mainWindow: NSWindow?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let ctx = TimelogMacApp.container.mainContext
        let sessions = (try? ctx.fetch(FetchDescriptor<ActiveSession>())) ?? []
        guard !sessions.isEmpty else { return .terminateNow }

        let alert = NSAlert()
        alert.messageText = String(localized: "Tracking session in progress")
        alert.informativeText = String(localized: "quit_anyway_sessions_warning \(sessions.count)")
        alert.alertStyle = .warning
        alert.addButton(withTitle: String(localized: "Quit Anyway"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }
}

@main
struct TimelogMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var settings = SettingsStore()
    @State private var timerVM = TimerViewModel()
    @State private var versionChecker = VersionChecker()
    private let notificationDelegate = AppNotificationDelegate()
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    static let container: ModelContainer = {
        let schema = Schema([Client.self, Project.self, TimeEntry.self, ActiveSession.self])
        let config = ModelConfiguration("TimelogMac", schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // Corrupt or incompatible store: reset automatically.
            let url = config.url
            try? FileManager.default.removeItem(at: url)
            let base = url.deletingPathExtension()
            try? FileManager.default.removeItem(at: base.appendingPathExtension("store-shm"))
            try? FileManager.default.removeItem(at: base.appendingPathExtension("store-wal"))
            return try! ModelContainer(for: schema, configurations: config)
        }
    }()

    var body: some Scene {
        WindowGroup("Timelog", id: "main") {
            MainMacView()
                .onAppear {
                    UNUserNotificationCenter.current().delegate = notificationDelegate
                    timerVM.applySettings(settings)
                    NotificationManager.shared.requestPermission()
                    settings.applyReminders()
                    RestSyncService.shared.userId = settings.userId
                    versionChecker.startChecking()
                }
                .modifier(RestSyncSetup())
                .modifier(IdleAlertModifier())
                .modifier(EndOfDayAlertModifier())
                .environment(settings)
                .environment(timerVM)
                .environment(versionChecker)
        }
        .modelContainer(Self.container)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appInfo) {
                Button("About Timelog") {
                    AboutWindowController.shared.showWindow(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
                Button(String(localized: "Sync Now")) {
                    RestSyncService.shared.triggerSyncNow()
                }
                .keyboardShortcut("s", modifiers: .command)
            }
        }

        MenuBarExtra {
            MenuBarView()
                .environment(settings)
                .environment(timerVM)
        } label: {
            MenuBarStatusLabel(vm: timerVM, updateAvailable: versionChecker.updateAvailable)
                .onAppear { versionChecker.startChecking() }
        }
        .menuBarExtraStyle(.window)
        .modelContainer(Self.container)

        Settings {
            MacSettingsView()
                .environment(settings)
                .environment(timerVM)
                .environment(versionChecker)
        }
        .modelContainer(Self.container)
    }
}

private struct MenuBarStatusLabel: View {
    let vm: TimerViewModel
    let updateAvailable: Bool

    private var iconName: String {
        guard vm.isRunning || vm.elapsed > 0 else { return "clock" }
        guard vm.pomodoroEnabled else { return "stopwatch" }
        switch vm.phase {
        case .work:       return "flame.fill"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak:  return "figure.walk"
        }
    }

    private var iconColor: Color {
        guard vm.isRunning else { return .secondary }
        guard vm.pomodoroEnabled else { return .orange }
        switch vm.phase {
        case .work:       return .red
        case .shortBreak: return .green
        case .longBreak:  return .blue
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                if updateAvailable {
                    Circle()
                        .fill(.orange)
                        .frame(width: 5, height: 5)
                        .offset(x: 3, y: -3)
                }
            }
            if vm.isRunning || vm.elapsed > 0 {
                Text(vm.displayTime)
                    .monospacedDigit()
                    .foregroundStyle(iconColor)
            }
        }
    }
}
