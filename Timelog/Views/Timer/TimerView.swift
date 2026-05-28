import TimelogCore
import SwiftUI

struct TimerView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(TimerViewModel.self) private var vm
    @State private var showModeChangeConfirm = false
    @State private var pendingPomodoroEnabled = false

    var body: some View {
        @Bindable var vm = vm
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                if vm.pomodoroEnabled {
                    VStack(spacing: 8) {
                        Text(LocalizedStringKey(vm.phase.label))
                            .font(.title3)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            ForEach(0..<vm.pomodorosBeforeLong, id: \.self) { i in
                                Circle()
                                    .fill(i < vm.completedPomodoros % vm.pomodorosBeforeLong
                                          ? Color.accentColor : Color.secondary.opacity(0.25))
                                    .frame(width: 10, height: 10)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                }

                ZStack {
                    if vm.pomodoroEnabled {
                        TimerRingView(progress: vm.progress, phase: vm.phase)
                            .frame(width: 280, height: 280)
                    }
                    Text(vm.displayTime)
                        .font(.system(size: 64, weight: .thin, design: .monospaced))
                        .contentTransition(.numericText())
                }

                HStack(spacing: 48) {
                    Button {
                        vm.reset()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Reset timer"))

                    Button {
                        vm.toggle()
                    } label: {
                        Image(systemName: vm.isRunning ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 72))
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(vm.isRunning ? String(localized: "Pause timer") : String(localized: "Start timer"))
                    #if targetEnvironment(macCatalyst)
                    .keyboardShortcut(.space, modifiers: [])
                    #endif

                    Toggle(isOn: Binding(
                        get: { vm.pomodoroEnabled },
                        set: { newValue in
                            if vm.elapsed > 0 || vm.isRunning {
                                pendingPomodoroEnabled = newValue
                                showModeChangeConfirm = true
                            } else {
                                vm.pomodoroEnabled = newValue
                                vm.reset()
                            }
                        }
                    )) {
                        Image(systemName: "timer")
                            .font(.title)
                    }
                    .toggleStyle(.button)
                    .accessibilityLabel(String(localized: "Pomodoro mode"))
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: 480)
            .navigationTitle("Timer")
            .onAppear { vm.applySettings(settings) }
            .confirmationDialog(
                String(localized: "Switch mode"),
                isPresented: $showModeChangeConfirm,
                titleVisibility: .visible
            ) {
                Button(String(localized: "Reset and switch"), role: .destructive) {
                    vm.pomodoroEnabled = pendingPomodoroEnabled
                    vm.reset()
                }
                Button(String(localized: "Cancel"), role: .cancel) {}
            } message: {
                Text("The current session will be reset.")
            }
        }
    }
}
