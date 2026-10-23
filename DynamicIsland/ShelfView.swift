import QuickLook
import SwiftUI

/// Files held on the island: drag out to use, click to select (⌘-click for more), double-click to
/// open. Selected files get Quick Look, AirDrop and Remove; hovering a file shows its remove button.
struct ShelfView: View {
    let shelf: Shelf
    @State private var selection: Set<URL> = []
    @State private var preview: URL?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                .foregroundStyle(.white.opacity(0.25))
            if shelf.files.isEmpty {
                Label("Drop files, links or text", systemImage: "tray.and.arrow.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(shelf.files, id: \.self) { url in
                            ShelfItem(url: url, isSelected: selection.contains(url), shelf: shelf,
                                      select: { select(url) }, preview: { preview = url })
                        }
                    }
                    .padding(10)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if !selection.isEmpty { actions }
        }
        .quickLookPreview($preview, in: shelf.files)
        .onChange(of: shelf.files) { _, files in selection.formIntersection(files) }
    }

    private func select(_ url: URL) {
        if NSEvent.modifierFlags.contains(.command) {
            if selection.remove(url) == nil { selection.insert(url) }
        } else {
            selection = selection == [url] ? [] : [url]
        }
    }

    private var actions: some View {
        HStack(spacing: 2) {
            action("eye", "Quick Look") { preview = shelf.files.first(where: selection.contains) }
            action("dot.radiowaves.left.and.right", "AirDrop") {
                AirDrop.send(shelf.files.filter(selection.contains).map(DroppedItem.file))
            }
            action("trash", "Remove from Shelf") {
                shelf.remove(selection)
                selection = []
            }
        }
        .padding(3)
        .background(.black.opacity(0.6), in: Capsule())
        .padding(4)
    }

    private func action(_ symbol: String, _ label: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Image(systemName: symbol)
                .font(.caption2)
                .frame(width: 20, height: 20)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}

private struct ShelfItem: View {
    let url: URL
    let isSelected: Bool
    let shelf: Shelf
    let select: () -> Void
    let preview: () -> Void
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 40, height: 40)
                .overlay(alignment: .topTrailing) {
                    if isHovering {
                        Button { shelf.remove(url) } label: {
                            Image(systemName: "xmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.75))
                        }
                        .buttonStyle(.plain)
                        .offset(x: 6, y: -6)
                        .help("Remove from Shelf")
                        .accessibilityLabel("Remove \(url.lastPathComponent)")
                    }
                }
            Text(url.lastPathComponent)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 56)
        }
        .padding(4)
        .background(.white.opacity(isSelected ? 0.18 : 0), in: RoundedRectangle(cornerRadius: 8))
        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
        .onHover { isHovering = $0 } // outside onDrag, whose drag-source view hides hover from what it wraps
        .onTapGesture(count: 2) { NSWorkspace.shared.open(url) }
        .onTapGesture(perform: select)
        .contextMenu {
            Button("Quick Look", action: preview)
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            Button("Remove") { shelf.remove(url) }
            Button("Clear Shelf") { shelf.clear() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(url.lastPathComponent)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { NSWorkspace.shared.open(url) }
        .accessibilityAction(named: "Quick Look", preview)
        .accessibilityAction(named: "Remove") { shelf.remove(url) }
    }
}
