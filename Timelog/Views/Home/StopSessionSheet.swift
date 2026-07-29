import TimelogCore
import TimelogSync
import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

struct StopSessionSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let session: ActiveSession
    let onStop: (() -> Void)?

    @State private var hours: Int
    @State private var minutes: Int
    @State private var notes: String
    @State private var selectedLabel: String?
    @State private var newLabelText = ""
    @State private var isSaving = false
    @State private var saveErrorMessage: String?

    init(session: ActiveSession, endHour: Int = 18, endMinute: Int = 0, onStop: (() -> Void)? = nil) {
        self.onStop = onStop
        self.session = session
        let elapsed = session.cappedElapsedMinutes(endHour: endHour, endMinute: endMinute)
        _hours = State(initialValue: elapsed / 60)
        _minutes = State(initialValue: elapsed % 60)
        _notes = State(initialValue: session.notes ?? "")
        _selectedLabel = State(initialValue: session.label)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "Session")) {
                    if let client = session.client {
                        LabeledContent(String(localized: "Client"), value: client.name)
                    }
                    if let project = session.project {
                        LabeledContent(String(localized: "Project"), value: project.name)
                    }
                    LabeledContent(String(localized: "Started")) {
                        Text(session.startDate, style: .time)
                    }
                }

                Section(String(localized: "Duration")) {
                    Stepper("\(hours)h", value: $hours, in: 0...23)
                    Stepper("\(minutes)m", value: $minutes, in: 0...59)
                }

                if let project = session.project {
                    Section(String(localized: "Type")) {
                        if !project.labels.isEmpty {
                            Picker(String(localized: "Type"), selection: $selectedLabel) {
                                Text("None").tag(Optional<String>.none)
                                ForEach(project.labels, id: \.self) { Text($0).tag(Optional($0)) }
                            }
                            .pickerStyle(.segmented)
                        }
                        HStack {
                            TextField(String(localized: "New label"), text: $newLabelText)
                            Button(String(localized: "Add")) { addLabel(to: project) }
                                .disabled(newLabelText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }

                Section(String(localized: "Notes")) {
                    TextField(String(localized: "Optional"), text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(String(localized: "Stop Tracking"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Log")) { stop() }
                        .disabled(isSaving || (hours == 0 && minutes == 0))
                }
            }
        }
        .onAppear    { RestSyncService.shared.isUserEditing = true  }
        .onDisappear { RestSyncService.shared.isUserEditing = false }
        .alert(String(localized: "Couldn't save session"), isPresented: errorAlertBinding) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "")
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(get: { saveErrorMessage != nil }, set: { if !$0 { saveErrorMessage = nil } })
    }

    private func addLabel(to project: Project) {
        let trimmed = newLabelText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !project.labels.contains(trimmed) else { return }
        project.labels.append(trimmed)
        try? context.save()
        selectedLabel = trimmed
        newLabelText = ""
    }

    private func stop() {
        guard !isSaving else { return }
        isSaving = true

        let entry = session.asTimeEntry(
            durationMinutes: hours * 60 + minutes,
            notes: notes.isEmpty ? nil : notes,
            label: selectedLabel
        )
        context.insert(entry)
        NotificationManager.shared.cancelSession(id: session.notificationID)
        let now = Date()
        session.deletedAt = now
        session.updatedAt = now

        do {
            try context.save()
        } catch {
            isSaving = false
            saveErrorMessage = error.localizedDescription
            return
        }

        onStop?()
        RestSyncService.shared.triggerSyncNow()
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        dismiss()
    }
}
