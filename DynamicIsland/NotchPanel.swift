import AppKit
import SwiftUI

/// Borderless, transparent panel pinned over the notch. Sized for the expanded
/// island; transparent pixels let clicks pass through to the menu bar.
final class NotchPanel: NSPanel {
    static let expandedSize = CGSize(width: 756, height: 180) // widest island: shelf and mirror on
    private let nowPlaying: NowPlaying
    private let shelf: Shelf
    private let hud: SystemHUD
    private let battery: Battery
    private let agenda: Agenda
    private let countdown: Countdown
    private let mirror: CameraMirror
    private let fullScreen: FullScreen
    private let clipboard: Clipboard
    private let notices: Notices

    init(nowPlaying: NowPlaying, shelf: Shelf, hud: SystemHUD, battery: Battery, agenda: Agenda,
         countdown: Countdown, mirror: CameraMirror, fullScreen: FullScreen, clipboard: Clipboard,
         notices: Notices) {
        self.countdown = countdown
        self.mirror = mirror
        self.fullScreen = fullScreen
        self.clipboard = clipboard
        self.notices = notices
        self.nowPlaying = nowPlaying
        self.shelf = shelf
        self.hud = hud
        self.battery = battery
        self.agenda = agenda
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3) // above the menu bar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }

    // ponytail: notched screen or main screen only; per-display islands when multi-monitor matters
    func reposition() {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return }
        let size = Self.expandedSize
        setFrame(CGRect(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height,
                        width: size.width, height: size.height), display: true)

        let hosting = HostingView(rootView: NotchView(notchSize: screen.notchSize, nowPlaying: nowPlaying, shelf: shelf, hud: hud, battery: battery, agenda: agenda, countdown: countdown, mirror: mirror, fullScreen: fullScreen, clipboard: clipboard, notices: notices))
        hosting.sizingOptions = []
        contentView = hosting
    }
}

/// Lets buttons respond on the first click even though the panel never becomes active.
private final class HostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

extension NSScreen {
    /// Physical notch size, or a fake notch matching the menu bar on screens without one.
    var notchSize: CGSize {
        guard safeAreaInsets.top > 0, let left = auxiliaryTopLeftArea, let right = auxiliaryTopRightArea else {
            return CGSize(width: 200, height: frame.maxY - visibleFrame.maxY)
        }
        return CGSize(width: frame.width - left.width - right.width, height: safeAreaInsets.top)
    }
}
