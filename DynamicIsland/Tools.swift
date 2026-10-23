import SwiftUI

/// Tabs of the island's right-hand column. Each can be turned off in Settings.
enum TrayTab: String, CaseIterable, Identifiable {
    case shelf, clipboard, notes, todos, shortcuts

    static let selectedKey = "trayTab"
    var id: Self { self }

    var title: String {
        switch self {
        case .shelf: "Shelf"
        case .clipboard: "Clipboard"
        case .notes: "Notes"
        case .todos: "To-dos"
        case .shortcuts: "Shortcuts"
        }
    }

    var symbol: String {
        switch self {
        case .shelf: "tray"
        case .clipboard: "doc.on.clipboard"
        case .notes: "note.text"
        case .todos: "checklist"
        case .shortcuts: "bolt"
        }
    }

    var enabledKey: String {
        switch self {
        case .shelf: Shelf.enabledKey
        case .clipboard: Clipboard.enabledKey
        case .notes: "notesEnabled"
        case .todos: "todosEnabled"
        case .shortcuts: "shortcutsEnabled"
        }
    }
}

// MARK: - Notes

/// One scratch note, saved as you type.
struct NotesView: View {
    static let textKey = "notesText"
    let onEditing: () -> Void
    @AppStorage(Self.textKey) private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextEditor(text: $text)
            .font(.callout)
            .scrollContentBackground(.hidden)
            .focused($isFocused)
            .padding(6)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Jot something down…")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: isFocused) { _, focused in if focused { onEditing() } }
            .accessibilityLabel("Notes")
    }
}

// MARK: - To-dos

struct Todo: Codable, Equatable, Identifiable {
    var id = UUID()
    var title: String
    var isDone = false
}

/// The to-do list, stored as JSON in UserDefaults.
enum Todos {
    static let key = "todoItems"

    static func decode(_ json: String) -> [Todo] {
        (try? JSONDecoder().decode([Todo].self, from: Data(json.utf8))) ?? []
    }

    static func encode(_ todos: [Todo]) -> String {
        (try? JSONEncoder().encode(todos)).map { String(decoding: $0, as: UTF8.self) } ?? "[]"
    }

    /// New items go to the top; blank titles are ignored.
    static func adding(_ title: String, to todos: [Todo]) -> [Todo] {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? todos : [Todo(title: title)] + todos
    }
}

struct TodosView: View {
    let onEditing: () -> Void
    @AppStorage(Todos.key) private var json = "[]"
    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        let todos = Todos.decode(json)
        VStack(spacing: 4) {
            TextField("Add a to-do", text: $draft)
                .textFieldStyle(.plain)
                .font(.callout)
                .focused($isFocused)
                .onSubmit {
                    json = Todos.encode(Todos.adding(draft, to: todos))
                    draft = ""
                    isFocused = true // keep adding
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            if todos.isEmpty {
                Text("Nothing to do")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(todos) { todo in
                            TodoRow(todo: todo, todos: todos) { json = Todos.encode($0) }
                        }
                    }
                }
            }
        }
        .padding(6)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        .onChange(of: isFocused) { _, focused in if focused { onEditing() } }
    }
}

private struct TodoRow: View {
    let todo: Todo
    let todos: [Todo]
    let save: ([Todo]) -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Button {
                save(todos.map { $0.id == todo.id ? Todo(id: $0.id, title: $0.title, isDone: !$0.isDone) : $0 })
            } label: {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isDone ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(todo.isDone ? "Mark not done" : "Mark done")
            Text(todo.title)
                .font(.callout)
                .strikethrough(todo.isDone)
                .foregroundStyle(todo.isDone ? .secondary : .primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            if isHovering {
                Button { save(todos.filter { $0.id != todo.id }) } label: {
                    Image(systemName: "xmark").font(.caption2).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete \(todo.title)")
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Delete") { save(todos.filter { $0.id != todo.id }) }
            Button("Clear Done") { save(todos.filter { !$0.isDone }) }
        }
    }
}

// MARK: - Shortcuts

/// Runs Apple Shortcuts by name through the system `shortcuts` command; no permission needed.
enum ShortcutsRunner {
    static let pinnedKey = "pinnedShortcuts" // names, one per line

    static func pinned(_ stored: String) -> [String] {
        stored.split(separator: "\n").map(String.init)
    }

    static func toggling(_ name: String, in stored: String) -> String {
        var names = pinned(stored)
        if let index = names.firstIndex(of: name) { names.remove(at: index) } else { names.append(name) }
        return names.joined(separator: "\n")
    }

    /// All of the user's shortcuts, for choosing in Settings.
    static func all() async -> [String] {
        await run(["list"]).map { $0.split(separator: "\n").map(String.init) } ?? []
    }

    @discardableResult
    static func run(_ arguments: [String]) async -> String? {
        await Task.detached {
            let process = Process()
            process.executableURL = URL(filePath: "/usr/bin/shortcuts")
            process.arguments = arguments
            let pipe = Pipe()
            process.standardOutput = pipe
            guard (try? process.run()) != nil else { return nil }
            let output = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return process.terminationStatus == 0 ? String(decoding: output, as: UTF8.self) : nil
        }.value
    }
}

struct ShortcutsView: View {
    @AppStorage(ShortcutsRunner.pinnedKey) private var stored = ""
    @State private var running: String?
    @State private var finished: String?

    var body: some View {
        let names = ShortcutsRunner.pinned(stored)
        Group {
            if names.isEmpty {
                Label("Choose shortcuts in Settings", systemImage: "bolt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 4) {
                        ForEach(names, id: \.self) { name in
                            Button { run(name) } label: {
                                HStack(spacing: 6) {
                                    Group {
                                        if running == name {
                                            ProgressView().controlSize(.mini)
                                        } else {
                                            Image(systemName: finished == name ? "checkmark" : "bolt.fill")
                                        }
                                    }
                                    .frame(width: 14)
                                    .foregroundStyle(finished == name ? .green : .orange)
                                    Text(name).font(.callout).lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(running != nil)
                            .accessibilityLabel("Run \(name)")
                        }
                    }
                    .padding(6)
                }
            }
        }
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
    }

    private func run(_ name: String) {
        running = name
        Task {
            let succeeded = await ShortcutsRunner.run(["run", name]) != nil
            running = nil
            finished = succeeded ? name : nil
            try? await Task.sleep(for: .seconds(2))
            if finished == name { finished = nil }
        }
    }
}
