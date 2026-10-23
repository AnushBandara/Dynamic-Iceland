import Testing
@testable import DynamicIsland

@MainActor @Test func clipboardKeepsRecentTextNewestFirst() {
    let clipboard = Clipboard()
    clipboard.record("one", types: [])
    clipboard.record("two", types: [])
    clipboard.record("one", types: []) // copied again: moves to the top, no duplicate
    #expect(clipboard.items == ["one", "two"])

    clipboard.record("secret", types: ["org.nspasteboard.ConcealedType"]) // password manager
    clipboard.record("  \n", types: [])
    clipboard.record(nil, types: []) // e.g. an image
    #expect(clipboard.items == ["one", "two"])

    for i in 0..<30 { clipboard.record("\(i)", types: []) }
    #expect(clipboard.items.count == Clipboard.limit)
    #expect(clipboard.items.first == "29")
}
