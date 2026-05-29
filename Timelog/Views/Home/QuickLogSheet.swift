import TimelogCore
import SwiftUI
import SwiftData

struct QuickLogSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings
    @Query(filter: #Predicate<Client> { !$0.isArchived && $0.deletedAt == nil }, sort: \Client.name)
    private var allClients: [Client]
    @Query(filter: #Predicate<Project> { $0.deletedAt == nil }, sort: \Project.name)
    private var allProjects: [Project]

    var entry: TimeEntry?

    @State private var selectedClient: Client?
    @State private var selectedProject: Project?
    @State private var selectedLabel: String?
    @State private var newLabelText = ""
    @State private var date = Date()
    @State private var hours = 0
    @State private var minutes = 30
    @State private var notes = ""

    private var clients: [Client] { allClients.filter { $0.userId == settings.userId } }
    private var availableProjects: [Project] {
        guard let client = selectedClient else { return [] }
        return allProjects.filter { $0.client?.persistentModelID == client.persistentModelID }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("When") {
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                }

                Section("Duration") {
                    HStack(spacing: 16) {
                        Picker("Hours", selection: $hours) {
                            ForEach(0..<24, id: \.self) { Text("\($0)h").tag($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)

                        Picker("Min", selection: $minutes) {
                            ForEach([0, 15, 30, 45], id: \.self) { Text("\($0)m").tag($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity)
                    }
                }

                Section("Project") {
                    Picker("Client", selection: $selectedClient) {
                        Text("None").tag(Optional<Client>.none)
                        ForEach(clients) { Text($0.name).tag(Optional($0)) }
                    }
                    .onChange(of: selectedClient) { _, newClient in
                        if selectedProject?.client?.persistentModelID != newClient?.persistentModelID {
                            selectedProject = nil
                            selectedLabel = nil
                        }
                    }

                    if !availableProjects.isEmpty {
                        Picker("Project", selection: $selectedProject) {
                            Text("None").tag(Optional<Project>.none)
                            ForEach(availableProjects) { Text($0.name).tag(Optional($0)) }
                        }
                        .onChange(of: selectedProject) { oldVal, newVal in
                            if oldVal?.persistentModelID != newVal?.persistentModelID {
                                selectedLabel = nil
                                newLabelText = ""
                            }
                        }
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
            .navigationTitle(entry == nil ? String(localized: "Log Time") : String(localized: "Edit Entry"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(hours == 0 && minutes == 0)
                }
            }
            .onAppear { populateIfEditing() }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 440)
        #endif
    }

    private func addLabel(to project: Project) {
        let trimmed = newLabelText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !project.labels.contains(trimmed) else { return }
        project.labels.append(trimmed)
        try? context.save()
        selectedLabel = trimmed
        newLabelText = ""
    }

    private func populateIfEditing() {
        guard let e = entry else { return }
        date = e.date
        hours = e.durationMinutes / 60
        minutes = e.durationMinutes % 60
        notes = e.notes ?? ""
        selectedClient = e.client
        selectedProject = e.project
        selectedLabel = e.label
    }

    private func save() {
        let total = hours * 60 + minutes
        if let e = entry {
            e.date = date
            e.durationMinutes = total
            e.notes = notes.isEmpty ? nil : notes
            e.label = selectedLabel
            e.client = selectedClient
            e.project = selectedProject
            try? context.save()
        } else {
            let e = TimeEntry(
                date: date, durationMinutes: total,
                notes: notes.isEmpty ? nil : notes,
                label: selectedLabel,
                client: selectedClient, project: selectedProject,
                userId: settings.userId
            )
            context.insert(e)
            try? context.save()
        }
        dismiss()
    }
}
