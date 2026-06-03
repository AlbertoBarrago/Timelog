import SwiftUI

enum AppTab: Int, CaseIterable, Identifiable {
    case today    = 0
    case history  = 1
    case clients  = 2
    case timer    = 3
    case settings = 4

    var id: Int { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .today:    "Today"
        case .history:  "History"
        case .clients:  "Clients"
        case .timer:    "Timer"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .today:    "clock"
        case .history:  "calendar"
        case .clients:  "person.2"
        case .timer:    "timer"
        case .settings: "gearshape"
        }
    }
}
