import SwiftUI
import SwiftData
import TimelogCore
import TimelogSync

struct MacSettingsView: View {
    @Environment(SettingsStore.self) private var store
    @Environment(TimerViewModel.self) private var timerVM
    @Environment(VersionChecker.self) private var versionChecker
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TimeEntry.date, order: .reverse) private var entries: [TimeEntry]
    @Query private var activeSessions: [ActiveSession]
    @State private var showDeleteConfirm = false

    var body: some View {
        @Bindable var store = store
        Form {
            // MARK: Pomodoro
            Section("Pomodoro") {
                Stepper("Focus: \(store.pomodoroWork) min",
                        value: $store.pomodoroWork, in: 1...90)
                    .onChange(of: store.pomodoroWork) { timerVM.applySettings(store) }
                Stepper("Short break: \(store.pomodoroShortBreak) min",
                        value: $store.pomodoroShortBreak, in: 1...30)
                    .onChange(of: store.pomodoroShortBreak) { timerVM.applySettings(store) }
                Stepper("Long break: \(store.pomodoroLongBreak) min",
                        value: $store.pomodoroLongBreak, in: 1...60)
                    .onChange(of: store.pomodoroLongBreak) { timerVM.applySettings(store) }
            }

            Section {
                Toggle(String(localized: "Auto-advance phases"), isOn: $store.pomodoroAutoAdvance)
                    .onChange(of: store.pomodoroAutoAdvance) { timerVM.applySettings(store) }
                Toggle(String(localized: "Sound effects"), isOn: $store.pomodoroSoundEnabled)
                    .onChange(of: store.pomodoroSoundEnabled) { timerVM.applySettings(store) }
            } footer: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-advance: when a phase ends the next one starts automatically, no input needed.")
                    Text("Sound effects: plays a chime at each phase transition.")
                }
            }

            // MARK: Reminders
            Section {
                Toggle("Daily reminder", isOn: $store.reminderEnabled)
                if store.reminderEnabled {
                    DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Days").font(.caption).foregroundStyle(.secondary)
                        DayPickerMac(selectedDays: $store.reminderDays)
                    }
                }
            } header: { Text("Reminders") }

            // MARK: Smart Tracking
            Section {
                DatePicker("Notify if still open at",
                           selection: trackingEndTime,
                           displayedComponents: .hourAndMinute)
                Toggle("Alert when idle", isOn: $store.idleAlertEnabled)
                if store.idleAlertEnabled {
                    Stepper("After \(store.idleAlertMinutes) min", value: $store.idleAlertMinutes, in: 1...120)
                }
                Toggle("Alert if no hours logged", isOn: $store.missingHoursAlertEnabled)
            } header: {
                Text("Smart Tracking")
            } footer: {
                Text("Sends a notification if a session is still running at this time, if you have no active session after the idle threshold, or if no hours have been logged for the day by closing time.")
            }

            // MARK: Work Schedule
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Working days").font(.caption).foregroundStyle(.secondary)
                    DayPickerMac(selectedDays: $store.workingDays)
                }
            } header: {
                Text("Work Schedule")
            } footer: {
                Text("Days you normally work. Used by analytics to exclude weekends from productivity baselines.")
            }

            // MARK: Sync — native macOS layout
            Section {
                HStack(spacing: 10) {
                    SyncStatusDotSettings()
                    Spacer()
                    Button("Sync Now") {
                        RestSyncService.shared.triggerSync()
                    }
                    .controlSize(.small)
                    .disabled(!RestSyncService.shared.isConfigured)

                    Divider().frame(height: 16)

                    Button("Reset & Pull") {
                        Task {
                            try? await RestSyncService.shared.pullAll(into: modelContext)
                            RestSyncService.shared.triggerSync()
                        }
                    }
                    .controlSize(.small)
                    .foregroundStyle(.orange)
                    .disabled(!RestSyncService.shared.isConfigured)
                }
            } header: {
                Text("Sync")
            } footer: {
                Text("Reset & Pull re-downloads all data from the server.")
            }

            // MARK: History
            Section {
                Picker(String(localized: "History chart style"), selection: $store.historyChartStyle) {
                    Text("Donut").tag(HistoryChartStyle.donut)
                    Text("Heatmap").tag(HistoryChartStyle.heatmap)
                }
            } header: {
                Text("History")
            } footer: {
                Text("Donut shows hours by project; Heatmap shows a GitHub-style activity grid coloured by the day's main client.")
            }

            // MARK: Export
            Section("Export") {
                Button("Export this week via Email") { exportEmail() }
                    .buttonStyle(.link)
            }

            // MARK: Account
            Section("Account") {
                NicknameRevealRow(nickname: store.userId)
            }

            // MARK: About
            Section("About") {
                LabeledContent("Developer") {
                    Link("Alberto Barrago", destination: URL(string: "https://github.com/AlbertoBarrago")!)
                }
                LabeledContent("Version") {
                    HStack(spacing: 6) {
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                        if versionChecker.updateAvailable {
                            Text(String(localized: "Update available"))
                                .font(.caption)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(.orange.opacity(0.15), in: Capsule())
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }

            // MARK: Support
            Section {
                BuyMeCoffeeCard()
            } header: {
                Text("Support")
            }

            // MARK: Danger Zone
            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete all entries", systemImage: "flame.fill")
                        .foregroundStyle(.red)
                }
                .confirmationDialog("Delete all entries?",
                                    isPresented: $showDeleteConfirm,
                                    titleVisibility: .visible) {
                    Button("Delete all", role: .destructive) {
                        for e in entries { modelContext.delete(e) }
                        for s in activeSessions {
                            NotificationManager.shared.cancelSession(id: s.notificationID)
                            modelContext.delete(s)
                        }
                        try? modelContext.save()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently delete all time entries and active sessions. This action cannot be undone.")
                }
            } header: {
                Text("Danger Zone")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .frame(minWidth: 400, maxWidth: 520)
    }

    // MARK: - Helpers

    private func exportEmail() {
        let cal = Calendar.current
        let now = Date()
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let weekEntries = entries.filter { $0.date >= weekStart }

        var lines = [String(localized: "Timelog — Week of") + " \(weekStart.formatted(date: .abbreviated, time: .omitted))", ""]
        for entry in weekEntries.sorted(by: { $0.date < $1.date }) {
            let dateStr = entry.date.formatted(date: .abbreviated, time: .omitted)
            let dur     = entry.durationMinutes.formattedDuration
            let client  = entry.client?.name ?? "—"
            let project = entry.project?.name ?? "—"
            let notes   = entry.notes.map { " — \($0)" } ?? ""
            lines.append("[\(dateStr)] \(client) / \(project): \(dur)\(notes)")
        }
        let total = weekEntries.reduce(0) { $0 + $1.durationMinutes }
        lines += ["", String(localized: "Total:") + " \(total.formattedDuration)"]

        let body    = lines.joined(separator: "\n")
        let subject = String(localized: "Timelog Week Export")
        let mailto  = "mailto:?subject=\(subject.urlEncoded)&body=\(body.urlEncoded)"
        if let url = URL(string: mailto) { openURL(url) }
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                var c = Calendar.current.dateComponents([.year, .month, .day], from: .now)
                c.hour = store.reminderHour; c.minute = store.reminderMinute
                return Calendar.current.date(from: c) ?? .now
            },
            set: {
                let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                store.reminderHour   = c.hour   ?? 17
                store.reminderMinute = c.minute ?? 0
            }
        )
    }

    private var trackingEndTime: Binding<Date> {
        Binding(
            get: {
                var c = Calendar.current.dateComponents([.year, .month, .day], from: .now)
                c.hour = store.trackingEndHour; c.minute = store.trackingEndMinute
                return Calendar.current.date(from: c) ?? .now
            },
            set: {
                let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                store.trackingEndHour   = c.hour   ?? 18
                store.trackingEndMinute = c.minute ?? 0
            }
        )
    }
}

