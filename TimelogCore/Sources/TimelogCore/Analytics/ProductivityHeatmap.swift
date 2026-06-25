import Foundation

public enum ProductivityHeatmap {

    /// Aggregates entries by (hour of day × weekday).
    /// - Returns: sparse cells (only buckets with at least one session), sorted by (weekday, hour).
    public static func cells(
        entries: [AnalyticsEntry],
        calendar: Calendar = .current
    ) -> [HeatmapProductivityCell] {
        // bucket: (hour, weekday) -> (totalMinutes, sessionCount)
        var buckets: [BucketKey: (minutes: Int, count: Int)] = [:]

        for entry in entries {
            // Entries longer than 8 h are almost certainly forgotten timers;
            // exclude them so they don't collapse the chart scale.
            guard entry.durationMinutes <= 480 else { continue }
            let hour = calendar.component(.hour, from: entry.date)
            let weekday = calendar.component(.weekday, from: entry.date)
            let key = BucketKey(hour: hour, weekday: weekday)
            let current = buckets[key] ?? (minutes: 0, count: 0)
            buckets[key] = (current.minutes + entry.durationMinutes, current.count + 1)
        }

        return buckets
            .map { key, value in
                HeatmapProductivityCell(
                    hour: key.hour,
                    weekday: key.weekday,
                    totalMinutes: value.minutes,
                    sessionCount: value.count
                )
            }
            .sorted { lhs, rhs in
                lhs.weekday != rhs.weekday ? lhs.weekday < rhs.weekday : lhs.hour < rhs.hour
            }
    }

    private struct BucketKey: Hashable {
        let hour: Int
        let weekday: Int
    }
}
