import Foundation
import Observation
#if os(iOS)
import UIKit
#endif
#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
#endif
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

public enum PomodoroPhase {
    case work, shortBreak, longBreak

    public var label: String {
        switch self {
        case .work: "Focus"
        case .shortBreak: "Short Break"
        case .longBreak: "Long Break"
        }
    }
}

@Observable
@MainActor
public final class TimerViewModel {
    public var isRunning = false
    public var elapsed: TimeInterval = 0
    public var pomodoroEnabled = false
    public var phase: PomodoroPhase = .work
    public var completedPomodoros = 0
    public var workMinutes = 25
    public var shortBreakMinutes = 5
    public var longBreakMinutes = 15
    public var pomodorosBeforeLong = 4
    public var pomodoroSoundEnabled = true
    public var pomodoroAutoAdvance = false

    public init() {
        restoreState()
        sessionWipeObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("RestSyncServiceWillWipeData"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isRunning else { return }
                self.reset()
            }
        }
    }

    public func applySettings(_ store: SettingsStore) {
        workMinutes = store.pomodoroWork
        shortBreakMinutes = store.pomodoroShortBreak
        longBreakMinutes = store.pomodoroLongBreak
        pomodoroSoundEnabled = store.pomodoroSoundEnabled
        pomodoroAutoAdvance = store.pomodoroAutoAdvance
    }

    private var timer: Timer?
    private var sessionWipeObserver: Any?

    public var phaseTotal: TimeInterval {
        switch phase {
        case .work: TimeInterval(workMinutes * 60)
        case .shortBreak: TimeInterval(shortBreakMinutes * 60)
        case .longBreak: TimeInterval(longBreakMinutes * 60)
        }
    }

    public var progress: Double {
        guard pomodoroEnabled, phaseTotal > 0 else { return 0 }
        return min(elapsed / phaseTotal, 1.0)
    }

    public var displayTime: String {
        if pomodoroEnabled {
            let remaining = max(phaseTotal - elapsed, 0)
            let m = Int(remaining) / 60
            let s = Int(remaining) % 60
            return String(format: "%02d:%02d", m, s)
        } else {
            let h = Int(elapsed) / 3600
            let m = (Int(elapsed) % 3600) / 60
            let s = Int(elapsed) % 60
            return h > 0
                ? String(format: "%d:%02d:%02d", h, m, s)
                : String(format: "%02d:%02d", m, s)
        }
    }

    public func toggle() { isRunning ? pause() : start() }

    private func startTimerLoop() {
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    public func start() {
        isRunning = true
        startTimerLoop()
        if pomodoroEnabled {
            NotificationManager.shared.schedulePomodoroEnd(phase: phase.label, in: phaseTotal - elapsed, completedCount: completedPomodoros)
        }
        saveState()
        #if os(iOS) && !targetEnvironment(macCatalyst)
        startLiveActivity()
        #endif
        #if os(iOS)
        haptic(.medium)
        #endif
    }

    public func pause() {
        stopTimer()
        saveState()
        #if os(iOS) && !targetEnvironment(macCatalyst)
        updateLiveActivity()
        #endif
        #if os(iOS)
        haptic(.light)
        #endif
    }

    public func reset() {
        stopTimer()
        elapsed = 0
        phase = .work
        completedPomodoros = 0
        saveState()
        #if os(iOS) && !targetEnvironment(macCatalyst)
        endLiveActivity()
        #endif
        #if os(iOS)
        haptic(.rigid)
        #endif
    }

    func tick() {
        elapsed += 1
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if Int(elapsed) % 5 == 0 { updateLiveActivity() }
        #endif
        if pomodoroEnabled, elapsed >= phaseTotal { phaseComplete() }
    }

    public func phaseComplete() {
        stopTimer()
        elapsed = 0
        if phase == .work {
            completedPomodoros += 1
            phase = completedPomodoros % pomodorosBeforeLong == 0 ? .longBreak : .shortBreak
        } else {
            phase = .work
        }
        NotificationManager.shared.notifyPhaseTransition(to: phase.label, completedCount: completedPomodoros)
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if pomodoroSoundEnabled { playPhaseSound(for: phase) }
        #endif
        saveState()
        #if os(iOS) && !targetEnvironment(macCatalyst)
        updateLiveActivity()
        #endif
        #if os(iOS)
        haptic(.light)
        #endif
        if pomodoroAutoAdvance { start() }
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    private func playPhaseSound(for phase: PomodoroPhase) {
        let name: String
        switch phase {
        case .shortBreak: name = "Glass"
        case .longBreak:  name = "Hero"
        case .work:       name = "Purr"
        }
        NSSound(named: .init(name))?.play()
    }
    #endif

    private func stopTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        NotificationManager.shared.cancelPomodoroNotification()
    }

    // MARK: - Persistence

    private enum Key {
        static let isRunning = "timerVM.isRunning"
        static let elapsed = "timerVM.elapsed"
        static let pomodoroEnabled = "timerVM.pomodoroEnabled"
        static let phase = "timerVM.phase"
        static let completedPomodoros = "timerVM.completedPomodoros"
        static let savedAt = "timerVM.savedAt"
        static let savedDate = "timerVM.savedDate"
    }

    private func restoreState() {
        let ud = UserDefaults.standard
        guard ud.object(forKey: Key.savedAt) != nil else { return }
        pomodoroEnabled = ud.bool(forKey: Key.pomodoroEnabled)
        phase = Self.phase(from: ud.integer(forKey: Key.phase))
        let savedDate = ud.string(forKey: Key.savedDate) ?? ""
        completedPomodoros = savedDate == Self.todayString() ? ud.integer(forKey: Key.completedPomodoros) : 0
        let savedElapsed = ud.double(forKey: Key.elapsed)
        let wasRunning = ud.bool(forKey: Key.isRunning)
        let savedAt = ud.double(forKey: Key.savedAt)
        if wasRunning && savedAt > 0 {
            elapsed = savedElapsed + max(0, Date().timeIntervalSince1970 - savedAt)
        } else {
            elapsed = savedElapsed
        }
        guard wasRunning else { return }
        // The timer was running when the app was last suspended/terminated. Resume the
        // ticking loop so the display keeps advancing instead of freezing at restore time.
        if pomodoroEnabled && elapsed >= phaseTotal {
            // The current phase already elapsed while the app was closed — resolve it now.
            phaseComplete()
        } else {
            isRunning = true
            startTimerLoop()
            if pomodoroEnabled {
                NotificationManager.shared.schedulePomodoroEnd(phase: phase.label, in: max(phaseTotal - elapsed, 0), completedCount: completedPomodoros)
            }
        }
    }

    private func saveState() {
        let ud = UserDefaults.standard
        ud.set(isRunning, forKey: Key.isRunning)
        ud.set(elapsed, forKey: Key.elapsed)
        ud.set(pomodoroEnabled, forKey: Key.pomodoroEnabled)
        ud.set(Self.int(from: phase), forKey: Key.phase)
        ud.set(completedPomodoros, forKey: Key.completedPomodoros)
        ud.set(Date().timeIntervalSince1970, forKey: Key.savedAt)
        ud.set(Self.todayString(), forKey: Key.savedDate)
    }

    private static func todayString() -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(c.year!)-\(c.month!)-\(c.day!)"
    }

    private static func phase(from raw: Int) -> PomodoroPhase {
        switch raw {
        case 1: .shortBreak
        case 2: .longBreak
        default: .work
        }
    }

    private static func int(from phase: PomodoroPhase) -> Int {
        switch phase {
        case .work: 0
        case .shortBreak: 1
        case .longBreak: 2
        }
    }

    #if os(iOS)
    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    #endif

    deinit {
        MainActor.assumeIsolated {
            if let obs = sessionWipeObserver { NotificationCenter.default.removeObserver(obs) }
            timer?.invalidate()
        }
    }
}

#if os(iOS) && !targetEnvironment(macCatalyst)
extension TimerViewModel {
    private var liveActivityState: TimelogActivityAttributes.ContentState {
        TimelogActivityAttributes.ContentState(
            displayTime: displayTime,
            isRunning: isRunning,
            phase: pomodoroEnabled ? phase.label : "Stopwatch"
        )
    }

    private var _liveActivity: Activity<TimelogActivityAttributes>? {
        Activity<TimelogActivityAttributes>.activities.first
    }

    func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endLiveActivity()
        _ = try? Activity.request(
            attributes: TimelogActivityAttributes(),
            content: .init(state: liveActivityState, staleDate: nil)
        )
    }

    func updateLiveActivity() {
        guard let a = _liveActivity else { return }
        Task { await a.update(.init(state: liveActivityState, staleDate: nil)) }
    }

    func endLiveActivity() {
        guard let a = _liveActivity else { return }
        Task { await a.end(.init(state: liveActivityState, staleDate: nil), dismissalPolicy: .immediate) }
    }
}
#endif
