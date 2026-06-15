import TimelogCore
import SwiftUI

struct ContentView: View {
    @Environment(TimerViewModel.self) private var timerVM
    @Environment(SettingsStore.self) private var settings
    @State private var selectedTab: AppTab = .today
    @AppStorage("onboarding_completed") private var onboardingCompleted = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label(AppTab.today.title, systemImage: AppTab.today.icon) }
                .tag(AppTab.today)
            HistoryView(embedded: true)
                .tabItem { Label(AppTab.history.title, systemImage: AppTab.history.icon) }
                .tag(AppTab.history)
            ClientsView()
                .tabItem { Label(AppTab.clients.title, systemImage: AppTab.clients.icon) }
                .tag(AppTab.clients)
            TimerView()
                .tabItem { Label(AppTab.timer.title, systemImage: AppTab.timer.icon) }
                .tag(AppTab.timer)
            SettingsView()
                .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.icon) }
                .tag(AppTab.settings)
            InsightsView()
                .tabItem { Label(AppTab.insights.title, systemImage: AppTab.insights.icon) }
                .tag(AppTab.insights)
        }
        .fullScreenCover(isPresented: Binding(
            get: { !onboardingCompleted },
            set: { if !$0 { onboardingCompleted = true } }
        )) {
            OnboardingView { onboardingCompleted = true }
        }
        .fullScreenCover(isPresented: Binding(
            get: { onboardingCompleted && settings.userId.isEmpty },
            set: { _ in }
        )) {
            UserSetupView()
                .environment(settings)
        }
    }
}
