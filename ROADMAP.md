# Roadmap

- [x] Notch panel, hover-to-expand, Liquid Glass toggle (macOS 26+)
- [x] Launch at login (`SMAppService`)
- [x] Now playing: artwork, title, progress, play/pause/skip, compact live activity. Via vendored mediaremote-adapter (MediaRemote is entitlement-gated since macOS 15.4)
- [x] File shelf: drag files onto the notch, drag them back out, kept across restarts (setting)
- [x] System HUDs: volume / brightness replace the macOS HUD (event tap, Accessibility). Keyboard backlight skipped: notched MacBooks have no backlight keys
- [x] Battery: charger-connected and 20% / 10% low-battery alerts (IOKit power source notifications)
- [ ] Calendar: next event + join link (EventKit)
- [ ] Timer / Pomodoro
- [ ] AirDrop drop target (`NSSharingService(named: .sendViaAirDrop)`)
- [ ] Camera mirror (AVFoundation)
- [ ] Clipboard history
- [ ] Download finished / AirPods connected alerts
- [ ] Focus mode indicator. No public API, reading Focus state needs Full Disk Access
