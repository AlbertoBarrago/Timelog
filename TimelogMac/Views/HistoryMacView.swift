import SwiftData
import SwiftUI
import TimelogCore

struct HistoryMacView: View {
    @Environment(\.modelContext) private var context
    @Environment(SettingsStore.self) private var settings
    @Query(filter: #Predicate<TimeEntry> { $0.deletedAt == nil }, sort: \TimeEntry.date, order: .reverse) private var allEntries: [TimeEntry]

    @State private var selectedDate = Date()
    @State private var entryToEdit: TimeEntry?
    @State private var bubblePeriod: BubblePeriod = .week
    @State private var isChartExpanded = false

    // MARK: - Computed

    private var userEntries: [TimeEntry] {
        allEntries.filter { $0.userId == settings.userId }
    }

    private var entries: [TimeEntry] {
        userEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    // MARK: - Chart data

    private var periodEntries: [TimeEntry] {
        let cal = Calendar.current
        switch bubblePeriod {
        case .week:
            guard let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)) else { return userEntries }
            let end = cal.date(byAdding: .day, value: 7, to: start) ?? .distantFuture
            return userEntries.filter { $0.date >= start && $0.date < end }
        case .month:
            let comps = cal.dateComponents([.year, .month], from: selectedDate)
            guard let start = cal.date(from: comps),
                  let end = cal.date(byAdding: .month, value: 1, to: start) else { return userEntries }
            return userEntries.filter { $0.date >= start && $0.date < end }
        case .allTime:
            return userEntries
        }
    }

    private var projectBubbles: [ProjectBubble] {
        var acc: [String: ProjectBubble] = [:]
        var clientMap: [String: String] = [:]

        for entry in periodEntries {
            let key: String = {
                if let proj = entry.project { return proj.mongoId ?? "local_\(proj.name)" }
                return "_none_"
            }()
            if acc[key] == nil {
                let baseColor: Color = key == "_none_"
                    ? Color.gray.opacity(0.55)
                    : (entry.client?.color ?? Color.secondary.opacity(0.6))
                acc[key] = ProjectBubble(
                    id: key,
                    name: entry.project?.name ?? String(localized: "No project"),
                    color: baseColor,
                    minutes: 0
                )
                clientMap[key] = entry.client?.mongoId ?? entry.client?.name ?? "_no_client_"
            }
            if var b = acc[key] {
                b.minutes += entry.durationMinutes
                acc[key] = b
            }
        }

        var sorted = acc.values.sorted { $0.minutes > $1.minutes }

        var clientIndices: [String: [Int]] = [:]
        for (i, bubble) in sorted.enumerated() {
            guard bubble.id != "_none_" else { continue }
            let clientKey = clientMap[bubble.id] ?? "_no_client_"
            clientIndices[clientKey, default: []].append(i)
        }
        for indices in clientIndices.values where indices.count > 1 {
            for (pos, idx) in indices.enumerated() {
                sorted[idx].color = colorVariant(base: sorted[idx].color, index: pos, total: indices.count)
            }
        }

        return sorted
    }

    private func colorVariant(base: Color, index: Int, total: Int) -> Color {
        guard index > 0, total > 1 else { return base }
        guard let ns = NSColor(base).usingColorSpace(.sRGB) else { return base }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let newH = (h + 25.0 / 360.0 * CGFloat(index)).truncatingRemainder(dividingBy: 1.0)
        return Color(nsColor: NSColor(hue: newH, saturation: s, brightness: b, alpha: a))
    }

    private var totalMinutes: Int {
        entries.reduce(0) { $0 + $1.durationMinutes }
    }

    // MARK: - Weekly chart

