import Carbon.HIToolbox
import Observation

/// Control-Option-I opens and closes the island from the keyboard; Esc closes it. Carbon hot keys
/// need no permission, and Esc is only claimed while the island is open this way, so the panel
/// never has to take keyboard focus from the app you're in.
@MainActor @Observable
final class IslandHotKey {
    static let enabledKey = "hotKeyEnabled"
    private static let toggleID: UInt32 = 1
    private static let escapeID: UInt32 = 2

    var isOpen = false {
        didSet { if isOpen != oldValue { updateEscape() } }
    }

    @ObservationIgnored private var toggleKey: EventHotKeyRef?
    @ObservationIgnored private var escapeKey: EventHotKeyRef?

    init() {
        UserDefaults.standard.register(defaults: [Self.enabledKey: true])
    }

    func start() {
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            // Delivered on the main thread's event loop.
            MainActor.assumeIsolated {
                let hotKey = Unmanaged<IslandHotKey>.fromOpaque(context!).takeUnretainedValue()
                hotKey.isOpen = id.id == IslandHotKey.toggleID ? !hotKey.isOpen : false
            }
            return noErr
        }, 1, &pressed, Unmanaged.passUnretained(self).toOpaque(), nil)
        updateToggle()
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { self.updateToggle() }
        }
    }

    private func updateToggle() {
        let enabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        if enabled, toggleKey == nil {
            toggleKey = register(kVK_ANSI_I, modifiers: controlKey | optionKey, id: Self.toggleID)
        } else if !enabled, let key = toggleKey {
            UnregisterEventHotKey(key)
            toggleKey = nil
            isOpen = false
        }
    }

    private func updateEscape() {
        if isOpen, escapeKey == nil {
            escapeKey = register(kVK_Escape, modifiers: 0, id: Self.escapeID)
        } else if !isOpen, let key = escapeKey {
            UnregisterEventHotKey(key)
            escapeKey = nil
        }
    }

    private func register(_ keyCode: Int, modifiers: Int, id: UInt32) -> EventHotKeyRef? {
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4449_534C), id: id) // "DISL"
        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &ref)
        return ref
    }
}
