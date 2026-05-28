import SwiftUI
import SwiftData
import TimelogCore
import TimelogSync

struct ClientsMacView: View {
    @Environment(\.modelContext) private var context
    @Environment(SettingsStore.self) private var settings
    @Query(filter: #Predicate<Client> { $0.deletedAt == nil }, sort: \Client.name) private var allClients: [Client]

    @State private var selectedClientID: PersistentIdentifier?
    @State private var showingAddClient  = false
    @State private var clientToEdit: Client?
    @State private var clientToDelete: Client?
    @State private var showArchived      = false

    private var visibleClients: [Client] {
        allClients.filter { $0.userId == settings.userId && (showArchived || !$0.isArchived) }
    }

    private var selectedClient: Client? {
        guard let id = selectedClientID else { return nil }
        return allClients.first { $0.persistentModelID == id }
    }

    var body: some View {
        HSplitView {
            // ── Clients list ──────────────────────────────
            VStack(spacing: 0) {
                List(visibleClients, selection: $selectedClientID) { client in
                    ClientMacRow(client: client)
                        .tag(client.persistentModelID)
                        .contextMenu {
                            Button("Edit") { clientToEdit = client }
                            Button(client.isArchived ? "Unarchive" : "Archive") {
                                client.isArchived.toggle()
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                clientToDelete = client
                            }
                        }
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 180, idealWidth: 200, maxWidth: 240)

            // ── Projects detail ───────────────────────────
            if let client = selectedClient {
                ProjectsMacView(client: client)
            } else {
                ContentUnavailableView("Select a client", systemImage: "person.2")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(y: -70)
            }
        }
        .navigationTitle("Clients")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { showingAddClient = true } label: {
                    Label("Add Client", systemImage: "plus")
                }
                .help(String(localized: "Add a new client"))

                Button { showArchived.toggle() } label: {
                    Label(showArchived ? "Hide Archived" : "Show Archived",
                          systemImage: showArchived ? "archivebox.fill" : "archivebox")
                }
                .help(showArchived ? String(localized: "Hide archived clients") : String(localized: "Show archived clients"))
            }
        }
        .sheet(isPresented: $showingAddClient)  { ClientMacFormView() }
        .sheet(item: $clientToEdit)             { ClientMacFormView(client: $0) }
        .confirmationDialog(
            clientToDelete.map { "Delete \"\($0.name)\"?" } ?? "",
            isPresented: Binding(get: { clientToDelete != nil }, set: { if !$0 { clientToDelete = nil } }),
            titleVisibility: .visible
        ) {
            if let client = clientToDelete {
                let projectCount = client.projects.filter { $0.deletedAt == nil }.count
                let minutes = client.projects.flatMap { $0.entries }.reduce(0) { $0 + $1.durationMinutes }
                let detail = [
                    projectCount > 0 ? "\(projectCount) project\(projectCount == 1 ? "" : "s")" : nil,
                    minutes > 0 ? "\(minutes.formattedDuration) of tracked time" : nil
                ].compactMap { $0 }.joined(separator: " and ")
                Button("Delete client\(detail.isEmpty ? "" : " and \(detail)")", role: .destructive) {
                    if selectedClientID == client.persistentModelID { selectedClientID = nil }
                    client.deletedAt = .now
                    try? context.save()
                    clientToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { clientToDelete = nil }
        }
        .syncGated(while: $showingAddClient)
        .syncGated(whilePresent: $clientToEdit)
        .onReceive(NotificationCenter.default.publisher(for: MongoSyncService.willWipeDataNotification)) { _ in
            selectedClientID = nil
            clientToEdit     = nil
        }
    }
}

private struct ClientMacRow: View {
    let client: Client
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(client.color).frame(width: 10, height: 10)
                .accessibilityHidden(true)
            Text(client.name)
                .foregroundStyle(client.isArchived ? .secondary : .primary)
            Spacer()
            if client.isArchived {
                Image(systemName: "archivebox")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel(String(localized: "Archived"))
            }
        }
        .padding(.vertical, 2)
    }
}

struct ProjectsMacView: View {
    @Environment(\.modelContext) private var context
    @Environment(SettingsStore.self) private var settings
    let client: Client

