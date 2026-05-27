import TimelogCore
import SwiftUI
import SwiftData

struct ProjectFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settings

    var client: Client
    var project: Project?

    @State private var name = ""
    @State private var code = ""
    @State private var labels: [String] = []
    @State private var newLabel = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Project name", text: $name)
                    TextField("Code (optional)", text: $code)
                }

                Section("Labels") {
                    ForEach(labels, id: \.self) { label in
                        Text(label)
                    }
                    .onDelete { labels.remove(atOffsets: $0) }

                    HStack {
                        TextField("New label", text: $newLabel)
                        Button("Add") { addLabel() }
                            .disabled(newLabel.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(project == nil ? "New Project" : "Edit Project")
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
                if let p = project {
                    name = p.name
                    code = p.code ?? ""
                    labels = p.labels
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 200)
        #endif
    }

    private func addLabel() {
        let trimmed = newLabel.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !labels.contains(trimmed) else { return }
        labels.append(trimmed)
        newLabel = ""
    }

    private func save() {
        dismiss()
        if let p = project {
            p.name = name
            p.code = code.isEmpty ? nil : code
            p.labels = labels
        } else {
            let p = Project(name: name, code: code.isEmpty ? nil : code, userId: settings.userId)
            p.client = client
            p.labels = labels
            context.insert(p)
        }
    }
}
