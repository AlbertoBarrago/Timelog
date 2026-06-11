import TimelogCore
import TimelogSync
import SwiftUI
import SwiftData
#if os(iOS)
import WidgetKit
#endif

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(SettingsStore.self) private var settings
    @Query(filter: #Predicate<TimeEntry> { $0.deletedAt == nil }, sort: \TimeEntry.date, order: .reverse) private var allEntries: [TimeEntry]
    @Query(sort: \ActiveSession.startDate) private var allSessions: [ActiveSession]
    @Query(filter: #Predicate<Client> { !$0.isArchived && $0.deletedAt == nil }, sort: \Client.name) private var allClients: [Client]
    @State private var activeSheet: HomeSheet?

    private var activeSessions: [ActiveSession] { allSessions.filter { $0.userId == settings.userId } }
    private var clients: [Client] { allClients.filter { $0.userId == settings.userId } }
    private var todayEntries: [TimeEntry] {
        allEntries.filter { $0.userId == settings.userId && Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TimelineView(.periodic(from: .now, by: 60)) { _ in
                    let loggedMinutes = todayEntries.reduce(0) { $0 + $1.durationMinutes }
                    let activeMinutes = activeSessions.reduce(0) { $0 + $1.elapsedMinutes }
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Today")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text((loggedMinutes + activeMinutes).formattedDuration)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                        }
                        Spacer()
                        Image(systemName: activeSessions.isEmpty ? "clock.fill" : "record.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(activeSessions.isEmpty ? Color.secondary.opacity(0.4) : Color.red.opacity(0.7))
                            .accessibilityHidden(true)
                    }
                    .padding()
                    .background(.quinary, in: RoundedRectangle(cornerRadius: 12))
                    .padding()
                }

                if activeSessions.isEmpty && todayEntries.isEmpty {
                    ContentUnavailableView(
                        "No entries today",
                        systemImage: "clock",
                        description: Text("Tap + to log time or ▶ to start tracking")
                    )
                    .padding(.bottom, 120)
                } else {
                    List {
                        if !activeSessions.isEmpty {
                            Section("Active") {
                                ForEach(activeSessions) { session in
                                    ActiveSessionRow(session: session)
                                        .contentShape(Rectangle())
                                        .onTapGesture { activeSheet = .stopSession(session) }
                                        .accessibilityAddTraits(.isButton)
                                        .accessibilityLabel(String(localized: "Active session, \(session.client?.name ?? "No client")"))
                                        .accessibilityHint(String(localized: "Tap to stop session"))
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                NotificationManager.shared.cancelSession(id: session.notificationID)
                                                context.delete(session)
                                                try? context.save()
                                                RestSyncService.shared.triggerSyncNow()
                                            } label: {
                                                Label("Discard", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }

                        ForEach(todayEntries) { entry in
                            EntryRow(entry: entry)
                                .contentShape(Rectangle())
                                .onTapGesture { activeSheet = .editEntry(entry) }
                                .accessibilityAddTraits(.isButton)
                                .accessibilityLabel(String(localized: "Entry, \(entry.client?.name ?? "No client")"))
                                .accessibilityHint(String(localized: "Tap to edit"))
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        entry.deletedAt = .now
                                        try? context.save()
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.inset)
                    .refreshable {
                        try? await RestSyncService.shared.pullAll(into: context)
                    }
                }
            }
            .navigationTitle("Timelog")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { activeSheet = .history } label: {
                        Image(systemName: "calendar")
                    }
                    .accessibilityLabel(String(localized: "History"))
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { activeSheet = .startTracking } label: {
                        Image(systemName: "play.circle")
                    }
                    .accessibilityLabel(String(localized: "Start tracking"))
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { activeSheet = .quickLog } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(String(localized: "Log time"))
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .quickLog:
                    QuickLogSheet()
                case .startTracking:
                    StartTrackingSheet(clients: clients)
                case .history:
                    HistoryView()
                case .editEntry(let entry):
                    QuickLogSheet(entry: entry)
                case .stopSession(let session):
                    StopSessionSheet(session: session,
                                     endHour: settings.trackingEndHour,
                                     endMinute: settings.trackingEndMinute)
                }
            }
            .onAppear { updateWidgetSnapshot() }
            .onChange(of: allEntries) { _, _ in updateWidgetSnapshot() }
            .onChange(of: allSessions) { _, _ in updateWidgetSnapshot() }
        }
    }

    private func updateWidgetSnapshot() {
        let latestEntry = todayEntries.first
        let latestSession = activeSessions.max { $0.startDate < $1.startDate }

        var byClient: [String: TimelogWidgetBreakdownItem] = [:]
        func accumulate(client: Client?, minutes: Int) {
            guard minutes > 0 else { return }
            let name = client?.name ?? String(localized: "No client")
            byClient[name] = TimelogWidgetBreakdownItem(
                name: name,
                colorHex: client?.colorHex ?? "#8E8E93",
                minutes: (byClient[name]?.minutes ?? 0) + minutes
            )
        }
        for entry in todayEntries { accumulate(client: entry.client, minutes: entry.durationMinutes) }
        for session in activeSessions { accumulate(client: session.client, minutes: session.elapsedMinutes) }

        let snapshot = TimelogWidgetSnapshot(
            loggedMinutes: todayEntries.reduce(0) { $0 + $1.durationMinutes },
            activeSessions: activeSessions.map {
                TimelogWidgetActiveSessionSnapshot(
                    startDate: $0.startDate,
                    clientName: $0.client?.name,
                    projectName: $0.project?.name,
                    clientColorHex: $0.client?.colorHex
                )
            },
            lastClientName: latestSession?.client?.name ?? latestEntry?.client?.name,
            lastProjectName: latestSession?.project?.name ?? latestEntry?.project?.name,
            breakdown: byClient.values.sorted { $0.minutes > $1.minutes }
        )
        WidgetSnapshotStore.save(snapshot)
        #if os(iOS)
        WidgetCenter.shared.reloadTimelines(ofKind: TimelogWidgetConstants.kind)
        #endif
    }
}

private enum HomeSheet: Identifiable {
    case quickLog
    case startTracking
    case history
    case editEntry(TimeEntry)
    case stopSession(ActiveSession)

    var id: String {
        switch self {
        case .quickLog: "quickLog"
        case .startTracking: "startTracking"
        case .history: "history"
        case .editEntry(let entry): "editEntry-\(entry.persistentModelID)"
        case .stopSession(let session): "stopSession-\(session.persistentModelID)"
        }
    }
}

private struct ActiveSessionRow: View {
    let session: ActiveSession

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(session.client?.color ?? .accentColor)
                .frame(width: 4, height: 36)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.client?.name ?? "No client")
                    .font(.subheadline.weight(.semibold))
                if let proj = session.project {
                    Text(proj.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            TimelineView(.periodic(from: .now, by: 1)) { _ in
                Text(session.elapsedDisplay)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.tint)
            }

            Image(systemName: "stop.circle.fill")
                .foregroundStyle(.red)
                .font(.title3)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 2)
    }
}

private struct EntryRow: View {
    let entry: TimeEntry

    var body: some View {
        HStack(spacing: 12) {
            if let color = entry.client?.color {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: 4, height: 36)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.client?.name ?? "No client")
                    .font(.subheadline.weight(.semibold))
                if let proj = entry.project {
                    HStack(spacing: 4) {
                        Text(proj.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let label = entry.label {
                            Text(label)
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                }
                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(entry.durationMinutes.formattedDuration)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
