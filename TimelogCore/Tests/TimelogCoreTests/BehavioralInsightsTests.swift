import Testing
import Foundation
@testable import TimelogCore

@Suite("BehavioralInsights")
struct BehavioralInsightsTests {

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func entry(
        year: Int = 2026, month: Int = 1, day: Int = 6,
        hour: Int = 10,
        duration: Int,
        label: String? = nil,
        clientId: String? = nil,
        clientName: String? = nil
    ) -> AnalyticsEntry {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        let date = c.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
        return AnalyticsEntry(
            date: date, durationMinutes: duration, label: label,
            clientId: clientId, clientName: clientName,
            projectId: nil, projectName: nil
        )
    }

    @Suite("AnalyticsRefreshToken")
    struct AnalyticsRefreshTokenTests {
        @Test func tokenChangesWhenTrackedFieldsChange() {
            let base = [
                AnalyticsEntry(
                    date: Date(timeIntervalSince1970: 100),
                    durationMinutes: 30,
                    label: "dev",
                    clientId: "c1",
                    clientName: "Client A",
                    projectId: "p1",
                    projectName: "Project A"
                )
            ]
            let changed = [
                AnalyticsEntry(
                    date: Date(timeIntervalSince1970: 100),
                    durationMinutes: 45,
                    label: "meetings",
                    clientId: "c1",
                    clientName: "Client A",
                    projectId: "p1",
                    projectName: "Project A"
                )
            ]

            #expect(AnalyticsRefreshToken.make(for: base) != AnalyticsRefreshToken.make(for: changed))
        }
    }

    @Suite("BehavioralInsightsService")
    @MainActor
    struct BehavioralInsightsServiceTests {
        private var cal: Calendar {
            var c = Calendar(identifier: .gregorian)
            c.timeZone = TimeZone(identifier: "UTC")!
            return c
        }

        private func entry(day: Int, duration: Int, label: String? = nil) -> AnalyticsEntry {
            let date = cal.date(
                from: DateComponents(year: 2026, month: 1, day: day, hour: 10)
            )!
            return AnalyticsEntry(
                date: date,
                durationMinutes: duration,
                label: label,
                clientId: nil,
                clientName: nil,
                projectId: nil,
                projectName: nil
            )
        }

        @Test func coalescesOverlappingRecomputeRequestsAndPublishesLatestState() async {
            let service = BehavioralInsightsService()
            service.testingComputeDelayNanoseconds = 200_000_000

            let firstEntries = [
                entry(day: 1, duration: 20, label: "dev"),
                entry(day: 2, duration: 20, label: "dev"),
                entry(day: 3, duration: 20, label: "dev"),
                entry(day: 4, duration: 20, label: "dev"),
                entry(day: 5, duration: 20, label: "dev")
            ]
            let latestEntries = [
                entry(day: 1, duration: 40, label: "meetings"),
                entry(day: 2, duration: 40, label: "meetings"),
                entry(day: 3, duration: 40, label: "meetings"),
                entry(day: 4, duration: 40, label: "meetings"),
                entry(day: 5, duration: 40, label: "meetings")
            ]

            async let firstRun: Void = service.recompute(entries: firstEntries, calendar: cal)
            try? await Task.sleep(nanoseconds: 50_000_000)
            await service.recompute(entries: latestEntries, calendar: cal)
            await firstRun

            #expect(service.labelInsights.first?.label == "meetings")
            #expect(service.labelInsights.first?.totalMinutes == 200)
            #expect(service.isComputing == false)
        }
    }

    // MARK: - FocusScoreEngine

    @Suite("FocusScoreEngine")
    struct FocusScoreEngineTests {
        private var cal: Calendar {
            var c = Calendar(identifier: .gregorian)
            c.timeZone = TimeZone(identifier: "UTC")!
            return c
        }
        private func entry(hour: Int = 10, duration: Int, label: String? = nil) -> AnalyticsEntry {
            let date = cal.date(from: DateComponents(year: 2026, month: 1, day: 6, hour: hour))!
            return AnalyticsEntry(date: date, durationMinutes: duration, label: label,
                                  clientId: nil, clientName: nil, projectId: nil, projectName: nil)
        }

        @Test func emptyEntriesGivesZeroScore() {
            let date = cal.date(from: DateComponents(year: 2026, month: 1, day: 6))!
            let result = FocusScoreEngine.score(for: [], date: date)
            #expect(result.score == 0)
            #expect(result.deepWorkPercent == 0)
        }

        @Test func allDeepWorkGivesHighScore() {
            let entries = [
                entry(duration: 60),
                entry(duration: 90),
                entry(duration: 45),
            ]
            let date = cal.date(from: DateComponents(year: 2026, month: 1, day: 6))!
            let result = FocusScoreEngine.score(for: entries, date: date)
            #expect(result.score >= 70)
            #expect(result.deepWorkPercent == 100.0)
        }

