import Testing
@testable import DynamicIsland

@Test func dropZoneFollowsPointerPosition() {
    #expect(DropZone.at(x: 100, width: 640, zones: [.shelf, .airDrop]) == .shelf)
    #expect(DropZone.at(x: 500, width: 640, zones: [.shelf, .airDrop]) == .airDrop)
    #expect(DropZone.at(x: 640, width: 640, zones: [.shelf, .airDrop]) == .airDrop) // right edge
    #expect(DropZone.at(x: 10, width: 520, zones: [.airDrop]) == .airDrop)
    #expect(DropZone.at(x: 10, width: 520, zones: []) == nil)
}
