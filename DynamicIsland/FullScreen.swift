import AppKit
import Observation

/// Whether the notched display is showing a full-screen app. Window frames can't tell: on notched
/// Macs a full-screen window and a zoomed one are the same size, but the current Space's type differs.
@MainActor @Observable
final class FullScreen {
    private(set) var isActive = false

    func start() {
        update()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                self.update()
                Task { // the Space type can settle just after the switch
                    try? await Task.sleep(for: .seconds(0.5))
                    self.update()
                }
            }
        }
    }

    private func update() {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main,
              let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
              let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue(),
              let spaces = SkyLight.managedDisplaySpaces()
        else { isActive = false; return }
        isActive = Self.isFullScreen(spaces: spaces, displayUUID: CFUUIDCreateString(nil, uuid) as String)
    }

    /// The display's entry (or "Main" when displays share Spaces) has a current Space of type 4.
    nonisolated static func isFullScreen(spaces: [[String: Any]], displayUUID: String) -> Bool {
        let display = spaces.first { $0["Display Identifier"] as? String == displayUUID }
            ?? spaces.first { $0["Display Identifier"] as? String == "Main" }
        return (display?["Current Space"] as? [String: Any])?["type"] as? Int == 4
    }
}

/// Private SkyLight API (no public way to read Space types). If it goes away, full screen is never detected.
@MainActor private enum SkyLight {
    private static let framework = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
    private static let connection = dlsym(framework, "SLSMainConnectionID")
        .map { unsafeBitCast($0, to: (@convention(c) () -> Int32).self)() }
    private static let copySpaces = dlsym(framework, "SLSCopyManagedDisplaySpaces")
        .map { unsafeBitCast($0, to: (@convention(c) (Int32) -> Unmanaged<CFArray>?).self) }

    static func managedDisplaySpaces() -> [[String: Any]]? {
        guard let connection, let copySpaces else { return nil }
        return copySpaces(connection)?.takeRetainedValue() as? [[String: Any]]
    }
}
