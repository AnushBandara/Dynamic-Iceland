import Testing
@testable import DynamicIsland

@Test func onlyFinishedDownloadsAlert() {
    let before: Set = ["old.pdf", "report.pdf.crdownload"]
    // Edge finished report.pdf; another download and a hidden file appeared meanwhile.
    let after: Set = ["old.pdf", "report.pdf", "video.mp4.crdownload", ".DS_Store", "Safari.zip.download"]
    #expect(Notices.finishedDownloads(old: before, new: after) == ["report.pdf"])
    #expect(Notices.finishedDownloads(old: after, new: after).isEmpty)
}
