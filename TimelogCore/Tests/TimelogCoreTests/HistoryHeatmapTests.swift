import Testing
import Foundation
@testable import TimelogCore

@Suite("HistoryHeatmap")
struct HistoryHeatmapTests {

    /// Deterministic UTC Gregorian calendar so day bucketing never depends on
    /// the test machine's timezone.
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func day(_ year: Int, _ month: Int, _ d: Int, hour: Int = 12) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: d, hour: hour))!
    }

    @Test func emitsOneCellPerDayInclusive() {
        let days = HistoryHeatmap.days(
            entries: [],
            from: day(2026, 1, 1),
            to: day(2026, 1, 7),
            calendar: cal
        )
        #expect(days.count == 7)
        #expect(days.allSatisfy { $0.minutes == 0 && $0.dominantClientId == nil })
    }

    @Test func sumsMinutesPerDay() {
        let entries = [
            HistoryHeatmap.Entry(date: day(2026, 1, 2, hour: 9), clientId: "a", minutes: 30),
            HistoryHeatmap.Entry(date: day(2026, 1, 2, hour: 14), clientId: "a", minutes: 45),
            HistoryHeatmap.Entry(date: day(2026, 1, 3), clientId: "b", minutes: 60),
        ]
        let days = HistoryHeatmap.days(entries: entries, from: day(2026, 1, 1), to: day(2026, 1, 3), calendar: cal)
        #expect(days[0].minutes == 0)
        #expect(days[1].minutes == 75)
        #expect(days[2].minutes == 60)
    }

    @Test func picksDominantClientByMinutes() {
        let entries = [
            HistoryHeatmap.Entry(date: day(2026, 1, 2, hour: 9), clientId: "a", minutes: 20),
            HistoryHeatmap.Entry(date: day(2026, 1, 2, hour: 10), clientId: "b", minutes: 50),
        ]
        let days = HistoryHeatmap.days(entries: entries, from: day(2026, 1, 2), to: day(2026, 1, 2), calendar: cal)
        #expect(days.first?.dominantClientId == "b")
    }

    @Test func noClientEntriesCanWin() {
        let entries = [
            HistoryHeatmap.Entry(date: day(2026, 1, 2), clientId: nil, minutes: 90),
            HistoryHeatmap.Entry(date: day(2026, 1, 2), clientId: "a", minutes: 10),
        ]
        let days = HistoryHeatmap.days(entries: entries, from: day(2026, 1, 2), to: day(2026, 1, 2), calendar: cal)
        #expect(days.first?.minutes == 100)
        #expect(days.first?.dominantClientId == nil)
    }

    @Test func ignoresEntriesOutsideRange() {
        let entries = [
            HistoryHeatmap.Entry(date: day(2025, 12, 31), clientId: "a", minutes: 99),
            HistoryHeatmap.Entry(date: day(2026, 1, 5), clientId: "a", minutes: 99),
        ]
        let days = HistoryHeatmap.days(entries: entries, from: day(2026, 1, 1), to: day(2026, 1, 3), calendar: cal)
        #expect(days.count == 3)
        #expect(days.allSatisfy { $0.minutes == 0 })
    }

    @Test func invertedRangeYieldsEmpty() {
        let days = HistoryHeatmap.days(entries: [], from: day(2026, 1, 7), to: day(2026, 1, 1), calendar: cal)
        #expect(days.isEmpty)
    }
}
