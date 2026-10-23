import SwiftUI
import Testing
@testable import DynamicIsland

@MainActor @Test func collapsedIslandRendersWithNothingPlaying() {
    let view = NotchView(notchSize: CGSize(width: 200, height: 32), nowPlaying: NowPlaying())
    let image = NSBitmapImageRep(cgImage: ImageRenderer(content: view.frame(width: 520, height: 180)).cgImage!)
    #expect(image.colorAt(x: 260, y: 10)?.alphaComponent == 1) // black island under the notch
}

@MainActor @Test func streamDiffsMergeIntoFullState() {
    let nowPlaying = NowPlaying()
    nowPlaying.apply(#"{"type":"data","diff":false,"payload":{"title":"Song","artist":"Band","playing":true,"durationMicros":180000000}}"#)
    nowPlaying.apply(#"{"type":"data","diff":true,"payload":{"playing":false,"artist":null}}"#)
    #expect(nowPlaying.title == "Song")
    #expect(nowPlaying.artist == nil)
    #expect(nowPlaying.isPlaying == false)
    #expect(nowPlaying.duration == 180)

    nowPlaying.apply(#"{"type":"data","diff":false,"payload":{}}"#)
    #expect(nowPlaying.title == nil)
}

@MainActor @Test func artworkLeftOverFromPreviousTrackIsHidden() {
    let png = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII="
    let nowPlaying = NowPlaying()
    nowPlaying.apply(#"{"type":"data","diff":false,"payload":{"title":"Waco","album":"","artworkData":"\#(png)"}}"#)
    #expect(nowPlaying.artwork != nil)

    // Edge switches tabs: new title, artwork bytes unchanged so absent from the diff
    nowPlaying.apply(#"{"type":"data","diff":true,"payload":{"title":"Because Of You"}}"#)
    #expect(nowPlaying.artwork == nil)

    nowPlaying.apply(#"{"type":"data","diff":true,"payload":{"artworkData":"\#(png)"}}"#)
    #expect(nowPlaying.artwork != nil)

    // Next track on the same album legitimately keeps the artwork
    nowPlaying.apply(#"{"type":"data","diff":false,"payload":{"title":"Track 1","album":"Album","artworkData":"\#(png)"}}"#)
    nowPlaying.apply(#"{"type":"data","diff":true,"payload":{"title":"Track 2"}}"#)
    #expect(nowPlaying.artwork != nil)
}
