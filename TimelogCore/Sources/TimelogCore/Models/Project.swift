import SwiftData
import Foundation

@Model
public final class Project {
    public var name: String
    public var code: String?
    public var mongoId: String?
    public var userId: String = ""
    public var client: Client?
    public var labels: [String] = []
    @Relationship(deleteRule: .nullify, inverse: \TimeEntry.project) public var entries: [TimeEntry] = []
    public var deletedAt: Date? = nil

    public init(name: String, code: String? = nil, userId: String = "") {
        self.name = name
        self.code = code
        self.mongoId = Client.newMongoId()
        self.userId = userId
    }
}
