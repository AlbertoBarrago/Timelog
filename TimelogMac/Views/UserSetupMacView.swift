import SwiftUI
import SwiftData
import TimelogCore
import TimelogSync

struct UserSetupMacView: View {
    @Environment(\.modelContext) private var context
    @Environment(SettingsStore.self) private var settings
    @State private var nickname = ""

    private var trimmed: String { nickname.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.blue.gradient)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 6) {
                Text("What's your name?")
                    .font(.title2.bold())
                Text("Your nickname identifies your data.\nEach teammate uses their own.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            TextField("Nickname", text: $nickname)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
                .onSubmit { if !trimmed.isEmpty { confirm() } }

            HStack {
                Spacer()
                Button("Get Started") { confirm() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .disabled(trimmed.isEmpty)
            }
        }
        .padding(28)
        .frame(width: 320)
    }

    private func confirm() {
        guard !trimmed.isEmpty else { return }
        migrateExistingRecords(to: trimmed)
        settings.userId = trimmed
        RestSyncService.shared.userId = trimmed
        Task {
            try? await RestSyncService.shared.pullAll(into: context)
            RestSyncService.shared.triggerSync()
        }
    }

    private func migrateExistingRecords(to userId: String) {
        let clients  = (try? context.fetch(FetchDescriptor<Client>()))        ?? []
        let projects = (try? context.fetch(FetchDescriptor<Project>()))       ?? []
        let entries  = (try? context.fetch(FetchDescriptor<TimeEntry>()))     ?? []
        let sessions = (try? context.fetch(FetchDescriptor<ActiveSession>())) ?? []
        clients.filter  { $0.userId.isEmpty }.forEach { $0.userId = userId }
        projects.filter { $0.userId.isEmpty }.forEach { $0.userId = userId }
        entries.filter  { $0.userId.isEmpty }.forEach { $0.userId = userId }
        sessions.filter { $0.userId.isEmpty }.forEach { $0.userId = userId }
    }
}
