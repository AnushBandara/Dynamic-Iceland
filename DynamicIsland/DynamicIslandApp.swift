import SwiftUI

@main
struct DynamicIslandApp: App {
    static let menuBarIconKey = "showMenuBarIcon"
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @AppStorage(menuBarIconKey) private var showsMenuBarIcon = true

    init() {
        if let flag = CommandLine.arguments.firstIndex(of: Notices.batteryFlag), flag + 1 < CommandLine.arguments.count {
            Notices.printBatteryAndExit(address: CommandLine.arguments[flag + 1])
        }
    }

    var body: some Scene {
        MenuBarExtra("Dynamic Island", systemImage: "capsule.fill", isInserted: $showsMenuBarIcon) {
            SettingsButton()
            Divider()
            Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
        }
        Settings { SettingsView() }
    }
}

/// Opens Settings in front: the app has no Dock icon, so it has to activate itself first.
private struct SettingsButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Settings…") { SettingsView.open(openSettings) }
        .keyboardShortcut(",")
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let nowPlaying = NowPlaying()
    private let shelf = Shelf()
    private let hud = SystemHUD()
    private let battery = Battery()
    private let agenda = Agenda()
    private let countdown = Countdown()
    private let mirror = CameraMirror()
    private let fullScreen = FullScreen()
    private let clipboard = Clipboard()
    private let notices = Notices()
    private let hotKey = IslandHotKey()
    private lazy var panel = NotchPanel(nowPlaying: nowPlaying, shelf: shelf, hud: hud, battery: battery,
                                        agenda: agenda, countdown: countdown, mirror: mirror, fullScreen: fullScreen,
                                        clipboard: clipboard, notices: notices, hotKey: hotKey)

    /// Opening the app again shows Settings, the way back when the menu bar icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: SettingsView.openRequest, object: nil)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        nowPlaying.stop()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        nowPlaying.start()
        fullScreen.start()
        hud.start()
        battery.start()
        agenda.start()
        clipboard.start()
        notices.start()
        hotKey.start()
        panel.reposition()
        panel.orderFrontRegardless()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [panel] _ in
            MainActor.assumeIsolated { panel.reposition() }
        }
    }
}