    @State private var showingAddProject = false
    @State private var projectToEdit: Project?
    @State private var projectToDelete: Project?
    @State private var selectedProjects  = Set<Project.ID>()

    @Query(sort: \Project.name) private var allProjects: [Project]
    @Query(sort: \ActiveSession.startDate) private var allSessions: [ActiveSession]

    private var visibleProjects: [Project] {
        allProjects.filter { $0.client?.persistentModelID == client.persistentModelID && $0.deletedAt == nil }
    }

    private var activeSessions: [ActiveSession] {
        allSessions.filter { $0.userId == settings.userId }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 8) {
                    Circle().fill(client.color).frame(width: 10, height: 10)
                        .accessibilityHidden(true)
                    Text(client.name).font(.headline)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if visibleProjects.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "folder")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            Text("No projects")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 32)
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(visibleProjects) { proj in
                        let isActive = activeSessions.contains { $0.project?.persistentModelID == proj.persistentModelID }
                        ProjectMacRow(project: proj, isActive: isActive) {
                            if isActive {
                                autoStop(activeSessions.filter { $0.project?.persistentModelID == proj.persistentModelID })
                            } else {
                                autoStop(activeSessions)
                                quickStart(project: proj)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { projectToEdit = proj }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint(String(localized: "Click to edit project"))
                        .contextMenu {
                            Button("Edit") { projectToEdit = proj }
                            Divider()
                            Button("Delete", role: .destructive) {
                                projectToDelete = proj
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
        .toolbar {
            ToolbarItemGroup(placement: .secondaryAction) {
                Button { showingAddProject = true } label: {
                    Label("Add Project", systemImage: "folder.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showingAddProject) { ProjectMacFormView(client: client) }
        .sheet(item: $projectToEdit)            { ProjectMacFormView(client: client, project: $0) }
        .confirmationDialog(
            projectToDelete.map { "Delete \"\($0.name)\"?" } ?? "",
            isPresented: Binding(get: { projectToDelete != nil }, set: { if !$0 { projectToDelete = nil } }),
            titleVisibility: .visible
        ) {
            if let project = projectToDelete {
                let minutes = project.entries.reduce(0) { $0 + $1.durationMinutes }
                Button("Delete project\(minutes > 0 ? " and \(minutes.formattedDuration) of tracked time" : "")", role: .destructive) {
                    project.deletedAt = .now
                    try? context.save()
                    projectToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { projectToDelete = nil }
        }
        .syncGated(while: $showingAddProject)
        .syncGated(whilePresent: $projectToEdit)
        .onReceive(NotificationCenter.default.publisher(for: MongoSyncService.willWipeDataNotification)) { _ in
            projectToEdit    = nil
            selectedProjects = []
        }
    }

    private func autoStop(_ sessions: [ActiveSession]) {
        for session in sessions {
            let seconds = max(0, Date().timeIntervalSince(session.startDate))
            let elapsed = max(1, Int((seconds / 60).rounded()))
            let entry = session.asTimeEntry(durationMinutes: elapsed, notes: session.notes, label: session.label)
            context.insert(entry)
            NotificationManager.shared.cancelSession(id: session.notificationID)
            context.delete(session)
        }
        try? context.save()
    }

    private func quickStart(project: Project) {
        let session = ActiveSession(
            client: project.client,
            project: project,
            userId: settings.userId
        )
        context.insert(session)
        NotificationManager.shared.scheduleSessionOverdue(
            id: session.notificationID,
            clientName: project.client?.name ?? "a project",
            projectName: project.name,
            startDate: session.startDate,
            endHour: settings.trackingEndHour,
            endMinute: settings.trackingEndMinute
        )
        try? context.save()
    }
}

private struct ProjectMacRow: View {
    let project: Project
    let isActive: Bool
    let onQuickToggle: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(project.name)
                    if let code = project.code {
                        Text(code)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }
            }
            Spacer()
            Button(action: onQuickToggle) {
                Image(systemName: isActive ? "stop.circle.fill" : "play.circle")
                    .foregroundStyle(isActive ? .red : .secondary)
            }
            .buttonStyle(.plain)
            .help(isActive ? String(localized: "Stop session") : String(localized: "Start session"))
            .accessibilityLabel(isActive ? String(localized: "Stop session") : String(localized: "Start session"))
        }
        .padding(.vertical, 2)
    }
}

private let presetColorHexes = [
    "#FF3B30", "#FF9500", "#FFCC00", "#34C759",
    "#30B0C7", "#007AFF", "#5856D6", "#AF52DE",
    "#FF2D55", "#A2845E", "#8E8E93", "#32ADE6"
]

struct ClientMacFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss
    @Environment(SettingsStore.self) private var settings
    var client: Client?

    @State private var name     = ""
    @State private var colorHex = "#007AFF"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(client == nil ? "New Client" : "Edit Client").font(.headline)
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                    ForEach(presetColorHexes, id: \.self) { hex in
                        colorSwatch(hex: hex)
                    }
                }
                ColorPicker("Custom", selection: Binding(
                    get: { Color(hex: colorHex) ?? .accentColor },
                    set: { colorHex = $0.hex }
                ), supportsOpacity: false)
                .labelsHidden()
            }
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.escape)
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 300)
        .onAppear { name = client?.name ?? ""; colorHex = client?.colorHex ?? "#007AFF" }
    }

    @ViewBuilder
    private func colorSwatch(hex: String) -> some View {
        let selected = colorHex.uppercased() == hex
        Circle()
            .fill(Color(hex: hex) ?? .blue)
            .frame(width: 28, height: 28)
            .overlay {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 1)
                }
            }
            .onTapGesture { colorHex = hex }
            .accessibilityLabel(colorName(for: hex))
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func colorName(for hex: String) -> String {
        switch hex.uppercased() {
        case "#FF3B30": return String(localized: "Red")
        case "#FF9500": return String(localized: "Orange")
        case "#FFCC00": return String(localized: "Yellow")
        case "#34C759": return String(localized: "Green")
        case "#30B0C7": return String(localized: "Teal")
        case "#007AFF": return String(localized: "Blue")
        case "#5856D6": return String(localized: "Indigo")
        case "#AF52DE": return String(localized: "Purple")
        case "#FF2D55": return String(localized: "Pink")
        case "#A2845E": return String(localized: "Brown")
        case "#8E8E93": return String(localized: "Gray")
        case "#32ADE6": return String(localized: "Light Blue")
        default:        return String(localized: "Custom color")
        }
    }

    private func save() {
        dismiss()
        if let c = client { c.name = name; c.colorHex = colorHex }
        else { context.insert(Client(name: name, colorHex: colorHex, userId: settings.userId)) }
    }
}

