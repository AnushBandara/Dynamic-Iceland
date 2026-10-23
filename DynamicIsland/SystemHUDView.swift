import SwiftUI

/// Collapsed volume/brightness HUD: icon left of the notch, level bar right of it.
struct CompactHUDView: View {
    let hud: SystemHUD
    let height: CGFloat

    var body: some View {
        HStack {
            Image(systemName: symbol)
                .font(.system(size: height * 0.4))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 24)
            Spacer()
            Capsule().fill(.white.opacity(0.2))
                .overlay {
                    Capsule().fill(.white)
                        .scaleEffect(x: CGFloat(hud.isMuted ? 0 : hud.level), anchor: .leading)
                        .animation(.smooth(duration: 0.15), value: hud.level)
                }
                .frame(width: 40, height: 5)
        }
        .padding(.horizontal, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hud.kind == .volume ? "Volume" : "Brightness")
        .accessibilityValue(hud.isMuted ? "Muted" : "\(Int((hud.level * 100).rounded())) percent")
    }

    private var symbol: String {
        switch hud.kind {
        case .brightness: hud.level < 0.5 ? "sun.min.fill" : "sun.max.fill"
        case .volume where hud.isMuted: "speaker.slash.fill"
        case .volume: hud.level < 0.34 ? "speaker.wave.1.fill" : hud.level < 0.67 ? "speaker.wave.2.fill" : "speaker.wave.3.fill"
        }
    }
}
