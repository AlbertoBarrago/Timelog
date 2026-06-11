import SwiftUI
import TimelogCore
import TimelogSync

enum SidebarItem: String, CaseIterable, Identifiable {
    case today    = "Today"
    case history  = "History"
    case clients  = "Clients"
    case timer    = "Timer"
    case settings = "Settings"

    static let primaryItems: [SidebarItem] = [.today, .history, .clients, .timer]

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .today:    "clock"
        case .history:  "calendar"
        case .clients:  "person.2"
        case .timer:    "timer"
        case .settings: "gearshape"
        }
    }
}

private struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            AppDelegate.mainWindow = view.window
            Self.lockToolbarDisplayMode(of: view.window)
        }
        // La toolbar di NavigationSplitView viene creata in modo lazy:
        // al primo tick async potrebbe non esistere ancora.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            Self.lockToolbarDisplayMode(of: view.window)
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        if AppDelegate.mainWindow == nil {
            AppDelegate.mainWindow = nsView.window
        }
        Self.lockToolbarDisplayMode(of: nsView.window)
    }

    /// Cambiare la modalità di visualizzazione della toolbar ("Icona e testo",
    /// "Solo testo") dal menu contestuale rompe il layout di NavigationSplitView:
    /// il toggle della sidebar sparisce dal bordo sinistro e riappare in fondo a
    /// destra. Forziamo .iconOnly e, dove l'API esiste, togliamo le voci dal menu.
    static func lockToolbarDisplayMode(of window: NSWindow?) {
        guard let toolbar = window?.toolbar else { return }
        if toolbar.displayMode != .iconOnly {
            toolbar.displayMode = .iconOnly
        }
        if #available(macOS 15.0, *) {
            toolbar.allowsDisplayModeCustomization = false
        }
    }
}

struct MainMacView: View {
    @Environment(SettingsStore.self) private var settings
    @State private var selection: SidebarItem = .today
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                List(SidebarItem.primaryItems, selection: $selection) { item in
                    Label(LocalizedStringKey(item.rawValue), systemImage: item.icon)
                        .tag(item)
                }
                .listStyle(.sidebar)

                Spacer(minLength: 0)

                Divider()
                    .padding(.horizontal, 10)

                Button {
                    selection = .settings
                } label: {
                    HStack(spacing: 0) {
                        Label(SidebarItem.settings.rawValue, systemImage: SidebarItem.settings.icon)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        SyncStatusDot()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background {
                        if selection == .settings {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor.opacity(0.16))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Settings"))
                .foregroundStyle(selection == .settings ? .primary : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            detailView
        }
        .frame(minWidth: 700, minHeight: 460)
        .background(WindowAccessor())
        .sheet(isPresented: Binding(
            get: { settings.userId.isEmpty },
            set: { _ in }
        )) {
            UserSetupMacView()
                .environment(settings)
        }
    }

    @ViewBuilder private var detailView: some View {
        switch selection {
        case .today:    TodayMacView()
        case .history:  HistoryMacView()
        case .clients:  ClientsMacView()
        case .timer:    TimerMacView()
        case .settings: MacSettingsView()
        }
    }
}

private struct SyncStatusDot: View {
    private var sync: RestSyncService { RestSyncService.shared }
    @State private var pulse = false
    @State private var showHint = false
    @AppStorage("syncHintDismissed") private var hintDismissed: Bool = false

    var body: some View {
        ZStack {
            if sync.isSyncing {
                Circle()
                    .fill(Color.yellow.opacity(0.3))
                    .frame(width: 12, height: 12)
                    .scaleEffect(pulse ? 1.8 : 1.0)
                    .opacity(pulse ? 0 : 1)
                    .animation(.easeOut(duration: 1.1).repeatForever(autoreverses: false), value: pulse)
            }
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(syncStatusDescription)
        .onAppear { pulse = true }
        .onChange(of: sync.isUserEditing) { _, isEditing in
            guard !isEditing, !hintDismissed else { return }
            showHint = true
        }
        .popover(isPresented: $showHint, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Press ⌘S to sync changes immediately.")
                    .font(.callout)
                Button(String(localized: "Got it")) {
                    hintDismissed = true
                    showHint = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(14)
            .frame(width: 240)
        }
    }

    private var dotColor: Color {
        if sync.isSyncing           { return .yellow }
        if sync.lastError != nil    { return .red }
        if sync.lastSyncDate != nil { return .green }
        return .clear
    }

    private var syncStatusDescription: String {
        if sync.isSyncing           { return String(localized: "Sync in progress") }
        if sync.lastError != nil    { return String(localized: "Sync error") }
        if sync.lastSyncDate != nil { return String(localized: "Synced") }
        return String(localized: "Sync not yet run")
    }
}

