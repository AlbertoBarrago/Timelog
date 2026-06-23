import Foundation
import TimelogCore

struct EndDayClosure: Identifiable {
    let date: Date
    let mood: String
    let note: String?

    var id: Date { date }

    static func today(from entries: [TimeEntry], calendar: Calendar = .current) -> EndDayClosure? {
        closures(from: entries, calendar: calendar).first { calendar.isDateInToday($0.date) }
    }

    static func closures(from entries: [TimeEntry], calendar: Calendar = .current) -> [EndDayClosure] {
        var byDay: [Date: EndDayClosure] = [:]

        for entry in entries {
            guard let parsed = parse(notes: entry.notes) else { continue }
            let day = calendar.startOfDay(for: entry.date)
            if byDay[day] == nil {
                byDay[day] = EndDayClosure(date: day, mood: parsed.mood, note: parsed.note)
            }
        }

        return byDay.values.sorted { $0.date > $1.date }
    }

    private static func parse(notes: String?) -> (mood: String, note: String?)? {
        guard let notes else { return nil }

        let lines = notes.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("Chiusura giornata:") else { continue }

            let mood = trimmed.replacingOccurrences(of: "Chiusura giornata:", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !mood.isEmpty else { return nil }

            let note = lines.dropFirst(index + 1)
                .first { $0.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("Nota:") }
                .map {
                    $0.replacingOccurrences(of: "Nota:", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .flatMap { $0.isEmpty ? nil : $0 }

            return (mood, note)
        }

        return nil
    }
}
