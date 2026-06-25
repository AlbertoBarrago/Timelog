import Foundation

public enum TimeLeakDetector {

    /// Identifies labels/clients that consume significantly more time than the baseline.
    /// - Parameters:
    ///   - recentEntries: entries from the last 7 days
    ///   - baselineEntries: entries from the previous 28 days, normalized to 7 days internally
    ///   - minimumBaselineMinutes: minimum baseline minutes required to consider a candidate
    public static func detect(
        recentEntries: [AnalyticsEntry],
        baselineEntries: [AnalyticsEntry],
        minimumBaselineMinutes: Int = 30
    ) -> [TimeLeakInsight] {
        var insights: [TimeLeakInsight] = []

        // Group by client.
        let recentByClient = groupMinutes(entries: recentEntries, key: { $0.clientId.map { "\($0)" } })
        let baselineByClient = groupMinutes(entries: baselineEntries, key: { $0.clientId.map { "\($0)" } })
        var clientNames: [String: String] = [:]
        for entry in recentEntries {
            if let id = entry.clientId, let name = entry.clientName {
                clientNames[id] = name
            }
        }

        for (key, currentMin) in recentByClient {
            guard let baselineTotal = baselineByClient[key] else { continue }
            let baselineWeekly = baselineTotal / 4
            guard baselineWeekly >= minimumBaselineMinutes else { continue }
            let delta = Double(currentMin - baselineWeekly) / Double(baselineWeekly) * 100.0
            guard delta > 20.0 else { continue }
            let name = clientNames[key] ?? key
            insights.append(TimeLeakInsight(
                id: "client-\(key)", kind: .client, name: name,
                currentMinutes: currentMin, baselineMinutes: baselineWeekly, deltaPercent: delta
            ))
        }

        // Group by label.
        let recentByLabel = groupMinutes(entries: recentEntries, key: { $0.label })
        let baselineByLabel = groupMinutes(entries: baselineEntries, key: { $0.label })

        for (key, currentMin) in recentByLabel {
            guard let baselineTotal = baselineByLabel[key] else { continue }
            let baselineWeekly = baselineTotal / 4
            guard baselineWeekly >= minimumBaselineMinutes else { continue }
            let delta = Double(currentMin - baselineWeekly) / Double(baselineWeekly) * 100.0
            guard delta > 20.0 else { continue }
            insights.append(TimeLeakInsight(
                id: "label-\(key)", kind: .label, name: key,
                currentMinutes: currentMin, baselineMinutes: baselineWeekly, deltaPercent: delta
            ))
        }

        return Array(insights.sorted { $0.deltaPercent > $1.deltaPercent }.prefix(5))
    }

    private static func groupMinutes(
        entries: [AnalyticsEntry],
        key: (AnalyticsEntry) -> String?
    ) -> [String: Int] {
        var result: [String: Int] = [:]
        for entry in entries {
            guard let k = key(entry) else { continue }
            result[k, default: 0] += entry.durationMinutes
        }
        return result
    }
}
