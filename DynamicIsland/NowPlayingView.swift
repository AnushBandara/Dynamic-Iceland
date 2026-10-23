import SwiftUI

/// Expanded island: artwork, track info, progress and controls.
struct NowPlayingView: View {
    let nowPlaying: NowPlaying

    var body: some View {
        if nowPlaying.title == nil {
            Label("Nothing playing", systemImage: "music.note")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(spacing: 14) {
                Button {
                    if let url = nowPlaying.appURL { NSWorkspace.shared.openApplication(at: url, configuration: .init()) }
                } label: {
                    ArtworkView(nowPlaying: nowPlaying)
                        .frame(width: 84, height: 84)
                        .clipShape(.rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(nowPlaying.appURL.map { "Open \($0.deletingPathExtension().lastPathComponent)" } ?? "Artwork")

                VStack(alignment: .leading, spacing: 6) {
                    Text(nowPlaying.title ?? "").font(.headline).lineLimit(1)
                    Text(nowPlaying.artist ?? "").font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    if nowPlaying.duration > 0 { progress }
                    HStack(spacing: 28) {
                        control("backward.fill", .previousTrack)
                        control(nowPlaying.isPlaying ? "pause.fill" : "play.fill", .togglePlayPause)
                        control("forward.fill", .nextTrack)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var progress: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = nowPlaying.elapsed(at: context.date)
            VStack(spacing: 2) {
                Capsule().fill(.white.opacity(0.2)).frame(height: 4)
                    .overlay { Capsule().fill(.white).scaleEffect(x: elapsed / nowPlaying.duration, anchor: .leading) }
                HStack {
                    Text(Duration.seconds(elapsed).formatted(.time(pattern: .minuteSecond)))
                    Spacer()
                    Text(Duration.seconds(nowPlaying.duration).formatted(.time(pattern: .minuteSecond)))
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
    }

    private func control(_ symbol: String, _ command: NowPlaying.Command) -> some View {
        Button { nowPlaying.send(command) } label: { Image(systemName: symbol).font(.title2) }
            .buttonStyle(.plain)
            .accessibilityLabel(label(for: command))
    }

    private func label(for command: NowPlaying.Command) -> String {
        switch command {
        case .previousTrack: "Previous track"
        case .nextTrack: "Next track"
        case .togglePlayPause: nowPlaying.isPlaying ? "Pause" : "Play"
        }
    }
}

/// Collapsed "live activity": artwork left of the notch, animated waveform right of it.
struct CompactNowPlayingView: View {
    let nowPlaying: NowPlaying
    let height: CGFloat

    var body: some View {
        HStack {
            ArtworkView(nowPlaying: nowPlaying)
                .frame(width: height - 10, height: height - 10)
                .clipShape(.rect(cornerRadius: 5))
            Spacer()
            Waveform(isPlaying: nowPlaying.isPlaying)
        }
        .padding(.horizontal, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Now playing")
        .accessibilityValue([nowPlaying.title, nowPlaying.artist].compactMap { $0 }.joined(separator: ", "))
    }
}

/// Five bars that change height four times a second, without animating in between. SF Symbol
/// effects and variable values animate on every change, which kept the island redrawing
/// (~20% CPU while playing); plain shapes cost well under 1%.
private struct Waveform: View {
    let isPlaying: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0

    private static let resting: [CGFloat] = [0.35, 0.65, 1, 0.65, 0.35]
    private static let steps: [[CGFloat]] = [
        [0.5, 0.9, 0.6, 0.8, 0.4], [0.8, 0.5, 1, 0.5, 0.7], [0.4, 1, 0.7, 0.6, 0.9], [0.7, 0.6, 0.9, 1, 0.5],
    ]

    var body: some View {
        let isMoving = isPlaying && !reduceMotion
        let heights = isMoving ? Self.steps[step % Self.steps.count] : Self.resting
        HStack(spacing: 2) {
            ForEach(heights.indices, id: \.self) { index in
                Capsule().frame(width: 2.5, height: 3 + 13 * heights[index])
            }
        }
        .frame(height: 16)
        .task(id: isMoving) {
            while isMoving && !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                step += 1
            }
        }
    }
}

/// Track artwork, falling back to the playing app's icon.
private struct ArtworkView: View {
    let nowPlaying: NowPlaying

    var body: some View {
        if let image = nowPlaying.artwork ?? nowPlaying.appIcon {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
        } else {
            Image(systemName: "music.note")
        }
    }
}
