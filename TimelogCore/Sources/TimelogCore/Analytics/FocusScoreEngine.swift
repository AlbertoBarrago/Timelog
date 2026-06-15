import Foundation

public enum FocusScoreEngine {

    /// Calcola il FocusScore per un singolo giorno.
    /// - Parameters:
    ///   - entries: entries del giorno (già filtrate per data dal chiamante)
    ///   - date: data di riferimento per il risultato
    public static func score(for entries: [AnalyticsEntry], date: Date) -> FocusScore {
        guard !entries.isEmpty else {
            return FocusScore(
                date: date, score: 0, avgDurationMinutes: 0,
                deepWorkPercent: 0, shortSessionCount: 0, labelVariety: 0,
                explanation: "No sessions recorded."
            )
        }

        let total = entries.count
        let avgDuration = Double(entries.reduce(0) { $0 + $1.durationMinutes }) / Double(total)
        let deepCount = entries.filter { $0.durationMinutes > 25 }.count
        let deepWorkPct = Double(deepCount) / Double(total) * 100.0
        let shortCount = entries.filter { $0.durationMinutes < 5 }.count
        let labelVariety = Set(entries.compactMap(\.label)).count

        // Score components (max 100):
        // - base:         30 pts always
        // - avgDuration:  up to 40 pts (reference: 90 min = perfect)
        // - deepWork:     up to 30 pts (proportional to ratio)
        // - penalties:    -5 per short session, -3 per label above 2
        let base = 30.0
        let avgComponent = min(40.0, avgDuration / 90.0 * 40.0)
        let deepComponent = min(30.0, deepWorkPct * 0.30)
        let shortPenalty = Double(shortCount) * 5.0
        let switchPenalty = Double(max(0, labelVariety - 2)) * 3.0

        let raw = base + avgComponent + deepComponent - shortPenalty - switchPenalty
        let score = Int(max(0.0, min(100.0, raw.rounded()))  )

        return FocusScore(
            date: date,
            score: score,
            avgDurationMinutes: avgDuration,
            deepWorkPercent: deepWorkPct,
            shortSessionCount: shortCount,
            labelVariety: labelVariety,
            explanation: buildExplanation(
                total: total, deepCount: deepCount,
                shortCount: shortCount, labelVariety: labelVariety,
                avgDuration: avgDuration
            )
        )
    }

    private static func buildExplanation(
        total: Int, deepCount: Int, shortCount: Int,
        labelVariety: Int, avgDuration: Double
    ) -> String {
        var parts: [String] = []

        let avgStr = avgDuration >= 60
            ? String(format: "%.0f h %.0f min", floor(avgDuration / 60), avgDuration.truncatingRemainder(dividingBy: 60))
            : String(format: "%.0f min", avgDuration)
        parts.append("Avg session: \(avgStr).")

        if deepCount > 0 {
            parts.append("\(deepCount) of \(total) sessions in deep focus (>25 min).")
        } else {
            parts.append("No deep focus sessions today.")
        }

        if shortCount > 0 {
            parts.append("\(shortCount) short interruption\(shortCount == 1 ? "" : "s") detected (<5 min).")
        }

        if labelVariety > 3 {
            parts.append("High context switching: \(labelVariety) different labels.")
        }

        return parts.joined(separator: " ")
    }
}
