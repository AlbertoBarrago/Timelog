import TimelogCore
import TimelogSync
import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(SettingsStore.self) private var store
    @Environment(TimerViewModel.self) private var timerVM
    @Query(sort: \TimeEntry.date, order: .reverse) private var entries: [TimeEntry]
    @Query private var activeSessions: [ActiveSession]
    @AppStorage("onboarding_completed") private var onboardingCompleted = true
    @State private var showDeleteConfirm = false

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section("Pomodoro") {
                    Stepper("Focus: \(store.pomodoroWork) min", value: $store.pomodoroWork, in: 1...90)
                        .onChange(of: store.pomodoroWork) { timerVM.applySettings(store) }
                    Stepper("Short break: \(store.pomodoroShortBreak) min", value: $store.pomodoroShortBreak, in: 1...30)
                        .onChange(of: store.pomodoroShortBreak) { timerVM.applySettings(store) }
                    Stepper("Long break: \(store.pomodoroLongBreak) min", value: $store.pomodoroLongBreak, in: 1...60)
                        .onChange(of: store.pomodoroLongBreak) { timerVM.applySettings(store) }
                }

                Section {
                    Toggle("Auto-advance phases", isOn: $store.pomodoroAutoAdvance)
                        .onChange(of: store.pomodoroAutoAdvance) { timerVM.applySettings(store) }
                    Toggle("Sound effects", isOn: $store.pomodoroSoundEnabled)
                        .onChange(of: store.pomodoroSoundEnabled) { timerVM.applySettings(store) }
                } footer: {
                    Text("Auto-advance: when a phase ends the next one starts automatically, no input needed.\nSound effects: plays a chime at each phase transition.")
                }

                Section {
                    Toggle("Daily reminder", isOn: $store.reminderEnabled)
                    if store.reminderEnabled {
                        DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Days")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            DayPicker(selectedDays: $store.reminderDays)
                        }
                    }
                } header: { Text("Reminders") }

                Section {
                    DatePicker("Notify if still open at", selection: trackingEndTime, displayedComponents: .hourAndMinute)
                    Toggle("Alert when idle", isOn: $store.idleAlertEnabled)
                    if store.idleAlertEnabled {
                        Stepper("After \(store.idleAlertMinutes) min", value: $store.idleAlertMinutes, in: 1...120)
                    }
                    Toggle("Alert if no hours logged", isOn: $store.missingHoursAlertEnabled)
                } header: {
                    Text("Smart Tracking")
                } footer: {
                    Text("You'll receive a notification if a session is still running at this time, if you have no active session after the idle threshold, or if no hours have been logged for the day by closing time.")
                }

                Section {
                    Button("Sync Now") {
                        Task { try? await RestSyncService.shared.pullAll(into: context) }
                    }
                    .disabled(!RestSyncService.shared.isConfigured)
                    RestSyncStatusRow()
                } header: {
                    Text("Sync")
                }

                Section("Export") {
                    Button("Export this week via Email") { exportEmail() }
                }

                Section {
                    Toggle("Show History tab", isOn: $store.showHistory)
                } header: {
                    Text("Navigation")
                } footer: {
                    Text("When enabled, a History tab appears in the tab bar for quick access to past entries.")
                }

                Section {
                    Button("Show guide again") { onboardingCompleted = false }
                }

                Section("Account") {
                    NicknameRevealRow(nickname: store.userId)
                }

                Section("About") {
                    LabeledContent("Developer") {
                        Link("Alberto Barrago", destination: URL(string: "https://github.com/AlbertoBarrago")!)
                    }
                    LabeledContent("Version") {
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    }
                }

                Section("Danger Zone") {
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
                            for e in entries { context.delete(e) }
                            for s in activeSessions {
                                NotificationManager.shared.cancelSession(id: s.notificationID)
                                context.delete(s)
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently delete all time entries and active sessions. This action cannot be undone.")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbar {
                #if targetEnvironment(macCatalyst)
                ToolbarItem(placement: .secondaryAction) {
                    TimerQuickToggle()
                }
                #endif
            }
        }
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                c.hour = store.reminderHour; c.minute = store.reminderMinute
                return Calendar.current.date(from: c) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                store.reminderHour = c.hour ?? 17
                store.reminderMinute = c.minute ?? 0
            }
        )
    }

    private var trackingEndTime: Binding<Date> {
        Binding(
            get: {
                var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                c.hour = store.trackingEndHour; c.minute = store.trackingEndMinute
                return Calendar.current.date(from: c) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                store.trackingEndHour = c.hour ?? 18
                store.trackingEndMinute = c.minute ?? 0
            }
        )
    }

    private func exportEmail() {
        let cal = Calendar.current
        let now = Date()
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let weekEntries = entries.filter { $0.date >= weekStart }

        var lines = [String(localized: "Timelog — Week of") + " \(weekStart.formatted(date: .abbreviated, time: .omitted))", ""]
        for entry in weekEntries.sorted(by: { $0.date < $1.date }) {
            let dateStr = entry.date.formatted(date: .abbreviated, time: .omitted)
            let dur = entry.durationMinutes.formattedDuration
            let client = entry.client?.name ?? "—"
            let project = entry.project?.name ?? "—"
            let notes = entry.notes.map { " — \($0)" } ?? ""
            lines.append("[\(dateStr)] \(client) / \(project): \(dur)\(notes)")
        }
        let total = weekEntries.reduce(0) { $0 + $1.durationMinutes }
        lines += ["", String(localized: "Total:") + " \(total.formattedDuration)"]

        let body = lines.joined(separator: "\n")
        let subject = String(localized: "Timelog Week Export")
        let mailto = "mailto:?subject=\(subject.urlEncoded)&body=\(body.urlEncoded)"
        if let url = URL(string: mailto) { openURL(url) }
    }
}

private struct RestSyncStatusRow: View {
    private var sync: RestSyncService { RestSyncService.shared }

    var body: some View {
        if sync.isSyncing {
            Label("Syncing…", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption).foregroundStyle(.secondary)
        } else if let error = sync.lastError {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.caption).foregroundStyle(.red)
        } else if let date = sync.lastSyncDate {
            Label("Last sync: \(date.formatted(date: .omitted, time: .shortened))",
                  systemImage: "checkmark.circle")
                .font(.caption).foregroundStyle(.green)
        }
        if let url = sync.readServerURL() {
            Text(url)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
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

private struct DayPicker: View {
    @Binding var selectedDays: Set<Int>

    private let days: [(label: String, index: Int)] = [
        ("M", 2), ("Tu", 3), ("W", 4), ("Th", 5), ("F", 6), ("Sa", 7), ("Su", 1)
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days, id: \.index) { day in
                let selected = selectedDays.contains(day.index)
                Button {
                    if selected { selectedDays.remove(day.index) }
                    else { selectedDays.insert(day.index) }
                } label: {
                    Text(LocalizedStringKey(day.label))
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(selected ? Color.accentColor : Color.secondary.opacity(0.15), in: Circle())
                        .foregroundStyle(selected ? .white : .primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(fullDayName(for: day.label))
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
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

private extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
