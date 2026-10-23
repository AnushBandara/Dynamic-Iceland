import SwiftUI

@main
struct DynamicIslandApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    init() {
        if let flag = CommandLine.arguments.firstIndex(of: Notices.batteryFlag), flag + 1 < CommandLine.arguments.count {
            Notices.printBatteryAndExit(address: CommandLine.arguments[flag + 1])
        }
    }

    var body: some Scene {
        MenuBarExtra("Dynamic Island", systemImage: "capsule.fill") {
            SettingsLink()
            Divider()
            Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut("q")
        }
        Settings { SettingsView() }
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
    private lazy var panel = NotchPanel(nowPlaying: nowPlaying, shelf: shelf, hud: hud, battery: battery,
                                        agenda: agenda, countdown: countdown, mirror: mirror, fullScreen: fullScreen,
                                        clipboard: clipboard, notices: notices)

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
        panel.reposition()
        panel.orderFrontRegardless()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [panel] _ in
            MainActor.assumeIsolated { panel.reposition() }
        }
    }
}
