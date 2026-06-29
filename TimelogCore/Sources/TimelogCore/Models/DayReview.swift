import SwiftData
import Foundation

@Model
public final class DayReview {
    public var date: Date
    public var mood: String?
    public var pressure: Int?
    public var notes: String?
    public var mongoId: String?
    public var userId: String = ""
    public var deletedAt: Date? = nil

    public init(
        date: Date = .now,
        mood: String? = nil,
        pressure: Int? = nil,
        notes: String? = nil,
        userId: String = ""
    ) {
        self.date = Calendar.current.startOfDay(for: date)
        self.mood = mood
        self.pressure = pressure
        self.notes = notes
        self.mongoId = Client.newMongoId()
        self.userId = userId
    }
}
