import SwiftUI
import SwiftData
import Charts
import TimelogCore

struct InsightsView: View {
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

    private var analyticsRefreshToken: Int {
        AnalyticsRefreshToken.make(for: analyticsEntries)
    }

    var body: some View {
        NavigationStack {
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
                                WorkFingerprintCard(fingerprint: fp)
                            }
                            if !service.focusScores.isEmpty {
                                FocusScoreCard(scores: service.focusScores)
                            }
                            if let review = service.weeklyReview {
                                WeeklyReviewCard(review: review)
                            }
                            if !service.heatmapCells.isEmpty {
                                ProductivityHeatmapCard(cells: service.heatmapCells)
                            }
                            if !service.labelInsights.isEmpty {
                                LabelPerformanceCard(insights: service.labelInsights)
                            }
                            if !service.timeLeaks.isEmpty {
                                TimeLeakCard(leaks: service.timeLeaks)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Stats")
            .overlay(alignment: .top) {
                if service.isComputing {
                    ProgressView()
                        .padding(.top, 8)
                }
            }
            .task(id: analyticsRefreshToken) {
                await service.recompute(entries: analyticsEntries)
            }
        }
    }
}

// MARK: - Work Fingerprint Card

private struct WorkFingerprintCard: View {
    let fingerprint: WorkFingerprint

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(fingerprint.title, systemImage: "person.crop.circle.badge.checkmark")
                    .font(.headline)
                Spacer()
                Text(fingerprint.type.rawValue.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(Capsule())
            }
            Text(fingerprint.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(fingerprint.traits, id: \.self) { trait in
                    Label(trait, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Work fingerprint: \(fingerprint.title). \(fingerprint.description)")
    }
}

// MARK: - Focus Score Card

private struct FocusScoreCard: View {
    let scores: [FocusScore]

    private var recent: [FocusScore] { Array(scores.prefix(7)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Focus Score — Last 7 Days", systemImage: "brain.head.profile")
                .font(.headline)

            Chart(recent) { score in
                BarMark(
                    x: .value("Day", score.date, unit: .day),
                    y: .value("Score", score.score)
                )
                .foregroundStyle(barColor(score.score))
                .cornerRadius(4)
                .accessibilityLabel("\(dayLabel(score.date)): \(score.score) points")
            }
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .frame(height: 140)

            if let today = scores.first(where: { Calendar.current.isDateInToday($0.date) }) {
                Text(today.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func barColor(_ score: Int) -> Color {
        switch score {
        case 70...100: return .green
        case 40..<70:  return .orange
        default:       return .red.opacity(0.7)
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }
}

// MARK: - Weekly Review Card

private struct WeeklyReviewCard: View {
    let review: WeeklyReview

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Weekly Review", systemImage: "calendar.badge.clock")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                StatCell(label: "Total hours", value: formatHours(review.totalMinutes))
                StatCell(label: "Best day", value: formatDay(review.bestDay))
                if let label = review.mostActiveLabel {
                    StatCell(label: "Top label", value: label)
                }
                if let client = review.mostActiveClientName {
                    StatCell(label: "Top client", value: client)
                }
                if let session = review.longestSession {
                    StatCell(label: "Longest session", value: formatMinutes(session.durationMinutes))
                }
                if let trend = review.trendPercent {
                    StatCell(
                        label: "vs last week",
                        value: String(format: "%+.0f%%", trend),
                        valueColor: trend >= 0 ? .green : .red
                    )
                }
            }

            Text(review.improvementTip)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(10)
                .background(Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatHours(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 { return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
        return "\(m)m"
    }

    private func formatMinutes(_ minutes: Int) -> String {
        minutes >= 60 ? String(format: "%.0fh %.0fm", Double(minutes / 60), Double(minutes % 60)) : "\(minutes)m"
    }

    private func formatDay(_ date: Date?) -> String {
        guard let date else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "EEE d"
        return f.string(from: date)
    }
}

private struct StatCell: View {
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
    }
}

// MARK: - Productivity Heatmap Card

private struct ProductivityHeatmapCard: View {
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
        VStack(alignment: .leading, spacing: 12) {
            Label("Peak Hours", systemImage: "clock.fill")
                .font(.headline)

            Chart(byHour) { bucket in
                BarMark(
                    x: .value("Hour", bucket.hour),
                    y: .value("Avg session", bucket.avgMinutes)
                )
                .foregroundStyle(Color.accentColor.gradient)
                .cornerRadius(3)
                .accessibilityLabel("\(hourLabel(bucket.hour)): avg \(bucket.avgMinutes) min, \(bucket.sessionCount) sessions")
            }
            .chartXAxis {
                AxisMarks(values: [6, 9, 12, 15, 18, 21]) { value in
                    AxisValueLabel {
                        Text(hourLabel(value.as(Int.self) ?? 0)).font(.caption2)
                    }
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
            .frame(height: 120)

            Text("Avg session length by hour of day")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Label Performance Card

private struct LabelPerformanceCard: View {
    let insights: [LabelInsight]

    private var top: [LabelInsight] { Array(insights.prefix(6)) }

    private var maxMinutes: Int {
        top.map(\.totalMinutes).max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Label Breakdown", systemImage: "tag.fill")
                .font(.headline)

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
                .accessibilityLabel("\(insight.label): \(formatMinutes(insight.totalMinutes)), \(insight.sessionCount) sessions")
            }
            .chartXAxis(.hidden)
            .frame(height: CGFloat(top.count) * 36)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatMinutes(_ minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60)h" : "\(minutes)m"
    }
}

// MARK: - Time Leak Card

private struct TimeLeakCard: View {
    let leaks: [TimeLeakInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Time Leaks", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            ForEach(leaks) { leak in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(leak.name)
                            .font(.subheadline)
                        Text(leak.kind == .client ? LocalizedStringKey("Client") : LocalizedStringKey("Label"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(String(format: "+%.0f%%", leak.deltaPercent))
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(leak.name): \(Int(leak.deltaPercent.rounded()))% more time than baseline")

                if leak.id != leaks.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
