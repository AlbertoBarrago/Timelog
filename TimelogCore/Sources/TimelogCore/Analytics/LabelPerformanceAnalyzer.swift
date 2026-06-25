import Foundation

public enum LabelPerformanceAnalyzer {

    static let unlabeledKey = "Unlabeled"

    /// Analyzes performance for each label/category in the provided entries.
    /// Entries without a label are grouped under "Unlabeled".
    /// - Returns: insights sorted by descending totalMinutes.
    public static func analyze(
        entries: [AnalyticsEntry],
        calendar: Calendar = .current
    ) -> [LabelInsight] {
        // Group by label.
        var totalByLabel: [String: Int] = [:]
        var countByLabel: [String: Int] = [:]
        var hourDistByLabel: [String: [Int: Int]] = [:]

        for entry in entries {
            let key = entry.label ?? unlabeledKey
            let hour = calendar.component(.hour, from: entry.date)

            totalByLabel[key, default: 0] += entry.durationMinutes
            countByLabel[key, default: 0] += 1
            hourDistByLabel[key, default: [:]][hour, default: 0] += entry.durationMinutes
        }

        return totalByLabel.map { label, total in
            let count = countByLabel[label] ?? 1
            let hourDist = hourDistByLabel[label] ?? [:]
            let peakHour = hourDist.max { $0.value < $1.value }?.key
            return LabelInsight(
                label: label,
                totalMinutes: total,
                sessionCount: count,
                avgDurationMinutes: Double(total) / Double(count),
                peakHour: peakHour,
                hourDistribution: hourDist
            )
        }
        .sorted { $0.totalMinutes > $1.totalMinutes }
    }
}
