import SwiftData
import SwiftUI

@Model
public final class Client {
    public var name: String
    public var colorHex: String
    public var isArchived: Bool
    public var userId: String = ""
    @Relationship(deleteRule: .cascade) public var projects: [Project] = []
    public var deletedAt: Date? = nil

    public init(name: String, colorHex: String = "#007AFF", isArchived: Bool = false, userId: String = "") {
        self.name = name
        self.colorHex = colorHex
        self.isArchived = isArchived
        self.userId = userId
    }

    public var color: Color { Color(hex: colorHex) ?? .accentColor }
}
