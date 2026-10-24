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
            case .focus(_, let symbol, let tint, let isOn):
                Image(systemName: symbol)
                    .foregroundStyle(isOn ? Self.colors[tint] ?? .indigo : .secondary)
                Spacer()
                Text(isOn ? "On" : "Off")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(isOn ? Self.colors[tint] ?? .indigo : .secondary)
            case .claude(let event, _, _):
                Image(systemName: "asterisk") // closest symbol to Claude's starburst
                    .fontWeight(.black)
                    .foregroundStyle(Self.claudeOrange)
                Spacer()
                switch event {
                case .approval:
                    Image(systemName: "hand.raised.fill").foregroundStyle(.orange)
                case .input:
                    Image(systemName: "ellipsis.bubble.fill").foregroundStyle(.blue)
                case .done:
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            case .claudeHint:
                Image(systemName: "asterisk")
                    .fontWeight(.black)
                    .foregroundStyle(Self.claudeOrange)
                Spacer()
                Image(systemName: "bell.badge.fill").foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        switch notice {
        case .downloaded(let url): "Downloaded \(url.lastPathComponent)"
        case .headphones(let name, let battery): "\(name) connected" + (battery.map { ", battery \($0) percent" } ?? "")
        case .focus(let name, _, _, let isOn): "\(name) \(isOn ? "on" : "off")"
        case .claude(.approval, let project, let message): "Claude Code needs approval in \(project). \(message)"
        case .claude(.input, let project, let message): "Claude Code is waiting for you in \(project). \(message)"
        case .claude(.done, let project, let message): "Claude Code finished in \(project). \(message)"
        case .claudeHint: "Show Claude Code alerts in the island? Click to turn on."
        }
    }

    static let claudeOrange = Color(red: 0.85, green: 0.47, blue: 0.34)

    /// Focus tints as named in ModeConfigurations.json.
    private static let colors: [String: Color] = [
        "systemIndigoColor": .indigo, "systemPurpleColor": .purple, "systemBlueColor": .blue, "systemCyanColor": .cyan,
        "systemTealColor": .teal, "systemMintColor": .mint, "systemGreenColor": .green, "systemYellowColor": .yellow,
        "systemOrangeColor": .orange, "systemRedColor": .red, "systemPinkColor": .pink, "systemBrownColor": .brown,
        "systemGrayColor": .gray,
    ]
}

/// Claude Code's message under the notch, when the island grows a line instead of showing only icons.
struct ClaudeMessageRow: View {
    let project: String
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Text(message)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            Text(project)
                .lineLimit(1)
                .foregroundStyle(CompactNoticeView.claudeOrange)
                .fixedSize() // the message truncates instead
        }
        .font(.callout)
        .padding(.horizontal, 14)
        .accessibilityHidden(true) // read with the notice above it
    }
}
