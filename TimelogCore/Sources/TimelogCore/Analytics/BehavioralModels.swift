import Foundation

// MARK: - Input DTO

/// Lightweight mirror of TimeEntry for analytics engines.
/// Kept free of SwiftData / SwiftUI so engines are unit-testable without a ModelContainer.
public struct AnalyticsEntry: Sendable {
    public let date: Date
    public let durationMinutes: Int
    public let label: String?
    public let clientId: String?
    public let clientName: String?
    public let projectId: String?
    public let projectName: String?

    public init(
        date: Date,
        durationMinutes: Int,
        label: String?,
        clientId: String?,
        clientName: String?,
        projectId: String?,
        projectName: String?
    ) {
        self.date = date
        self.durationMinutes = durationMinutes
        self.label = label
        self.clientId = clientId
        self.clientName = clientName
        self.projectId = projectId
        self.projectName = projectName
    }
}

public enum AnalyticsRefreshToken {
    public static func make(for entries: [AnalyticsEntry]) -> Int {
        var hasher = Hasher()
        hasher.combine(entries.count)

        for entry in entries {
            hasher.combine(entry.date.timeIntervalSinceReferenceDate)
            hasher.combine(entry.durationMinutes)
            hasher.combine(entry.label)
            hasher.combine(entry.clientId)
            hasher.combine(entry.clientName)
            hasher.combine(entry.projectId)
            hasher.combine(entry.projectName)
        }

        return hasher.finalize()
    }
}

public enum SyncDataFingerprint {
    public static func make(
        clients: [Client],
        projects: [Project],
        entries: [TimeEntry],
        sessions: [ActiveSession],
        dayReviews: [DayReview] = []
    ) -> Int {
        var hasher = Hasher()
        hasher.combine(clients.count)
        hasher.combine(projects.count)
        hasher.combine(entries.count)
        hasher.combine(sessions.count)
        hasher.combine(dayReviews.count)

        for client in clients {
            hasher.combine(client.mongoId)
            hasher.combine(client.name)
            hasher.combine(client.colorHex)
            hasher.combine(client.isArchived)
            hasher.combine(client.userId)
            hasher.combine(client.deletedAt?.timeIntervalSinceReferenceDate)
        }

        for project in projects {
            hasher.combine(project.mongoId)
            hasher.combine(project.name)
            hasher.combine(project.code)
            hasher.combine(project.client?.mongoId)
            hasher.combine(project.userId)
            hasher.combine(project.deletedAt?.timeIntervalSinceReferenceDate)
            for label in project.labels {
                hasher.combine(label)
            }
        }

        for entry in entries {
            hasher.combine(entry.mongoId)
            hasher.combine(entry.date.timeIntervalSinceReferenceDate)
            hasher.combine(entry.durationMinutes)
            hasher.combine(entry.notes)
            hasher.combine(entry.label)
            hasher.combine(entry.client?.mongoId)
            hasher.combine(entry.project?.mongoId)
            hasher.combine(entry.userId)
            hasher.combine(entry.deletedAt?.timeIntervalSinceReferenceDate)
        }

        for session in sessions {
            hasher.combine(session.mongoId)
            hasher.combine(session.startDate.timeIntervalSinceReferenceDate)
            hasher.combine(session.notes)
            hasher.combine(session.label)
            hasher.combine(session.notificationID)
            hasher.combine(session.client?.mongoId)
            hasher.combine(session.project?.mongoId)
            hasher.combine(session.userId)
        }

        for review in dayReviews {
            hasher.combine(review.mongoId)
            hasher.combine(review.date.timeIntervalSinceReferenceDate)
            hasher.combine(review.mood)
            hasher.combine(review.pressure)
            hasher.combine(review.notes)
            hasher.combine(review.userId)
            hasher.combine(review.deletedAt?.timeIntervalSinceReferenceDate)
        }

        return hasher.finalize()
    }
}

// MARK: - FocusScoreEngine output

public struct FocusScore: Sendable, Identifiable {
    public let date: Date
    public let score: Int
    public let avgDurationMinutes: Double
    public let deepWorkPercent: Double
    public let shortSessionCount: Int
    public let labelVariety: Int
    public let explanation: String

