import AppKit
import Observation

/// Whether the notched display is showing a full-screen app: a native full-screen Space, or an app's
/// own full-screen window covering the whole display, menu bar included (VLC's default mode).
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
        // App-drawn full screen doesn't switch Spaces, so nothing notifies us.
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated { self.update() }
        }.tolerance = 0.5 // lets macOS batch the wake-up with others
    }

    private func update() {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main,
              let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
              let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue(),
              let spaces = SkyLight.managedDisplaySpaces()
        else { isActive = false; return }
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        let active = Self.isFullScreen(spaces: spaces, displayUUID: CFUUIDCreateString(nil, uuid) as String)
            || Self.coversDisplay(windows: windows, display: CGDisplayBounds(id),
                                  ownPID: ProcessInfo.processInfo.processIdentifier)
        if active != isActive { isActive = active }
    }

    /// Another app has a window exactly covering the display. Zoomed windows stop below the menu bar.
    nonisolated static func coversDisplay(windows: [[String: Any]], display: CGRect, ownPID: Int32) -> Bool {
        windows.contains { window in
            guard window[kCGWindowOwnerPID as String] as? Int32 != ownPID,
                  (window[kCGWindowLayer as String] as? Int ?? -1) >= 0,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds)
            else { return false }
            return rect == display
        }
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