// MARK: - Private helpers

private extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}

private struct BuyMeCoffeeCard: View {
    @Environment(\.openURL) private var openURL
    @State private var isHovered = false

    var body: some View {
        Button {
            openURL(URL(string: "https://buymeacoffee.com/albz")!)
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text("$").foregroundStyle(.green.opacity(0.8))
                    Text("brew install --formula gratitude")
                        .foregroundStyle(.primary.opacity(0.85))
                }
                HStack(spacing: 6) {
                    Text("✔").foregroundStyle(.green)
                    Text("Timelog is free. Coffee is optional.")
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    Text("→").foregroundStyle(.secondary)
                    Text("buymeacoffee.com/albz")
                        .foregroundStyle(isHovered ? Color.accentColor : .secondary)
                        .underline(isHovered)
                }
            }
            .font(.system(.footnote, design: .monospaced))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(.background.secondary)
                    .overlay(RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(.separator, lineWidth: 0.5))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel("Buy me a coffee at buymeacoffee.com/albz")
    }
}

private struct NicknameRevealRow: View {
    let nickname: String
    @State private var revealed = false
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        LabeledContent("Nickname") {
            HStack(spacing: 8) {
                Text(revealed ? nickname : String(repeating: "•", count: max(nickname.count, 4)))
                    .foregroundStyle(revealed ? .primary : .secondary)
                    .animation(.easeInOut(duration: 0.15), value: revealed)
                Button {
                    reveal()
                } label: {
                    Image(systemName: revealed ? "eye.slash" : "eye")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(revealed ? String(localized: "Hide nickname") : String(localized: "Show nickname"))
            }
        }
    }

