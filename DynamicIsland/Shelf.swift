import Foundation
import Observation

/// Files dropped on the island. Stored as bookmarks so they survive renames and moves,
/// and restored at launch when "Keep shelf files after restart" is on.
@MainActor @Observable
final class Shelf {
    static let enabledKey = "shelfEnabled"
    static let keepKey = "keepShelfAfterRestart"
    private static let storageKey = "shelfBookmarks"

    private(set) var files: [URL] = []
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Self.keepKey: true])
        if defaults.bool(forKey: Self.keepKey) {
            files = (defaults.array(forKey: Self.storageKey) as? [Data] ?? []).compactMap { bookmark in
                var isStale = false
                return try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale)
            }
        }
        save() // drops deleted files and refreshes moved ones
    }

    func add(_ urls: [URL]) {
        for url in urls where url.isFileURL && !files.contains(url) {
            files.append(url)
        }
        save()
    }

    func remove(_ url: URL) {
        files.removeAll { $0 == url }
        save()
    }

    func clear() {
        files = []
        save()
    }

    private func save() {
        defaults.set(files.compactMap { try? $0.bookmarkData() }, forKey: Self.storageKey)
    }
}
