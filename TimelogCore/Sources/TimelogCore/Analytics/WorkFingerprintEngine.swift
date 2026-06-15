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
                title: String(localized: "The Builder", bundle: .module),
                description: String(localized: "You thrive in long, uninterrupted sessions. Your work is deep and focused, with few context switches.", bundle: .module),
                traits: [
                    String(localized: "Long focus sessions (45+ min)", bundle: .module),
                    String(localized: "Minimal context switching", bundle: .module),
                    String(localized: "High deep work ratio", bundle: .module)
                ]
            )
        case .maker:
            return WorkFingerprint(
                type: .maker,
                title: String(localized: "The Maker", bundle: .module),
                description: String(localized: "You balance steady sessions with creative flexibility. Deep work is important to you, though you adapt across a few areas.", bundle: .module),
                traits: [
                    String(localized: "Consistent session length (30+ min)", bundle: .module),
                    String(localized: "Good deep work ratio", bundle: .module),
                    String(localized: "Moderate label variety", bundle: .module)
                ]
            )
        case .coordinator:
            return WorkFingerprint(
                type: .coordinator,
                title: String(localized: "The Coordinator", bundle: .module),
                description: String(localized: "You manage many moving parts — multiple clients and labels. You're the connective tissue that keeps everything running.", bundle: .module),
                traits: [
                    String(localized: "Many clients and labels", bundle: .module),
                    String(localized: "High cross-domain activity", bundle: .module),
                    String(localized: "Frequent context switching", bundle: .module)
                ]
            )
        case .explorer:
            return WorkFingerprint(
                type: .explorer,
                title: String(localized: "The Explorer", bundle: .module),
                description: String(localized: "You sample broadly across topics and tasks. Your strength is versatility, though longer focus blocks might boost your output.", bundle: .module),
                traits: [
                    String(localized: "High label diversity", bundle: .module),
                    String(localized: "Many short sessions", bundle: .module),
                    String(localized: "Wide range of activity types", bundle: .module)
                ]
            )
        case .balanced:
            return WorkFingerprint(
                type: .balanced,
                title: String(localized: "The Balanced", bundle: .module),
                description: String(localized: "Your work style is well-rounded — a healthy mix of focus and flexibility across your tracked activities.", bundle: .module),
                traits: [
                    String(localized: "Moderate session length", bundle: .module),
                    String(localized: "Balanced context switching", bundle: .module),
                    String(localized: "Steady across clients and labels", bundle: .module)
                ]
            )
        }
    }
}