struct ProjectMacFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss)      private var dismiss
    @Environment(SettingsStore.self) private var settings
    let client: Client
    var project: Project?

    @State private var name = ""
    @State private var code = ""
    @State private var labels: [String] = []
    @State private var newLabel = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(project == nil ? "New Project" : "Edit Project").font(.headline)
            TextField("Name", text: $name).textFieldStyle(.roundedBorder)
            TextField("Code (optional)", text: $code).textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("Labels")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !labels.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(labels, id: \.self) { label in
                            HStack {
                                Text(label)
                                Spacer()
                                Button {
                                    labels.removeAll { $0 == label }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(String(localized: "Remove \(label)"))
                            }
                        }
                    }
                    .padding(8)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }

                HStack {
                    TextField("New label", text: $newLabel)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addLabel() }
                    Button("Add") { addLabel() }
                        .disabled(newLabel.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.escape)
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 300)
        .onAppear {
            name = project?.name ?? ""
            code = project?.code ?? ""
            labels = project?.labels ?? []
        }
    }

    private func addLabel() {
        let trimmed = newLabel.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !labels.contains(trimmed) else { return }
        labels.append(trimmed)
        newLabel = ""
    }

    private func save() {
        dismiss()
        if let p = project {
            p.name = name
            p.code = code.isEmpty ? nil : code
            p.labels = labels
        } else {
            let p = Project(name: name, code: code.isEmpty ? nil : code, userId: settings.userId)
            p.client = client
            p.labels = labels
            context.insert(p)
        }
    }
}
