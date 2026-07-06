import SwiftUI

struct DurationPickerMac: View {
    @Binding var hours: Int
    @Binding var minutes: Int

    private let quickPicks = [15, 30, 45, 60, 90, 120]
    private let quickPickColumns = [
        GridItem(.adaptive(minimum: 58), spacing: 8, alignment: .leading)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: quickPickColumns, alignment: .leading, spacing: 8) {
                ForEach(quickPicks, id: \.self) { (mins: Int) in
                    quickPickButton(mins: mins)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    TextField("0", value: $hours, format: .number)
                        .frame(width: 44)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: hours) { _, v in hours = min(max(v, 0), 23) }
                    Stepper("", value: $hours, in: 0...23).labelsHidden()
                    Text("h").foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    TextField("0", value: $minutes, format: .number)
                        .frame(width: 44)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: minutes) { _, v in minutes = min(max(v, 0), 59) }
                    Stepper("", value: $minutes, in: 0...59).labelsHidden()
                    Text("m").foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func quickPickButton(mins: Int) -> some View {
        if hours * 60 + minutes == mins {
            Button(quickLabel(mins)) { hours = mins / 60; minutes = mins % 60 }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        } else {
            Button(quickLabel(mins)) { hours = mins / 60; minutes = mins % 60 }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    private func quickLabel(_ mins: Int) -> String {
        guard mins >= 60 else { return "\(mins)m" }
        let h = mins / 60, m = mins % 60
        return m == 0 ? "\(h)h" : "\(h)h\(m)m"
    }
}
