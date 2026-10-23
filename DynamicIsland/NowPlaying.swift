import AppKit
import Observation

/// System-wide now playing (Music, Spotify, YouTube in browsers…) via the bundled
/// mediaremote-adapter. Apps lost MediaRemote access in macOS 15.4; /usr/bin/perl still has it.
@MainActor @Observable
final class NowPlaying {
    static let activityKey = "nowPlayingActivityEnabled" // artwork + waveform beside the notch
    enum Command: Int { case togglePlayPause = 2, nextTrack = 4, previousTrack = 5 }

    private(set) var title: String?
    private(set) var artist: String?
    private(set) var isPlaying = false
    private(set) var appURL: URL?
    private(set) var appIcon: NSImage?
    private var album: String?
    private var receivedArtwork: NSImage?
    private var artworkTitle: String?
    private var artworkAlbum: String?
    private(set) var duration: TimeInterval = 0
    private var elapsedAtTimestamp: TimeInterval = 0
    private var timestamp = Date()
    private var rate = 1.0

    @ObservationIgnored private var info: [String: Any] = [:]
    @ObservationIgnored private var stream: Process?

    func start() {
        stream = run("stream", "--micros", "--debounce=50")
        guard let output = (stream?.standardOutput as? Pipe)?.fileHandleForReading else { return }
        // Per the adapter docs, a stream that exits is not restarted.
        Task.detached {
            do {
                for try await line in output.bytes.lines { await self.apply(line) }
            } catch {
                print("Now playing stream ended: \(error)")
            }
        }
    }

    func stop() { stream?.terminate() }

    func send(_ command: Command) { run("send", String(command.rawValue)) }

    /// Chromium browsers can keep the previous tab's artwork when the playing tab changes,
    /// so artwork that didn't change with the track is stale, unless it's the same album.
    var artwork: NSImage? {
        artworkTitle == title || (album?.isEmpty == false && album == artworkAlbum) ? receivedArtwork : nil
    }

    func elapsed(at date: Date) -> TimeInterval {
        guard isPlaying else { return elapsedAtTimestamp }
        return min(duration, elapsedAtTimestamp + date.timeIntervalSince(timestamp) * rate)
    }

    /// Applies one `stream` line: a full payload, or a diff where `null` removes a key.
    func apply(_ line: String) {
        guard let message = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
              let payload = message["payload"] as? [String: Any] else { return }
        let isDiff = message["diff"] as? Bool == true
        if !isDiff { info = [:] }
        for (key, value) in payload { info[key] = value is NSNull ? nil : value }

        title = info["title"] as? String
        artist = info["artist"] as? String
        album = info["album"] as? String
        isPlaying = info["playing"] as? Bool ?? false
        duration = (info["durationMicros"] as? Double ?? 0) / 1e6
        elapsedAtTimestamp = (info["elapsedTimeMicros"] as? Double ?? 0) / 1e6
        timestamp = (info["timestampEpochMicros"] as? Double).map { Date(timeIntervalSince1970: $0 / 1e6) } ?? .now
        rate = info["playbackRate"] as? Double ?? 1
        let bundleID = info["parentApplicationBundleIdentifier"] as? String ?? info["bundleIdentifier"] as? String
        let url = bundleID.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
        if url != appURL {
            appURL = url
            appIcon = url.map { NSWorkspace.shared.icon(forFile: $0.path).thumbnail() }
        }
        if !isDiff || payload["artworkData"] != nil {
            receivedArtwork = (info["artworkData"] as? String).flatMap { Data(base64Encoded: $0) }
                .flatMap(NSImage.init(data:))?.thumbnail()
            artworkTitle = title
            artworkAlbum = album
        }
    }

    @discardableResult
    private func run(_ arguments: String...) -> Process? {
        guard let script = Bundle.main.path(forResource: "mediaremote-adapter", ofType: "pl"),
              let frameworks = Bundle.main.privateFrameworksPath else { return nil }
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/perl")
        process.arguments = [script, frameworks + "/MediaRemoteAdapter.framework"] + arguments
        process.standardOutput = Pipe()
        guard (try? process.run()) != nil else { return nil }
        return process
    }
}

extension NSImage {
    /// A copy rendered once at a small size, so redraws don't resample a full-size image
    /// (app icons are 1024 px, artwork can be larger) to fit a 28-point square.
    func thumbnail(maxPixels: CGFloat = 256) -> NSImage {
        let scale = min(1, maxPixels / max(size.width, size.height, 1))
        let pixels = NSSize(width: max(1, (size.width * scale).rounded()), height: max(1, (size.height * scale).rounded()))
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(pixels.width), pixelsHigh: Int(pixels.height),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { return self }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        draw(in: NSRect(origin: .zero, size: pixels))
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: pixels)
        image.addRepresentation(rep)
        return image
    }
}
