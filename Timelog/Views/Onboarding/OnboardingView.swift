import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            symbol: "clock.fill",
            color: .blue,
            title: "Welcome to Timelog",
            body: "Track your team's time without making it a chore."
        ),
        OnboardingPage(
            symbol: "plus.circle.fill",
            color: .green,
            title: "Log Time Manually",
            body: "Tap + in Today, choose the client and project, add the time, and move on."
        ),
        OnboardingPage(
            symbol: "play.circle.fill",
            color: .orange,
            title: "Track in Real Time",
            body: "Tap ▶ when you start working and stop it when you're done. Timelog handles the duration for you."
        ),
        OnboardingPage(
            symbol: "bell.fill",
            color: .purple,
            title: "Never Forget to Log",
            body: "Set a daily reminder in Settings to nudge yourself at the end of the day. Sessions left open past your end-of-day time get an automatic alert too."
        ),
        OnboardingPage(
            symbol: "checkmark.circle.fill",
            color: .teal,
            title: "You're All Set!",
            body: "You're ready. You can reopen this guide anytime from Settings."
        )
    ]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in
                    PageView(page: pages[i])
                        .tag(i)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            #endif

            Button("Skip") { onComplete() }
                .font(.subheadline)
                .padding()
                .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom) {
            if page == pages.count - 1 {
                Button(action: onComplete) {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .accessibilityLabel(String(localized: "Get Started"))
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            } else {
                Button(action: { withAnimation { page += 1 } }) {
                    Text("Next")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .accessibilityLabel(String(localized: "Next page"))
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
    }
}

private struct OnboardingPage {
    let symbol: String
    let color: Color
    let title: LocalizedStringKey
    let body: LocalizedStringKey
}

private struct PageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: page.symbol)
                .font(.system(size: 96))
                .foregroundStyle(page.color.gradient)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text(page.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}