    private var weekDays: [Date] {
        let cal = Calendar.current
        guard let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))
        else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private func minutesForDay(_ date: Date) -> Int {
        allEntries
            .filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    private var maxWeekMinutes: Int {
        weekDays.map { minutesForDay($0) }.max() ?? 0
    }

    // MARK: - Grouped entries

    private struct ClientGroup: Identifiable {
        let id: String
        let clientName: String
        let color: Color
        var entries: [TimeEntry]
        var total: Int { entries.reduce(0) { $0 + $1.durationMinutes } }
    }

    private var groupedEntries: [ClientGroup] {
        var dict: [String: ClientGroup] = [:]
        for entry in entries {
            let key   = entry.client?.name ?? ""
            let name  = entry.client?.name ?? "No client"
            let color = entry.client?.color ?? Color.secondary.opacity(0.5)
            if dict[key] == nil {
                dict[key] = ClientGroup(id: key, clientName: name, color: color, entries: [])
            }
            dict[key]!.entries.append(entry)
        }
        return dict.values.sorted { $0.total > $1.total }
    }

    // MARK: - Body

    var body: some View {
        List {
            // Header: date nav + total
            Section {
                HStack(alignment: .center, spacing: 12) {
                    DateNavControl(date: $selectedDate)
                    Spacer()
                    if totalMinutes > 0 {
                        Text(totalMinutes.formattedDuration)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .monospacedDigit()
                    }
                }
                .padding(.vertical, 4)

                WeeklyBarChart(
                    weekDays: weekDays,
                    selectedDate: selectedDate,
                    minutesForDay: minutesForDay,
                    maxMinutes: maxWeekMinutes
                ) { selectedDate = $0 }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            // Accordion: hours per project
            Section {
                DisclosureGroup(isExpanded: $isChartExpanded) {
                    Picker("", selection: $bubblePeriod) {
                        ForEach(BubblePeriod.allCases) { p in
                            Text(p.localizedLabel).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.top, 4)

                    DonutChartView(bubbles: projectBubbles)
                } label: {
                    Text(String(localized: "Hours by project"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            // Entries grouped by client
            if entries.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                            Text("No entries")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("Pick another day to review logged time.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 32)
                        Spacer()
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(groupedEntries) { group in
                    Section {
                        ForEach(group.entries) { entry in
                            HistoryMacRow(entry: entry)
                                .contentShape(Rectangle())
                                .onTapGesture { entryToEdit = entry }
                                .contextMenu {
                                    Button("Edit") { entryToEdit = entry }
                                    Divider()
                                    Button("Delete", role: .destructive) {
                                        entry.deletedAt = .now
                                        try? context.save()
                                    }
                                }
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(group.color)
                                .frame(width: 8, height: 8)
                            Text(group.clientName)
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text(group.total.formattedDuration)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
        .navigationTitle("History")
        .sheet(item: $entryToEdit) { QuickLogMacView(entry: $0) }
    }

}

// MARK: - Weekly Bar Chart

private struct WeeklyBarChart: View {
    let weekDays: [Date]
    let selectedDate: Date
    let minutesForDay: (Date) -> Int
    let maxMinutes: Int
    let onSelect: (Date) -> Void

    private let maxBarHeight: CGFloat = 36

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(weekDays, id: \.self) { date in
                DayBar(
                    date: date,
                    minutes: minutesForDay(date),
                    maxMinutes: maxMinutes,
                    maxBarHeight: maxBarHeight,
                    isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                    isFuture: date > Calendar.current.startOfDay(for: Date()),
                    onSelect: onSelect
                )
            }
        }
        .frame(height: maxBarHeight + 28)
    }
}

private struct DayBar: View {
    let date: Date
    let minutes: Int
    let maxMinutes: Int
    let maxBarHeight: CGFloat
    let isSelected: Bool
    let isFuture: Bool
    let onSelect: (Date) -> Void

    private var barHeight: CGFloat {
        guard maxMinutes > 0, minutes > 0 else { return 3 }
        return max(4, CGFloat(minutes) / CGFloat(maxMinutes) * maxBarHeight)
    }

    private var barColor: Color {
        if isSelected  { return .accentColor }
        if isFuture    { return Color.secondary.opacity(0.1) }
        if minutes > 0 { return Color.accentColor.opacity(0.28) }
        return Color.secondary.opacity(0.13)
    }

    var body: some View {
        Button { if !isFuture { onSelect(date) } } label: {
            VStack(spacing: 4) {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: 3)
                    .fill(barColor)
                    .frame(height: barHeight)
                    .animation(.easeOut(duration: 0.15), value: barHeight)
                Text(date.formatted(.dateTime.weekday(.narrow)))
                    .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(
                        isSelected ? Color.accentColor
                        : isFuture  ? Color.secondary.opacity(0.35)
                        : .secondary
                    )
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }
}

// MARK: - Row

private struct HistoryMacRow: View {
    let entry: TimeEntry
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(entry.client?.color ?? Color.secondary.opacity(0.3))
                .frame(width: 4, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                if let project = entry.project {
                    HStack(spacing: 4) {
                        Text(project.name).fontWeight(.medium)
                        if let label = entry.label {
                            Text(label)
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                } else if let notes = entry.notes, !notes.isEmpty {
                    Text(notes).fontWeight(.medium).lineLimit(1)
                } else {
                    Text(entry.client?.name ?? "No client").fontWeight(.medium)
                }
                if entry.project != nil, let notes = entry.notes, !notes.isEmpty {
                    Text(notes).font(.caption).foregroundStyle(.secondary).lineLimit(1)
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

// MARK: - Date Nav Control

private struct DateNavControl: View {
    @Binding var date: Date
    private let cal = Calendar.current

    private var isToday: Bool { cal.isDateInToday(date) }

    var body: some View {
        HStack(spacing: 0) {
            Button { step(-1) } label: {
                Image(systemName: "chevron.left")
                    .imageScale(.small)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel(Text("Previous day"))

            Text(date, format: .dateTime.weekday(.abbreviated).day().month(.wide).year())
                .font(.system(.body, weight: .medium))
                .frame(minWidth: 200, alignment: .center)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.12), value: date)

            Button { step(+1) } label: {
                Image(systemName: "chevron.right")
                    .imageScale(.small)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(isToday)
            .accessibilityLabel(Text("Next day"))

            if !isToday {
                Button(String(localized: "Today")) { date = .now }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.leading, 8)
            }
        }
    }

    private func step(_ days: Int) {
        if let next = cal.date(byAdding: .day, value: days, to: date) {
            let cap = cal.startOfDay(for: .now).addingTimeInterval(86400)
            date = min(next, cap)
        }
    }
}
