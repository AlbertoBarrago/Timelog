import TimelogCore
import SwiftUI
import SwiftData

private let presetColorHexes = [
    "#FF3B30", "#FF9500", "#FFCC00", "#34C759",
    "#30B0C7", "#007AFF", "#5856D6", "#AF52DE",
    "#FF2D55", "#A2845E", "#8E8E93", "#32ADE6"
]

struct ClientFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings

    var client: Client?

    @State private var name = ""
    @State private var colorHex = "#007AFF"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Client name", text: $name)
                }
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(presetColorHexes, id: \.self) { hex in
                            colorSwatch(hex: hex)
                        }
                    }
                    .padding(.vertical, 4)
                    ColorPicker("Custom", selection: Binding(
                        get: { Color(hex: colorHex) ?? .accentColor },
                        set: { colorHex = $0.hex }
                    ), supportsOpacity: false)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(client == nil ? "New Client" : "Edit Client")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let c = client {
                    name = c.name
                    colorHex = c.colorHex
                }
            }
        }
    }

    @ViewBuilder
    private func colorSwatch(hex: String) -> some View {
        let selected = colorHex.uppercased() == hex
        Circle()
            .fill(Color(hex: hex) ?? .blue)
            .frame(width: 36, height: 36)
            .overlay {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 1)
                }
            }
            .onTapGesture { colorHex = hex }
            .accessibilityLabel(colorName(for: hex))
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func colorName(for hex: String) -> String {
        switch hex.uppercased() {
        case "#FF3B30": return String(localized: "Red")
        case "#FF9500": return String(localized: "Orange")
        case "#FFCC00": return String(localized: "Yellow")
        case "#34C759": return String(localized: "Green")
        case "#30B0C7": return String(localized: "Teal")
        case "#007AFF": return String(localized: "Blue")
        case "#5856D6": return String(localized: "Indigo")
        case "#AF52DE": return String(localized: "Purple")
        case "#FF2D55": return String(localized: "Pink")
        case "#A2845E": return String(localized: "Brown")
        case "#8E8E93": return String(localized: "Gray")
        case "#32ADE6": return String(localized: "Light Blue")
        default:        return String(localized: "Custom color")
        }
    }

    private func save() {
        dismiss()
        if let c = client {
            c.name = name
            c.colorHex = colorHex
        } else {
            context.insert(Client(name: name, colorHex: colorHex, userId: settings.userId))
        }
        try? context.save()
    }
}
