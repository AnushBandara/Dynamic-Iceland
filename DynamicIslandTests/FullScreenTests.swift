import CoreGraphics
import Testing
@testable import DynamicIsland

@Test func detectsFullScreenSpaceForTheNotchedDisplay() {
    let spaces: [[String: Any]] = [
        ["Display Identifier": "EXTERNAL", "Current Space": ["type": 4]],
        ["Display Identifier": "BUILTIN", "Current Space": ["type": 0]],
    ]
    #expect(!FullScreen.isFullScreen(spaces: spaces, displayUUID: "BUILTIN")) // other display is full screen
    #expect(FullScreen.isFullScreen(spaces: spaces, displayUUID: "EXTERNAL"))
    #expect(FullScreen.isFullScreen(spaces: [["Display Identifier": "Main", "Current Space": ["type": 4]]], displayUUID: "BUILTIN"))
    #expect(!FullScreen.isFullScreen(spaces: [], displayUUID: "BUILTIN"))
}

@Test func detectsAppDrawnFullScreenWindow() {
    func window(pid: Int32, layer: Int, _ rect: CGRect) -> [String: Any] {
        ["kCGWindowOwnerPID": pid, "kCGWindowLayer": layer, "kCGWindowBounds": rect.dictionaryRepresentation]
    }
    let display = CGRect(x: 0, y: 0, width: 1800, height: 1169)
    #expect(FullScreen.coversDisplay(windows: [window(pid: 2, layer: 0, display)], display: display, ownPID: 1)) // VLC
    #expect(!FullScreen.coversDisplay(windows: [window(pid: 2, layer: 0, CGRect(x: 0, y: 40, width: 1800, height: 1129))],
                                      display: display, ownPID: 1)) // zoomed
    #expect(!FullScreen.coversDisplay(windows: [window(pid: 1, layer: 0, display)], display: display, ownPID: 1)) // ours
}