    private func reveal() {
        hideTask?.cancel()
        revealed = true
        hideTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            revealed = false
        }
    }
}

private struct SyncStatusDotSettings: View {
    private var sync: RestSyncService { RestSyncService.shared }
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                if sync.isSyncing {
                    Circle()
                        .fill(Color.yellow.opacity(0.25))
                        .frame(width: 14, height: 14)
                        .scaleEffect(pulse ? 1.6 : 1.0)
                        .opacity(pulse ? 0 : 1)
                        .animation(.easeOut(duration: 1.1).repeatForever(autoreverses: false), value: pulse)
                }
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
            }
            Text(statusText)
                .font(.callout)
                .foregroundStyle(textColor)
        }
        .onAppear { pulse = true }
    }

    private var dotColor: Color {
        if sync.isSyncing           { return .yellow }
        if sync.lastError != nil    { return .red }
        if sync.lastSyncDate != nil { return .green }
        return Color.secondary.opacity(0.4)
    }

    private var textColor: Color { sync.lastError != nil ? .red : .secondary }

    private var statusText: String {
        if sync.isSyncing           { return "Syncing…" }
        if let e = sync.lastError   { return e }
        if let d = sync.lastSyncDate {
            return "Last sync \(d.formatted(.relative(presentation: .named)))"
        }
        return "Not connected"
    }
}

private struct DayPickerMac: View {
    @Binding var selectedDays: Set<Int>

    private let days: [(label: String, index: Int)] = [
        ("M", 2), ("Tu", 3), ("W", 4), ("Th", 5), ("F", 6), ("Sa", 7), ("Su", 1)
    ]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days, id: \.index) { day in
                let on = selectedDays.contains(day.index)
                Button {
                    if on { selectedDays.remove(day.index) }
                    else  { selectedDays.insert(day.index) }
                } label: {
                    Text(LocalizedStringKey(day.label))
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .background(on ? Color.accentColor : Color.secondary.opacity(0.12), in: Circle())
                        .foregroundStyle(on ? .white : .primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(fullDayName(for: day.label))
                .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private func fullDayName(for label: String) -> String {
        switch label {
        case "M":  return String(localized: "Monday")
        case "Tu": return String(localized: "Tuesday")
        case "W":  return String(localized: "Wednesday")
        case "Th": return String(localized: "Thursday")
        case "F":  return String(localized: "Friday")
        case "Sa": return String(localized: "Saturday")
        case "Su": return String(localized: "Sunday")
        default:   return label
        }
    }
}
