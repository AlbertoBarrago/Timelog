import SwiftData
import Foundation

@Model
public final class ActiveSession {
    public var startDate: Date
    public var client: Client?
    public var project: Project?
    public var notes: String?
    public var label: String?
    public var notificationID: String
    public var mongoId: String?
    public var userId: String = ""

    public init(client: Client? = nil, project: Project? = nil, notes: String? = nil, label: String? = nil, userId: String = "") {
        self.startDate = .now
        self.client = client
        self.project = project
        self.notes = notes
        self.label = label
        self.notificationID = UUID().uuidString
        self.mongoId = nil
        self.userId = userId
    }

    public var elapsedDisplay: String {
        let s = Int(Date().timeIntervalSince(startDate))
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%02d:%02d", m, sec)
    }

    public var elapsedMinutes: Int {
        max(0, Int(Date().timeIntervalSince(startDate) / 60))
    }

    /// Minuti trascorsi con tetto alla prima fine di giornata lavorativa
    /// successiva all'avvio: una sessione dimenticata aperta per giorni
    /// non produce voci di durata abnorme (es. 150 ore).
    public func cappedElapsedMinutes(endHour: Int, endMinute: Int) -> Int {
        let seconds = max(0, Date().timeIntervalSince(startDate))
        let raw = max(1, Int((seconds / 60).rounded()))
        let calendar = Calendar.current
        guard var boundary = calendar.date(bySettingHour: endHour, minute: endMinute,
                                           second: 0, of: startDate) else { return raw }
        if boundary <= startDate {
            // Sessione avviata dopo l'orario di fine: vale la fine del giorno dopo
            boundary = calendar.date(byAdding: .day, value: 1, to: boundary) ?? boundary
        }
        guard boundary < Date() else { return raw }
        return max(1, Int(boundary.timeIntervalSince(startDate) / 60))
    }

    public func asTimeEntry(durationMinutes: Int, notes: String?, label: String? = nil) -> TimeEntry {
        TimeEntry(
            date: startDate,
            durationMinutes: durationMinutes,
            notes: notes,
            label: label ?? self.label,
            client: client,
            project: project,
            userId: userId
        )
    }
}
