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
        content.title = "Time to log!"
        content.body = "Don't forget to fill in your timesheet for today."
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
        content.title = "Did you forget to stop tracking?"
        let projectText = projectName.map { " / \($0)" } ?? ""
        content.body = "\(clientName)\(projectText) started at \(startDate.formatted(date: .omitted, time: .shortened)) is still running."
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
                ("Focus #\(completedCount) done!", "Guarda fuori dalla finestra per 20 secondi. Sul serio."),
                ("Pomodoro \(completedCount) completato!", "Alzati. Stiracchiati. Il codice può aspettarti."),
                ("Ottimo lavoro!", "Regola 20-20-20: 20 piedi di distanza, 20 secondi. I tuoi occhi ti ringrazieranno."),
                ("Session \(completedCount) in the bag!", "Ruota le spalle. Bevi dell'acqua. Sei una macchina biologica, non solo digitale."),
                ("Focus finito!", "Gira la faccia dal monitor. Anche solo 5 minuti fanno la differenza."),
            ]
            let (title, body) = messages.randomElement()!
            content.title = title; content.body = body
        case "Short Break":
            let messages: [(String, String)] = [
                ("Pausa finita, si torna!", "La mente è ricaricata. Diamoci dentro."),
                ("Break over!", "Il prossimo focus inizia adesso. Ce la puoi fare."),
                ("Pronti?", "Respiro profondo e via — un pomodoro alla volta."),
                ("Torna alla scrivania!", "La pausa ha fatto il suo lavoro. Ora tocca a te."),
                ("Si riparte!", "Focus mode attivata. Silenzio e concentrazione."),
            ]
            let (title, body) = messages.randomElement()!
            content.title = title; content.body = body
        case "Long Break":
            let messages: [(String, String)] = [
                ("Lunga pausa finita!", "Speriamo tu abbia fatto una passeggiata. Ora si lavora."),
                ("Bentornato!", "La pausa lunga è servita. Rimettiamoci in carreggiata."),
                ("Riposato?", "Perché ora inizia un nuovo set di pomodori."),
                ("Ci sei?", "Dopo una bella pausa lunga, il cervello è al massimo. Usiamolo."),
            ]
            let (title, body) = messages.randomElement()!
            content.title = title; content.body = body
        default:
            content.title = "\(phase) complete!"
            content.body = "Time for a break."
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
        content.title = String(localized: "You're not tracking anything")
        content.body = String(localized: "What are you working on?")
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
        let request = UNNotificationRequest(identifier: Self.idleNotificationID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    public func cancelIdleAlert() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.idleNotificationID])
    }

    public func notifyPhaseTransition(to phase: String, completedCount: Int) {
        let content = UNMutableNotificationContent()
        content.sound = .default
        switch phase {
        case "Focus":
            content.title = "Si riparte!"
            content.body = "Pausa finita — focus mode attivata. Un pomodoro alla volta."
        case "Short Break":
            content.title = "Focus #\(completedCount) completato!"
            content.body = "Guarda fuori dalla finestra per 20 secondi. I tuoi occhi ti ringrazieranno."
        case "Long Break":
            content.title = "Ottimo lavoro! \(completedCount) pomodori completati."
            content.body = "Meriti una pausa lunga. Alzati e stiracchiati."
        default:
            content.title = "\(phase) started"
            content.body = ""
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(identifier: "pomodoro_transition", content: content, trigger: trigger)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["pomodoro_transition"])
        UNUserNotificationCenter.current().add(request)
    }
}
