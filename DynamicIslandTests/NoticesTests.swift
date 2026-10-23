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
