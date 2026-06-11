import SwiftUI
import TimelogCore

struct TimerMacView: View {
    @Environment(TimerViewModel.self) private var vm
    @Environment(SettingsStore.self) private var settings
    @State private var showModeChangeConfirm = false
    @State private var pendingPomodoroEnabled = false

    var body: some View {
        @Bindable var vm = vm

        VStack(spacing: 0) {
            header(vm: vm)

            Divider()

            HStack(spacing: 28) {
                timerFace(vm: vm)
                    .frame(width: 290, height: 290)

                VStack(alignment: .leading, spacing: 18) {
                    phasePanel(vm: vm)
                    metricsPanel(vm: vm)
                    controls(vm: vm)
                }
                .frame(width: 260)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(28)
        }
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

    private func header(vm: TimerViewModel) -> some View {
        return HStack(spacing: 16) {
            Picker("Mode", selection: Binding(
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
                Label("Stopwatch", systemImage: "stopwatch").tag(false)
                Label("Pomodoro", systemImage: "timer").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(width: 260)
            .onChange(of: vm.pomodoroEnabled, initial: false) { vm.reset() }


            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(vm.isRunning ? Color.green : Color.secondary.opacity(0.35))
                    .frame(width: 8, height: 8)
                Text(vm.isRunning ? "Running" : "Paused")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func timerFace(vm: TimerViewModel) -> some View {
        ZStack {
            Circle()
                .fill(.quaternary.opacity(0.55))

            if vm.pomodoroEnabled {
                Circle()
                    .stroke(Color.secondary.opacity(0.13), lineWidth: 14)
                    .padding(12)

                Circle()
                    .trim(from: 0, to: vm.progress)
                    .stroke(
                        ringColor(for: vm.phase),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(12)
                    .animation(.linear(duration: 1), value: vm.progress)
            } else {
                Circle()
                    .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                    .padding(12)
            }

            VStack(spacing: 8) {
                Image(systemName: vm.pomodoroEnabled ? "timer" : "stopwatch")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(vm.pomodoroEnabled ? ringColor(for: vm.phase) : .secondary)

                Text(vm.displayTime)
                    .font(.system(size: 56, weight: .thin, design: .monospaced))
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Text(vm.pomodoroEnabled ? LocalizedStringKey(vm.phase.label) : "Stopwatch")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func phasePanel(vm: TimerViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(vm.pomodoroEnabled ? LocalizedStringKey(vm.phase.label) : "Open session", systemImage: vm.pomodoroEnabled ? "timer" : "clock")
                .font(.headline)

            Text(vm.pomodoroEnabled ? LocalizedStringKey(phaseDescription(for: vm.phase)) : "Track elapsed time without a fixed interval.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if vm.pomodoroEnabled {
                HStack(spacing: 7) {
                    ForEach(0..<vm.pomodorosBeforeLong, id: \.self) { index in
                        Capsule()
                            .fill(index < vm.completedPomodoros % vm.pomodorosBeforeLong ? Color.accentColor : Color.secondary.opacity(0.22))
                            .frame(width: 28, height: 6)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "\(vm.completedPomodoros % vm.pomodorosBeforeLong) of \(vm.pomodorosBeforeLong) pomodoros completed"))
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
    }

    private func metricsPanel(vm: TimerViewModel) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
            GridRow {
                metric("Mode", vm.pomodoroEnabled ? "Pomodoro" : "Free")
                metric("Done", "\(vm.completedPomodoros)")
            }

            GridRow {
                metric("Work", "\(vm.workMinutes)m")
                metric("Break", "\(vm.shortBreakMinutes)m")
            }
        }
        .padding(14)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 8))
    }

    private func controls(vm: TimerViewModel) -> some View {
        HStack(spacing: 12) {
            Button {
                vm.reset()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!vm.isRunning && vm.elapsed == 0)

            Button {
                vm.toggle()
            } label: {
                Label(playButtonTitle, systemImage: vm.isRunning ? "pause.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.space, modifiers: [])
        }
    }

    private var playButtonTitle: String {
        if vm.isRunning { return String(localized: "Pause") }
        return vm.elapsed > 0
            ? String(localized: "Resume")
            : String(localized: "Start")
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .rounded, weight: .semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func phaseDescription(for phase: PomodoroPhase) -> String {
        switch phase {
        case .work:
            "Focus interval based on your configured work duration."
        case .shortBreak:
            "Short recovery before the next focus interval."
        case .longBreak:
            "Longer break after completing the current set."
        }
    }

    private func ringColor(for phase: PomodoroPhase) -> Color {
        switch phase {
        case .work:       .accentColor
        case .shortBreak: .green
        case .longBreak:  .mint
        }
    }
}
