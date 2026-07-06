import SwiftUI

struct DurationPickerMac: View {
    @Binding var hours: Int
    @Binding var minutes: Int

    private let quickPicks = [15, 30, 45, 60, 90, 120]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(quickPicks, id: \.self) { (mins: Int) in
                    quickPickButton(mins: mins)
                }
            }

            HStack(spacing: 10) {
                durationField(value: $hours, range: 0...23, suffix: "h")
                durationField(value: $minutes, range: 0...59, suffix: "m")
            }
        }
    }

    @ViewBuilder
    private func quickPickButton(mins: Int) -> some View {
        if hours * 60 + minutes == mins {
            Button(quickLabel(mins)) { hours = mins / 60; minutes = mins % 60 }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .frame(minWidth: 48)
        } else {
            Button(quickLabel(mins)) { hours = mins / 60; minutes = mins % 60 }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(minWidth: 48)
        }
    }

    private func durationField(value: Binding<Int>, range: ClosedRange<Int>, suffix: String) -> some View {
        HStack(spacing: 5) {
            TextField("0", value: value, format: .number)
                .frame(width: 42)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .onChange(of: value.wrappedValue) { _, newValue in
                    value.wrappedValue = min(max(newValue, range.lowerBound), range.upperBound)
                }
            Stepper("", value: value, in: range)
                .labelsHidden()
            Text(suffix)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 12, alignment: .leading)
        }
        .padding(6)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
        }
    }

    private func quickLabel(_ mins: Int) -> String {
        guard mins >= 60 else { return "\(mins)m" }
        let h = mins / 60, m = mins % 60
        return m == 0 ? "\(h)h" : "\(h)h\(m)m"
    }
}
