import Foundation

public enum TimelogWidgetConstants {
    public static let kind        = "me.albz.timelog.today"
    public static let projectsKind = "me.albz.timelog.quickstart"
}

public struct TimelogWidgetProjectEntry: Codable, Hashable {
    public let mongoId: String
    public let name: String
    public let clientName: String?

    public init(mongoId: String, name: String, clientName: String?) {
        self.mongoId = mongoId
        self.name = name
        self.clientName = clientName
    }
}

public struct TimelogWidgetActiveSessionSnapshot: Codable, Hashable {
    public let startDate: Date
    public let clientName: String?
    public let projectName: String?

    public init(startDate: Date, clientName: String?, projectName: String?) {
        self.startDate = startDate
        self.clientName = clientName
        self.projectName = projectName
    }

    public var elapsedMinutes: Int {
        max(0, Int(Date().timeIntervalSince(startDate) / 60))
    }
}

public struct TimelogWidgetSnapshot: Codable, Hashable {
    public let date: Date
    public let loggedMinutes: Int
    public let activeSessions: [TimelogWidgetActiveSessionSnapshot]
    public let lastClientName: String?
    public let lastProjectName: String?
    public let recentProjects: [TimelogWidgetProjectEntry]

    public init(
        date: Date = .now,
        loggedMinutes: Int,
        activeSessions: [TimelogWidgetActiveSessionSnapshot],
        lastClientName: String?,
        lastProjectName: String?,
        recentProjects: [TimelogWidgetProjectEntry] = []
    ) {
        self.date = date
        self.loggedMinutes = loggedMinutes
        self.activeSessions = activeSessions
        self.lastClientName = lastClientName
        self.lastProjectName = lastProjectName
        self.recentProjects = recentProjects
    }

    public static let empty = TimelogWidgetSnapshot(
        loggedMinutes: 0,
        activeSessions: [],
        lastClientName: nil,
        lastProjectName: nil,
        recentProjects: []
    )

    public var activeMinutes: Int {
        activeSessions.reduce(0) { $0 + $1.elapsedMinutes }
    }

    public var totalMinutes: Int {
        loggedMinutes + activeMinutes
    }
}

public enum WidgetSnapshotStore {
    public static let appGroupID = "group.me.albz.timelog"

    private static let snapshotKey    = "today_widget_snapshot"
    private static let pendingStartKey = "pending_project_start"

    public static func load() -> TimelogWidgetSnapshot {
        guard
            let defaults = UserDefaults(suiteName: appGroupID),
            let data = defaults.data(forKey: snapshotKey),
            let snapshot = try? JSONDecoder().decode(TimelogWidgetSnapshot.self, from: data),
            Calendar.current.isDateInToday(snapshot.date)
        else {
            return .empty
        }
        return snapshot
    }

    public static func save(_ snapshot: TimelogWidgetSnapshot) {
        guard
            let defaults = UserDefaults(suiteName: appGroupID),
            let data = try? JSONEncoder().encode(snapshot)
        else { return }
        defaults.set(data, forKey: snapshotKey)
    }

    public static func savePendingStart(mongoId: String) {
        UserDefaults(suiteName: appGroupID)?.set(mongoId, forKey: pendingStartKey)
    }

    public static func consumePendingStart() -> String? {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return nil }
        let id = defaults.string(forKey: pendingStartKey)
        defaults.removeObject(forKey: pendingStartKey)
        return id
    }

    public static func hasPendingStart() -> Bool {
        UserDefaults(suiteName: appGroupID)?.string(forKey: pendingStartKey) != nil
    }
}
