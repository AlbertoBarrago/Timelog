import TimelogCore
import TimelogSync
import SwiftUI
import SwiftData

private enum ProjectSheet: Identifiable {
    case add
    case edit(Project)
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let p): return "edit-\(p.persistentModelID)"
        }
    }
}

struct ProjectListView: View {
    @Environment(\.modelContext) private var context
    @Environment(SettingsStore.self) private var settings
    var client: Client

    @Query(sort: \Project.name) private var allProjects: [Project]
    @Query(sort: \ActiveSession.startDate) private var allSessions: [ActiveSession]
    @State private var activeSheet: ProjectSheet?

    private var activeProjects: [Project] {
        allProjects.filter { $0.client?.persistentModelID == client.persistentModelID && !$0.isArchived }
    }
    private var archivedProjects: [Project] {
        allProjects.filter { $0.client?.persistentModelID == client.persistentModelID && $0.isArchived }
    }
    private var activeSessions: [ActiveSession] {
        allSessions.filter { $0.userId == settings.userId }
    }

    var body: some View {
        List {
            if activeProjects.isEmpty && archivedProjects.isEmpty {
                ContentUnavailableView("No projects", systemImage: "folder",
                    description: Text("Tap + to add a project"))
            }

            if !activeProjects.isEmpty {
                Section("Active") {
                    ForEach(activeProjects, content: projectRow)
                }
            }
            if !archivedProjects.isEmpty {
                Section("Archived") {
                    ForEach(archivedProjects, content: projectRow)
                }
            }
        }
        .navigationTitle(client.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { activeSheet = .add } label: { Image(systemName: "plus") }
                    .accessibilityLabel(String(localized: "Add project"))
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .add:
                ProjectFormView(client: client)
            case .edit(let p):
                ProjectFormView(client: client, project: p)
            }
        }
    }

    @ViewBuilder
    private func projectRow(_ project: Project) -> some View {
        let isActive = activeSessions.contains { $0.project?.persistentModelID == project.persistentModelID }
        HStack {
            Text(project.name)
            if let code = project.code {
                Text(code)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.15), in: Capsule())
            }
            Spacer()
            if !project.isArchived {
                Button {
                    if isActive {
                        autoStop(activeSessions.filter { $0.project?.persistentModelID == project.persistentModelID })
                    } else {
                        autoStop(activeSessions)
                        quickStart(project: project)
                    }
                } label: {
                    Image(systemName: isActive ? "stop.circle.fill" : "play.circle")
                        .foregroundStyle(isActive ? .red : .secondary)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isActive ? String(localized: "Stop session") : String(localized: "Start session"))
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { project.deletedAt = .now } label: {
                Label("Delete", systemImage: "trash")
            }
            Button { activeSheet = .edit(project) } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                project.isArchived.toggle()
            } label: {
                Label(project.isArchived ? "Unarchive" : "Archive",
                      systemImage: project.isArchived ? "tray.and.arrow.up" : "archivebox")
            }
            .tint(.orange)
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
