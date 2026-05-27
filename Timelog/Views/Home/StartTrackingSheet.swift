import TimelogCore
import SwiftUI
import SwiftData

struct StartTrackingSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings

    let clients: [Client]

    @State private var selectedClient: Client?
    @State private var selectedProject: Project?
    @State private var selectedLabel: String?
    @State private var newLabelText = ""
    @State private var notes = ""

    @Query(filter: #Predicate<Project> { !$0.isArchived && $0.deletedAt == nil }, sort: \Project.name)
    private var allProjects: [Project]

    private var availableProjects: [Project] {
        guard let client = selectedClient else { return [] }
        return allProjects.filter { $0.client?.persistentModelID == client.persistentModelID }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    Picker("Client", selection: $selectedClient) {
                        Text("None").tag(Optional<Client>.none)
                        ForEach(clients) { Text($0.name).tag(Optional($0)) }
                    }
                    .onChange(of: selectedClient) { selectedProject = nil; selectedLabel = nil }

                    if !availableProjects.isEmpty {
                        Picker("Project", selection: $selectedProject) {
                            Text("None").tag(Optional<Project>.none)
                            ForEach(availableProjects) { Text($0.name).tag(Optional($0)) }
                        }
                        .onChange(of: selectedProject) { _, _ in selectedLabel = nil }
                    }

                    if let project = selectedProject {
                        if !project.labels.isEmpty {
                            Picker("Type", selection: $selectedLabel) {
                                Text("None").tag(Optional<String>.none)
                                ForEach(project.labels, id: \.self) { Text($0).tag(Optional($0)) }
                            }
                        }
                        HStack {
                            TextField("New label", text: $newLabelText)
                            Button("Add") { addLabel(to: project) }
                                .disabled(newLabelText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }

                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(String(localized: "Start Tracking"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") { start() }
                }
            }
        }
    }

    private func addLabel(to project: Project) {
        let trimmed = newLabelText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !project.labels.contains(trimmed) else { return }
        project.labels.append(trimmed)
        try? context.save()
        selectedLabel = trimmed
        newLabelText = ""
    }

    private func start() {
        let session = ActiveSession(
            client: selectedClient,
            project: selectedProject,
            notes: notes.isEmpty ? nil : notes,
            label: selectedLabel,
            userId: settings.userId
        )
        context.insert(session)
        NotificationManager.shared.scheduleSessionOverdue(
            id: session.notificationID,
            clientName: session.client?.name ?? "a project",
            projectName: session.project?.name,
            startDate: session.startDate,
            endHour: settings.trackingEndHour,
            endMinute: settings.trackingEndMinute
        )
        try? context.save()
        dismiss()
    }
}
