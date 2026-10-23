import AppKit
import AudioToolbox
import CoreAudio
import Observation

/// Takes over the volume and brightness keys (event tap, needs Accessibility) so the island
/// shows the level instead of the macOS HUD. Keys pass through when the change can't be
/// applied, e.g. an output device without volume control or no built-in display.
@MainActor @Observable
final class SystemHUD {
    static let enabledKey = "systemHUDEnabled"
    enum Kind { case volume, brightness }

    private(set) var kind = Kind.volume
    private(set) var level: Float = 0
    private(set) var isMuted = false
    private(set) var isVisible = false

    @ObservationIgnored private var tap: CFMachPort?
    @ObservationIgnored private var hideTask: Task<Void, Never>?
    @ObservationIgnored private var isWaitingForPermission = false

    init() {
        UserDefaults.standard.register(defaults: [Self.enabledKey: true])
    }

    private var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }

    func start() {
        installTap()
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { self.installTap() }
        }
    }

    private func installTap() {
        guard isEnabled, tap == nil, !isWaitingForPermission else { return }
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                eventsOfInterest: 1 << 14, // NX_SYSDEFINED: media and brightness keys
                                callback: handleTapEvent, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else {
            // Not trusted yet: ask once, then retry until the user allows it in System Settings.
            AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary) // kAXTrustedCheckOptionPrompt
            isWaitingForPermission = true
            Task {
                while !AXIsProcessTrusted() { try? await Task.sleep(for: .seconds(2)) }
                isWaitingForPermission = false
                installTap()
            }
            return
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
    }

    /// Returns true when the event was handled and must not reach macOS.
    fileprivate func handle(_ type: CGEventType, _ mediaEvent: (data1: Int, flags: NSEvent.ModifierFlags)?) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }
        guard isEnabled, let mediaEvent else { return false }
        let (key, isDown) = Self.mediaKey(data1: mediaEvent.data1)
        let step: Float = mediaEvent.flags.contains([.shift, .option]) ? 1 / 64 : 1 / 16

        switch key {
        case 0, 1, 7: // NX_KEYTYPE_SOUND_UP, SOUND_DOWN, MUTE
            guard let volume = Audio.volume else { return false }
            guard isDown else { return true }
            let muted = key == 7 ? !Audio.isMuted : key == 0 ? false : Audio.isMuted
            let newVolume = key == 7 ? volume : Self.stepped(volume, by: key == 0 ? step : -step)
            guard Audio.setVolume(newVolume), Audio.setMuted(muted) else { return false }
            show(.volume, newVolume, muted: muted || newVolume == 0)
            return true
        case 2, 3: // NX_KEYTYPE_BRIGHTNESS_UP, BRIGHTNESS_DOWN
            guard let brightness = Display.brightness else { return false }
            guard isDown else { return true }
            let newBrightness = Self.stepped(brightness, by: key == 2 ? step : -step)
            guard Display.setBrightness(newBrightness) else { return false }
            show(.brightness, newBrightness)
            return true
        default:
            return false
        }
    }

    private func show(_ kind: Kind, _ level: Float, muted: Bool = false) {
        self.kind = kind
        self.level = level
        isMuted = muted
        isVisible = true
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            if !Task.isCancelled { isVisible = false }
        }
    }

    /// Key code and pressed state packed into an NX_SYSDEFINED event's data1.
    nonisolated static func mediaKey(data1: Int) -> (key: Int, isDown: Bool) {
        ((data1 & 0xFFFF_0000) >> 16, (data1 & 0xFF00) >> 8 == 0xA)
    }

    /// Moves to the next step on the grid like macOS does, so off-grid values snap back onto it.
    nonisolated static func stepped(_ value: Float, by step: Float) -> Float {
        min(1, max(0, ((value / abs(step)).rounded() + (step > 0 ? 1 : -1)) * abs(step)))
    }
}

private func handleTapEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                            userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    let hud = Unmanaged<SystemHUD>.fromOpaque(userInfo!).takeUnretainedValue()
    let mediaEvent = NSEvent(cgEvent: event).flatMap { $0.subtype.rawValue == 8 ? ($0.data1, $0.modifierFlags) : nil }
    let handled = MainActor.assumeIsolated { hud.handle(type, mediaEvent) } // tap runs on the main run loop
    return handled ? nil : Unmanaged.passUnretained(event)
}

/// Default output device volume and mute via CoreAudio.
@MainActor private enum Audio {
    static var volume: Float? { read(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, Float32(0)) }
    static var isMuted: Bool { read(kAudioDevicePropertyMute, UInt32(0)) == 1 }
    static func setVolume(_ volume: Float) -> Bool { write(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, Float32(volume)) }
    // Devices without a mute control are fine as long as we're not muting.
    static func setMuted(_ muted: Bool) -> Bool { write(kAudioDevicePropertyMute, UInt32(muted ? 1 : 0)) || !muted }

    private static var device: AudioObjectID? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var device = AudioObjectID()
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        return status == noErr ? device : nil
    }

    private static func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput,
                                   mElement: kAudioObjectPropertyElementMain)
    }

    private static func read<T: BitwiseCopyable>(_ selector: AudioObjectPropertySelector, _ initial: T) -> T? {
        guard let device else { return nil }
        var address = address(selector)
        var value = initial
        var size = UInt32(MemoryLayout<T>.size)
        return AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr ? value : nil
    }

    private static func write<T: BitwiseCopyable>(_ selector: AudioObjectPropertySelector, _ value: T) -> Bool {
        guard let device else { return false }
        var address = address(selector)
        var value = value
        return AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<T>.size), &value) == noErr
    }
}

/// Built-in display brightness via the private DisplayServices framework (no public API exists).
@MainActor private enum Display {
    private typealias Get = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias Set = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private static let framework = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
    private static let get = dlsym(framework, "DisplayServicesGetBrightness").map { unsafeBitCast($0, to: Get.self) }
    private static let set = dlsym(framework, "DisplayServicesSetBrightness").map { unsafeBitCast($0, to: Set.self) }

    // ponytail: built-in display only; external monitors need DDC, add if users ask
    private static var builtIn: CGDirectDisplayID? {
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)
        var count = UInt32(0)
        CGGetOnlineDisplayList(16, &displays, &count)
        return displays.prefix(Int(count)).first { CGDisplayIsBuiltin($0) != 0 }
    }

    static var brightness: Float? {
        guard let get, let display = builtIn else { return nil }
        var value = Float(0)
        return get(display, &value) == 0 ? value : nil
    }

    static func setBrightness(_ value: Float) -> Bool {
        guard let set, let display = builtIn else { return false }
        return set(display, value) == 0
    }
}
