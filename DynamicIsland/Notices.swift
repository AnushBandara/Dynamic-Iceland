import AppKit
import IOBluetooth
import Observation

/// Short alerts beside the notch: a download finished in ~/Downloads, Bluetooth headphones connected,
/// a Focus mode turned on / off, or Claude Code needs you / finished.
/// Each watcher starts only once its setting is on, so the Downloads / Bluetooth prompts wait until then.
@MainActor @Observable
final class Notices: NSObject {
    static let downloadsKey = "downloadAlertsEnabled"
    static let headphonesKey = "headphoneAlertsEnabled"
    static let focusKey = "focusAlertsEnabled"
    static let claudeKey = "claudeAlertsEnabled"
    static let claudeMessageKey = "claudeAlertMessages"
    static let claudeHintKey = "claudeAlertsOffered"
    // Browsers write to these, then rename to the real name when the download completes.
    nonisolated static let partialExtensions: Set<String> = ["crdownload", "download", "part", "partial"]

    enum Notice: Equatable {
        case downloaded(URL)
        case headphones(name: String, battery: Int?)
        case focus(name: String, symbol: String, tint: String, isOn: Bool)
        case claude(ClaudeEvent, project: String, message: String)
        case claudeHint // once, offering the Claude Code alerts

        var isClaude: Bool {
            switch self {
            case .claude, .claudeHint: true
            default: false
            }
        }
    }

    enum ClaudeEvent { case approval, input, done }

    private(set) var current: Notice?

    @ObservationIgnored private var downloadsSource: DispatchSourceFileSystemObject?
    @ObservationIgnored private var downloadsListing: Set<String> = []
    @ObservationIgnored private var bluetoothNotification: IOBluetoothUserNotification?
    @ObservationIgnored private var bluetoothStart = Date.distantFuture
    @ObservationIgnored private var focusSource: DispatchSourceFileSystemObject?
    @ObservationIgnored private var focusRetry: Task<Void, Never>?
    @ObservationIgnored private var focusMode: String?? // nil until first read: the starting state isn't a change
    @ObservationIgnored private var hideTask: Task<Void, Never>?
    @ObservationIgnored private var claudeApp: NSRunningApplication?

    override init() {
        UserDefaults.standard.register(defaults: [Self.downloadsKey: true, Self.headphonesKey: true, Self.focusKey: true, Self.claudeKey: false, Self.claudeMessageKey: true])
    }

