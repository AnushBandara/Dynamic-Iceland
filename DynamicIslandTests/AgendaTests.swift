import Foundation
import Testing
@testable import DynamicIsland

@Test func findsMeetingLinksInEventText() {
    #expect(Agenda.meetingURL(in: [nil, "Room 4", "Join: https://olee.zoom.us/j/123?pwd=x thanks"])?.host() == "olee.zoom.us")
    #expect(Agenda.meetingURL(in: ["https://teams.microsoft.com/l/meetup-join/abc"])?.host() == "teams.microsoft.com")
    #expect(Agenda.meetingURL(in: ["meet.google.com/abc-defg-hij"]) != nil)
    #expect(Agenda.meetingURL(in: ["https://docs.google.com/agenda", "https://notzoom.us/j/1"]) == nil)
}

@Test func labelsEventTimes() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    #expect(Agenda.timeLabel(start: now.addingTimeInterval(-60), end: now.addingTimeInterval(600), now: now) == "now")
    #expect(Agenda.timeLabel(start: now.addingTimeInterval(11 * 60 + 30), end: now.addingTimeInterval(3600), now: now) == "in 12 min")
    #expect(Agenda.timeLabel(start: now.addingTimeInterval(3 * 3600), end: now.addingTimeInterval(4 * 3600), now: now) != "now")
}
