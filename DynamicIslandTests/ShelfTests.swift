import Foundation
import Testing
@testable import DynamicIsland

@MainActor @Test func shelfPersistsAcrossRestartsOnlyWhenEnabled() throws {
    let suite = "ShelfTests-\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let kept = FileManager.default.temporaryDirectory.appending(path: "kept-\(UUID()).txt")
    let deleted = FileManager.default.temporaryDirectory.appending(path: "deleted-\(UUID()).txt")
    try Data().write(to: kept)
    try Data().write(to: deleted)
    defer { try? FileManager.default.removeItem(at: kept) }

    Shelf(defaults: defaults).add([kept, deleted, kept, URL(string: "https://olee.ai")!])
    try FileManager.default.removeItem(at: deleted)

    let restarted = Shelf(defaults: defaults)
    #expect(restarted.files.map(\.lastPathComponent) == [kept.lastPathComponent])

    defaults.set(false, forKey: Shelf.keepKey)
    #expect(Shelf(defaults: defaults).files.isEmpty)
}
