import Testing
import Foundation
import TimelogCore

@Suite("TimerViewModel")
@MainActor
struct TimerViewModelTests {

    // MARK: displayTime — modalità stopwatch

    @Test func displayTimeMMSSWhenUnderOneHour() {
        let vm = TimerViewModel()
        vm.elapsed = 90
        #expect(vm.displayTime == "01:30")
    }

    @Test func displayTimeHHMMSSWhenOverOneHour() {
        let vm = TimerViewModel()
        vm.elapsed = 3661
        #expect(vm.displayTime == "1:01:01")
    }

    // MARK: displayTime — modalità pomodoro (mostra tempo rimanente)

    @Test func displayTimePomodoroShowsRemainingAtStart() {
        let vm = TimerViewModel()
        vm.pomodoroEnabled = true
        vm.workMinutes = 25
        vm.elapsed = 0
        #expect(vm.displayTime == "25:00")
    }

    @Test func displayTimePomodoroCountsDown() {
        let vm = TimerViewModel()
        vm.pomodoroEnabled = true
        vm.workMinutes = 25
        vm.elapsed = 60
        #expect(vm.displayTime == "24:00")
    }

    // MARK: progress

    @Test func progressZeroWhenPomodoroDisabled() {
        let vm = TimerViewModel()
        vm.elapsed = 500
        #expect(vm.progress == 0.0)
    }

    @Test func progressAtHalfway() {
        let vm = TimerViewModel()
        vm.pomodoroEnabled = true
        vm.workMinutes = 25
        vm.elapsed = TimeInterval(25 * 60 / 2)
        #expect(abs(vm.progress - 0.5) < 0.001)
    }

    @Test func progressClampedToOne() {
        let vm = TimerViewModel()
        vm.pomodoroEnabled = true
        vm.workMinutes = 25
        vm.elapsed = TimeInterval(25 * 60 + 100)
        #expect(vm.progress == 1.0)
    }

    // MARK: phaseComplete — transizioni di stato

    @Test func phaseCompleteWorkToShortBreak() {
        let vm = TimerViewModel()
        vm.phase = .work
        vm.completedPomodoros = 0
        vm.phaseComplete()
        #expect(vm.phase == .shortBreak)
        #expect(vm.completedPomodoros == 1)
        #expect(vm.elapsed == 0)
    }

    @Test func phaseCompleteWorkToLongBreakAfterFourCycles() {
        let vm = TimerViewModel()
        vm.phase = .work
        vm.completedPomodoros = 3
        vm.phaseComplete()
        #expect(vm.phase == .longBreak)
        #expect(vm.completedPomodoros == 4)
    }

    @Test func phaseCompleteBreakReturnsToWork() {
        let vm = TimerViewModel()
        vm.phase = .shortBreak
        vm.phaseComplete()
        #expect(vm.phase == .work)
    }

    @Test func phaseCompleteLongBreakReturnsToWork() {
        let vm = TimerViewModel()
        vm.phase = .longBreak
        vm.phaseComplete()
        #expect(vm.phase == .work)
    }

    // MARK: applySettings

    @Test func applySettingsUpdatesMinutes() {
        let vm = TimerViewModel()
        let suiteName = "test_timer_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = SettingsStore(defaults: defaults)
        store.pomodoroWork = 45
        store.pomodoroShortBreak = 10
        store.pomodoroLongBreak = 20
        vm.applySettings(store)
        #expect(vm.workMinutes == 45)
        #expect(vm.shortBreakMinutes == 10)
        #expect(vm.longBreakMinutes == 20)
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: reset

    @Test func resetClearsTimerButPreservesCount() {
        let vm = TimerViewModel()
        vm.elapsed = 300
        vm.phase = .shortBreak
        vm.completedPomodoros = 2
        vm.reset()
        #expect(vm.elapsed == 0)
        #expect(vm.phase == .work)
        #expect(vm.completedPomodoros == 2)
        #expect(vm.isRunning == false)
    }

    // MARK: restoreState — a running timer resumes after relaunch (does not freeze)

    @Test func runningStopwatchResumesAfterRelaunch() {
        let ud = UserDefaults.standard
        let keys = ["timerVM.isRunning", "timerVM.elapsed", "timerVM.pomodoroEnabled",
                    "timerVM.phase", "timerVM.completedPomodoros", "timerVM.savedAt", "timerVM.savedDate"]
        defer { keys.forEach { ud.removeObject(forKey: $0) } }

        // Simulate a stopwatch that was running 10s ago with 5s already elapsed.
        ud.set(true, forKey: "timerVM.isRunning")
        ud.set(5.0, forKey: "timerVM.elapsed")
        ud.set(false, forKey: "timerVM.pomodoroEnabled")
        ud.set(0, forKey: "timerVM.phase")
        ud.set(0, forKey: "timerVM.completedPomodoros")
        ud.set(Date().timeIntervalSince1970 - 10, forKey: "timerVM.savedAt")
        ud.set("ignored", forKey: "timerVM.savedDate")

        let vm = TimerViewModel()
        defer { vm.pause() } // invalidate the live timer started by restore

        #expect(vm.isRunning == true)            // previously froze as paused
        #expect(vm.elapsed >= 15)                // 5s saved + ~10s wall-clock
    }
}
