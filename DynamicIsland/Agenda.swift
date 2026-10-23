import EventKit
import Observation

/// The current or next timed calendar event in the coming 24 hours, with its meeting link.
@MainActor @Observable
final class Agenda {
    static let enabledKey = "calendarEnabled"

    struct Event {
        let title: String
        let start: Date
        let end: Date
        let color: CGColor?
        let joinURL: URL?
    }

    private(set) var next: Event?
    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var isStarted = false

    init() {
        UserDefaults.standard.register(defaults: [Self.enabledKey: true])
    }

    private var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }

    func start() {
        startIfEnabled()
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { self.startIfEnabled() }
        }
    }

    private func startIfEnabled() {
        guard isEnabled else { next = nil; return }
        guard !isStarted else { return }
        isStarted = true
        Task {
            // Not allowed yet: retry on the next settings change, e.g. after granting it from Settings.
            guard (try? await store.requestFullAccessToEvents()) == true else { isStarted = false; return }
            NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { _ in
                MainActor.assumeIsolated { self.refresh() }
            }
            while true { // also rolls over to the next event as time passes
                refresh()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    private func refresh() {
        guard isEnabled else { next = nil; return }
        let now = Date()
        let predicate = store.predicateForEvents(withStart: now, end: now.addingTimeInterval(24 * 3600), calendars: nil)
        next = store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.endDate > now && $0.attendees?.first(where: \.isCurrentUser)?.participantStatus != .declined }
            .min { $0.startDate < $1.startDate }
            .map { Event(title: $0.title ?? "", start: $0.startDate, end: $0.endDate, color: $0.calendar.cgColor,
                         joinURL: Self.meetingURL(in: [$0.url?.absoluteString, $0.location, $0.notes])) }
    }

    /// First Zoom / Teams / Meet / Webex / FaceTime… link found in the event's URL, location or notes.
    nonisolated static func meetingURL(in texts: [String?]) -> URL? {
        let hosts = ["zoom.us", "teams.microsoft.com", "teams.live.com", "meet.google.com", "webex.com",
                     "whereby.com", "meet.jit.si", "facetime.apple.com"]
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        for text in texts.compactMap({ $0 }) {
            for match in detector?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? [] {
                if let url = match.url, let host = url.host()?.lowercased(),
                   hosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) {
                    return url
                }
            }
        }
        return nil
    }

    /// "now", "in 12 min" within the hour, otherwise the start time.
    nonisolated static func timeLabel(start: Date, end: Date, now: Date) -> String {
        if start <= now { return "now" }
        let minutes = Int(start.timeIntervalSince(now) / 60) + 1
        return minutes <= 60 ? "in \(minutes) min" : start.formatted(date: .omitted, time: .shortened)
    }
}
