import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @State private var permissions = Permissions()

    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            IslandSettings(permissions: permissions)
                .tabItem { Label("Island", systemImage: "capsule.fill") }
            AlertSettings(permissions: permissions)
                .tabItem { Label("Alerts", systemImage: "bell.badge") }
            PermissionSettings(permissions: permissions)
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
        .frame(width: 560, height: 620)
        .onAppear(perform: Self.bringToFront)
        // Most permissions have no change notification; pick up grants made in System Settings.
        .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in permissions.refresh() }
    }

    /// Posted when the app is opened again (Finder, Spotlight) so the island, which can open Settings, does.
    static let openRequest = Notification.Name("openSettingsRequest")

    /// Opens Settings in front of other apps, also when it was already open behind them.
    static func open(_ openSettings: OpenSettingsAction) {
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
        bringToFront()
    }

    /// The app has no Dock icon, so macOS leaves its windows behind the frontmost app unless it activates.
    static func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            NSApp.windows.first { $0.identifier?.rawValue.contains("Settings") == true }?.makeKeyAndOrderFront(nil)
        }
    }
}

// MARK: - Tabs

private struct GeneralSettings: View {
    @AppStorage("useLiquidGlass") private var useLiquidGlass = false
    @AppStorage(DynamicIslandApp.menuBarIconKey) private var showsMenuBarIcon = true
    @AppStorage(IslandHotKey.enabledKey) private var hotKeyEnabled = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Startup") {
                FeatureRow(title: "Launch at login", icon: "power", color: .gray,
                           detail: "Start Dynamic Island automatically when you log in to your Mac.",
                           isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
            }
            Section {
                FeatureRow(title: "Show menu bar icon", icon: "menubar.rectangle", color: .gray,
                           detail: "Turn off to keep the menu bar clean. Open Settings from the gear in the open island, or by opening Dynamic Island again from Applications.",
                           isOn: $showsMenuBarIcon)
            } header: {
                Text("Menu bar")
            }
            Section("Keyboard") {
                FeatureRow(title: "Open with Control-Option-I", icon: "keyboard", color: .gray,
                           detail: "Press ⌃⌥I anywhere to open or close the island without the pointer. Esc closes it.",
                           isOn: $hotKeyEnabled)
            }
            Section {
                if #available(macOS 26, *) {
                    FeatureRow(title: "Liquid Glass", icon: "drop.fill", color: .cyan,
                               detail: "Gives the island the translucent glass look of macOS 26 instead of solid black.",
                               isOn: $useLiquidGlass)
                } else {
                    FeatureRow(title: "Liquid Glass", icon: "drop.fill", color: .cyan,
                               detail: "Translucent glass look for the island. Requires macOS 26 or later.",
                               isOn: .constant(false))
                        .disabled(true)
                }
            } header: {
                Text("Appearance")
            }
            Section("How to use") {
                InfoRow(icon: "cursorarrow.rays", color: .blue,
                        text: "Rest the pointer on the notch to open the island, or press ⌃⌥I. Move away or press Esc to close it.")
                InfoRow(icon: "doc.on.doc.fill", color: .indigo,
                        text: "Drag files onto the notch to keep them on the shelf or send them with AirDrop.")
                InfoRow(icon: "bell.badge.fill", color: .orange,
                        text: "Volume, brightness, battery and other alerts appear beside the notch for a few seconds.")
                InfoRow(icon: "arrow.up.left.and.arrow.down.right", color: .gray,
                        text: "In full screen the island hides what's playing, but alerts and hover still work.")
            }
            Section {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                LabeledContent("Quit Dynamic Island") {
                    Button("Quit") { NSApp.terminate(nil) }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {}
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

private struct IslandSettings: View {
    let permissions: Permissions
    @AppStorage(NowPlaying.activityKey) private var activityEnabled = true
    @AppStorage(Agenda.enabledKey) private var calendarEnabled = true
    @AppStorage(Countdown.enabledKey) private var timerEnabled = true
    @AppStorage(CameraMirror.enabledKey) private var mirrorEnabled = true
    @AppStorage(Clipboard.enabledKey) private var clipboardEnabled = true
    @AppStorage(TrayTab.notes.enabledKey) private var notesEnabled = true
    @AppStorage(TrayTab.todos.enabledKey) private var todosEnabled = true
    @AppStorage(TrayTab.shortcuts.enabledKey) private var shortcutsEnabled = true
    @AppStorage(ShortcutsRunner.pinnedKey) private var pinnedShortcuts = ""
    @State private var allShortcuts: [String]?
    @AppStorage(Shelf.enabledKey) private var shelfEnabled = true
    @AppStorage(Shelf.keepKey) private var keepShelf = true
    @AppStorage(DropZone.airDropKey) private var airDropEnabled = true

    var body: some View {
        Form {
            Section {
                FeatureRow(title: "Now playing beside the notch", icon: "waveform", color: .pink,
                           detail: "While music or a video plays, shows the artwork and a live waveform. The player controls are always in the open island.",
                           isOn: $activityEnabled)
            } header: {
                Text("Now Playing")
            } footer: {
                Text("Works with Music, Spotify, and videos in browsers like Edge, Safari and Chrome.")
            }
            Section("In the open island") {
                FeatureRow(title: "Calendar", icon: "calendar", color: .red,
                           detail: "Shows your current or next meeting at the top left, with a Join button for Zoom, Meet and Teams links.",
                           isOn: $calendarEnabled, permission: .calendar, permissions: permissions)
                FeatureRow(title: "Timer", icon: "timer", color: .orange,
                           detail: "5, 15 and 25 minute timers at the top right. The countdown stays beside the notch, with a sound when it's done.",
                           isOn: $timerEnabled)
                FeatureRow(title: "Camera mirror", icon: "camera.fill", color: .green,
                           detail: "Click the tile to check how you look before a call. The camera turns off when the island closes.",
                           isOn: $mirrorEnabled, permission: .camera, permissions: permissions)
                FeatureRow(title: "Clipboard history", icon: "doc.on.clipboard.fill", color: .indigo,
                           detail: "Your last 20 copied texts. Click one to copy it again. Kept in memory only; password manager copies are skipped.",
                           isOn: $clipboardEnabled)
            }
            Section {
                FeatureRow(title: "Notes", icon: "note.text", color: .yellow,
                           detail: "A scratch note in the island's right column, saved as you type. The island stays open while you type; press Esc or unpin to close it.",
                           isOn: $notesEnabled)
                FeatureRow(title: "To-dos", icon: "checklist", color: .orange,
                           detail: "A quick checklist. Type and press Return to add; click the circle to tick it off.",
                           isOn: $todosEnabled)
                FeatureRow(title: "Shortcuts", icon: "bolt.fill", color: .purple,
                           detail: "Run your favourite Apple Shortcuts with one click. Choose which ones below.",
                           isOn: $shortcutsEnabled)
                if shortcutsEnabled {
                    if let allShortcuts {
                        if allShortcuts.isEmpty {
                            Text("No shortcuts found. Make some in the Shortcuts app.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(allShortcuts, id: \.self) { name in
                            Toggle(name, isOn: Binding(
                                get: { ShortcutsRunner.pinned(pinnedShortcuts).contains(name) },
                                set: { _ in pinnedShortcuts = ShortcutsRunner.toggling(name, in: pinnedShortcuts) }))
                                .padding(.leading, 38)
                        }
                    } else {
                        ProgressView().controlSize(.small)
                    }
                }
            } header: {
                Text("Tools")
            } footer: {
                Text("Shelf, Clipboard, Notes, To-dos and Shortcuts share the island's right column, with tabs to switch.")
            }
            Section("Files") {
                FeatureRow(title: "File shelf", icon: "tray.full.fill", color: .blue,
                           detail: "Drop files on the notch to hold them, then drag them out wherever you need them.",
                           isOn: $shelfEnabled)
                FeatureRow(title: "Keep shelf files after restart", icon: "arrow.clockwise", color: .blue,
                           detail: "Files stay on the shelf when you quit the app or restart your Mac.",
                           isOn: $keepShelf)
                    .disabled(!shelfEnabled)
                FeatureRow(title: "AirDrop drop zone", icon: "dot.radiowaves.up.forward", color: .cyan,
                           detail: "While dragging files over the notch, drop them on the AirDrop zone to share them.",
                           isOn: $airDropEnabled)
            }
        }
        .formStyle(.grouped)
        .task { allShortcuts = await ShortcutsRunner.all() }
    }
}

private struct AlertSettings: View {
    let permissions: Permissions
    @AppStorage(SystemHUD.enabledKey) private var hudEnabled = true
    @AppStorage(Battery.enabledKey) private var batteryEnabled = true
    @AppStorage(Notices.downloadsKey) private var downloadsEnabled = true
    @AppStorage(Notices.headphonesKey) private var headphonesEnabled = true
    @AppStorage(Notices.focusKey) private var focusEnabled = true
    @AppStorage(Notices.claudeKey) private var claudeEnabled = false
    @AppStorage(Notices.claudeMessageKey) private var claudeMessages = true

    var body: some View {
        Form {
            Section {
                FeatureRow(title: "Volume & brightness", icon: "speaker.wave.2.fill", color: .gray,
                           detail: "Replaces the macOS popup with a slim bar beside the notch. Hold Shift + Option for finer steps.",
                           isOn: $hudEnabled, permission: .accessibility, permissions: permissions)
                FeatureRow(title: "Battery", icon: "battery.100percent.bolt", color: .green,
                           detail: "Shows the level when you plug in the charger, and warns at 20% and 10%.",
                           isOn: $batteryEnabled)
                FeatureRow(title: "Downloads", icon: "arrow.down.circle.fill", color: .cyan,
                           detail: "Shows when a download finishes in your Downloads folder.",
                           isOn: $downloadsEnabled, permission: .downloads, permissions: permissions)
                FeatureRow(title: "Headphones", icon: "headphones", color: .blue,
                           detail: "Shows when AirPods or other Bluetooth headphones connect, with their battery level.",
                           isOn: $headphonesEnabled, permission: .bluetooth, permissions: permissions)
                FeatureRow(title: "Focus", icon: "moon.fill", color: .indigo,
                           detail: "Shows when Do Not Disturb or another Focus mode turns on or off.",
                           isOn: $focusEnabled, permission: .fullDiskAccess, permissions: permissions)
                FeatureRow(title: "Claude Code", icon: "asterisk", color: .orange,
                           detail: "Shows when Claude Code needs your approval or reply, and when it finishes. Adds hooks to ~/.claude/settings.json; restart open sessions.",
                           isOn: $claudeEnabled)
                    .onChange(of: claudeEnabled) { _, on in
                        // settings.json isn't valid JSON: stay off. Off never flips back, so this can't loop.
                        if !Notices.setClaudeHooks(installed: on), on { claudeEnabled = false }
                    }
                Picker("Claude Code alert style", selection: $claudeMessages) {
                    Text("Icon only").tag(false)
                    Text("With message").tag(true)
                }
                .disabled(!claudeEnabled)
            } header: {
                Text("Beside the notch")
            } footer: {
                Text("Alerts show for a few seconds, also in full screen.")
            }
        }
        .formStyle(.grouped)
    }
}

private struct PermissionSettings: View {
    let permissions: Permissions

    var body: some View {
        Form {
            Section {
                ForEach(Permission.allCases) { permission in
                    HStack(spacing: 12) {
                        SettingsIcon(name: permission.icon, color: permission.color)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(permission.title)
                            Text(permission.usage)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 16)
                        if permissions.granted.contains(permission) {
                            Label("Allowed", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .fixedSize()
                        } else {
                            Button("Grant Access") { permissions.request(permission) }
                                .buttonStyle(.borderedProminent)
                                .fixedSize()
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("System access")
            } footer: {
                Text("Grant Access shows the macOS prompt, or opens the right page in System Settings. Turn on Dynamic Island there and this page updates by itself.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Rows

/// A feature switch: colored icon, title, explanation, and a grant link while its permission is missing.
private struct FeatureRow: View {
    let title: String
    let icon: String
    let color: Color
    let detail: String
    @Binding var isOn: Bool
    var permission: Permission?
    var permissions: Permissions?

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(alignment: .top, spacing: 12) {
                SettingsIcon(name: icon, color: color)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if isOn, let permission, let permissions, !permissions.granted.contains(permission) {
                        Button {
                            permissions.request(permission)
                        } label: {
                            Label("Needs \(permission.title) access. Grant…", systemImage: "exclamationmark.triangle.fill")
                                .font(.callout)
                                .foregroundStyle(.orange)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .toggleStyle(.switch)
    }
}

private struct InfoRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(name: icon, color: color)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// White symbol on a colored rounded square, like System Settings.
private struct SettingsIcon: View {
    let name: String
    let color: Color

    var body: some View {
        Image(systemName: name)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
