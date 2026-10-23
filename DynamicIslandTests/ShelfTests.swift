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

@MainActor @Test func droppedLinksAndTextBecomeShelfFilesThatGoAwayWithThem() throws {
    let suite = "ShelfTests-\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    let folder = FileManager.default.temporaryDirectory.appending(path: "ShelfItems-\(UUID())")
    defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: folder) }
    let shelf = Shelf(defaults: defaults, itemsFolder: folder)

    shelf.add([.link(URL(string: "https://olee.ai/docs")!), .text("Meeting notes\nsecond line"), .text("Meeting notes")])
    #expect(shelf.files.map(\.lastPathComponent) == ["olee.ai.webloc", "Meeting notes.txt", "Meeting notes 2.txt"])
    let webloc = try PropertyListSerialization.propertyList(from: Data(contentsOf: shelf.files[0]), format: nil) as? [String: String]
    #expect(webloc?["URL"] == "https://olee.ai/docs")
    #expect(try String(contentsOf: shelf.files[1], encoding: .utf8) == "Meeting notes\nsecond line")

    let text = shelf.files[1]
    shelf.remove([text])
    #expect(!FileManager.default.fileExists(atPath: text.path)) // the shelf's own file is deleted
    #expect(Shelf.title(for: "  a/b:c.  ") == "a-b-c")
    #expect(Shelf.title(for: "\n") == "Text")
}
