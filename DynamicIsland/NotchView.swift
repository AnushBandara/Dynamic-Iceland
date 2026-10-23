import SwiftUI

struct NotchView: View {
    let notchSize: CGSize
    let nowPlaying: NowPlaying
    let shelf: Shelf
    let hud: SystemHUD
    let battery: Battery
    let agenda: Agenda
    let countdown: Countdown
    let mirror: CameraMirror
    let fullScreen: FullScreen
    let clipboard: Clipboard
    let notices: Notices
    @State private var isHovering = false
    @State private var isDropTargeted = false
    @State private var dropZone: DropZone?
    @State private var showsClipboard = false
    @AppStorage("useLiquidGlass") private var useLiquidGlass = false
    @AppStorage(Shelf.enabledKey) private var shelfEnabled = true
    @AppStorage(Clipboard.enabledKey) private var clipboardEnabled = true
    @AppStorage(DropZone.airDropKey) private var airDropEnabled = true
    @AppStorage(CameraMirror.enabledKey) private var mirrorEnabled = true
    @AppStorage(Countdown.enabledKey) private var timerEnabled = true

    var body: some View {
        // Dragging a file onto the notch opens it too: hover doesn't fire during a drag.
        let isExpanded = isHovering || isDropTargeted
        let showsHUD = !isExpanded && hud.isVisible
        let showsBattery = !isExpanded && !showsHUD && battery.alert != nil
        let notice = isExpanded || showsHUD || showsBattery ? nil : notices.current
        let showsCountdown = !isExpanded && !showsHUD && !showsBattery && notice == nil
            && (countdown.isActive || countdown.isFinished)
        // The always-on now playing hides in full screen (e.g. over a video); alerts still show.
        let showsActivity = !isExpanded && !fullScreen.isActive && !showsHUD && !showsBattery && notice == nil
            && !showsCountdown && nowPlaying.isPlaying
        // Wider when the shelf / clipboard column (+120) or the mirror tile (+116) is on.
        let expandedSize = CGSize(width: 520 + (shelfEnabled || clipboardEnabled ? 120 : 0) + (mirrorEnabled ? 116 : 0),
                                  height: NotchPanel.expandedSize.height)
        let cornerWidth = (expandedSize.width - notchSize.width) / 2 - 32 // strips beside the notch
        // Each side only as wide as its content: HUD bar / battery percentage / time, or artwork.
        let wings: CGFloat = showsHUD || showsBattery || notice != nil || showsCountdown ? 112 : showsActivity ? notchSize.height * 2 : 0
        let size = isExpanded ? expandedSize : CGSize(width: notchSize.width + wings, height: notchSize.height)
        let radius: CGFloat = isExpanded ? 24 : 10
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius)
        let dropZones = DropZone.allCases.filter { $0 == .shelf ? shelfEnabled : airDropEnabled }

        ZStack { // not Group: an empty Group drops its modifiers, leaving no island to hover
            if isExpanded {
                Group {
                    if isDropTargeted {
                        DropZonesView(zones: dropZones, highlighted: dropZone)
                    } else {
                        HStack(spacing: 16) {
                            if mirrorEnabled {
                                MirrorView(mirror: mirror)
                            }
                            NowPlayingView(nowPlaying: nowPlaying)
                            if shelfEnabled || clipboardEnabled {
                                trayColumn.frame(width: 200)
                            }
                        }
                    }
                }
                .padding(EdgeInsets(top: notchSize.height + 8, leading: 24, bottom: 16, trailing: 24))
                .frame(width: expandedSize.width, height: expandedSize.height)
                .overlay(alignment: .topLeading) {
                    AgendaHeaderView(agenda: agenda)
                        .frame(width: cornerWidth, height: notchSize.height)
                        .padding(.leading, 24)
                }
                .overlay(alignment: .topTrailing) {
                    if timerEnabled || countdown.isActive {
                        CountdownHeaderView(countdown: countdown)
                            .frame(width: cornerWidth, height: notchSize.height)
                            .padding(.trailing, 24)
                    }
                }
                .transition(.opacity)
            } else if showsHUD {
                CompactHUDView(hud: hud, height: notchSize.height)
                    .frame(maxHeight: .infinity) // centre vertically; the island aligns content to the top
                    .transition(.opacity)
            } else if showsBattery {
                CompactBatteryView(battery: battery)
                    .frame(maxHeight: .infinity)
                    .transition(.opacity)
            } else if let notice {
                CompactNoticeView(notice: notice)
                    .frame(maxHeight: .infinity)
                    .transition(.opacity)
            } else if showsCountdown {
                CompactCountdownView(countdown: countdown)
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
        .islandDropTarget(zones: dropZones, delegate: IslandDropDelegate(
            zones: dropZones, width: size.width, isTargeted: $isDropTargeted, zone: $dropZone
        ) { zone, urls in
            zone == .shelf ? shelf.add(urls) : AirDrop.send(urls)
        })
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: size)
        .environment(\.colorScheme, .dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// Shelf and clipboard share one column, with a switch when both are on.
    private var trayColumn: some View {
        VStack(spacing: 6) {
            if shelfEnabled && clipboardEnabled {
                Picker("", selection: $showsClipboard) {
                    Image(systemName: "tray").tag(false)
                    Image(systemName: "doc.on.clipboard").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
            }
            if clipboardEnabled && (showsClipboard || !shelfEnabled) {
                ClipboardView(clipboard: clipboard)
            } else {
                ShelfView(shelf: shelf)
            }
        }
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

    /// No drop zones enabled: don't register for drags at all, so the notch ignores dragged files.
    @ViewBuilder
    func islandDropTarget(zones: [DropZone], delegate: IslandDropDelegate) -> some View {
        if zones.isEmpty {
            self
        } else {
            onDrop(of: [.fileURL], delegate: delegate)
        }
    }
}
