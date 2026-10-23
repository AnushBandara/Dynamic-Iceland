import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage("useLiquidGlass") private var useLiquidGlass = false
    @AppStorage(Shelf.enabledKey) private var shelfEnabled = true
    @AppStorage(SystemHUD.enabledKey) private var hudEnabled = true
    @AppStorage(Battery.enabledKey) private var batteryAlertsEnabled = true
    @AppStorage(Agenda.enabledKey) private var calendarEnabled = true
    @AppStorage(Countdown.enabledKey) private var timerEnabled = true
    @AppStorage(DropZone.airDropKey) private var airDropEnabled = true
    @AppStorage(CameraMirror.enabledKey) private var mirrorEnabled = true
    @AppStorage(Shelf.keepKey) private var keepShelf = true
    @AppStorage(Clipboard.enabledKey) private var clipboardEnabled = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in
                    do {
                        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
            Toggle(isOn: $hudEnabled) {
                Text("Volume & brightness HUD")
                Text("Replaces the macOS popup. Needs Accessibility permission.")
            }
            Toggle(isOn: $batteryAlertsEnabled) {
                Text("Battery alerts")
                Text("Shows when the charger connects and at 20% / 10%.")
            }
            Toggle(isOn: $calendarEnabled) {
                Text("Calendar")
                Text("Shows your next meeting with a join button. Needs Calendar access.")
            }
            Toggle(isOn: $timerEnabled) {
                Text("Timer")
                Text("5 / 15 / 25 minute countdown beside the notch.")
            }
            Toggle(isOn: $airDropEnabled) {
                Text("AirDrop drop zone")
                Text("Drop files on the notch to send them with AirDrop.")
            }
            Toggle(isOn: $mirrorEnabled) {
                Text("Camera mirror")
                Text("Click the tile to check your camera. It turns off when the island closes.")
            }
            Toggle(isOn: $clipboardEnabled) {
                Text("Clipboard history")
                Text("Your last 20 copied texts. Kept in memory only; password manager copies are skipped.")
            }
            Toggle("File shelf", isOn: $shelfEnabled)
            Toggle("Keep shelf files after restart", isOn: $keepShelf).disabled(!shelfEnabled)
            if #available(macOS 26, *) {
                Toggle("Liquid Glass", isOn: $useLiquidGlass)
            } else {
                Toggle("Liquid Glass (requires macOS 26)", isOn: .constant(false)).disabled(true)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
    }
}