    func start() {
        startEnabledWatchers()
        offerClaudeAlerts()
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { self.startEnabledWatchers() }
        }
        DistributedNotificationCenter.default().addObserver(forName: Self.claudeNotification, object: nil, queue: .main) { note in
            let input = note.userInfo?["input"] as? String
            let app = note.userInfo?["app"] as? Int
            MainActor.assumeIsolated {
                guard self.isEnabled(Self.claudeKey), let notice = Self.claudeNotice(hookInput: Data((input ?? "").utf8)) else { return }
                self.claudeApp = app.flatMap { NSRunningApplication(processIdentifier: pid_t($0)) }
                self.show(notice, for: 6) // long enough to read the message
            }
        }
    }

    private func isEnabled(_ key: String) -> Bool { UserDefaults.standard.bool(forKey: key) }

    private func startEnabledWatchers() {
        if isEnabled(Self.downloadsKey), downloadsSource == nil { watchDownloads() }
        if isEnabled(Self.headphonesKey), bluetoothNotification == nil {
            bluetoothStart = Date()
            bluetoothNotification = IOBluetoothDevice.register(forConnectNotifications: self,
                                                               selector: #selector(deviceConnected(_:device:)))
        }
        if isEnabled(Self.focusKey) {
            if focusSource == nil { watchFocus() } else if focusMode == nil { checkFocus() } // turned back on
        }
    }

    // MARK: Downloads

    private func watchDownloads() {
        let folder = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Downloads")
        let descriptor = open(folder.path, O_EVTONLY)
        guard descriptor >= 0 else { return } // Downloads access denied
        downloadsListing = Self.listing(folder)
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .main)
        source.setEventHandler {
            MainActor.assumeIsolated {
                let listing = Self.listing(folder)
                let finished = Self.finishedDownloads(old: self.downloadsListing, new: listing)
                self.downloadsListing = listing
                if let name = finished.last, self.isEnabled(Self.downloadsKey) {
                    self.show(.downloaded(folder.appending(path: name)))
                }
            }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        downloadsSource = source
    }

    private nonisolated static func listing(_ folder: URL) -> Set<String> {
        Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
    }

    /// Names that just appeared, minus hidden files and in-progress browser downloads.
    // ponytail: any new file counts, including ones moved into Downloads by hand; Firefox's empty placeholder alerts early
    nonisolated static func finishedDownloads(old: Set<String>, new: Set<String>) -> [String] {
        new.subtracting(old)
            .filter { !$0.hasPrefix(".") && !partialExtensions.contains(($0 as NSString).pathExtension.lowercased()) }
            .sorted()
    }

    // MARK: Headphones

    @objc private nonisolated func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        nonisolated(unsafe) let device = device // delivered on the main run loop, and only used there
        MainActor.assumeIsolated {
            // Registering reports devices that are already connected; only alert on new connections.
            guard Date().timeIntervalSince(bluetoothStart) > 3, isEnabled(Self.headphonesKey),
                  device.deviceClassMajor == UInt32(kBluetoothDeviceClassMajorAudio),
                  let address = device.addressString else { return }
            let name = device.name ?? "Headphones"
            show(.headphones(name: name, battery: nil), for: 7) // held while the level arrives
            Task { // the battery level arrives a second or so after the connection
                for _ in 0..<5 {
                    try? await Task.sleep(for: .seconds(1))
                    guard case .headphones(name, nil)? = current else { return }
                    if let battery = await Self.freshBattery(address: address) {
                        show(.headphones(name: name, battery: battery))
                        return
                    }
                }
            }
        }
    }

    nonisolated static let batteryFlag = "--headphone-battery"

    /// IOBluetooth caches a device's battery level per process at the first read, which right after
    /// connecting is still 0, so each read runs this app again as a short-lived helper.
    private nonisolated static func freshBattery(address: String) async -> Int? {
        await Task.detached {
            let process = Process()
            process.executableURL = Bundle.main.executableURL
            process.arguments = [batteryFlag, address]
            let pipe = Pipe()
            process.standardOutput = pipe
            guard (try? process.run()) != nil else { return nil }
            let output = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return Int(String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
        }.value
    }

    /// Helper mode (see `freshBattery`): prints the level and exits. Private IOBluetoothDevice
    /// properties, the same levels Control Center shows; 0 means unknown.
    nonisolated static func printBatteryAndExit(address: String) -> Never {
        func level(_ device: IOBluetoothDevice, _ key: String) -> Int? {
            guard device.responds(to: NSSelectorFromString(key)),
                  let value = (device.value(forKey: key) as? NSNumber)?.intValue, value > 0 else { return nil }
            return value
        }
        if let device = IOBluetoothDevice(addressString: address),
           let battery = level(device, "batteryPercentSingle")
               ?? [level(device, "batteryPercentLeft"), level(device, "batteryPercentRight")].compactMap({ $0 }).min() {
            print(battery)
        }
        exit(0)
    }

    // MARK: Focus

    // Focus has no public API. Its state lives here, readable only with Full Disk Access.
    private nonisolated static let focusFolder = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/DoNotDisturb/DB")

    nonisolated static var canReadFocus: Bool {
        (try? Data(contentsOf: focusFolder.appending(path: "Assertions.json"))) != nil
    }

    /// macOS replaces Assertions.json rather than editing it, so watch its folder, like Downloads.
    private func watchFocus() {
        let descriptor = open(Self.focusFolder.path, O_EVTONLY)
        guard descriptor >= 0 else { // no Full Disk Access yet: try again in a while
            if focusRetry == nil {
                focusRetry = Task {
                    try? await Task.sleep(for: .seconds(30))
                    focusRetry = nil
                    startEnabledWatchers()
                }
            }
            return
        }
        checkFocus() // the starting state, not shown
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .main)
        source.setEventHandler { MainActor.assumeIsolated { self.checkFocus() } }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        focusSource = source
    }

    private func checkFocus() {
        guard isEnabled(Self.focusKey),
              let assertions = try? Data(contentsOf: Self.focusFolder.appending(path: "Assertions.json"))
        else { focusMode = nil; return }
        let mode = Self.activeFocusMode(assertions: assertions)
        defer { focusMode = mode }
        guard let previous = focusMode, previous != mode, let id = mode ?? previous else { return }
        let config = Self.focusConfiguration(id, data: try? Data(contentsOf: Self.focusFolder.appending(path: "ModeConfigurations.json")))
        show(.focus(name: config.name, symbol: config.symbol, tint: config.tint, isOn: mode != nil))
    }

    /// Mode identifier of the newest active Focus assertion, e.g. "com.apple.donotdisturb.mode.default".
    nonisolated static func activeFocusMode(assertions: Data) -> String? {
        let store = ((try? JSONSerialization.jsonObject(with: assertions)) as? [String: Any])
            .flatMap { ($0["data"] as? [[String: Any]])?.first }
        let records = store?["storeAssertionRecords"] as? [[String: Any]] ?? []
        return (records.last?["assertionDetails"] as? [String: Any])?["assertionDetailsModeIdentifier"] as? String
    }

    nonisolated static func focusConfiguration(_ id: String, data: Data?) -> (name: String, symbol: String, tint: String) {
        let store = data.flatMap { (try? JSONSerialization.jsonObject(with: $0)) as? [String: Any] }
            .flatMap { ($0["data"] as? [[String: Any]])?.first }
        let mode = ((store?["modeConfigurations"] as? [String: Any])?[id] as? [String: Any])?["mode"] as? [String: Any]
        return (mode?["name"] as? String ?? "Focus", mode?["symbolImageName"] as? String ?? "moon.fill",
                mode?["tintColorName"] as? String ?? "systemIndigoColor")
    }

    // MARK: Claude Code

    nonisolated static let claudeHookFlag = "--claude-hook"
    private nonisolated static let claudeNotification = Notification.Name("io.github.anushbandara.dynamicisland.claude")
    nonisolated static let claudeSettingsFile = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".claude/settings.json")

    /// Helper mode, run by Claude Code's hooks: hands the hook's JSON to the running app and exits.
    /// Delivered immediately: the app is never active, which would otherwise hold it back.
    nonisolated static func forwardClaudeHookAndExit() -> Never {
        let input = String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
        var info: [String: Any] = ["input": input]
        info["app"] = hostApp().map { Int($0) }
        DistributedNotificationCenter.default().postNotificationName(claudeNotification, object: nil,
                                                                     userInfo: info, deliverImmediately: true)
        exit(0)
    }

    /// Once, a few seconds after launch: when Claude Code is installed and its alerts are off, offer them.
    // ponytail: offered once even if a HUD covered it; Settings > Alerts is the way back
    private func offerClaudeAlerts() {
        guard !isEnabled(Self.claudeHintKey), !isEnabled(Self.claudeKey),
              FileManager.default.fileExists(atPath: Self.claudeSettingsFile.deletingLastPathComponent().path) else { return }
        UserDefaults.standard.set(true, forKey: Self.claudeHintKey)
        Task {
            try? await Task.sleep(for: .seconds(3))
            show(.claudeHint, for: 10)
        }
    }

    /// Clicking the offer: turns the alerts on, then says so.
    func acceptClaudeHint() {
        claudeApp = nil
        if Self.setClaudeHooks(installed: true) {
            UserDefaults.standard.set(true, forKey: Self.claudeKey)
            show(.claude(.done, project: "", message: "Claude Code alerts on. Restart open sessions"), for: 4)
        } else {
            show(.claude(.input, project: "", message: "Couldn't update ~/.claude/settings.json"), for: 6)
        }
    }

    /// The app Claude Code runs in (Terminal, VS Code, the Claude app…): the nearest regular app
    /// above this helper. nil when there is none, e.g. inside tmux, whose server has no app above it.
    private nonisolated static func hostApp() -> pid_t? {
        var pid = getppid()
        while pid > 1 {
            if NSRunningApplication(processIdentifier: pid)?.activationPolicy == .regular { return pid }
            var process = kinfo_proc()
            var size = MemoryLayout<kinfo_proc>.stride
            var query = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
            guard sysctl(&query, 4, &process, &size, nil, 0) == 0, size > 0 else { return nil }
            pid = process.kp_eproc.e_ppid
        }
        return nil
    }

    /// Clicking a Claude Code alert: brings its app forward and dismisses the alert.
    // ponytail: the app, not the exact window or tab; VS Code with several windows shows its last-used one
    func openClaudeApp() {
        if let url = claudeApp?.bundleURL {
            // Opening, not activate(): an app that isn't active itself can't hand activation to another.
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
        hideTask?.cancel()
        current = nil
    }

    /// Stop: Claude finished its turn. Notification: it wants a permission, or is waiting for your reply.
    /// The message is Claude Code's own ("Claude needs your permission to use Bash"), or for Stop the
    /// first line of Claude's last reply, read from the session transcript.
    nonisolated static func claudeNotice(hookInput: Data) -> Notice? {
        guard let input = (try? JSONSerialization.jsonObject(with: hookInput)) as? [String: Any] else { return nil }
        let project = ((input["cwd"] as? String ?? "") as NSString).lastPathComponent
        let message = input["message"] as? String ?? ""
        switch (input["hook_event_name"] as? String, input["notification_type"] as? String) {
        case ("Stop", _):
            let reply = (input["transcript_path"] as? String).flatMap { lastReply(transcript: URL(filePath: $0)) }
            return .claude(.done, project: project, message: reply ?? "Finished")
        case ("Notification", "permission_prompt"): return .claude(.approval, project: project, message: message)
        case ("Notification", "idle_prompt"), ("Notification", "elicitation_dialog"):
            return .claude(.input, project: project, message: message)
        default: return nil
        }
    }

    /// First line of the newest assistant text in a transcript (JSON lines), without Markdown marks.
    /// Only the end of the file is read: transcripts grow to megabytes.
    nonisolated static func lastReply(transcript: URL) -> String? {
        guard let file = try? FileHandle(forReadingFrom: transcript) else { return nil }
        defer { try? file.close() }
        let size = (try? file.seekToEnd()) ?? 0
        try? file.seek(toOffset: size > 262_144 ? size - 262_144 : 0)
        let tail = String(decoding: (try? file.readToEnd()) ?? Data(), as: UTF8.self)
        for line in tail.split(separator: "\n").reversed() where line.contains(#""type":"assistant""#) {
            guard let entry = (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any],
                  entry["isSidechain"] as? Bool != true, // a subagent's reply, not Claude's
                  let content = (entry["message"] as? [String: Any])?["content"] as? [[String: Any]],
                  let text = content.last(where: { $0["type"] as? String == "text" })?["text"] as? String
            else { continue }
            let first = text.split(separator: "\n").lazy
                .map { $0.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "#-*> ").union(.whitespaces)) }
                .first { !$0.isEmpty }
            if let first { return first }
        }
        return nil
    }

    /// ~/.claude/settings.json with this app's Notification and Stop hooks added (`command`) or removed (nil),
    /// leaving every other hook alone. nil when the existing file isn't valid JSON, so it's never overwritten.
    nonisolated static func claudeSettings(_ data: Data?, hookCommand command: String?) -> Data? {
        let parsed = data.map { (try? JSONSerialization.jsonObject(with: $0)) as? [String: Any] } ?? [:]
        guard var root = parsed else { return nil }
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        for event in ["Notification", "Stop"] {
            var groups = (hooks[event] as? [[String: Any]] ?? []).compactMap { group -> [String: Any]? in
                let entries = group["hooks"] as? [[String: Any]] ?? []
                let others = entries.filter { ($0["command"] as? String)?.contains(claudeHookFlag) != true }
                guard others.count != entries.count else { return group }
                return others.isEmpty ? nil : group.merging(["hooks": others]) { $1 }
            }
            if let command { groups.append(["hooks": [["type": "command", "command": command]]]) }
            hooks[event] = groups.isEmpty ? nil : groups
        }
        root["hooks"] = hooks.isEmpty ? nil : hooks
        return try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }

    /// Adds or removes the hooks. Running Claude Code sessions pick them up when restarted.
    // ponytail: the hook points at this copy of the app; moving it means toggling the setting again
    nonisolated static func setClaudeHooks(installed: Bool) -> Bool {
        let file = claudeSettingsFile
        let command = installed ? "\"\(Bundle.main.executablePath ?? "")\" \(claudeHookFlag)" : nil
        guard let data = claudeSettings(try? Data(contentsOf: file), hookCommand: command) else { return false }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        return (try? data.write(to: file, options: .atomic)) != nil
    }

    private func show(_ notice: Notice, for seconds: Double = 3) {
        current = notice
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            if !Task.isCancelled { current = nil }
        }
    }
}
