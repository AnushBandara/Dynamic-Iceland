import SwiftUI

/// Collapsed battery alert: battery icon left of the notch, percentage right of it.
struct CompactBatteryView: View {
    let battery: Battery

    var body: some View {
        let color: Color = battery.alert == .low ? .red : .green
        HStack {
            Image(systemName: battery.alert == .low ? "battery.25" : "battery.100.bolt")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(color)
            Spacer()
            Text("\(battery.level)%")
                .font(.callout.monospacedDigit().weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
    }
}
