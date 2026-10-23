import AppKit
import Observation

/// A single countdown timer (5 / 15 / 25 min presets) with pause, and a short "Done" alert.
@MainActor @Observable
final class Countdown {
    static let enabledKey = "timerEnabled"

    private(set) var end: Date?
    private(set) var pausedRemaining: TimeInterval?
    private(set) var isFinished = false
    @ObservationIgnored private var task: Task<Void, Never>?

    var isActive: Bool { end != nil || pausedRemaining != nil }
    var isPaused: Bool { pausedRemaining != nil }

    func remaining(at now: Date) -> TimeInterval {
        pausedRemaining ?? max(0, end?.timeIntervalSince(now) ?? 0)
    }

    func start(seconds: TimeInterval) {
        task?.cancel()
        pausedRemaining = nil
        isFinished = false
        end = Date().addingTimeInterval(seconds)
        task = Task {
            try? await Task.sleep(for: .seconds(seconds)) // continuous clock: keeps counting while asleep
            guard !Task.isCancelled else { return }
            end = nil
            isFinished = true
            NSSound(named: "Glass")?.play()
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled { isFinished = false }
        }
    }

    func pause() {
        guard let end else { return }
        task?.cancel()
        pausedRemaining = max(0, end.timeIntervalSinceNow)
        self.end = nil
    }

    func resume() {
        if let pausedRemaining { start(seconds: pausedRemaining) }
    }

    func stop() {
        task?.cancel()
        end = nil
        pausedRemaining = nil
        isFinished = false
    }

    /// "4:05", rounded up so a fresh 25 min timer reads 25:00 and the last second 0:01.
    nonisolated static func format(_ remaining: TimeInterval) -> String {
        Duration.seconds(remaining.rounded(.up)).formatted(.time(pattern: .minuteSecond))
    }
}
