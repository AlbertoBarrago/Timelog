import SwiftUI
import SwiftData
import UserNotifications
import TimelogCore
import TimelogSync
import AppKit

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
                    try? await RestSyncService.shared.pullAll(into: modelContext)
                    RestSyncService.shared.triggerSync()
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
        clients.count &+ projects.count &+ entries.count &+ sessions.count
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
    private let notificationDelegate = AppNotificationDelegate()

    static let container: ModelContainer = {
        let schema = Schema([Client.self, Project.self, TimeEntry.self, ActiveSession.self])
        let config = ModelConfiguration("TimelogMac", schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // Store corrotto o incompatibile — reset automatico
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
                }
                .modifier(RestSyncSetup())
                .modifier(IdleAlertModifier())
                .environment(settings)
                .environment(timerVM)
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
            MenuBarStatusLabel(vm: timerVM)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(Self.container)

        Settings {
            MacSettingsView()
                .environment(settings)
                .environment(timerVM)
        }
        .modelContainer(Self.container)
    }
}

private struct MenuBarStatusLabel: View {
    let vm: TimerViewModel

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
        if vm.isRunning || vm.elapsed > 0 {
            Label(vm.displayTime, systemImage: iconName)
                .monospacedDigit()
                .foregroundStyle(iconColor)
        } else {
            Label("Timelog", systemImage: "clock")
        }
    }
}
