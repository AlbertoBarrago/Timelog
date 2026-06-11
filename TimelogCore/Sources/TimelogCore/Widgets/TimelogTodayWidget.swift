#if canImport(WidgetKit)
import SwiftUI
import WidgetKit

// MARK: - Provider

struct TimelogTodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimelogTodayEntry {
        TimelogTodayEntry(
            date: .now,
            snapshot: TimelogWidgetSnapshot(
                loggedMinutes: 125,
                activeSessions: [
                    TimelogWidgetActiveSessionSnapshot(
                        startDate: Date().addingTimeInterval(-24 * 60),
                        clientName: "Acme",
                        projectName: "Mobile app",
                        clientColorHex: "#007AFF"
                    )
                ],
                lastClientName: "Acme",
                lastProjectName: "Mobile app",
                breakdown: [
                    TimelogWidgetBreakdownItem(name: "Acme", colorHex: "#007AFF", minutes: 95),
                    TimelogWidgetBreakdownItem(name: "Globex", colorHex: "#FF9500", minutes: 54)
                ]
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TimelogTodayEntry) -> Void) {
        completion(TimelogTodayEntry(date: .now, snapshot: WidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimelogTodayEntry>) -> Void) {
        let now = Date()
        let snapshot = WidgetSnapshotStore.load()
        let entries = (0..<8).map { offset in
            TimelogTodayEntry(
                date: Calendar.current.date(byAdding: .minute, value: offset * 15, to: now) ?? now,
                snapshot: snapshot
            )
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct TimelogTodayEntry: TimelineEntry {
    let date: Date
    let snapshot: TimelogWidgetSnapshot
}

// MARK: - View

struct TimelogTodayEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TimelogTodayEntry

    private var totalMinutes: Int {
        entry.snapshot.loggedMinutes + activeMinutes
    }

    private var activeMinutes: Int {
        entry.snapshot.activeSessions.reduce(0) {
            $0 + max(0, Int(entry.date.timeIntervalSince($1.startDate) / 60))
        }
    }

    private var isTracking: Bool {
        !entry.snapshot.activeSessions.isEmpty
    }

    private var subtitle: String {
        if let project = entry.snapshot.lastProjectName, !project.isEmpty {
            return project
        }
        if let client = entry.snapshot.lastClientName, !client.isEmpty {
            return client
        }
        return isTracking
            ? String(localized: "Tracking now", bundle: Bundle.module)
            : String(localized: "No entries today", bundle: Bundle.module)
    }

    var body: some View {
        Group {
            switch family {
            case .systemMedium:         medium
            case .systemLarge:          large
            #if os(iOS)
            case .accessoryCircular:    circular
            case .accessoryRectangular: rectangular
            case .accessoryInline:      inline
            #endif
            default:                    small
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: Building blocks

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(String(localized: "Today", bundle: Bundle.module))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            if isTracking {
                Image(systemName: "record.circle.fill")
                    .foregroundStyle(.red)
                    .imageScale(.small)
            }
        }
    }

    private var latestActiveStart: Date? {
        entry.snapshot.activeSessions.map(\.startDate).max()
    }

    private var statusLine: some View {
        Group {
            if let start = latestActiveStart {
                // Text(_, style: .timer) ticks live inside the widget,
                // no timeline refresh needed.
                (Text(start, style: .timer).monospacedDigit()
                 + Text(" ")
                 + Text(String(localized: "active", bundle: Bundle.module)))
            } else {
                Text(String(localized: "Logged", bundle: Bundle.module))
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .multilineTextAlignment(.leading)
    }

    @ViewBuilder
    private func breakdownColumn(maxRows: Int) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            if entry.snapshot.clientBreakdown.isEmpty {
                Text(String(localized: "No entries today", bundle: Bundle.module))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(entry.snapshot.clientBreakdown.prefix(maxRows))) { item in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(hex: item.colorHex) ?? .accentColor)
                            .frame(width: 3, height: 14)
                            .accessibilityHidden(true)
                        Text(item.name)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(item.minutes.formattedDuration)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                let extra = entry.snapshot.clientBreakdown.count - maxRows
                if extra > 0 {
                    Text(String(localized: "+\(extra) more", bundle: Bundle.module))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: System families

    private var small: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow

            Text(totalMinutes.formattedDuration)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.75)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 3) {
                Text(subtitle)
                    .font(.caption)
                    .lineLimit(1)
                statusLine
            }

            Spacer(minLength: 0)
        }
        .padding()
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                headerRow
                Text(totalMinutes.formattedDuration)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                VStack(alignment: .leading, spacing: 3) {
                    Text(subtitle)
                        .font(.caption)
                        .lineLimit(1)
                    statusLine
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            breakdownColumn(maxRows: 3)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding()
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(totalMinutes.formattedDuration)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                statusLine
            }

            Divider()

            breakdownColumn(maxRows: 6)

            Spacer(minLength: 0)
        }
        .padding()
    }

    // MARK: Lock screen accessories (iOS)

    #if os(iOS)
    private var compactTime: String {
        String(format: "%d:%02d", totalMinutes / 60, totalMinutes % 60)
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: isTracking ? "record.circle.fill" : "clock")
                    .font(.caption2)
                Text(compactTime)
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .padding(4)
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text(String(localized: "Today", bundle: Bundle.module))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if isTracking {
                    Image(systemName: "record.circle.fill")
                        .font(.caption2)
                }
            }
            Text(totalMinutes.formattedDuration)
                .font(.headline)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        Label(totalMinutes.formattedDuration,
              systemImage: isTracking ? "record.circle.fill" : "clock")
    }
    #endif
}

// MARK: - Widget

public struct TimelogTodayWidget: Widget {
    public init() {}

    private var families: [WidgetFamily] {
        #if os(iOS)
        [.systemSmall, .systemMedium, .systemLarge,
         .accessoryCircular, .accessoryRectangular, .accessoryInline]
        #else
        [.systemSmall, .systemMedium, .systemLarge]
        #endif
    }

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: TimelogWidgetConstants.kind, provider: TimelogTodayProvider()) { entry in
            TimelogTodayEntryView(entry: entry)
        }
        .configurationDisplayName(String(localized: "Timelog Today", bundle: Bundle.module))
        .description(String(localized: "Shows today's logged time and active tracking.", bundle: Bundle.module))
        .supportedFamilies(families)
    }
}
#endif
