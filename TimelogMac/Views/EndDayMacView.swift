import SwiftUI
import SwiftData
import TimelogCore
import TimelogSync

private enum EndDayMood: String, CaseIterable, Identifiable {
    case ok = "Ok"
    case intense = "Tirata"
    case rough = "Giornata di merda"
    case miracle = "Ho fatto miracoli"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .ok: "checkmark.circle"
        case .intense: "bolt.circle"
        case .rough: "exclamationmark.circle"
        case .miracle: "sparkles"
        }
    }
}

struct EndDayMacView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings

    @Query(sort: \ActiveSession.startDate) private var allSessions: [ActiveSession]
    @Query(filter: #Predicate<TimeEntry> { $0.deletedAt == nil }, sort: \TimeEntry.date, order: .reverse) private var allEntries: [TimeEntry]

    let endHour: Int
    let endMinute: Int

    @State private var selectedMood: EndDayMood = .ok
    @State private var note = ""

    private var activeSessions: [ActiveSession] {
        allSessions.filter { $0.userId == settings.userId }
    }

    private var todayEntries: [TimeEntry] {
        allEntries.filter { $0.userId == settings.userId && Calendar.current.isDateInToday($0.date) }
    }

    private var todayTotal: Int {
        todayEntries.reduce(0) { $0 + $1.durationMinutes }
        + activeSessions.reduce(0) { $0 + $1.cappedElapsedMinutes(endHour: endHour, endMinute: endMinute) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Per oggi basta")
                    .font(.headline)
                Text(todayTotal > 0 ? "Hai messo insieme \(todayTotal.formattedDuration)." : "Non c'e ancora tempo registrato oggi.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !activeSessions.isEmpty {
                GroupBox("Sessioni da chiudere") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(activeSessions) { session in
                            sessionRow(session)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                GroupBox("Chiusura") {
                    Text(todayEntries.isEmpty
                         ? "Niente da chiudere o annotare per oggi."
                         : "Non ci sono sessioni attive. La chiusura verra aggiunta all'ultima entry di oggi.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            GroupBox("Com'e andata?") {
                Picker("Com'e andata?", selection: $selectedMood) {
                    ForEach(EndDayMood.allCases) { mood in
                        Label(mood.rawValue, systemImage: mood.systemImage).tag(mood)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            GroupBox("Nota per domani") {
                TextField("Opzionale", text: $note, axis: .vertical)
                    .lineLimit(3...5)
                    .frame(maxWidth: .infinity)
            }

            HStack {
                Button("Annulla") { dismiss() }
                    .keyboardShortcut(.escape)
                Spacer()
                Button(actionTitle) { closeDay() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return)
                    .disabled(activeSessions.isEmpty && todayEntries.isEmpty)
            }
        }
        .padding()
        .frame(width: 460)
    }

    private var actionTitle: String {
        activeSessions.isEmpty ? "Salva chiusura" : "Chiudi giornata"
    }

    private func sessionRow(_ session: ActiveSession) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(session.client?.color ?? .accentColor)
                .frame(width: 4, height: 30)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.client?.name ?? "No client")
                    .fontWeight(.medium)
                if let project = session.project {
                    Text(project.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(session.cappedElapsedMinutes(endHour: endHour, endMinute: endMinute).formattedDuration)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func closeDay() {
        let closureNote = makeClosureNote()

        if activeSessions.isEmpty {
            appendClosureNote(to: todayEntries.first, closureNote: closureNote)
        } else {
            for session in activeSessions {
                let entry = session.asTimeEntry(
                    durationMinutes: session.cappedElapsedMinutes(endHour: endHour, endMinute: endMinute),
                    notes: mergedNotes(session.notes, closureNote),
                    label: session.label
                )
                context.insert(entry)
                NotificationManager.shared.cancelSession(id: session.notificationID)
                context.delete(session)
            }
        }

        try? context.save()
        RestSyncService.shared.triggerSyncNow()
        dismiss()
    }

    private func appendClosureNote(to entry: TimeEntry?, closureNote: String) {
        guard let entry else { return }
        entry.notes = mergedNotes(entry.notes, closureNote)
    }

    private func makeClosureNote() -> String {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNote.isEmpty else {
            return "Chiusura giornata: \(selectedMood.rawValue)"
        }
        return "Chiusura giornata: \(selectedMood.rawValue)\nNota: \(trimmedNote)"
    }

    private func mergedNotes(_ existing: String?, _ closureNote: String) -> String {
        let trimmedExisting = existing?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedExisting.isEmpty else { return closureNote }
        return "\(trimmedExisting)\n\n\(closureNote)"
    }
}
