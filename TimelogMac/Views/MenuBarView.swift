import SwiftUI
import SwiftData
import TimelogCore
import TimelogSync
import AppKit

struct MenuBarView: View {
    @Environment(TimerViewModel.self) private var timerVM
    @Environment(SettingsStore.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \ActiveSession.startDate) private var allSessions: [ActiveSession]
    @Query(filter: #Predicate<TimeEntry> { $0.deletedAt == nil }, sort: \TimeEntry.date, order: .reverse) private var allEntries: [TimeEntry]
    @Query(filter: #Predicate<Client> { !$0.isArchived && $0.deletedAt == nil }, sort: \Client.name) private var allClients: [Client]

    @State private var showingStartTracking = false
    @State private var sessionToStop: ActiveSession?

    private var activeSessions: [ActiveSession] { allSessions.filter { $0.userId == settings.userId } }
    private var clients: [Client] { allClients.filter { $0.userId == settings.userId } }
    private var todayMinutes: Int {
        let logged = allEntries.filter { $0.userId == settings.userId && Calendar.current.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.durationMinutes }
        return logged + activeSessions.reduce(0) { $0 + $1.elapsedMinutes }
    }

    var body: some View {
        VStack(spacing: 0) {
            CompactTimerRow(vm: timerVM)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            if showingStartTracking {
                StartTrackingMacView(onDismiss: { showingStartTracking = false })
                    .environment(settings)
            } else if let session = sessionToStop {
                StopSessionMacView(session: session, onDismiss: { sessionToStop = nil })
                    .background(Color(nsColor: .windowBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
                    .padding(8)
            } else {
                // Active sessions
                if !activeSessions.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Label("Active", systemImage: "record.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 12)
                            .padding(.top, 8)
                            .padding(.bottom, 4)

                        TimelineView(.periodic(from: .now, by: 1)) { tl in
                            ForEach(activeSessions) { session in
                                MenuSessionRow(session: session, now: tl.date) {
                                    sessionToStop = session
                                } onDiscard: {
                                    NotificationManager.shared.cancelSession(id: session.notificationID)
                                    context.delete(session)
                                    try? context.save()
                                    RestSyncService.shared.triggerSyncNow()
                                }
                            }
                        }
                    }
                    Divider()
                }

                // Footer
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Today").font(.caption2).foregroundStyle(.secondary)
                        TimelineView(.periodic(from: .now, by: 60)) { _ in
                            Text(todayMinutes.formattedDuration)
                                .font(.caption.weight(.semibold)).monospacedDigit()
                        }
                    }
                    Spacer()
                    Button { showingStartTracking = true } label: {
                        Label("Track", systemImage: "play.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        if let window = AppDelegate.mainWindow {
                            if window.isVisible {
                                window.orderOut(nil)
                            } else {
                                window.makeKeyAndOrderFront(nil)
                                NSApp.activate(ignoringOtherApps: true)
                            }
                        } else {
                            openWindow(id: "main")
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    } label: {
                        Image(systemName: "arrow.up.forward.app")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(String(localized: "Show/hide Timelog window"))
                    .accessibilityLabel(String(localized: "Toggle Timelog window"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .frame(width: 300)
    }
}

private struct CompactTimerRow: View {
    @Bindable var vm: TimerViewModel
    @State private var showModeChangeConfirm = false
    @State private var pendingPomodoroEnabled = false

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(vm.pomodoroEnabled ? LocalizedStringKey(vm.phase.label) : "Stopwatch")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text(vm.displayTime)
                        .font(.system(size: 22, weight: .light, design: .monospaced))
                        .monospacedDigit()
                }
                Spacer()
                Toggle(isOn: Binding(
                    get: { vm.pomodoroEnabled },
                    set: { newValue in
                        if vm.elapsed > 0 || vm.isRunning {
                            pendingPomodoroEnabled = newValue
                            showModeChangeConfirm = true
                        } else {
                            vm.pomodoroEnabled = newValue
                            vm.reset()
                        }
                    }
                )) {
                    Image(systemName: "timer")
                }
                .toggleStyle(.button)
                .controlSize(.small)
                .accessibilityLabel(String(localized: "Pomodoro mode"))

                Button { vm.reset() } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(!vm.isRunning && vm.elapsed == 0)
                .accessibilityLabel(String(localized: "Reset timer"))

                Button { vm.toggle() } label: {
                    Image(systemName: vm.isRunning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.space, modifiers: [])
                .accessibilityLabel(vm.isRunning ? String(localized: "Pause timer") : String(localized: "Start timer"))
            }

            if showModeChangeConfirm {
                HStack(spacing: 8) {
                    Text(String(localized: "Timer will be reset."))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(String(localized: "Cancel")) {
                        showModeChangeConfirm = false
                    }
                    .controlSize(.small)
                    Button(String(localized: "Reset & switch")) {
                        vm.pomodoroEnabled = pendingPomodoroEnabled
                        vm.reset()
                        showModeChangeConfirm = false
                    }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityLabel(String(localized: "Confirm mode switch"))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: showModeChangeConfirm)
    }
}

private struct MenuSessionRow: View {
    let session: ActiveSession
    var now: Date = .now
    let onStop: () -> Void
    let onDiscard: () -> Void

    private var elapsedDisplay: String {
        let s = Int(now.timeIntervalSince(session.startDate))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%02d:%02d", m, sec)
    }

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(session.client?.color ?? .accentColor)
                .frame(width: 3, height: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(session.client?.name ?? "No client")
                    .font(.caption.weight(.semibold)).lineLimit(1)
                if let proj = session.project {
                    Text(proj.name).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Text(elapsedDisplay)
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .foregroundStyle(.tint).monospacedDigit()
            Button(action: onStop) {
                Image(systemName: "stop.circle.fill").foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help(String(localized: "Stop and log"))
            .accessibilityLabel(String(localized: "Stop and log session"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .contextMenu {
            Button("Stop & Log", action: onStop)
            Divider()
            Button("Discard", role: .destructive, action: onDiscard)
        }
    }
}
