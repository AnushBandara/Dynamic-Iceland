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
            Image(systemName: "waveform")
                .symbolEffect(.variableColor.iterative, isActive: nowPlaying.isPlaying)
        }
        .padding(.horizontal, 8)
    }
}

/// Track artwork, falling back to the playing app's icon.
private struct ArtworkView: View {
    let nowPlaying: NowPlaying

    var body: some View {
        if let image = nowPlaying.artwork ?? nowPlaying.appURL.map({ NSWorkspace.shared.icon(forFile: $0.path) }) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
        } else {
            Image(systemName: "music.note")
        }
    }
}
