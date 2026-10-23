import Testing
@testable import DynamicIsland

@Test func decodesMediaKeyEvents() {
    #expect(SystemHUD.mediaKey(data1: 0x0000_0A00) == (0, true))  // volume up, pressed
    #expect(SystemHUD.mediaKey(data1: 0x0003_0B00) == (3, false)) // brightness down, released
    #expect(SystemHUD.mediaKey(data1: 0x0007_0A01) == (7, true))  // mute, key repeat
}

@Test func stepsSnapToTheSystemGrid() {
    #expect(SystemHUD.stepped(9 / 16, by: 1 / 16) == Float(10) / 16)
    #expect(SystemHUD.stepped(0.659, by: -1 / 16) == Float(10) / 16) // off-grid brightness snaps
    #expect(SystemHUD.stepped(1, by: 1 / 16) == 1)
    #expect(SystemHUD.stepped(0.01, by: -1 / 16) == 0)
}
