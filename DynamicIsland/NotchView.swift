import SwiftUI

struct NotchView: View {
    let notchSize: CGSize
    let nowPlaying: NowPlaying
    let shelf: Shelf
    @State private var isHovering = false
    @State private var isDropTargeted = false
    @AppStorage("useLiquidGlass") private var useLiquidGlass = false

    var body: some View {
        // Dragging a file onto the notch opens it too: hover doesn't fire during a drag.
        let isExpanded = isHovering || isDropTargeted
        let showsActivity = !isExpanded && nowPlaying.isPlaying
        let size = isExpanded ? NotchPanel.expandedSize
            : CGSize(width: notchSize.width + (showsActivity ? notchSize.height * 2 : 0), height: notchSize.height)
        let radius: CGFloat = isExpanded ? 24 : 10
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius)

        ZStack { // not Group: an empty Group drops its modifiers, leaving no island to hover
            if isExpanded {
                HStack(spacing: 16) {
                    NowPlayingView(nowPlaying: nowPlaying)
                    ShelfView(shelf: shelf, isDropTargeted: isDropTargeted).frame(width: 200)
                }
                .padding(EdgeInsets(top: notchSize.height + 8, leading: 24, bottom: 16, trailing: 24))
                .frame(width: NotchPanel.expandedSize.width, height: NotchPanel.expandedSize.height)
                .transition(.opacity)
            } else if showsActivity {
                CompactNowPlayingView(nowPlaying: nowPlaying, height: notchSize.height)
                    .transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .islandBackground(shape, glass: useLiquidGlass)
        .clipShape(shape) // the growing shape reveals the full-size content instead of it overflowing
        .contentShape(shape)
        .onHover { isHovering = $0 }
        .dropDestination(for: URL.self) { urls, _ in
            shelf.add(urls)
            return true
        } isTargeted: { isDropTargeted = $0 }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: size)
        .environment(\.colorScheme, .dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private extension View {
    @ViewBuilder
    func islandBackground(_ shape: some Shape, glass: Bool) -> some View {
        if glass, #available(macOS 26, *) {
            glassEffect(.regular.tint(.black.opacity(0.6)), in: shape)
        } else {
            background(.black, in: shape)
        }
    }
}
