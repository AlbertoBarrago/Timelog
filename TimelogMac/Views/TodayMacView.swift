import SwiftUI
import SwiftData
import TimelogCore
import TimelogSync

struct TodayMacView: View {
    @Environment(\.modelContext) private var context
    @Environment(SettingsStore.self) private var settings
    @Query(filter: #Predicate<TimeEntry> { $0.deletedAt == nil }, sort: \TimeEntry.date, order: .reverse) private var allEntries: [TimeEntry]
    @Query(sort: \ActiveSession.startDate) private var allSessions: [ActiveSession]

    @State private var showingQuickLog      = false
    @State private var showingStartTracking = false
    @State private var showingHistory       = false
    @State private var entryToEdit: TimeEntry?
    @State private var sessionToStop: ActiveSession?

    private var activeSessions: [ActiveSession] { allSessions.filter { $0.userId == settings.userId } }
    private var todayEntries: [TimeEntry] {
        allEntries.filter { $0.userId == settings.userId && Calendar.current.isDateInToday($0.date) }
    }
    private var todayTotal: Int {
        todayEntries.reduce(0) { $0 + $1.durationMinutes }
        + activeSessions.reduce(0) { $0 + $1.elapsedMinutes }
    }

    var body: some View {
        Group {
            if activeSessions.isEmpty && todayEntries.isEmpty {
                ContentUnavailableView {
                    Label("No entries today", systemImage: "clock")
                } description: {
                    Text("Log time manually or start a tracking session.")
                } actions: {
                    Button("Log Time")       { showingQuickLog = true }
                    Button("Start Tracking") { showingStartTracking = true }
                }
                .offset(y: -40)
            } else {
                List {
                    Section("Active") {
                        if activeSessions.isEmpty {
                            Text("No active sessions on this Mac")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        } else {
                            TimelineView(.periodic(from: .now, by: 1)) { tl in
                                ForEach(activeSessions) { session in
                                    ActiveSessionMacRow(session: session, now: tl.date) {
                                        sessionToStop = session
                                    }
                                    .contextMenu {
                                        Button("Stop & Log") { sessionToStop = session }
                                        Divider()
                                        Button("Discard", role: .destructive) {
                                            NotificationManager.shared.cancelSession(id: session.notificationID)
                                            context.delete(session)
                                            try? context.save()
                                            MongoSyncService.shared.triggerSyncNow()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Section("Entries") {
                        ForEach(todayEntries) { entry in
                            EntryMacRow(entry: entry)
                                .contentShape(Rectangle())
                                .onTapGesture { entryToEdit = entry }
                                .accessibilityAddTraits(.isButton)
                                .accessibilityHint(String(localized: "Click to edit entry"))
                                .contextMenu {
                                    Button("Edit") { entryToEdit = entry }
                                    Divider()
                                    Button("Delete", role: .destructive) { entry.deletedAt = .now }
                                }
                        }
                    }
                }
            }
        }
        .navigationTitle("Today")
        .navigationSubtitle(todayTotal > 0 ? todayTotal.formattedDuration : "")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { showingHistory = true } label: {
                    Label("History", systemImage: "calendar")
                }
                .help("Open history")

                Button { showingStartTracking = true } label: {
                    Label("Track", systemImage: "play.circle")
                }
                .help("Start a new tracking session")

                Button { showingQuickLog = true } label: {
                    Label("Log", systemImage: "plus")
                }
                .help("Log time manually")
            }
        }
        .sheet(isPresented: $showingQuickLog)      { QuickLogMacView() }
        .sheet(isPresented: $showingStartTracking)  { StartTrackingMacView().environment(settings) }
        .sheet(isPresented: $showingHistory)        { HistoryMacView().frame(minWidth: 520, minHeight: 420) }
        .sheet(item: $entryToEdit)                  { QuickLogMacView(entry: $0) }
        .sheet(item: $sessionToStop)                { StopSessionMacView(session: $0) }
        .syncGated(while: $showingQuickLog)
        .syncGated(while: $showingStartTracking)
        .syncGated(whilePresent: $entryToEdit)
        .syncGated(whilePresent: $sessionToStop)
    }
}

struct ActiveSessionMacRow: View {
    let session: ActiveSession
    var now: Date = .now
    var onStop: (() -> Void)? = nil
    @State private var isHovered = false

    private var elapsedDisplay: String {
        let s = Int(now.timeIntervalSince(session.startDate))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%02d:%02d", m, sec)
    }

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(session.client?.color ?? .accentColor)
                .frame(width: 4, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.client?.name ?? "No client")
                    .fontWeight(.medium)
                if let proj = session.project {
                    Text(proj.name).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(elapsedDisplay)
                .font(.system(.body, design: .monospaced, weight: .medium))
                .foregroundStyle(.tint)
                .monospacedDigit()
            if let onStop {
                Button(action: onStop) {
                    Image(systemName: "stop.circle.fill")
                        .foregroundStyle(.red)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .help("Stop and log")
                .accessibilityLabel(String(localized: "Stop and log session"))
            } else {
                Image(systemName: "stop.circle.fill")
                    .foregroundStyle(.red)
                    .imageScale(.large)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(isHovered ? Color.primary.opacity(0.05) : .clear, in: RoundedRectangle(cornerRadius: 5))
        .onHover { isHovered = $0 }
    }
}

struct EntryMacRow: View {
    let entry: TimeEntry
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(entry.client?.color ?? Color.secondary.opacity(0.3))
                .frame(width: 4, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.client?.name ?? "No client").fontWeight(.medium)
                if let proj = entry.project {
                    HStack(spacing: 4) {
                        Text(proj.name)
                        if let label = entry.label {
                            Text(label)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes).lineLimit(1)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(entry.durationMinutes.formattedDuration)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(isHovered ? Color.primary.opacity(0.05) : .clear, in: RoundedRectangle(cornerRadius: 5))
        .onHover { isHovered = $0 }
    }
}
