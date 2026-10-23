import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Where files dragged onto the island can go. The island shows the enabled zones side by side.
enum DropZone: CaseIterable, Identifiable {
    case shelf, airDrop
    static let airDropKey = "airDropEnabled"

    var id: Self { self }
    var title: String { self == .shelf ? "Shelf" : "AirDrop" }
    var symbol: String { self == .shelf ? "tray.and.arrow.down" : "dot.radiowaves.left.and.right" }

    /// Zones split the island's width evenly, left to right.
    static func at(x: CGFloat, width: CGFloat, zones: [DropZone]) -> DropZone? {
        guard !zones.isEmpty, width > 0 else { return nil }
        return zones[min(zones.count - 1, max(0, Int(x / (width / CGFloat(zones.count)))))]
    }
}

/// Something dragged onto the island: a file, a web link, or a piece of text.
enum DroppedItem: Equatable {
    case file(URL), link(URL), text(String)

    static let types: [UTType] = [.fileURL, .url, .plainText]

    /// File first (a file URL is also a URL), then link, then text, since browsers offer a link as all three.
    @MainActor static func load(_ provider: NSItemProvider) async -> DroppedItem? {
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            return await provider.loadURL().map(DroppedItem.file)
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            return await provider.loadURL().map(DroppedItem.link)
        }
        return await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: String.self) { text, _ in continuation.resume(returning: text.map(DroppedItem.text)) }
        }
    }
}

private extension NSItemProvider {
    @MainActor func loadURL() async -> URL? {
        await withCheckedContinuation { continuation in
            _ = loadObject(ofClass: URL.self) { url, _ in continuation.resume(returning: url) }
        }
    }
}

enum AirDrop {
    /// Opens the AirDrop picker; nothing is sent until a device is chosen. Links go as links, so they
    /// open in the browser on the other device.
    @MainActor static func send(_ items: [DroppedItem]) {
        let objects: [Any] = items.map { item in
            switch item {
            case .file(let url), .link(let url): url
            case .text(let text): text
            }
        }
        guard !objects.isEmpty, let service = NSSharingService(named: .sendViaAirDrop), service.canPerform(withItems: objects)
        else { return }
        NSApp.activate() // the picker only comes to the front for the active app
        service.perform(withItems: objects)
    }
}

/// One drop target for the whole island: expands it while files hover and picks the zone by position.
/// (Nested drop targets would un-target the island when the pointer reaches a zone, making it flicker.)
struct IslandDropDelegate: DropDelegate {
    let zones: [DropZone]
    let width: CGFloat
    @Binding var isTargeted: Bool
    @Binding var zone: DropZone?
    let onDrop: @MainActor (DropZone, [DroppedItem]) -> Void

    func validateDrop(info: DropInfo) -> Bool { !zones.isEmpty && info.hasItemsConforming(to: DroppedItem.types) }

    func dropEntered(info: DropInfo) {
        isTargeted = true
        zone = DropZone.at(x: info.location.x, width: width, zones: zones)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        zone = DropZone.at(x: info.location.x, width: width, zones: zones)
        return DropProposal(operation: .copy)
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
        zone = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let target = DropZone.at(x: info.location.x, width: width, zones: zones) else { return false }
        let providers = info.itemProviders(for: DroppedItem.types)
        isTargeted = false
        zone = nil
        Task {
            var items: [DroppedItem] = []
            for provider in providers {
                if let item = await DroppedItem.load(provider) { items.append(item) }
            }
            onDrop(target, items)
        }
        return true
    }
}

/// Shown in the expanded island while files are dragged over it.
struct DropZonesView: View {
    let zones: [DropZone]
    let highlighted: DropZone?

    var body: some View {
        HStack(spacing: 12) {
            ForEach(zones) { zone in
                let isOn = zone == highlighted
                VStack(spacing: 6) {
                    Image(systemName: zone.symbol).font(.title2)
                    Text(zone.title).font(.caption.weight(.semibold))
                }
                .foregroundStyle(isOn ? .primary : .secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.white.opacity(isOn ? 0.1 : 0), in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                        .foregroundStyle(.white.opacity(isOn ? 0.9 : 0.25))
                }
            }
        }
        .animation(.smooth(duration: 0.15), value: highlighted)
    }
}
