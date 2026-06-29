import SwiftUI
import SwiftData
import TimelogCore
import TimelogSync

struct UserSetupView: View {
    @Environment(\.modelContext) private var context
    @Environment(SettingsStore.self) private var settings
    @State private var nickname = ""

    private var trimmed: String { nickname.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue.gradient)
                .symbolRenderingMode(.hierarchical)
                .padding(.bottom, 32)

            VStack(spacing: 12) {
                Text("How should Timelog call you?")
                    .font(.title.bold())

                Text("Use the same nickname on each device so your time stays together.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            TextField("Nickname", text: $nickname)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 48)
                .padding(.top, 32)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .onSubmit { if !trimmed.isEmpty { confirm() } }

            Spacer()

            Button(action: confirm) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .disabled(trimmed.isEmpty)
            .accessibilityLabel(String(localized: "Get Started"))
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private func confirm() {
        guard !trimmed.isEmpty else { return }
        migrateExistingRecords(to: trimmed)
        settings.userId = trimmed
        RestSyncService.shared.userId = trimmed
        Task {
            try? await RestSyncService.shared.pullAll(into: context)
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
