import TimelogCore
import SwiftUI
import SwiftData

private enum ClientSheet: Identifiable {
    case add
    case edit(Client)
    var id: String {
        switch self {
        case .add:           return "add"
        case .edit(let c):   return "edit-\(c.persistentModelID)"
        }
    }
}

struct ClientsView: View {
    @Environment(\.modelContext) private var context
    @Environment(SettingsStore.self) private var settings
    @Query(filter: #Predicate<Client> { $0.deletedAt == nil }, sort: \Client.name) private var allClients: [Client]

    @State private var activeSheet: ClientSheet?
    @State private var showArchived = false
    @State private var clientToDelete: Client?

    private var visibleClients: [Client] {
        allClients.filter { $0.userId == settings.userId && (showArchived || !$0.isArchived) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if visibleClients.isEmpty {
                    ContentUnavailableView(
                        showArchived ? "No clients" : "No active clients",
                        systemImage: "person.2",
                        description: Text(showArchived ? "Tap + to add your first client" : "All clients are archived")
                    )
                } else {
                    List {
                        ForEach(visibleClients) { client in
                            NavigationLink { ProjectListView(client: client) } label: {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(client.color)
                                        .frame(width: 12, height: 12)
                                        .accessibilityHidden(true)
                                    Text(client.name)
                                        .foregroundStyle(client.isArchived ? .secondary : .primary)
                                    Spacer()
                                    if client.isArchived {
                                        Text("Archived")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("\(client.projects.filter { $0.deletedAt == nil }.count) projects")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { clientToDelete = client } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button { activeSheet = .edit(client) } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    client.isArchived.toggle()
                                    try? context.save()
                                } label: {
                                    Label(client.isArchived ? "Unarchive" : "Archive",
                                          systemImage: client.isArchived ? "tray.and.arrow.up" : "archivebox")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                }
            }
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
                        client.deletedAt = .now
                        try? context.save()
                        clientToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) { clientToDelete = nil }
            }
            .navigationTitle("Clients")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { activeSheet = .add } label: { Image(systemName: "plus") }
                        .accessibilityLabel(String(localized: "Add client"))
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        showArchived.toggle()
                    } label: {
                        Label(showArchived ? "Hide archived" : "Show archived",
                              systemImage: showArchived ? "archivebox.fill" : "archivebox")
                    }
                }
                #if targetEnvironment(macCatalyst)
                ToolbarItem(placement: .secondaryAction) {
                    TimerQuickToggle()
                }
                #endif
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .add:          ClientFormView()
                case .edit(let c):  ClientFormView(client: c)
                }
            }
        }
    }
}
