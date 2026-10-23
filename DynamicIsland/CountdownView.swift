import SwiftUI

/// Timer controls in the expanded island's top-right corner, beside the notch.
struct CountdownHeaderView: View {
    let countdown: Countdown

    var body: some View {
        HStack(spacing: 4) {
            Spacer(minLength: 0)
            if countdown.isActive {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(Countdown.format(countdown.remaining(at: context.date)))
                        .font(.callout.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.orange)
                }
                button(countdown.isPaused ? "play.fill" : "pause.fill", label: countdown.isPaused ? "Resume timer" : "Pause timer") {
                    countdown.isPaused ? countdown.resume() : countdown.pause()
                }
                button("xmark", label: "Stop timer") { countdown.stop() }
            } else {
                Image(systemName: "timer").font(.caption).foregroundStyle(.secondary).accessibilityHidden(true)
                ForEach([5, 15, 25], id: \.self) { minutes in
                    Button("\(minutes)m") { countdown.start(seconds: TimeInterval(minutes * 60)) }
                        .font(.caption2.weight(.semibold))
                        .fixedSize() // never wrap "15m" in the narrow strip
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.12), in: Capsule())
                        .buttonStyle(.plain)
                        .accessibilityLabel("Start \(minutes) minute timer")
                }
            }
        }
    }

    private func button(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.caption2)
                .frame(width: 20, height: 20)
                .background(.white.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Collapsed countdown: timer icon left of the notch, remaining time (or "Done") right of it.
struct CompactCountdownView: View {
    let countdown: Countdown

    var body: some View {
        HStack {
            Image(systemName: countdown.isFinished ? "bell.fill" : "timer")
                .symbolEffect(.bounce, value: countdown.isFinished)
            Spacer()
            if countdown.isFinished {
                Text("Done")
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(Countdown.format(countdown.remaining(at: context.date)))
                }
            }
        }
        .font(.callout.monospacedDigit().weight(.semibold))
        .foregroundStyle(.orange)
        .padding(.horizontal, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Timer")
    }
}
