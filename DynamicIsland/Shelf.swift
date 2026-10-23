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
    /// Where dropped links and text are saved as files, so they can be dragged out like any other.
    @ObservationIgnored let itemsFolder: URL

    init(defaults: UserDefaults = .standard,
         itemsFolder: URL = URL.applicationSupportDirectory.appending(path: "Dynamic Island/Shelf Items")) {
        self.defaults = defaults
        self.itemsFolder = itemsFolder
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

    /// Links become .webloc files and text becomes .txt files in `itemsFolder`.
    func add(_ items: [DroppedItem]) {
        add(items.compactMap { item in
            switch item {
            case .file(let url): url
            case .link(let url): write(Self.webloc(for: url), named: url.host() ?? "Link", extension: "webloc")
            case .text(let text): write(Data(text.utf8), named: Self.title(for: text), extension: "txt")
            }
        })
    }

    func remove(_ urls: some Sequence<URL>) {
        let removed = Set(urls)
        files.removeAll { removed.contains($0) }
        deleteOwnedFiles(removed)
        save()
    }

    func remove(_ url: URL) {
        remove([url])
    }

    func clear() {
        deleteOwnedFiles(Set(files))
        files = []
        save()
    }

    /// Files the shelf created for links and text go away with them; the user's files are never touched.
    private func deleteOwnedFiles(_ urls: Set<URL>) {
        for url in urls where url.deletingLastPathComponent().standardizedFileURL == itemsFolder.standardizedFileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func write(_ data: Data, named name: String, extension ext: String) -> URL? {
        try? FileManager.default.createDirectory(at: itemsFolder, withIntermediateDirectories: true)
        var url = itemsFolder.appending(path: "\(name).\(ext)")
        var copy = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = itemsFolder.appending(path: "\(name) \(copy).\(ext)")
            copy += 1
        }
        return (try? data.write(to: url)) != nil ? url : nil
    }

    static func webloc(for url: URL) -> Data {
        (try? PropertyListSerialization.data(fromPropertyList: ["URL": url.absoluteString], format: .xml, options: 0)) ?? Data()
    }

    /// The text's first line, shortened and safe as a file name.
    static func title(for text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let safe = line.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: ".")))
        return safe.isEmpty ? "Text" : String(safe.prefix(40))
    }

    private func save() {
        defaults.set(files.compactMap { try? $0.bookmarkData() }, forKey: Self.storageKey)
    }
}
