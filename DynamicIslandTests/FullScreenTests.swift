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
