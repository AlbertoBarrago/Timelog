import SwiftUI
import TimelogCore

enum SidebarItem: String, CaseIterable, Identifiable {
    case today    = "Today"
    case history  = "History"
    case clients  = "Clients"
    case timer    = "Timer"
    case insights = "Stats"
    case settings = "Settings"

    static let primaryItems: [SidebarItem] = [.today, .history, .clients, .timer, .insights]

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .today:    "clock"
        case .history:  "calendar"
        case .clients:  "person.2"
        case .timer:    "timer"
        case .insights: "chart.xyaxis.line"
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
        // NavigationSplitView creates its toolbar lazily; it may not exist
        // on the first async tick yet.
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

    /// Changing the toolbar display mode ("Icon and Text", "Text Only") from
    /// the context menu breaks the NavigationSplitView layout: the sidebar
    /// toggle disappears from the leading edge and reappears at the trailing
    /// side. Force `.iconOnly` and, where the API exists, remove those menu items.
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
                    Label(SidebarItem.settings.rawValue, systemImage: SidebarItem.settings.icon)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
        case .insights: InsightsMacView()
        case .settings: MacSettingsView()
        }
    }
}

