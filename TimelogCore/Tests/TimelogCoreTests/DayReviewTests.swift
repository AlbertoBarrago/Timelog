import Testing
import Foundation
import SwiftData
@testable import TimelogCore

@Suite("DayReview")
@MainActor
struct DayReviewTests {

    @Test func dateIsStoredAtStartOfDay() throws {
        let container = try makeContainer()
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 29, hour: 15, minute: 45))!
        let review = DayReview(date: date, mood: "Ok", pressure: 2, notes: "Done", userId: "albz")

        container.mainContext.insert(review)

        #expect(review.date == calendar.startOfDay(for: date))
        #expect(review.mood == "Ok")
        #expect(review.pressure == 2)
        #expect(review.notes == "Done")
        #expect(review.userId == "albz")
        #expect(review.mongoId?.count == 24)
    }

    @Test func syncFingerprintIncludesDayReviews() throws {
        let container = try makeContainer()
        let review = DayReview(mood: "Ok", pressure: 1, notes: "First", userId: "albz")

        container.mainContext.insert(review)

        let initial = SyncDataFingerprint.make(clients: [], projects: [], entries: [], sessions: [], dayReviews: [review])
        review.notes = "Updated"
        let updated = SyncDataFingerprint.make(clients: [], projects: [], entries: [], sessions: [], dayReviews: [review])

        #expect(initial != updated)
    }

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Client.self, Project.self, TimeEntry.self, ActiveSession.self, DayReview.self,
            configurations: config
        )
    }
}
