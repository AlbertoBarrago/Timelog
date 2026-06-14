import Testing
import Foundation
import SwiftData
@testable import TimelogCore

@Suite("ActiveSession")
@MainActor
struct ActiveSessionTests {

    // MARK: elapsedMinutes (non richiede ModelContainer — accede solo a startDate)

    @Test func elapsedMinutesRoundsDown() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ActiveSession.self, Client.self, Project.self, TimeEntry.self,
            configurations: config
        )
        let session = ActiveSession()
        container.mainContext.insert(session)
        session.startDate = Date(timeIntervalSinceNow: -125)
        #expect(session.elapsedMinutes == 2)
    }

    @Test func elapsedMinutesNeverNegative() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ActiveSession.self, Client.self, Project.self, TimeEntry.self,
            configurations: config
        )
        let session = ActiveSession()
        container.mainContext.insert(session)
        session.startDate = Date(timeIntervalSinceNow: 100)
        #expect(session.elapsedMinutes == 0)
    }

    @Test func elapsedMinutesZeroForJustStarted() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ActiveSession.self, Client.self, Project.self, TimeEntry.self,
            configurations: config
        )
        let session = ActiveSession()
        container.mainContext.insert(session)
        #expect(session.elapsedMinutes == 0)
    }

    // MARK: elapsedDisplay

    @Test func elapsedDisplayMMSSFormatUnderOneHour() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ActiveSession.self, Client.self, Project.self, TimeEntry.self,
            configurations: config
        )
        let session = ActiveSession()
        container.mainContext.insert(session)
        session.startDate = Date(timeIntervalSinceNow: -30)
        let colons = session.elapsedDisplay.filter { $0 == ":" }.count
        #expect(colons == 1)
    }

    @Test func elapsedDisplayHHMMSSFormatOverOneHour() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ActiveSession.self, Client.self, Project.self, TimeEntry.self,
            configurations: config
        )
        let session = ActiveSession()
        container.mainContext.insert(session)
        session.startDate = Date(timeIntervalSinceNow: -3700)
        let colons = session.elapsedDisplay.filter { $0 == ":" }.count
        #expect(colons == 2)
    }

    // MARK: cappedElapsedMinutes

    @Test func capLimitsForgottenSessionToWorkdayEnd() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ActiveSession.self, Client.self, Project.self, TimeEntry.self,
            configurations: config
        )
        let session = ActiveSession()
        container.mainContext.insert(session)
        let calendar = Calendar.current
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: .now)!
        session.startDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: threeDaysAgo)!

        let boundary = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: session.startDate)!
        let expected = calendar.dateComponents([.minute], from: session.startDate, to: boundary).minute!
        #expect(session.cappedElapsedMinutes(endHour: 18, endMinute: 0) == expected)
        #expect(session.cappedElapsedMinutes(endHour: 18, endMinute: 0) < session.elapsedMinutes)
    }

    @Test func capUsesNextDayBoundaryForEveningStart() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ActiveSession.self, Client.self, Project.self, TimeEntry.self,
            configurations: config
        )
        let session = ActiveSession()
        container.mainContext.insert(session)
        let calendar = Calendar.current
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: .now)!
        session.startDate = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: threeDaysAgo)!

        let sameDayBoundary = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: session.startDate)!
        let boundary = calendar.date(byAdding: .day, value: 1, to: sameDayBoundary)!
        let expected = calendar.dateComponents([.minute], from: session.startDate, to: boundary).minute!
        #expect(session.cappedElapsedMinutes(endHour: 18, endMinute: 0) == expected)
    }

    @Test func capDoesNotAffectSessionStillBeforeBoundary() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ActiveSession.self, Client.self, Project.self, TimeEntry.self,
            configurations: config
        )
        let session = ActiveSession()
        container.mainContext.insert(session)
        session.startDate = Date(timeIntervalSinceNow: -30 * 60)

        let calendar = Calendar.current
        let farBoundary = session.startDate.addingTimeInterval(3600) // 1h after start, always after "now"
        let endHour = calendar.component(.hour, from: farBoundary)
        let endMinute = calendar.component(.minute, from: farBoundary)
        #expect(session.cappedElapsedMinutes(endHour: endHour, endMinute: endMinute) == 30)
    }

    @Test func capReturnsAtLeastOneMinute() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ActiveSession.self, Client.self, Project.self, TimeEntry.self,
            configurations: config
        )
        let session = ActiveSession()
        container.mainContext.insert(session)
        #expect(session.cappedElapsedMinutes(endHour: 18, endMinute: 0) >= 1)
    }

    // MARK: asTimeEntry

    @Test func asTimeEntryPreservesFields() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ActiveSession.self, Client.self, Project.self, TimeEntry.self,
            configurations: config
        )
        let session = ActiveSession()
        container.mainContext.insert(session)
        let entry = session.asTimeEntry(durationMinutes: 45, notes: "standup")
        #expect(entry.durationMinutes == 45)
        #expect(entry.notes == "standup")
        #expect(entry.date == session.startDate)
    }

    @Test func asTimeEntryNilNotes() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ActiveSession.self, Client.self, Project.self, TimeEntry.self,
            configurations: config
        )
        let session = ActiveSession()
        container.mainContext.insert(session)
        let entry = session.asTimeEntry(durationMinutes: 10, notes: nil)
        #expect(entry.notes == nil)
    }
}