        @Test func manyShortSessionsPenalizes() {
            let entries = (0..<5).map { _ in entry(duration: 3) }
            let date = cal.date(from: DateComponents(year: 2026, month: 1, day: 6))!
            let noShortEntries = [entry(duration: 60)]
            let resultWithShort = FocusScoreEngine.score(for: entries, date: date)
            let resultNoShort = FocusScoreEngine.score(for: noShortEntries, date: date)
            #expect(resultWithShort.score < resultNoShort.score)
            #expect(resultWithShort.shortSessionCount == 5)
        }

        @Test func highLabelVarietyPenalizes() {
            let manyLabels = (0..<5).map { i in entry(duration: 30, label: "label\(i)") }
            let fewLabels = [entry(duration: 30, label: "work"), entry(duration: 30, label: "work")]
            let date = cal.date(from: DateComponents(year: 2026, month: 1, day: 6))!
            let resultMany = FocusScoreEngine.score(for: manyLabels, date: date)
            let resultFew = FocusScoreEngine.score(for: fewLabels, date: date)
            #expect(resultMany.score < resultFew.score)
        }

        @Test func scoreIsClampedBetweenZeroAndHundred() {
            let perfect = [entry(duration: 90), entry(duration: 120), entry(duration: 90)]
            let date = cal.date(from: DateComponents(year: 2026, month: 1, day: 6))!
            let result = FocusScoreEngine.score(for: perfect, date: date)
            #expect(result.score >= 0)
            #expect(result.score <= 100)
        }
    }

    // MARK: - TimeLeakDetector

    @Suite("TimeLeakDetector")
    struct TimeLeakDetectorTests {
        private func entry(duration: Int, label: String? = nil, clientId: String? = nil, clientName: String? = nil) -> AnalyticsEntry {
            AnalyticsEntry(date: Date(), durationMinutes: duration, label: label,
                           clientId: clientId, clientName: clientName, projectId: nil, projectName: nil)
        }

        @Test func noLeakWhenBelowThreshold() {
            let recent = [entry(duration: 50, label: "dev")]
            // baseline weekly equiv = 40/4 = 10 min — below minimum 30
            let baseline = Array(repeating: entry(duration: 10, label: "dev"), count: 4)
            let results = TimeLeakDetector.detect(recentEntries: recent, baselineEntries: baseline)
            #expect(results.isEmpty)
        }

        @Test func detectsLabelLeakAbove20Percent() {
            let recent = [entry(duration: 200, label: "meetings")]
            // baseline for 28 days: 600 min total -> 150 min/week -> delta = (200-150)/150 = 33%
            let baseline = Array(repeating: entry(duration: 150, label: "meetings"), count: 4)
            let results = TimeLeakDetector.detect(recentEntries: recent, baselineEntries: baseline)
            #expect(results.contains { $0.kind == .label && $0.name == "meetings" })
        }

        @Test func noDeltaBelowThreshold() {
            let recent = [entry(duration: 100, label: "dev")]
            // baseline 400 total / 4 = 100 weekly -> delta = 0%
            let baseline = Array(repeating: entry(duration: 100, label: "dev"), count: 4)
            let results = TimeLeakDetector.detect(recentEntries: recent, baselineEntries: baseline)
            #expect(results.isEmpty)
        }

        @Test func topFiveResultsMax() {
            var recent: [AnalyticsEntry] = []
            var baseline: [AnalyticsEntry] = []
            for i in 0..<10 {
                let label = "label\(i)"
                recent.append(entry(duration: 500, label: label))
                for _ in 0..<4 {
                    baseline.append(entry(duration: 100, label: label))
                }
            }
            let results = TimeLeakDetector.detect(recentEntries: recent, baselineEntries: baseline)
            #expect(results.count <= 5)
        }
    }

    // MARK: - ProductivityHeatmap

    @Suite("ProductivityHeatmap")
    struct ProductivityHeatmapTests {
        private var cal: Calendar {
            var c = Calendar(identifier: .gregorian)
            c.timeZone = TimeZone(identifier: "UTC")!
            return c
        }

        @Test func emptyEntriesYieldsEmptyCells() {
            let cells = ProductivityHeatmap.cells(entries: [], calendar: cal)
            #expect(cells.isEmpty)
        }

