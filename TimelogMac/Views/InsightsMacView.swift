import SwiftUI
import SwiftData
import Charts
import TimelogCore

struct InsightsMacView: View {
    @Environment(SettingsStore.self) private var settings
    @Query(filter: #Predicate<TimeEntry> { $0.deletedAt == nil },
           sort: \TimeEntry.date, order: .reverse) private var allEntries: [TimeEntry]

    @State private var service = BehavioralInsightsService()

    private var userEntries: [TimeEntry] {
        allEntries.filter { $0.userId == settings.userId }
    }

    private var analyticsEntries: [AnalyticsEntry] {
        userEntries.map { $0.toAnalyticsEntry() }
    }

    var body: some View {
        Group {
            if userEntries.count < 5 {
                ContentUnavailableView(
                    "Not enough data",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Track at least 5 sessions to see your behavioral insights.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if let fp = service.workFingerprint {
                            InsightCard(title: "Work Style", icon: "person.crop.circle.badge.checkmark") {
                                WorkFingerprintRow(fingerprint: fp)
                            }
                        }
                        if !service.focusScores.isEmpty {
                            InsightCard(title: "Focus Score — Last 7 Days", icon: "brain.head.profile") {
                                FocusScoreChartRow(scores: service.focusScores)
                            }
                        }
                        if let review = service.weeklyReview {
                            InsightCard(title: "Weekly Review", icon: "calendar.badge.clock") {
                                WeeklyReviewRows(review: review)
                            }
                        }
                        if !service.heatmapCells.isEmpty {
                            InsightCard(title: "Peak Hours", icon: "clock.fill") {
                                HeatmapChartRow(cells: service.heatmapCells)
                            }
                        }
                        if !service.labelInsights.isEmpty {
                            InsightCard(title: "Label Breakdown", icon: "tag.fill") {
                                LabelChartRow(insights: service.labelInsights)
                            }
                        }
                        if !service.timeLeaks.isEmpty {
                            InsightCard(title: "Time Leaks", icon: "exclamationmark.triangle.fill", tint: .orange) {
                                ForEach(service.timeLeaks) { leak in
                                    TimeLeakRow(leak: leak)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Stats")
        .navigationSubtitle(service.isComputing ? String(localized: "Computing…") : "")
        .task(id: userEntries.count) {
            await service.recompute(entries: analyticsEntries)
        }
    }
}

// MARK: - Shared card container

private struct InsightCard<Content: View>: View {
    let title: LocalizedStringKey
    let icon: String
    var tint: Color = .accentColor
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(tint)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Work Fingerprint Row

private struct WorkFingerprintRow: View {
    let fingerprint: WorkFingerprint

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(fingerprint.title)
                    .font(.subheadline.bold())
                Spacer()
                Text(fingerprint.type.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
            }
            Text(fingerprint.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(fingerprint.traits, id: \.self) { trait in
                    Label(trait, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Work fingerprint \(fingerprint.title): \(fingerprint.description)")
    }
}

// MARK: - Focus Score Chart Row

private struct FocusScoreChartRow: View {
    let scores: [FocusScore]

    private var recent: [FocusScore] { Array(scores.prefix(7)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart(recent) { score in
                BarMark(
                    x: .value("Day", score.date, unit: .day),
                    y: .value("Score", score.score)
                )
                .foregroundStyle(barColor(score.score))
                .cornerRadius(4)
            }
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .frame(height: 120)

            if let today = scores.first(where: { Calendar.current.isDateInToday($0.date) }) {
                Text(today.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func barColor(_ score: Int) -> Color {
        switch score {
        case 70...100: return .green
        case 40..<70:  return .orange
        default:       return .red.opacity(0.7)
        }
    }
}

// MARK: - Weekly Review Rows

private struct WeeklyReviewRows: View {
    let review: WeeklyReview

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MacStatCell(label: "Total hours", value: formatHours(review.totalMinutes))
                if let day = review.bestDay {
                    MacStatCell(label: "Best day", value: formatDay(day))
                }
                if let label = review.mostActiveLabel {
                    MacStatCell(label: "Top label", value: label)
                }
                if let client = review.mostActiveClientName {
                    MacStatCell(label: "Top client", value: client)
                }
                if let session = review.longestSession {
                    MacStatCell(label: "Longest session", value: formatMinutes(session.durationMinutes))
                }
                if let trend = review.trendPercent {
                    MacStatCell(label: "vs last week",
                                value: String(format: "%+.0f%%", trend),
                                valueColor: trend >= 0 ? .green : .red)
                }
            }
            Text(review.improvementTip)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
    }

    private func formatHours(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h > 0 { return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
        return "\(m)m"
    }

    private func formatMinutes(_ minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    private func formatDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE d MMM"
        return f.string(from: date)
    }
}

private struct MacStatCell: View {
    let label: LocalizedStringKey
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Heatmap Chart Row

private struct HeatmapChartRow: View {
    let cells: [HeatmapProductivityCell]

    private struct HourBucket: Identifiable {
        let hour: Int
        let avgMinutes: Int
        let sessionCount: Int
        var id: Int { hour }
    }

    private var byHour: [HourBucket] {
        var minuteMap: [Int: Int] = [:]
        var countMap: [Int: Int] = [:]
        for cell in cells {
            minuteMap[cell.hour, default: 0] += cell.totalMinutes
            countMap[cell.hour, default: 0] += cell.sessionCount
        }
        return minuteMap.compactMap { hour, total -> HourBucket? in
            let count = countMap[hour] ?? 0
            guard count > 0 else { return nil }
            return HourBucket(hour: hour, avgMinutes: total / count, sessionCount: count)
        }.sorted { $0.hour < $1.hour }
    }

    private func hourLabel(_ h: Int) -> String {
        h == 0 ? "12am" : h < 12 ? "\(h)am" : h == 12 ? "12pm" : "\(h - 12)pm"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Chart(byHour) { bucket in
                BarMark(
                    x: .value("Hour", bucket.hour),
                    y: .value("Avg session", bucket.avgMinutes)
                )
                .foregroundStyle(Color.accentColor.gradient)
                .cornerRadius(3)
                .accessibilityLabel("\(hourLabel(bucket.hour)): avg \(bucket.avgMinutes) min")
            }
            .chartXAxis {
                AxisMarks(values: [6, 9, 12, 15, 18, 21]) { value in
                    AxisValueLabel { Text(hourLabel(value.as(Int.self) ?? 0)).font(.caption2) }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
                    AxisValueLabel {
                        let m = value.as(Int.self) ?? 0
                        Text(m >= 60 ? "\(m / 60)h" : "\(m)m").font(.caption2)
                    }
                }
            }
            .chartPlotStyle { plot in
                plot.padding(.trailing, 20)
            }
            .frame(height: 100)

            Text("Avg session length by hour of day")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Label Chart Row

private struct LabelChartRow: View {
    let insights: [LabelInsight]

    private var top: [LabelInsight] { Array(insights.prefix(8)) }

    private func formatMinutes(_ minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    var body: some View {
        Chart(top) { insight in
            BarMark(
                x: .value("Minutes", insight.totalMinutes),
                y: .value("Label", insight.label)
            )
            .cornerRadius(4)
            .foregroundStyle(Color.accentColor.gradient)
            .annotation(position: .trailing, alignment: .leading, spacing: 6) {
                Text(formatMinutes(insight.totalMinutes))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("\(insight.label): \(formatMinutes(insight.totalMinutes))")
        }
        .chartXAxis(.hidden)
        .frame(height: CGFloat(top.count) * 28)
    }
}

// MARK: - Time Leak Row

private struct TimeLeakRow: View {
    let leak: TimeLeakInsight

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(leak.name)
                    .font(.body)
                Text(leak.kind == .client ? LocalizedStringKey("Client") : LocalizedStringKey("Label"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(String(format: "+%.0f%%", leak.deltaPercent))
                .font(.subheadline.bold())
                .foregroundStyle(.orange)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(leak.name): \(Int(leak.deltaPercent.rounded()))% more time than baseline")
    }
}

// MARK: - TimeEntry conversion

extension TimeEntry {
    func toAnalyticsEntry() -> AnalyticsEntry {
        AnalyticsEntry(
            date: date,
            durationMinutes: durationMinutes,
            label: label,
            clientId: client?.mongoId ?? client?.name,
            clientName: client?.name,
            projectId: project?.mongoId ?? project?.name,
            projectName: project?.name
        )
    }
}
