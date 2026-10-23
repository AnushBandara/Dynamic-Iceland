# Roadmap

- [x] Notch panel, hover-to-expand, Liquid Glass toggle (macOS 26+)
- [x] Launch at login (`SMAppService`)
- [x] Now playing: artwork, title, progress, play/pause/skip, compact live activity. Via vendored mediaremote-adapter (MediaRemote is entitlement-gated since macOS 15.4)
- [ ] File shelf: drag files onto the notch, drag them back out
- [ ] System HUDs: volume / brightness / keyboard backlight. Needs Accessibility permission for media-key event tap
- [ ] Battery: charging / low-battery animation (IOKit power source notifications)
- [ ] Calendar: next event + join link (EventKit)
- [ ] Timer / Pomodoro
- [ ] AirDrop drop target (`NSSharingService(named: .sendViaAirDrop)`)
- [ ] Camera mirror (AVFoundation)
- [ ] Clipboard history
- [ ] Download finished / AirPods connected alerts
- [ ] Focus mode indicator. No public API, reading Focus state needs Full Disk Access