        @Test func aggregatesByHourAndWeekday() {
            // 2026-01-06 is Tuesday -> weekday = 3 (Gregorian, 1=Sunday)
            let date = cal.date(from: DateComponents(year: 2026, month: 1, day: 6, hour: 9))!
            let entry = AnalyticsEntry(date: date, durationMinutes: 45, label: nil,
                                       clientId: nil, clientName: nil, projectId: nil, projectName: nil)
            let cells = ProductivityHeatmap.cells(entries: [entry], calendar: cal)
            #expect(cells.count == 1)
            #expect(cells[0].hour == 9)
            #expect(cells[0].totalMinutes == 45)
            #expect(cells[0].sessionCount == 1)
        }

        @Test func sameHourSameDayAccumulates() {
            let date1 = cal.date(from: DateComponents(year: 2026, month: 1, day: 6, hour: 9))!
            let date2 = cal.date(from: DateComponents(year: 2026, month: 1, day: 6, hour: 9, minute: 30))!
            let entries = [
                AnalyticsEntry(date: date1, durationMinutes: 30, label: nil, clientId: nil, clientName: nil, projectId: nil, projectName: nil),
                AnalyticsEntry(date: date2, durationMinutes: 20, label: nil, clientId: nil, clientName: nil, projectId: nil, projectName: nil),
            ]
            let cells = ProductivityHeatmap.cells(entries: entries, calendar: cal)
            #expect(cells.count == 1)
            #expect(cells[0].totalMinutes == 50)
            #expect(cells[0].sessionCount == 2)
        }

        @Test func forgottenTimerIsExcluded() {
            let date = cal.date(from: DateComponents(year: 2026, month: 1, day: 6, hour: 20))!
            let normal = AnalyticsEntry(date: date, durationMinutes: 45, label: nil,
                                        clientId: nil, clientName: nil, projectId: nil, projectName: nil)
            let outlier = AnalyticsEntry(date: date, durationMinutes: 481, label: nil,
                                         clientId: nil, clientName: nil, projectId: nil, projectName: nil)
            let cells = ProductivityHeatmap.cells(entries: [normal, outlier], calendar: cal)
            #expect(cells.count == 1)
            #expect(cells[0].totalMinutes == 45)
            #expect(cells[0].sessionCount == 1)
        }
    }

    // MARK: - LabelPerformanceAnalyzer

    @Suite("LabelPerformanceAnalyzer")
    struct LabelPerformanceAnalyzerTests {
        private var cal: Calendar {
            var c = Calendar(identifier: .gregorian)
            c.timeZone = TimeZone(identifier: "UTC")!
            return c
        }

        private func entry(duration: Int, label: String?, hour: Int = 10) -> AnalyticsEntry {
            let date = cal.date(from: DateComponents(year: 2026, month: 1, day: 6, hour: hour))!
            return AnalyticsEntry(date: date, durationMinutes: duration, label: label,
                                  clientId: nil, clientName: nil, projectId: nil, projectName: nil)
        }

        @Test func nilLabelGroupedAsUnlabeled() {
            let entries = [entry(duration: 30, label: nil)]
            let insights = LabelPerformanceAnalyzer.analyze(entries: entries, calendar: cal)
            #expect(insights.count == 1)
            #expect(insights[0].label == LabelPerformanceAnalyzer.unlabeledKey)
        }

        @Test func sortsByTotalMinutesDesc() {
            let entries = [
                entry(duration: 10, label: "A"),
                entry(duration: 60, label: "B"),
                entry(duration: 30, label: "A"),
            ]
            let insights = LabelPerformanceAnalyzer.analyze(entries: entries, calendar: cal)
            #expect(insights[0].label == "B")
            #expect(insights[1].label == "A")
        }

        @Test func peakHourIsCorrect() {
            let entries = [
                entry(duration: 10, label: "dev", hour: 9),
                entry(duration: 50, label: "dev", hour: 14),
                entry(duration: 20, label: "dev", hour: 14),
            ]
            let insights = LabelPerformanceAnalyzer.analyze(entries: entries, calendar: cal)
            #expect(insights.first?.peakHour == 14)
        }

        @Test func sessionCountIsAccurate() {
            let entries = [
                entry(duration: 30, label: "X"),
                entry(duration: 45, label: "X"),
                entry(duration: 20, label: "Y"),
            ]
            let insights = LabelPerformanceAnalyzer.analyze(entries: entries, calendar: cal)
            let x = insights.first { $0.label == "X" }
            #expect(x?.sessionCount == 2)
            #expect(x?.totalMinutes == 75)
        }
    }

    // MARK: - WeeklyReviewGenerator

    @Suite("WeeklyReviewGenerator")
    struct WeeklyReviewGeneratorTests {
        private var cal: Calendar {
            var c = Calendar(identifier: .gregorian)
            c.timeZone = TimeZone(identifier: "UTC")!
            return c
        }

