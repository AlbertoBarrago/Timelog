import Foundation
import Observation

@Observable
@MainActor
public final class BehavioralInsightsService {
    private struct PendingRequest {
        let entries: [AnalyticsEntry]
        let calendar: Calendar
    }

    private struct ComputationResult {
        let focusScores: [FocusScore]
        let timeLeaks: [TimeLeakInsight]
        let heatmapCells: [HeatmapProductivityCell]
        let labelInsights: [LabelInsight]
        let weeklyReview: WeeklyReview?
        let workFingerprint: WorkFingerprint?
    }

    public private(set) var focusScores: [FocusScore] = []
    public private(set) var timeLeaks: [TimeLeakInsight] = []
    public private(set) var heatmapCells: [HeatmapProductivityCell] = []
    public private(set) var labelInsights: [LabelInsight] = []
    public private(set) var weeklyReview: WeeklyReview?
    public private(set) var workFingerprint: WorkFingerprint?
    public private(set) var isComputing = false
    private var pendingRequest: PendingRequest?
    var testingComputeDelayNanoseconds: UInt64 = 0

    public init() {}

    /// FocusScore di oggi, se disponibile.
    public var todayFocusScore: FocusScore? {
        focusScores.first { Calendar.current.isDateInToday($0.date) }
    }

    /// Ricalcola tutti gli analytics. Chiamato dalla view quando le entries cambiano.
    /// - Parameter entries: tutte le entries non-deleted dell'utente corrente
    public func recompute(entries: [AnalyticsEntry], calendar: Calendar = .current) async {
        pendingRequest = PendingRequest(entries: entries, calendar: calendar)
        guard !isComputing else { return }
        isComputing = true
        defer { isComputing = false }

        while let request = pendingRequest {
            pendingRequest = nil
            let result = await Self.compute(
                entries: request.entries,
                calendar: request.calendar,
                delayNanoseconds: testingComputeDelayNanoseconds
            )

            focusScores = result.focusScores
            timeLeaks = result.timeLeaks
            heatmapCells = result.heatmapCells
            labelInsights = result.labelInsights
            weeklyReview = result.weeklyReview
            workFingerprint = result.workFingerprint
        }
    }

    // MARK: - Private

    nonisolated private static func compute(
        entries: [AnalyticsEntry],
        calendar: Calendar,
        delayNanoseconds: UInt64
    ) async -> ComputationResult {
        await Task.detached(priority: .utility) {
            if delayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }

            let now = Date()
            let startOfToday = calendar.startOfDay(for: now)

            let weekStart: Date = {
                var comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
                comps.weekday = calendar.firstWeekday
                return calendar.date(from: comps) ?? calendar.startOfDay(for: now)
            }()

            guard
                let prevWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart),
                let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: startOfToday),
                let twentyEightDaysAgo = calendar.date(byAdding: .day, value: -28, to: startOfToday),
                let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: startOfToday)
            else {
                return ComputationResult(
                    focusScores: [],
                    timeLeaks: [],
                    heatmapCells: [],
                    labelInsights: [],
                    weeklyReview: nil,
                    workFingerprint: nil
                )
            }

            let currentWeekEntries = entries.filter { $0.date >= weekStart }
            let prevWeekEntries = entries.filter { $0.date >= prevWeekStart && $0.date < weekStart }
            let recentEntries = entries.filter { $0.date >= sevenDaysAgo }
            let baselineEntries = entries.filter { $0.date >= twentyEightDaysAgo && $0.date < sevenDaysAgo }
            let fingerprintEntries = entries.filter { $0.date >= thirtyDaysAgo }

            return ComputationResult(
                focusScores: buildFocusScores(entries: entries, today: startOfToday, calendar: calendar),
                timeLeaks: TimeLeakDetector.detect(recentEntries: recentEntries, baselineEntries: baselineEntries),
                heatmapCells: ProductivityHeatmap.cells(entries: entries, calendar: calendar),
                labelInsights: LabelPerformanceAnalyzer.analyze(entries: entries, calendar: calendar),
                weeklyReview: WeeklyReviewGenerator.generate(
                    currentWeek: currentWeekEntries,
                    previousWeek: prevWeekEntries,
                    weekStart: weekStart,
                    calendar: calendar
                ),
                workFingerprint: WorkFingerprintEngine.fingerprint(entries: fingerprintEntries, calendar: calendar)
            )
        }.value
    }

    nonisolated private static func buildFocusScores(entries: [AnalyticsEntry], today: Date, calendar: Calendar) -> [FocusScore] {
        (0..<7).compactMap { offset -> FocusScore? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let dayEntries = entries.filter { calendar.isDate($0.date, inSameDayAs: day) }
            guard !dayEntries.isEmpty else { return nil }
            return FocusScoreEngine.score(for: dayEntries, date: day)
        }
        .sorted { $0.date > $1.date }
    }
}
