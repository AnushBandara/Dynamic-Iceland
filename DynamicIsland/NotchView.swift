import SwiftUI

struct NotchView: View {
    let notchSize: CGSize
    let nowPlaying: NowPlaying
    let shelf: Shelf
    let hud: SystemHUD
    let battery: Battery
    @State private var isHovering = false
    @State private var isDropTargeted = false
    @AppStorage("useLiquidGlass") private var useLiquidGlass = false
    @AppStorage(Shelf.enabledKey) private var shelfEnabled = true

    var body: some View {
        // Dragging a file onto the notch opens it too: hover doesn't fire during a drag.
        let isExpanded = isHovering || isDropTargeted
        let showsHUD = !isExpanded && hud.isVisible
        let showsBattery = !isExpanded && !showsHUD && battery.alert != nil
        let showsActivity = !isExpanded && !showsHUD && !showsBattery && nowPlaying.isPlaying
        let expandedSize = CGSize(width: shelfEnabled ? NotchPanel.expandedSize.width : 520,
                                  height: NotchPanel.expandedSize.height)
        let wings: CGFloat = showsHUD || showsBattery ? 180 : showsActivity ? notchSize.height * 2 : 0
        let size = isExpanded ? expandedSize : CGSize(width: notchSize.width + wings, height: notchSize.height)
        let radius: CGFloat = isExpanded ? 24 : 10
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius)

        ZStack { // not Group: an empty Group drops its modifiers, leaving no island to hover
            if isExpanded {
                HStack(spacing: 16) {
                    NowPlayingView(nowPlaying: nowPlaying)
                    if shelfEnabled {
                        ShelfView(shelf: shelf, isDropTargeted: isDropTargeted).frame(width: 200)
                    }
                }
                .padding(EdgeInsets(top: notchSize.height + 8, leading: 24, bottom: 16, trailing: 24))
                .frame(width: expandedSize.width, height: expandedSize.height)
                .transition(.opacity)
            } else if showsHUD {
                CompactHUDView(hud: hud, height: notchSize.height)
                    .frame(maxHeight: .infinity) // centre vertically; the island aligns content to the top
                    .transition(.opacity)
            } else if showsBattery {
                CompactBatteryView(battery: battery)
                    .frame(maxHeight: .infinity)
                    .transition(.opacity)
            } else if showsActivity {
                CompactNowPlayingView(nowPlaying: nowPlaying, height: notchSize.height)
                    .frame(maxHeight: .infinity)
                    .transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .islandBackground(shape, glass: useLiquidGlass)
        .clipShape(shape) // the growing shape reveals the full-size content instead of it overflowing
        .contentShape(shape)
        .onHover { isHovering = $0 }
        .shelfDropDestination(shelfEnabled ? shelf : nil, isTargeted: $isDropTargeted)
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

    /// No shelf: don't register for drags at all, so the notch ignores dragged files.
    @ViewBuilder
    func shelfDropDestination(_ shelf: Shelf?, isTargeted: Binding<Bool>) -> some View {
        if let shelf {
            dropDestination(for: URL.self) { urls, _ in
                shelf.add(urls)
                return true
            } isTargeted: { isTargeted.wrappedValue = $0 }
        } else {
            self
        }
    }
}
