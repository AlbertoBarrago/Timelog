import SwiftUI
import TimelogCore

/// GitHub-style contribution heatmap: 7 weekday rows × week columns.
/// Each cell is tinted with the prevailing client's colour for that day;
/// opacity scales with the minutes logged (empty days stay neutral).
struct ContributionHeatmapView: View {
    let days: [HeatmapDay]
    let maxMinutes: Int
    /// Maps a client id (or `nil` = no client) to its display colour.
    let colorForClient: (String?) -> Color
    /// Maps a client id (or `nil`) to its display name (used for tooltip / a11y).
    let nameForClient: (String?) -> String

    @State private var availableWidth: CGFloat = 0
    private let spacing: CGFloat = 3
    private var cal: Calendar { .current }

    /// Dynamic cell size that fills the full container width.
    /// Formula: availableWidth = 14 (weekday col) + nCols*(cs+spacing) - spacing
    private var cellSize: CGFloat {
        guard availableWidth > 20, !columns.isEmpty else { return 13 }
        let nCols = CGFloat(columns.count)
        let cs = (availableWidth - 14) / nCols - spacing
        return max(9, min(18, cs))
    }

    private var neutral: Color { Color.secondary.opacity(0.12) }

    // Leading padding so the first real day lands on its weekday row.
    private var paddedCells: [HeatmapDay?] {
        guard let first = days.first else { return [] }
        let weekday = cal.component(.weekday, from: first.date)
        let leading = (weekday - cal.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leading) + days.map { Optional($0) }
    }

    private var columns: [[HeatmapDay?]] {
        stride(from: 0, to: paddedCells.count, by: 7).map { i in
            Array(paddedCells[i ..< min(i + 7, paddedCells.count)])
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = cal.veryShortStandaloneWeekdaySymbols // index 0 = Sunday
        return (0 ..< 7).map { symbols[(cal.firstWeekday - 1 + $0) % 7] }
    }

    var body: some View {
        if days.isEmpty {
            Text("No entries")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: spacing) {
                    weekdayColumn
                    HStack(spacing: spacing) {
                        ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                            VStack(spacing: spacing) {
                                ForEach(0 ..< 7, id: \.self) { row in
                                    cell(row < column.count ? column[row] : nil)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { availableWidth = $0 }
                legend
            }
            .padding(.top, 4)
        }
    }

    private var weekdayColumn: some View {
        VStack(spacing: spacing) {
            ForEach(0 ..< 7, id: \.self) { row in
                Text(row % 2 == 1 ? weekdaySymbols[row] : " ")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: cellSize, alignment: .leading)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 4) {
            Text("Less").font(.system(size: 9)).foregroundStyle(.secondary)
            ForEach(0 ..< 5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(level == 0 ? neutral : Color.accentColor.opacity(opacity(forLevel: level)))
                    .frame(width: 10, height: 10)
            }
            Text("More").font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .accessibilityHidden(true)
    }

    private func cell(_ day: HeatmapDay?) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(fill(for: day))
            .frame(width: cellSize, height: cellSize)
            .help(tooltip(for: day))
            .accessibilityLabel(accessibilityLabel(for: day))
    }

    private func fill(for day: HeatmapDay?) -> Color {
        guard let day, day.minutes > 0 else { return neutral }
        return colorForClient(day.dominantClientId).opacity(opacity(forLevel: level(for: day.minutes)))
    }

    private func level(for minutes: Int) -> Int {
        guard maxMinutes > 0, minutes > 0 else { return 0 }
        let ratio = Double(minutes) / Double(maxMinutes)
        switch ratio {
        case ..<0.25: return 1
        case ..<0.50: return 2
        case ..<0.75: return 3
        default:      return 4
        }
    }

    private func opacity(forLevel level: Int) -> Double {
        switch level {
        case 1:  return 0.35
        case 2:  return 0.55
        case 3:  return 0.78
        default: return 1.0
        }
    }

    private func tooltip(for day: HeatmapDay?) -> String {
        guard let day else { return "" }
        let date = day.date.formatted(.dateTime.weekday(.wide).day().month(.wide))
        guard day.minutes > 0 else { return "\(date) — \(String(localized: "No entries"))" }
        return "\(date) — \(day.minutes.formattedDuration) · \(nameForClient(day.dominantClientId))"
    }

    private func accessibilityLabel(for day: HeatmapDay?) -> Text {
        Text(tooltip(for: day))
    }
}
