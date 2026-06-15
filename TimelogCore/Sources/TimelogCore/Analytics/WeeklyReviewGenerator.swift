import Foundation

public enum WeeklyReviewGenerator {

    /// Genera il report settimanale.
    /// - Parameters:
    ///   - currentWeek: entries della settimana target
    ///   - previousWeek: entries della settimana precedente (per calcolare il trend)
    ///   - weekStart: inizio della settimana corrente
    public static func generate(
        currentWeek: [AnalyticsEntry],
        previousWeek: [AnalyticsEntry],
        weekStart: Date,
        calendar: Calendar = .current
    ) -> WeeklyReview {
        let totalMinutes = currentWeek.reduce(0) { $0 + $1.durationMinutes }
        let prevTotal = previousWeek.reduce(0) { $0 + $1.durationMinutes }

        let mostActiveLabel = topKey(entries: currentWeek, key: { $0.label })
        let mostActiveClientName = topClientName(entries: currentWeek)
        let longestSession = currentWeek.max { $0.durationMinutes < $1.durationMinutes }
        let bestDay = bestDayDate(entries: currentWeek, calendar: calendar)
        let trendPercent: Double? = prevTotal > 0
            ? Double(totalMinutes - prevTotal) / Double(prevTotal) * 100.0
            : nil

        let tip = improvementTip(
            entries: currentWeek,
            trendPercent: trendPercent,
            calendar: calendar
        )

        return WeeklyReview(
            weekStart: weekStart,
            totalMinutes: totalMinutes,
            mostActiveLabel: mostActiveLabel,
            mostActiveClientName: mostActiveClientName,
            longestSession: longestSession,
            bestDay: bestDay,
            trendPercent: trendPercent,
            improvementTip: tip
        )
    }

    // MARK: - Private helpers

    private static func topKey(entries: [AnalyticsEntry], key: (AnalyticsEntry) -> String?) -> String? {
        var totals: [String: Int] = [:]
        for entry in entries {
            guard let k = key(entry) else { continue }
            totals[k, default: 0] += entry.durationMinutes
        }
        return totals.max { $0.value < $1.value }?.key
    }

    private static func topClientName(entries: [AnalyticsEntry]) -> String? {
        var totals: [String: (name: String, minutes: Int)] = [:]
        for entry in entries {
            guard let id = entry.clientId, let name = entry.clientName else { continue }
            let current = totals[id] ?? (name: name, minutes: 0)
            totals[id] = (name: name, minutes: current.minutes + entry.durationMinutes)
        }
        return totals.max { $0.value.minutes < $1.value.minutes }?.value.name
    }

    private static func bestDayDate(entries: [AnalyticsEntry], calendar: Calendar) -> Date? {
        var byDay: [Date: Int] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            byDay[day, default: 0] += entry.durationMinutes
        }
        return byDay.max { $0.value < $1.value }?.key
    }

    private static func improvementTip(
        entries: [AnalyticsEntry],
        trendPercent: Double?,
        calendar: Calendar
    ) -> String {
        let labelVariety = Set(entries.compactMap(\.label)).count
        let shortCount = entries.filter { $0.durationMinutes < 5 }.count

        if let trend = trendPercent, trend < -10 {
            return "You tracked less time than last week. Check if any sessions were missed."
        }
        if shortCount > 3 {
            return "You had \(shortCount) very short sessions this week. Try protecting longer focus blocks."
        }
        if labelVariety > 4 {
            return "You switched between \(labelVariety) labels this week. Batching similar work can reduce context switching."
        }
        if let trend = trendPercent, trend > 20 {
            return "Great week — you tracked \(Int(trend.rounded()))% more than last week. Keep the momentum."
        }
        return "Consistent work is the foundation of productivity. Keep tracking!"
    }
}
