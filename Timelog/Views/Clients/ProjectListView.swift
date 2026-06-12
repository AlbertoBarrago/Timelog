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
    @State private var projectToDelete: Project?
    @State private var projectToStart: Project?

    private var projects: [Project] {
        allProjects.filter { $0.client?.persistentModelID == client.persistentModelID && $0.deletedAt == nil }
    }
    private var activeSessions: [ActiveSession] {
        allSessions.filter { $0.userId == settings.userId }
    }

    var body: some View {
        List {
            if projects.isEmpty {
                ContentUnavailableView("No projects", systemImage: "folder",
                    description: Text("Tap + to add a project"))
            } else {
                ForEach(projects, content: projectRow)
            }
        }
        .navigationTitle(client.name)
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
        .confirmationDialog(
            String(localized: "Other tracking in progress"),
            isPresented: Binding(get: { projectToStart != nil }, set: { if !$0 { projectToStart = nil } }),
            titleVisibility: .visible
        ) {
            if let project = projectToStart {
                Button(String(localized: "Start in parallel")) {
                    quickStart(project: project)
                    projectToStart = nil
                }
                Button(String(localized: "Stop others and start")) {
                    autoStop(activeSessions)
                    quickStart(project: project)
                    projectToStart = nil
                }
            }
            Button("Cancel", role: .cancel) { projectToStart = nil }
        } message: {
            Text("You can keep multiple sessions running, or stop the others and log them now.")
        }
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
            Button {
                if isActive {
                    autoStop(activeSessions.filter { $0.project?.persistentModelID == project.persistentModelID })
                } else if activeSessions.isEmpty {
                    quickStart(project: project)
                } else {
                    projectToStart = project
                }
            } label: {
                Image(systemName: isActive ? "stop.circle.fill" : "play.circle")
                    .foregroundStyle(isActive ? .red : .secondary)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isActive ? String(localized: "Stop session") : String(localized: "Start session"))
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                projectToDelete = project
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button { activeSheet = .edit(project) } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
    }

    private func autoStop(_ sessions: [ActiveSession]) {
        for session in sessions {
            let elapsed = session.cappedElapsedMinutes(endHour: settings.trackingEndHour,
                                                       endMinute: settings.trackingEndMinute)
            let entry = session.asTimeEntry(durationMinutes: elapsed, notes: session.notes, label: session.label)
            context.insert(entry)
            NotificationManager.shared.cancelSession(id: session.notificationID)
            context.delete(session)
        }
        try? context.save()
        RestSyncService.shared.triggerSyncNow()
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
