import Foundation
import Testing
@testable import DynamicIsland

@MainActor @Test func countdownPausesResumesAndFinishes() async throws {
    let countdown = Countdown()
    countdown.start(seconds: 60)
    #expect(countdown.isActive)
    #expect(abs(countdown.remaining(at: Date().addingTimeInterval(30)) - 30) < 1)

    countdown.pause()
    let paused = countdown.remaining(at: Date())
    #expect(countdown.remaining(at: Date().addingTimeInterval(100)) == paused) // frozen while paused

    countdown.start(seconds: 0.1)
    try await Task.sleep(for: .seconds(0.5))
    #expect(countdown.isFinished && !countdown.isActive)

    countdown.stop()
    #expect(!countdown.isFinished)
}

@Test func formatsRemainingTime() {
    #expect(Countdown.format(25 * 60) == "25:00")
    #expect(Countdown.format(0.2) == "0:01")
    #expect(Countdown.format(245) == "4:05")
}
