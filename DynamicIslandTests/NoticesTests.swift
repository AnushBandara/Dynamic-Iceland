import Foundation
import Testing
@testable import DynamicIsland

@Test func onlyFinishedDownloadsAlert() {
    let before: Set = ["old.pdf", "report.pdf.crdownload"]
    // Edge finished report.pdf; another download and a hidden file appeared meanwhile.
    let after: Set = ["old.pdf", "report.pdf", "video.mp4.crdownload", ".DS_Store", "Safari.zip.download"]
    #expect(Notices.finishedDownloads(old: before, new: after) == ["report.pdf"])
    #expect(Notices.finishedDownloads(old: after, new: after).isEmpty)
}

@Test func readsActiveFocusMode() {
    let active = #"{"data":[{"storeAssertionRecords":[{"assertionDetails":{"assertionDetailsModeIdentifier":"com.apple.focus.work"}}],"storeInvalidationRecords":[]}]}"#
    let none = #"{"data":[{"storeInvalidationRecords":[]}]}"#
    #expect(Notices.activeFocusMode(assertions: Data(active.utf8)) == "com.apple.focus.work")
    #expect(Notices.activeFocusMode(assertions: Data(none.utf8)) == nil)

    let modes = #"{"data":[{"modeConfigurations":{"com.apple.focus.work":{"mode":{"name":"Work","symbolImageName":"person.lanyardcard.fill","tintColorName":"systemTealColor"}}}}]}"#
    #expect(Notices.focusConfiguration("com.apple.focus.work", data: Data(modes.utf8)) == ("Work", "person.lanyardcard.fill", "systemTealColor"))
    #expect(Notices.focusConfiguration("unknown", data: nil).name == "Focus")
}

@Test func readsClaudeCodeHooks() {
    func notice(_ json: String) -> Notices.Notice? { Notices.claudeNotice(hookInput: Data(json.utf8)) }
    #expect(notice(#"{"hook_event_name":"Stop","cwd":"/Users/me/app"}"#) == .claude(.done, project: "app"))
    #expect(notice(#"{"hook_event_name":"Notification","notification_type":"permission_prompt","cwd":"/x/api"}"#) == .claude(.approval, project: "api"))
    #expect(notice(#"{"hook_event_name":"Notification","notification_type":"idle_prompt","cwd":"/x/api"}"#) == .claude(.input, project: "api"))
    #expect(notice(#"{"hook_event_name":"Notification","notification_type":"auth_success"}"#) == nil)
    #expect(notice("not json") == nil)
}

@Test func addsAndRemovesClaudeHooksOnly() throws {
    let existing = #"{"model":"opus","hooks":{"Stop":[{"hooks":[{"type":"command","command":"say done"}]}]}}"#
    let installed = try #require(Notices.claudeSettings(Data(existing.utf8), hookCommand: "\"/A.app/DI\" --claude-hook"))
    // Installing twice replaces rather than duplicates.
    let again = try #require(Notices.claudeSettings(installed, hookCommand: "\"/B.app/DI\" --claude-hook"))
    let root = try #require(try JSONSerialization.jsonObject(with: again) as? [String: Any])
    let hooks = try #require(root["hooks"] as? [String: [[String: Any]]])
    #expect(root["model"] as? String == "opus")
    #expect(hooks["Stop"]?.count == 2 && hooks["Notification"]?.count == 1)
    #expect(String(decoding: again, as: UTF8.self).contains("/B.app/DI") && !String(decoding: again, as: UTF8.self).contains("/A.app"))

    let removed = try #require(Notices.claudeSettings(again, hookCommand: nil))
    let left = try #require(try JSONSerialization.jsonObject(with: removed) as? [String: Any])
    #expect((left["hooks"] as? [String: [[String: Any]]])?.keys.sorted() == ["Stop"])
    #expect(String(decoding: removed, as: UTF8.self).contains("say done"))

    #expect(Notices.claudeSettings(Data("{ broken".utf8), hookCommand: "x --claude-hook") == nil)
    #expect(Notices.claudeSettings(nil, hookCommand: "x --claude-hook") != nil)
}
