import SwiftUI
import SwiftData
import TimelogCore
import TimelogSync

struct StopSessionMacView: View {
    enum Presentation {
        case sheet
        case menuBar
    }

    var presentation: Presentation = .sheet
    var onDismiss: (() -> Void)? = nil
    var onStop: (() -> Void)? = nil
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let session: ActiveSession

    @State private var hours: Int
    @State private var minutes: Int
    @State private var notes: String
    @State private var selectedLabel: String?
    @State private var newLabelText = ""
    @State private var showDiscardAlert = false

    init(
        session: ActiveSession,
        endHour: Int = 18,
        endMinute: Int = 0,
        presentation: Presentation = .sheet,
        onDismiss: (() -> Void)? = nil,
        onStop: (() -> Void)? = nil
    ) {
        self.onDismiss = onDismiss
        self.onStop = onStop
        self.presentation = presentation
        self.session = session
        let elapsed = session.cappedElapsedMinutes(endHour: endHour, endMinute: endMinute)
        _hours = State(initialValue: elapsed / 60)
        _minutes = State(initialValue: elapsed % 60)
        _notes = State(initialValue: session.notes ?? "")
        _selectedLabel = State(initialValue: session.label)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            sessionSummary

            section(title: "Duration") {
                DurationPickerMac(hours: $hours, minutes: $minutes)
            }

            if let project = session.project {
                section(title: "Type") {
                    VStack(alignment: .leading, spacing: 10) {
                        if !project.labels.isEmpty {
                            labelPicker(for: project)
                        }
                        HStack(spacing: 8) {
                            TextField(String(localized: "New label"), text: $newLabelText)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit { addLabel(to: project) }
                            Button(String(localized: "Add")) { addLabel(to: project) }
                                .disabled(newLabelText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
            }

            section(title: "Notes") {
                TextField("Optional", text: $notes)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
            }

            actions
        }
        .padding(presentation == .menuBar ? 12 : 18)
        .frame(width: presentation == .menuBar ? 360 : 420)
    }

    @ViewBuilder
    private func labelPicker(for project: Project) -> some View {
        let labels = [nil] + project.labels.map(Optional.some)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(labels, id: \.self) { label in
                labelButton(label)
            }
        }
    }

    @ViewBuilder
    private func labelButton(_ label: String?) -> some View {
        if label == selectedLabel {
            Button {
                selectedLabel = label
            } label: {
                labelButtonText(label)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        } else {
            Button {
                selectedLabel = label
            } label: {
                labelButtonText(label)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func labelButtonText(_ label: String?) -> some View {
        Text(label ?? String(localized: "None"))
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .frame(maxWidth: .infinity)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Stop Tracking")
                .font(.headline.weight(.semibold))
        }
    }

    private var sessionSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let client = session.client {
                summaryRow("Client", value: client.name, systemImage: "person.crop.circle")
            }
            if let project = session.project {
                summaryRow("Project", value: project.name, systemImage: "folder")
            }
            HStack(spacing: 7) {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                Text("Started")
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(session.startDate, style: .time)
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
        }
        .font(.caption)
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
        }
    }

    private func summaryRow(_ title: LocalizedStringKey, value: String, systemImage: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .fontWeight(.medium)
                .lineLimit(1)
        }
    }

    private func section<Content: View>(title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
                }
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button("Discard", role: .destructive) { showDiscardAlert = true }
                .alert("Discard session?", isPresented: $showDiscardAlert) {
                    Button("Discard", role: .destructive) { discard() }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("The tracked time will be lost.")
                }
            Spacer()
            Button("Cancel") { dismissSelf() }
            Button("Log Entry") { stop() }
                .buttonStyle(.borderedProminent)
                .disabled(hours == 0 && minutes == 0)
        }
        .padding(.top, 2)
    }

    private func addLabel(to project: Project) {
        let trimmed = newLabelText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !project.labels.contains(trimmed) else { return }
        project.labels.append(trimmed)
        try? context.save()
        selectedLabel = trimmed
        newLabelText = ""
    }

    private func dismissSelf() {
        if let onDismiss { onDismiss() } else { dismiss() }
    }

    private func discard() {
        NotificationManager.shared.cancelSession(id: session.notificationID)
        let now = Date()
        session.deletedAt = now
        session.updatedAt = now
        try? context.save()
        onStop?()
        RestSyncService.shared.triggerSyncNow()
        dismissSelf()
    }

    private func stop() {
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
        try? context.save()
        onStop?()
        RestSyncService.shared.triggerSyncNow()
        dismissSelf()
    }
}
