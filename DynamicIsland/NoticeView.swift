import SwiftUI

/// Collapsed notice: what happened left of the notch, its status right of it.
struct CompactNoticeView: View {
    let notice: Notices.Notice

    var body: some View {
        HStack {
            switch notice {
            case .downloaded(let url):
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .frame(width: 22, height: 22)
                Spacer()
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.green)
            case .headphones(let name, let battery):
                Image(systemName: name.localizedCaseInsensitiveContains("AirPods") ? "airpods" : "headphones")
                Spacer()
                if let battery {
                    Text("\(battery)%")
                        .font(.callout.monospacedDigit().weight(.semibold))
                        .foregroundStyle(battery <= 20 ? .red : .green)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(.horizontal, 10)
    }
}
