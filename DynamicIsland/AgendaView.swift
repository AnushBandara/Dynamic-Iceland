import SwiftUI

/// Next meeting in the expanded island's top-left corner, beside the notch.
struct AgendaHeaderView: View {
    let agenda: Agenda

    var body: some View {
        if let event = agenda.next {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(cgColor: event.color ?? .white))
                    .frame(width: 6, height: 6)
                VStack(alignment: .leading, spacing: 0) {
                    Text(event.title).font(.caption.weight(.semibold)).lineLimit(1)
                    TimelineView(.everyMinute) { context in
                        Text(Agenda.timeLabel(start: event.start, end: event.end, now: context.date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 4)
                if let url = event.joinURL {
                    Button { NSWorkspace.shared.open(url) } label: {
                        Image(systemName: "video.fill")
                            .font(.caption2)
                            .padding(5)
                            .background(.green, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Join meeting")
                }
            }
        }
    }
}
