import SwiftUI

@main
struct DynamicIslandApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

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
    private lazy var panel = NotchPanel(nowPlaying: nowPlaying)

    func applicationWillTerminate(_ notification: Notification) {
        nowPlaying.stop()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        nowPlaying.start()
        panel.reposition()
        panel.orderFrontRegardless()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [panel] _ in
            MainActor.assumeIsolated { panel.reposition() }
        }
    }
}
