# Roadmap

- [x] Notch panel, hover-to-expand, Liquid Glass toggle (macOS 26+)
- [x] Launch at login (`SMAppService`)
- [x] Now playing: artwork, title, progress, play/pause/skip, compact live activity. Via vendored mediaremote-adapter (MediaRemote is entitlement-gated since macOS 15.4)
- [x] File shelf: drag files onto the notch, drag them back out, kept across restarts (setting)
- [x] System HUDs: volume / brightness replace the macOS HUD (event tap, Accessibility). Keyboard backlight skipped: notched MacBooks have no backlight keys
- [x] Battery: charger-connected and 20% / 10% low-battery alerts (IOKit power source notifications)
- [x] Calendar: current / next event beside the notch with a join button for meeting links (EventKit)
- [x] Timer / Pomodoro: 5 / 15 / 25 min presets beside the notch, pause / stop, compact countdown, "Done" alert with sound
- [x] AirDrop drop target: Shelf / AirDrop drop zones while dragging files over the island (`NSSharingService`)
- [x] Camera mirror: click-to-start preview tile in the expanded island, camera off when it collapses (AVFoundation)
- [x] Clipboard history: last 20 copied texts, click to copy again, shares the shelf column. Memory only, skips concealed (password manager) copies
- [x] Download finished / headphones connected alerts: watches ~/Downloads (skips .crdownload etc.), Bluetooth audio connect with battery via private IOBluetoothDevice properties
- [x] Focus alerts: mode icon + On / Off when a Focus changes. No public API: reads ~/Library/DoNotDisturb/DB (Full Disk Access)