    public var id: Date { date }

    public init(
        date: Date,
        score: Int,
        avgDurationMinutes: Double,
        deepWorkPercent: Double,
        shortSessionCount: Int,
        labelVariety: Int,
        explanation: String
    ) {
        self.date = date
        self.score = score
        self.avgDurationMinutes = avgDurationMinutes
        self.deepWorkPercent = deepWorkPercent
        self.shortSessionCount = shortSessionCount
        self.labelVariety = labelVariety
        self.explanation = explanation
    }
}

// MARK: - TimeLeakDetector output

public enum LeakKind: String, Sendable {
    case client, label
}

public struct TimeLeakInsight: Sendable, Identifiable {
    public let id: String
    public let kind: LeakKind
    public let name: String
    public let currentMinutes: Int
    public let baselineMinutes: Int
    public let deltaPercent: Double

    public init(id: String, kind: LeakKind, name: String, currentMinutes: Int, baselineMinutes: Int, deltaPercent: Double) {
        self.id = id
        self.kind = kind
        self.name = name
        self.currentMinutes = currentMinutes
        self.baselineMinutes = baselineMinutes
        self.deltaPercent = deltaPercent
    }
}

// MARK: - ProductivityHeatmap output

public struct HeatmapProductivityCell: Sendable, Identifiable {
    public let hour: Int
    public let weekday: Int
    public let totalMinutes: Int
    public let sessionCount: Int

    public var id: String { "\(weekday)-\(hour)" }

    public init(hour: Int, weekday: Int, totalMinutes: Int, sessionCount: Int) {
        self.hour = hour
        self.weekday = weekday
        self.totalMinutes = totalMinutes
        self.sessionCount = sessionCount
    }
}

// MARK: - LabelPerformanceAnalyzer output

public struct LabelInsight: Sendable, Identifiable {
    public let label: String
    public let totalMinutes: Int
    public let sessionCount: Int
    public let avgDurationMinutes: Double
    public let peakHour: Int?
    public let hourDistribution: [Int: Int]

    public var id: String { label }

    public init(
        label: String,
        totalMinutes: Int,
        sessionCount: Int,
        avgDurationMinutes: Double,
        peakHour: Int?,
        hourDistribution: [Int: Int]
    ) {
        self.label = label
        self.totalMinutes = totalMinutes
        self.sessionCount = sessionCount
        self.avgDurationMinutes = avgDurationMinutes
        self.peakHour = peakHour
        self.hourDistribution = hourDistribution
    }
}

// MARK: - WeeklyReviewGenerator output

public struct WeeklyReview: Sendable {
    public let weekStart: Date
    public let totalMinutes: Int
    public let mostActiveLabel: String?
    public let mostActiveClientName: String?
    public let longestSession: AnalyticsEntry?
    public let bestDay: Date?
    public let trendPercent: Double?
    public let improvementTip: String

    public init(
        weekStart: Date,
        totalMinutes: Int,
        mostActiveLabel: String?,
        mostActiveClientName: String?,
        longestSession: AnalyticsEntry?,
        bestDay: Date?,
        trendPercent: Double?,
        improvementTip: String
    ) {
        self.weekStart = weekStart
        self.totalMinutes = totalMinutes
        self.mostActiveLabel = mostActiveLabel
        self.mostActiveClientName = mostActiveClientName
        self.longestSession = longestSession
        self.bestDay = bestDay
        self.trendPercent = trendPercent
        self.improvementTip = improvementTip
    }
}

// MARK: - WorkFingerprintEngine output

public enum WorkFingerprintType: String, Sendable, CaseIterable {
    case builder, maker, coordinator, explorer, balanced
}

public struct WorkFingerprint: Sendable {
    public let type: WorkFingerprintType
    public let title: String
    public let description: String
    public let traits: [String]

    public init(type: WorkFingerprintType, title: String, description: String, traits: [String]) {
        self.type = type
        self.title = title
        self.description = description
        self.traits = traits
    }
}
