import SwiftUI
import TimelogCore
import WidgetKit

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(
            date: .now,
            snapshot: TimelogWidgetSnapshot(
                loggedMinutes: 125,
                activeSessions: [
                    TimelogWidgetActiveSessionSnapshot(
                        startDate: Date().addingTimeInterval(-24 * 60),
                        clientName: "Acme",
                        projectName: "Mobile app"
                    )
                ],
                lastClientName: "Acme",
                lastProjectName: "Mobile app"
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(TodayEntry(date: .now, snapshot: WidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let now = Date()
        let snapshot = WidgetSnapshotStore.load()
        let entries = (0..<8).map { offset in
            TodayEntry(
                date: Calendar.current.date(byAdding: .minute, value: offset * 15, to: now) ?? now,
                snapshot: snapshot
            )
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct TodayEntry: TimelineEntry {
    let date: Date
    let snapshot: TimelogWidgetSnapshot
}

struct TimelogWidgetExtensionEntryView: View {
    let entry: TodayEntry

    private var totalMinutes: Int {
        entry.snapshot.loggedMinutes + activeMinutes
    }

    private var activeMinutes: Int {
        entry.snapshot.activeSessions.reduce(0) {
            $0 + max(0, Int(entry.date.timeIntervalSince($1.startDate) / 60))
        }
    }

    private var subtitle: String {
        if let project = entry.snapshot.lastProjectName, !project.isEmpty {
            return project
        }
        if let client = entry.snapshot.lastClientName, !client.isEmpty {
            return client
        }
        return entry.snapshot.activeSessions.isEmpty
            ? String(localized: "No entries today")
            : String(localized: "Tracking now")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                if !entry.snapshot.activeSessions.isEmpty {
                    Image(systemName: "record.circle.fill")
                        .foregroundStyle(.red)
                        .imageScale(.small)
                }
            }

            Text(totalMinutes.formattedDuration)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.75)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 3) {
                Text(subtitle)
                    .font(.caption)
                    .lineLimit(1)
                Text(entry.snapshot.activeSessions.isEmpty
                     ? String(localized: "Logged")
                     : String(localized: "\(activeMinutes.formattedDuration) active"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct TimelogWidgetExtension: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: TimelogWidgetConstants.kind, provider: TodayProvider()) { entry in
            TimelogWidgetExtensionEntryView(entry: entry)
                .padding()
        }
        .configurationDisplayName("Timelog Today")
        .description("Shows today's logged time and active tracking.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    TimelogWidgetExtension()
} timeline: {
    TodayEntry(
        date: .now,
        snapshot: TimelogWidgetSnapshot(
            loggedMinutes: 95,
            activeSessions: [
                TimelogWidgetActiveSessionSnapshot(
                    startDate: Date().addingTimeInterval(-32 * 60),
                    clientName: "Acme",
                    projectName: "Mobile app"
                )
            ],
            lastClientName: "Acme",
            lastProjectName: "Mobile app"
        )
    )
}
