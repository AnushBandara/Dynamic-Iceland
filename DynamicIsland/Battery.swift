import Foundation
import IOKit.ps
import Observation

/// Internal battery state from IOKit power-source notifications. Raises a short alert
/// when the charger is connected or the level drops to 20% / 10% on battery.
@MainActor @Observable
final class Battery {
    static let enabledKey = "batteryAlertsEnabled"
    enum Alert { case charging, low }

    private(set) var level = 0
    private(set) var isCharging = false
    private(set) var alert: Alert?

    @ObservationIgnored private var isOnAC: Bool?
    @ObservationIgnored private var hideTask: Task<Void, Never>?

    init() {
        UserDefaults.standard.register(defaults: [Self.enabledKey: true])
    }

    func start() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource({ context in
            // Delivered on the main run loop, where the source is added.
            MainActor.assumeIsolated { Unmanaged<Battery>.fromOpaque(context!).takeUnretainedValue().update() }
        }, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        update()
    }

    private func update() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              let battery = sources.lazy
                  .compactMap({ IOPSGetPowerSourceDescription(info, $0)?.takeUnretainedValue() as? [String: Any] })
                  .first(where: { $0[kIOPSTypeKey] as? String == kIOPSInternalBatteryType })
        else { return } // desktop Mac: no battery

        let newLevel = (battery[kIOPSCurrentCapacityKey] as? Int ?? 0) * 100 / max(battery[kIOPSMaxCapacityKey] as? Int ?? 100, 1)
        let onAC = battery[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
        let newAlert = Self.alert(wasOnAC: isOnAC, isOnAC: onAC, oldLevel: level, newLevel: newLevel)
        level = newLevel
        isCharging = battery[kIOPSIsChargingKey] as? Bool ?? false
        isOnAC = onAC
        if let newAlert, UserDefaults.standard.bool(forKey: Self.enabledKey) { show(newAlert) }
    }

    private func show(_ alert: Alert) {
        self.alert = alert
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(alert == .low ? 4 : 3))
            if !Task.isCancelled { self.alert = nil }
        }
    }

    /// Charger connected, or the level crossed 20% / 10% while on battery. Nothing on the first reading.
    nonisolated static func alert(wasOnAC: Bool?, isOnAC: Bool, oldLevel: Int, newLevel: Int) -> Alert? {
        guard let wasOnAC else { return nil }
        if !wasOnAC && isOnAC { return .charging }
        if !isOnAC, [20, 10].contains(where: { oldLevel > $0 && newLevel <= $0 }) { return .low }
        return nil
    }
}
