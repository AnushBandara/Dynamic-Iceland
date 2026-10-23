import SwiftUI

/// Recently copied text: click a row to copy it again, right-click for more.
struct ClipboardView: View {
    let clipboard: Clipboard

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.06))
            if clipboard.items.isEmpty {
                Label("Copied text shows here", systemImage: "doc.on.clipboard")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(clipboard.items, id: \.self) { ClipboardRow(clipboard: clipboard, text: $0) }
                    }
                    .padding(6)
                }
            }
        }
    }
}

private struct ClipboardRow: View {
    let clipboard: Clipboard
    let text: String
    @State private var isHovering = false

    var body: some View {
        Text(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " "))
            .font(.caption)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(isHovering ? 0.12 : 0), in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .onHover { isHovering = $0 }
            .onTapGesture { clipboard.copy(text) }
            .help(text)
            .contextMenu {
                Button("Copy") { clipboard.copy(text) }
                Button("Remove") { clipboard.remove(text) }
                Button("Clear History") { clipboard.clear() }
            }
    }
}
