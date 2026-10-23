import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage("useLiquidGlass") private var useLiquidGlass = false
    @AppStorage(Shelf.enabledKey) private var shelfEnabled = true
    @AppStorage(Shelf.keepKey) private var keepShelf = true
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
