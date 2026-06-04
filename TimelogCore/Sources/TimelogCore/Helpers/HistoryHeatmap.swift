import Foundation

/// One calendar day in the History contribution heatmap.
public struct HeatmapDay: Identifiable, Sendable, Equatable {
    /// Start-of-day for the represented date.
    public let date: Date
    /// Total minutes logged on this day.
    public let minutes: Int
    /// Identifier of the client with the most minutes this day (`nil` when the
    /// day is empty or the prevailing bucket has no client).
    public let dominantClientId: String?

    public var id: Date { date }

    public init(date: Date, minutes: Int, dominantClientId: String?) {
        self.date = date
        self.minutes = minutes
        self.dominantClientId = dominantClientId
    }
}

/// Pure aggregation for the GitHub-style contribution heatmap.
///
/// Kept free of SwiftData / SwiftUI so it can be unit-tested in isolation; the
/// macOS History view adapts `TimeEntry` values into `Entry` inputs.
public enum HistoryHeatmap {
    public struct Entry: Sendable {
        public let date: Date
        public let clientId: String?
        public let minutes: Int

        public init(date: Date, clientId: String?, minutes: Int) {
            self.date = date
            self.clientId = clientId
            self.minutes = minutes
        }
    }

    /// Builds one `HeatmapDay` for **every** calendar day in `[start, end]`
    /// (inclusive), so the resulting grid is continuous. Days with no entries
    /// yield `minutes == 0` and `dominantClientId == nil`.
    ///
    /// For each day the dominant client is the one with the most summed
    /// minutes; ties break deterministically by client id. A `nil` client id
    /// (entries with no client) participates and can win.
    public static func days(
        entries: [Entry],
        from start: Date,
        to end: Date,
        calendar: Calendar = .current
    ) -> [HeatmapDay] {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        guard startDay <= endDay else { return [] }

        // day -> (clientId -> minutes)
        var buckets: [Date: [String?: Int]] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            guard day >= startDay, day <= endDay else { continue }
            buckets[day, default: [:]][entry.clientId, default: 0] += entry.minutes
        }

        var result: [HeatmapDay] = []
        var cursor = startDay
        while cursor <= endDay {
            if let perClient = buckets[cursor], !perClient.isEmpty {
                let total = perClient.values.reduce(0, +)
                let dominant = perClient.max { lhs, rhs in
                    if lhs.value != rhs.value { return lhs.value < rhs.value }
                    // Deterministic tie-break: nil sorts before any id, then lexicographic.
                    return (lhs.key ?? "") < (rhs.key ?? "")
                }?.key ?? nil
                result.append(HeatmapDay(date: cursor, minutes: total, dominantClientId: dominant))
            } else {
                result.append(HeatmapDay(date: cursor, minutes: 0, dominantClientId: nil))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }
}