        private func entry(day: Int, duration: Int, label: String? = nil, clientId: String? = nil, clientName: String? = nil) -> AnalyticsEntry {
            let date = cal.date(from: DateComponents(year: 2026, month: 1, day: day, hour: 10))!
            return AnalyticsEntry(date: date, durationMinutes: duration, label: label,
                                  clientId: clientId, clientName: clientName, projectId: nil, projectName: nil)
        }

        @Test func trendIsNilWhenNoPreviousWeek() {
            let weekStart = cal.date(from: DateComponents(year: 2026, month: 1, day: 5))!
            let review = WeeklyReviewGenerator.generate(
                currentWeek: [entry(day: 6, duration: 60)],
                previousWeek: [],
                weekStart: weekStart,
                calendar: cal
            )
            #expect(review.trendPercent == nil)
        }

        @Test func trendPercentIsPositiveWhenMoreWork() {
            let weekStart = cal.date(from: DateComponents(year: 2026, month: 1, day: 5))!
            let review = WeeklyReviewGenerator.generate(
                currentWeek: [entry(day: 6, duration: 120)],
                previousWeek: [entry(day: 1, duration: 60)],
                weekStart: weekStart,
                calendar: cal
            )
            #expect((review.trendPercent ?? 0) > 0)
        }

        @Test func bestDayIsMaxMinutesDay() {
            let weekStart = cal.date(from: DateComponents(year: 2026, month: 1, day: 5))!
            let entries = [
                entry(day: 5, duration: 30),
                entry(day: 6, duration: 120),
                entry(day: 7, duration: 60),
            ]
            let review = WeeklyReviewGenerator.generate(
                currentWeek: entries,
                previousWeek: [],
                weekStart: weekStart,
                calendar: cal
            )
            let expectedDay = cal.date(from: DateComponents(year: 2026, month: 1, day: 6))!
            #expect(review.bestDay != nil)
            #expect(cal.isDate(review.bestDay!, inSameDayAs: expectedDay))
        }

        @Test func totalMinutesIsSumOfAll() {
            let weekStart = cal.date(from: DateComponents(year: 2026, month: 1, day: 5))!
            let entries = [entry(day: 5, duration: 45), entry(day: 6, duration: 90)]
            let review = WeeklyReviewGenerator.generate(
                currentWeek: entries,
                previousWeek: [],
                weekStart: weekStart,
                calendar: cal
            )
            #expect(review.totalMinutes == 135)
        }
    }

    // MARK: - WorkFingerprintEngine

    @Suite("WorkFingerprintEngine")
    struct WorkFingerprintEngineTests {
        private var cal: Calendar {
            var c = Calendar(identifier: .gregorian)
            c.timeZone = TimeZone(identifier: "UTC")!
            return c
        }

        private func entry(duration: Int, label: String? = nil, clientId: String? = nil) -> AnalyticsEntry {
            let date = cal.date(from: DateComponents(year: 2026, month: 1, day: 6, hour: 10))!
            return AnalyticsEntry(date: date, durationMinutes: duration, label: label,
                                  clientId: clientId, clientName: nil, projectId: nil, projectName: nil)
        }

        @Test func returnsNilForEmptyEntries() {
            #expect(WorkFingerprintEngine.fingerprint(entries: [], calendar: cal) == nil)
        }

        @Test func classifiesBuilderCorrectly() {
            // Long sessions, few labels, high deepWork.
            let entries = Array(repeating: entry(duration: 60, label: "code", clientId: "c1"), count: 20)
            let fp = WorkFingerprintEngine.fingerprint(entries: entries, calendar: cal)
            #expect(fp?.type == .builder)
        }

        @Test func classifiesCoordinatorForManyClients() {
            var entries: [AnalyticsEntry] = []
            for c in ["c1", "c2", "c3", "c4"] {
                for l in ["label1", "label2", "label3", "label4"] {
                    entries.append(entry(duration: 20, label: l, clientId: c))
                }
            }
            let fp = WorkFingerprintEngine.fingerprint(entries: entries, calendar: cal)
            #expect(fp?.type == .coordinator)
        }

        @Test func defaultsToBalanced() {
            // Moderate sessions, few clients and labels.
            let entries = Array(repeating: entry(duration: 20, label: "work", clientId: "c1"), count: 10)
            let fp = WorkFingerprintEngine.fingerprint(entries: entries, calendar: cal)
            #expect(fp?.type == .balanced)
        }

        @Test func fingerprintHasThreeTraits() {
            let entries = Array(repeating: entry(duration: 60, label: "code", clientId: "c1"), count: 20)
            let fp = WorkFingerprintEngine.fingerprint(entries: entries, calendar: cal)
            #expect(fp?.traits.count == 3)
        }
    }
}
