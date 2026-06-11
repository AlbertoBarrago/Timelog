import Foundation

public enum TimelogWidgetConstants {
    public static let kind = "me.albz.timelog.today"
}

public struct TimelogWidgetActiveSessionSnapshot: Codable, Hashable {
    public let startDate: Date
    public let clientName: String?
    public let projectName: String?
    // Optional per retrocompatibilità con snapshot serializzati da versioni precedenti
    public let clientColorHex: String?

    public init(startDate: Date, clientName: String?, projectName: String?, clientColorHex: String? = nil) {
        self.startDate = startDate
        self.clientName = clientName
        self.projectName = projectName
        self.clientColorHex = clientColorHex
    }

    public var elapsedMinutes: Int {
        max(0, Int(Date().timeIntervalSince(startDate) / 60))
    }
}

public struct TimelogWidgetBreakdownItem: Codable, Hashable, Identifiable {
    public let name: String
    public let colorHex: String
    public let minutes: Int

    public var id: String { name }

    public init(name: String, colorHex: String, minutes: Int) {
        self.name = name
        self.colorHex = colorHex
        self.minutes = minutes
    }
}

public struct TimelogWidgetSnapshot: Codable, Hashable {
    public let date: Date
    public let loggedMinutes: Int
    public let activeSessions: [TimelogWidgetActiveSessionSnapshot]
    public let lastClientName: String?
    public let lastProjectName: String?
    // Optional per retrocompatibilità con snapshot serializzati da versioni precedenti
    public let breakdown: [TimelogWidgetBreakdownItem]?

    public init(
        date: Date = .now,
        loggedMinutes: Int,
        activeSessions: [TimelogWidgetActiveSessionSnapshot],
        lastClientName: String?,
        lastProjectName: String?,
        breakdown: [TimelogWidgetBreakdownItem]? = nil
    ) {
        self.date = date
        self.loggedMinutes = loggedMinutes
        self.activeSessions = activeSessions
        self.lastClientName = lastClientName
        self.lastProjectName = lastProjectName
        self.breakdown = breakdown
    }

    /// Ripartizione di oggi per cliente, ordinata per minuti decrescenti.
    public var clientBreakdown: [TimelogWidgetBreakdownItem] {
        breakdown ?? []
    }

    public static let empty = TimelogWidgetSnapshot(
        loggedMinutes: 0,
        activeSessions: [],
        lastClientName: nil,
        lastProjectName: nil
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

    private static let snapshotKey = "today_widget_snapshot"

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
}
