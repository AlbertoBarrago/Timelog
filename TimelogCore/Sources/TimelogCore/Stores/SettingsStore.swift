import Foundation
import Observation

/// Visualization style for the History "Hours by project" chart.
public enum HistoryChartStyle: String, CaseIterable, Identifiable, Sendable {
    case donut
    case heatmap
    public var id: String { rawValue }
}

@Observable
public final class SettingsStore {
    public var userId: String = "" { didSet { save() } }

    public var pomodoroWork: Int = 25 { didSet { save() } }
    public var pomodoroShortBreak: Int = 5 { didSet { save() } }
    public var pomodoroLongBreak: Int = 15 { didSet { save() } }
    public var pomodoroSoundEnabled: Bool = true { didSet { save() } }
    public var pomodoroAutoAdvance: Bool = false { didSet { save() } }

    public var reminderEnabled: Bool = false { didSet { save(); if !isLoading { applyReminders() } } }
    public var reminderHour: Int = 17 { didSet { save(); if !isLoading { applyReminders() } } }
    public var reminderMinute: Int = 0 { didSet { save(); if !isLoading { applyReminders() } } }
    public var reminderDays: Set<Int> = [2, 3, 4, 5, 6] { didSet { save(); if !isLoading { applyReminders() } } }

    public var trackingEndHour: Int = 18 { didSet { save() } }
    public var trackingEndMinute: Int = 0 { didSet { save() } }

    public var idleAlertEnabled: Bool = false { didSet { save() } }
    public var idleAlertMinutes: Int = 10 { didSet { save() } }

    public var workingDays: Set<Int> = [2, 3, 4, 5, 6] { didSet { save() } }

    public var historyChartStyle: HistoryChartStyle = .donut { didSet { save() } }
    public var missingHoursAlertEnabled: Bool = false { didSet { save() } }

    private let defaults: UserDefaults
    private var isLoading = false

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    public func load() {
        isLoading = true
        defer {
            isLoading = false
            applyReminders()
        }
        userId = defaults.string(forKey: "user_id") ?? ""
        let w = defaults.integer(forKey: "pomodoro_work")
        let s = defaults.integer(forKey: "pomodoro_short")
        let l = defaults.integer(forKey: "pomodoro_long")
        pomodoroWork = w > 0 ? w : 25
        pomodoroShortBreak = s > 0 ? s : 5
        pomodoroLongBreak = l > 0 ? l : 15
        pomodoroSoundEnabled = defaults.object(forKey: "pomodoro_sound") != nil ? defaults.bool(forKey: "pomodoro_sound") : true
        pomodoroAutoAdvance = defaults.bool(forKey: "pomodoro_auto_advance")
        reminderEnabled = defaults.bool(forKey: "reminder_enabled")
        reminderHour   = defaults.object(forKey: "reminder_hour")   != nil ? defaults.integer(forKey: "reminder_hour")   : 17
        reminderMinute = defaults.object(forKey: "reminder_minute") != nil ? defaults.integer(forKey: "reminder_minute") : 0
        if let days = defaults.array(forKey: "reminder_days") as? [Int], !days.isEmpty {
            reminderDays = Set(days)
        }
        trackingEndHour   = defaults.object(forKey: "tracking_end_hour")   != nil ? defaults.integer(forKey: "tracking_end_hour")   : 18
        trackingEndMinute = defaults.object(forKey: "tracking_end_minute") != nil ? defaults.integer(forKey: "tracking_end_minute") : 0
        idleAlertEnabled  = defaults.bool(forKey: "idle_alert_enabled")
        idleAlertMinutes  = defaults.object(forKey: "idle_alert_minutes")  != nil ? defaults.integer(forKey: "idle_alert_minutes")  : 10
        if let days = defaults.array(forKey: "working_days") as? [Int], !days.isEmpty {
            workingDays = Set(days)
        }
        historyChartStyle = HistoryChartStyle(rawValue: defaults.string(forKey: "history_chart_style") ?? "") ?? .donut
        missingHoursAlertEnabled = defaults.bool(forKey: "missing_hours_alert_enabled")
    }

    public func save() {
        guard !isLoading else { return }
        defaults.set(userId,             forKey: "user_id")
        defaults.set(pomodoroWork,         forKey: "pomodoro_work")
        defaults.set(pomodoroShortBreak,   forKey: "pomodoro_short")
        defaults.set(pomodoroLongBreak,    forKey: "pomodoro_long")
        defaults.set(pomodoroSoundEnabled, forKey: "pomodoro_sound")
        defaults.set(pomodoroAutoAdvance,  forKey: "pomodoro_auto_advance")
        defaults.set(reminderEnabled,    forKey: "reminder_enabled")
        defaults.set(reminderHour,       forKey: "reminder_hour")
        defaults.set(reminderMinute,     forKey: "reminder_minute")
        defaults.set(Array(reminderDays),forKey: "reminder_days")
        defaults.set(trackingEndHour,    forKey: "tracking_end_hour")
        defaults.set(trackingEndMinute,  forKey: "tracking_end_minute")
        defaults.set(idleAlertEnabled,        forKey: "idle_alert_enabled")
        defaults.set(idleAlertMinutes,        forKey: "idle_alert_minutes")
        defaults.set(Array(workingDays),      forKey: "working_days")
        defaults.set(historyChartStyle.rawValue, forKey: "history_chart_style")
        defaults.set(missingHoursAlertEnabled, forKey: "missing_hours_alert_enabled")
    }

    public func applyReminders() {
        if reminderEnabled {
            NotificationManager.shared.reschedule(hour: reminderHour, minute: reminderMinute, days: reminderDays)
        } else {
            NotificationManager.shared.cancelAllReminders()
        }
    }
}
