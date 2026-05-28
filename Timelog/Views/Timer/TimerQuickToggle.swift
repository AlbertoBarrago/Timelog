import TimelogCore
import SwiftUI

/// Toolbar button that toggles the stopwatch without switching tabs.
struct TimerQuickToggle: View {
    @Environment(TimerViewModel.self) private var vm

    var body: some View {
        Button { vm.toggle() } label: {
            if vm.isRunning {
                Label(vm.displayTime, systemImage: "timer")
                    .monospacedDigit()
                    .foregroundStyle(.tint)
            } else {
                Image(systemName: "timer")
            }
        }
        .help(vm.isRunning ? String(localized: "Pause timer") : String(localized: "Start timer"))
        .accessibilityLabel(vm.isRunning ? String(localized: "Pause timer") : String(localized: "Start timer"))
    }
}
