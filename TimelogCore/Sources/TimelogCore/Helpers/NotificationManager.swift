import UserNotifications

public final class NotificationManager {
    public static let shared = NotificationManager()
    private static let overdueNotificationDelay: TimeInterval = 4 * 3600
    private init() {}

    public func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: - Daily reminders

    public func reschedule(hour: Int, minute: Int, days: Set<Int>) {
        cancelAllReminders()
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Time to log!", bundle: Bundle.module)
        content.body = String(localized: "Don't forget to fill in your timesheet for today.", bundle: Bundle.module)
        content.sound = .default
        for weekday in days {
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            components.weekday = weekday
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "timelog_reminder_\(weekday)", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    public func cancelAllReminders() {
        let ids = (1...7).map { "timelog_reminder_\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Session overdue

    public func scheduleSessionOverdue(id: String, clientName: String, projectName: String?,
                                       startDate: Date, endHour: Int, endMinute: Int) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Did you forget to stop tracking?", bundle: Bundle.module)
        let projectText = projectName.map { " / \($0)" } ?? ""
        let sessionName = "\(clientName)\(projectText)"
        let startTime = startDate.formatted(date: .omitted, time: .shortened)
        content.body = String(localized: "\(sessionName) started at \(startTime) is still running.", bundle: Bundle.module)
        content.sound = .default
        content.userInfo = ["sessionID": id]
        let calendar = Calendar.current
        var fireDate = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: startDate) ?? startDate
        if fireDate <= .now { fireDate = Date().addingTimeInterval(Self.overdueNotificationDelay) }
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "session_\(id)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    public func cancelSession(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["session_\(id)"])
    }

    public func cancelAllSessions() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix("session_") }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Pomodoro

    public func schedulePomodoroEnd(phase: String, in seconds: TimeInterval, completedCount: Int = 0) {
        cancelPomodoroNotification()
        guard seconds > 0 else { return }
        let content = UNMutableNotificationContent()
        content.sound = .default

        switch phase {
        case "Focus":
            let messages: [(String, String)] = [
                (String(localized: "Focus #\(completedCount) done!", bundle: Bundle.module),
                 String(localized: "Look out the window for 20 seconds. Seriously.", bundle: Bundle.module)),
                (String(localized: "Pomodoro \(completedCount) complete!", bundle: Bundle.module),
                 String(localized: "Stand up. Stretch. The code can wait.", bundle: Bundle.module)),
                (String(localized: "Great work!", bundle: Bundle.module),
                 String(localized: "20-20-20 rule: look 20 feet away for 20 seconds. Your eyes will thank you.", bundle: Bundle.module)),
                (String(localized: "Session \(completedCount) in the bag!", bundle: Bundle.module),
                 String(localized: "Roll your shoulders. Drink some water. You're a biological machine, not just a digital one.", bundle: Bundle.module)),
                (String(localized: "Focus finished!", bundle: Bundle.module),
                 String(localized: "Look away from the monitor. Even 5 minutes make a difference.", bundle: Bundle.module)),
            ]
            if let (title, body) = messages.randomElement() {
                content.title = title; content.body = body
            }
        case "Short Break":
            let messages: [(String, String)] = [
                (String(localized: "Break's over, back to it!", bundle: Bundle.module),
                 String(localized: "Your mind is recharged. Let's dive in.", bundle: Bundle.module)),
                (String(localized: "Break over!", bundle: Bundle.module),
                 String(localized: "The next focus starts now. You've got this.", bundle: Bundle.module)),
                (String(localized: "Ready?", bundle: Bundle.module),
                 String(localized: "Deep breath and go — one pomodoro at a time.", bundle: Bundle.module)),
                (String(localized: "Back to the desk!", bundle: Bundle.module),
                 String(localized: "The break did its job. Now it's your turn.", bundle: Bundle.module)),
                (String(localized: "Here we go again!", bundle: Bundle.module),
                 String(localized: "Focus mode on. Silence and concentration.", bundle: Bundle.module)),
            ]
            if let (title, body) = messages.randomElement() {
                content.title = title; content.body = body
            }
        case "Long Break":
            let messages: [(String, String)] = [
                (String(localized: "Long break's over!", bundle: Bundle.module),
                 String(localized: "Hope you took a walk. Time to get back to work.", bundle: Bundle.module)),
                (String(localized: "Welcome back!", bundle: Bundle.module),
                 String(localized: "The long break did its job. Let's get back on track.", bundle: Bundle.module)),
                (String(localized: "Rested?", bundle: Bundle.module),
                 String(localized: "Because a new set of pomodoros starts now.", bundle: Bundle.module)),
                (String(localized: "You there?", bundle: Bundle.module),
                 String(localized: "After a good long break, your brain is at its best. Let's use it.", bundle: Bundle.module)),
            ]
            if let (title, body) = messages.randomElement() {
                content.title = title; content.body = body
            }
        default:
            content.title = String(localized: "\(phase) complete!", bundle: Bundle.module)
            content.body = String(localized: "Time for a break.", bundle: Bundle.module)
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: "pomodoro_phase", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    public func cancelPomodoroNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["pomodoro_phase"])
    }

    // MARK: - Idle alert

    private static let idleNotificationID = "timelog_idle_alert"

    public func scheduleIdleAlert(afterMinutes minutes: Int) {
        cancelIdleAlert()
        guard minutes > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "You're not tracking anything", bundle: Bundle.module)
        content.body = String(localized: "What are you working on?", bundle: Bundle.module)
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
        let request = UNNotificationRequest(identifier: Self.idleNotificationID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    public func cancelIdleAlert() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.idleNotificationID])
    }

    // MARK: - Missing hours alert

    private static let missingHoursNotificationID = "timelog_missing_hours"

    public func scheduleMissingHoursAlert(endHour: Int, endMinute: Int) {
        cancelMissingHoursAlert()
        let calendar = Calendar.current
        guard let fireDate = calendar.date(bySettingHour: endHour, minute: endMinute, second: 0, of: Date()),
              fireDate > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Did you forget to track today?", bundle: Bundle.module)
        content.body = String(localized: "Your office hours are ending. Log your time before you go.", bundle: Bundle.module)
        content.sound = .default
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: Self.missingHoursNotificationID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    public func cancelMissingHoursAlert() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.missingHoursNotificationID])
    }

    public func notifyPhaseTransition(to phase: String, completedCount: Int) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        switch phase {
        case "Focus":
            content.title = String(localized: "Here we go again!", bundle: Bundle.module)
            content.body = String(localized: "Break's over — focus mode on. One pomodoro at a time.", bundle: Bundle.module)
        case "Short Break":
            content.title = String(localized: "Focus #\(completedCount) done!", bundle: Bundle.module)
            content.body = String(localized: "Look out the window for 20 seconds. Your eyes will thank you.", bundle: Bundle.module)
        case "Long Break":
            content.title = String(localized: "Great work! \(completedCount) pomodoros completed.", bundle: Bundle.module)
            content.body = String(localized: "You deserve a long break. Stand up and stretch.", bundle: Bundle.module)
        default:
            content.title = String(localized: "\(phase) started", bundle: Bundle.module)
            content.body = ""
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(identifier: "pomodoro_transition", content: content, trigger: trigger)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["pomodoro_transition"])
        UNUserNotificationCenter.current().add(request)
    }
}
