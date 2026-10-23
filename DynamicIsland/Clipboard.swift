import AppKit
import Observation

/// Recently copied text, newest first. macOS has no pasteboard change notification, so this polls
/// the change count. Kept in memory only, and password managers' concealed copies are skipped.
@MainActor @Observable
final class Clipboard {
    static let enabledKey = "clipboardEnabled"
    static let limit = 20
    // nspasteboard.org markers that password managers and similar apps set on sensitive copies
    private static let skippedTypes: Set<String> = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType"]

    private(set) var items: [String] = []
    @ObservationIgnored private var changeCount = NSPasteboard.general.changeCount

    init() {
        UserDefaults.standard.register(defaults: [Self.enabledKey: true])
    }

    func start() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            MainActor.assumeIsolated { self.poll() }
        }
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != changeCount else { return }
        changeCount = pasteboard.changeCount
        guard UserDefaults.standard.bool(forKey: Self.enabledKey) else { return }
        record(pasteboard.string(forType: .string), types: pasteboard.types?.map(\.rawValue) ?? [])
    }

    func record(_ text: String?, types: [String]) {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              Self.skippedTypes.isDisjoint(with: types) else { return }
        items.removeAll { $0 == text }
        items.insert(text, at: 0)
        items = Array(items.prefix(Self.limit))
    }

    /// Puts the text back on the clipboard; the next poll moves it to the top.
    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func remove(_ text: String) {
        items.removeAll { $0 == text }
    }

    func clear() {
        items = []
    }
}
