import Foundation

public enum WorkFingerprintEngine {

    /// Classifica il work style dell'utente su un periodo significativo.
    /// - Parameter entries: entries del periodo (consigliati almeno 30 gg)
    /// - Returns: `nil` se le entries sono vuote
    public static func fingerprint(
        entries: [AnalyticsEntry],
        calendar: Calendar = .current
    ) -> WorkFingerprint? {
        guard !entries.isEmpty else { return nil }

        let total = Double(entries.count)
        let avgDuration = Double(entries.reduce(0) { $0 + $1.durationMinutes }) / total
        let distinctClients = Set(entries.compactMap(\.clientId)).count
        let distinctLabels = Set(entries.compactMap(\.label)).count
        let deepWorkRatio = Double(entries.filter { $0.durationMinutes > 25 }.count) / total
        let shortSessionRatio = Double(entries.filter { $0.durationMinutes < 5 }.count) / total

        let type = classify(
            avgDuration: avgDuration,
            distinctClients: distinctClients,
            distinctLabels: distinctLabels,
            deepWorkRatio: deepWorkRatio,
            shortSessionRatio: shortSessionRatio
        )

        return makeFingerprint(type: type)
    }

    private static func classify(
        avgDuration: Double,
        distinctClients: Int,
        distinctLabels: Int,
        deepWorkRatio: Double,
        shortSessionRatio: Double
    ) -> WorkFingerprintType {
        if avgDuration > 45, distinctLabels <= 3, deepWorkRatio > 0.5 {
            return .builder
        }
        if distinctClients >= 4, distinctLabels >= 4 {
            return .coordinator
        }
        if shortSessionRatio > 0.3 || distinctLabels > 6 {
            return .explorer
        }
        if avgDuration > 30, deepWorkRatio > 0.4 {
            return .maker
        }
        return .balanced
    }

    private static func makeFingerprint(type: WorkFingerprintType) -> WorkFingerprint {
        switch type {
        case .builder:
            return WorkFingerprint(
                type: .builder,
                title: "The Builder",
                description: "You thrive in long, uninterrupted sessions. Your work is deep and focused, with few context switches.",
                traits: ["Long focus sessions (45+ min)", "Minimal context switching", "High deep work ratio"]
            )
        case .maker:
            return WorkFingerprint(
                type: .maker,
                title: "The Maker",
                description: "You balance steady sessions with creative flexibility. Deep work is important to you, though you adapt across a few areas.",
                traits: ["Consistent session length (30+ min)", "Good deep work ratio", "Moderate label variety"]
            )
        case .coordinator:
            return WorkFingerprint(
                type: .coordinator,
                title: "The Coordinator",
                description: "You manage many moving parts — multiple clients and labels. You're the connective tissue that keeps everything running.",
                traits: ["Many clients and labels", "High cross-domain activity", "Frequent context switching"]
            )
        case .explorer:
            return WorkFingerprint(
                type: .explorer,
                title: "The Explorer",
                description: "You sample broadly across topics and tasks. Your strength is versatility, though longer focus blocks might boost your output.",
                traits: ["High label diversity", "Many short sessions", "Wide range of activity types"]
            )
        case .balanced:
            return WorkFingerprint(
                type: .balanced,
                title: "The Balanced",
                description: "Your work style is well-rounded — a healthy mix of focus and flexibility across your tracked activities.",
                traits: ["Moderate session length", "Balanced context switching", "Steady across clients and labels"]
            )
        }
    }
}
