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
    // @Observable so mutating hover state does NOT re-render the cells themselves.
    @State private var hover = HoverTracker()
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
                    // Cell grid — onContinuousHover on the whole grid avoids
                    // per-cell GeometryReader which caused re-render flicker.
                    HStack(spacing: spacing) {
                        ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                            VStack(spacing: spacing) {
                                ForEach(0 ..< 7, id: \.self) { row in
                                    cell(row < column.count ? column[row] : nil)
                                }
                            }
                        }
                    }
                    .onContinuousHover { phase in
                        let cs = cellSize
                        switch phase {
                        case .active(let loc):
                            let col = Int(loc.x / (cs + spacing))
                            let row = Int(loc.y / (cs + spacing))
                            guard col >= 0, col < columns.count, row >= 0, row < 7 else {
                                hover.day = nil; return
                            }
                            let column = columns[col]
                            let d = row < column.count ? column[row] : nil
                            if let d, d.minutes > 0 {
                                hover.day = d
                                hover.position = loc
                            } else {
                                hover.day = nil
                            }
                        case .ended:
                            hover.day = nil
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        // Separate view reads hover state — cells never re-render on hover change.
                        HoverCardOverlay(hover: hover,
                                         nameForClient: nameForClient,
                                         colorForClient: colorForClient,
                                         cellSize: cellSize)
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
        let cs = cellSize
        return RoundedRectangle(cornerRadius: 3)
            .fill(fill(for: day))
            .frame(width: cs, height: cs)
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

// MARK: - Hover state

/// @Observable so only HoverCardOverlay re-renders on changes; cells are unaffected.
@Observable private final class HoverTracker {
    var day: HeatmapDay?
    var position: CGPoint = .zero
}

// MARK: - Hover card overlay

private struct HoverCardOverlay: View {
    let hover: HoverTracker
    let nameForClient: (String?) -> String
    let colorForClient: (String?) -> Color
    let cellSize: CGFloat

    var body: some View {
        if let day = hover.day {
            let pos = hover.position
            let gridH = 7 * cellSize + 6 * CGFloat(3)
            let cardEstH: CGFloat = 80
            // Center the card on the cursor, clamped to stay within the grid bounds.
            let y = max(0, min(pos.y - cardEstH / 2, gridH - cardEstH))

            DayHoverCard(day: day, nameForClient: nameForClient, colorForClient: colorForClient)
                .fixedSize()
                .offset(x: max(0, pos.x - 90), y: y)
                .allowsHitTesting(false)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.1), value: pos)
        }
    }
}

// MARK: - Hover card

private struct DayHoverCard: View {
    let day: HeatmapDay
    let nameForClient: (String?) -> String
    let colorForClient: (String?) -> Color

    private var sortedClients: [(id: String?, color: Color, minutes: Int)] {
        day.clientMinutes
            .sorted { $0.value > $1.value }
            .map { (id: $0.key, color: colorForClient($0.key), minutes: $0.value) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(day.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year()))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 5)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(sortedClients.enumerated()), id: \.offset) { _, client in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(client.color)
                            .frame(width: 7, height: 7)
                        Text(nameForClient(client.id))
                            .font(.caption2)
                            .lineLimit(1)
                        Spacer(minLength: 12)
                        Text(client.minutes.formattedDuration)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            if sortedClients.count > 1 {
                Divider()
                HStack {
                    Text("Total")
                        .font(.caption2.weight(.semibold))
                    Spacer()
                    Text(day.minutes.formattedDuration)
                        .font(.caption2.weight(.semibold).monospacedDigit())
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
        }
        .frame(minWidth: 160, maxWidth: 220)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
    }
}
