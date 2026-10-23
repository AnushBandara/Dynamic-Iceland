import AppKit
import IOBluetooth
import Observation

/// Short alerts beside the notch: a download finished in ~/Downloads, Bluetooth headphones connected,
/// or a Focus mode turned on / off.
/// Each watcher starts only once its setting is on, so the Downloads / Bluetooth prompts wait until then.
@MainActor @Observable
final class Notices: NSObject {
    static let downloadsKey = "downloadAlertsEnabled"
    static let headphonesKey = "headphoneAlertsEnabled"
    static let focusKey = "focusAlertsEnabled"
    // Browsers write to these, then rename to the real name when the download completes.
    nonisolated static let partialExtensions: Set<String> = ["crdownload", "download", "part", "partial"]

    enum Notice: Equatable {
        case downloaded(URL)
        case headphones(name: String, battery: Int?)
        case focus(name: String, symbol: String, tint: String, isOn: Bool)
    }

    private(set) var current: Notice?

    @ObservationIgnored private var downloadsSource: DispatchSourceFileSystemObject?
    @ObservationIgnored private var downloadsListing: Set<String> = []
    @ObservationIgnored private var bluetoothNotification: IOBluetoothUserNotification?
    @ObservationIgnored private var bluetoothStart = Date.distantFuture
    @ObservationIgnored private var focusMode: String?? // nil until first read: the starting state isn't a change
    @ObservationIgnored private var hideTask: Task<Void, Never>?

    override init() {
        UserDefaults.standard.register(defaults: [Self.downloadsKey: true, Self.headphonesKey: true, Self.focusKey: true])
    }

    func start() {
        startEnabledWatchers()
        // ponytail: polls a ~2 KB file each second; a file watch if it ever shows up in profiles
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated { self.checkFocus() }
        }.tolerance = 0.5 // lets macOS batch the wake-up with others
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { self.startEnabledWatchers() }
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

    private func show(_ notice: Notice, for seconds: Double = 3) {
        current = notice
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            if !Task.isCancelled { current = nil }
        }
    }
}
