import SwiftUI
import SwiftData
import TimelogCore
import UIKit
import UserNotifications

private final class ForegroundNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        return [.banner, .sound]
    }
}

private struct IdleAlertModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SettingsStore.self) private var settings
    @Query(filter: #Predicate<ActiveSession> { $0.deletedAt == nil }) private var sessions: [ActiveSession]

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
                    .modifier(IdleAlertModifier())
                    .modifier(EndOfDayAlertModifier())
                    .onReceive(NotificationCenter.default.publisher(
                        for: UIApplication.willTerminateNotification)) { _ in
                        // Pending requests would still fire with the app closed.
                        NotificationManager.shared.cancelAllPending()
                    }

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
