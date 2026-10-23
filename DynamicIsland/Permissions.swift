import AVFoundation
import ApplicationServices
import CoreBluetooth
import EventKit
import SwiftUI

/// System permissions the features rely on, as shown on the Permissions tab.
enum Permission: CaseIterable, Identifiable {
    case accessibility, calendar, camera, bluetooth, downloads, fullDiskAccess

    var id: Self { self }

    var title: String {
        switch self {
        case .accessibility: "Accessibility"
        case .calendar: "Calendar"
        case .camera: "Camera"
        case .bluetooth: "Bluetooth"
        case .downloads: "Downloads Folder"
        case .fullDiskAccess: "Full Disk Access"
        }
    }

    var usage: String {
        switch self {
        case .accessibility: "Lets the volume and brightness keys show the island HUD instead of the macOS popup."
        case .calendar: "Reads your events to show the next meeting and its join button. Nothing leaves your Mac."
        case .camera: "Used only while the camera mirror tile is on, and stops when the island closes."
        case .bluetooth: "Notices when headphones connect and reads their battery level."
        case .downloads: "Watches the Downloads folder for finished downloads. Files are never opened or read."
        case .fullDiskAccess: "macOS keeps Focus state in a protected folder. Needed only for Focus alerts. If the app isn't listed, click + and add it."
        }
    }

    var icon: String {
        switch self {
        case .accessibility: "accessibility"
        case .calendar: "calendar"
        case .camera: "camera.fill"
        case .bluetooth: "dot.radiowaves.left.and.right"
        case .downloads: "arrow.down.circle.fill"
        case .fullDiskAccess: "externaldrive.fill"
        }
    }

    var color: Color {
        switch self {
        case .accessibility: .blue
        case .calendar: .red
        case .camera: .green
        case .bluetooth: .blue
        case .downloads: .cyan
        case .fullDiskAccess: .gray
        }
    }

    /// Privacy & Security pane in System Settings.
    fileprivate var settingsURL: URL {
        let pane = switch self {
        case .accessibility: "Privacy_Accessibility"
        case .calendar: "Privacy_Calendars"
        case .camera: "Privacy_Camera"
        case .bluetooth: "Privacy_Bluetooth"
        case .downloads: "Privacy_FilesAndFolders"
        case .fullDiskAccess: "Privacy_AllFiles"
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!
    }
}

/// Which permissions are granted. There are no change notifications for most of them,
/// so the Settings window refreshes this while it's open.
@MainActor @Observable
final class Permissions {
    private(set) var granted: Set<Permission> = []
    @ObservationIgnored private var bluetooth: CBCentralManager?

    init() {
        refresh()
    }

    func refresh() {
        let now = Set(Permission.allCases.filter(Self.isGranted))
        if now != granted { granted = now }
    }

    private static func isGranted(_ permission: Permission) -> Bool {
        switch permission {
        case .accessibility: AXIsProcessTrusted()
        case .calendar: EKEventStore.authorizationStatus(for: .event) == .fullAccess
        case .camera: AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        case .bluetooth: CBManager.authorization == .allowedAlways
        case .downloads: canListDownloads
        case .fullDiskAccess: Notices.canReadFocus
        }
    }

    private static var canListDownloads: Bool {
        let downloads = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Downloads")
        return (try? FileManager.default.contentsOfDirectory(atPath: downloads.path)) != nil
    }

    /// Shows the system prompt when macOS still allows one, otherwise opens the System Settings pane.
    func request(_ permission: Permission) {
        switch permission {
        case .calendar where EKEventStore.authorizationStatus(for: .event) == .notDetermined:
            Task {
                _ = try? await EKEventStore().requestFullAccessToEvents()
                refresh()
            }
        case .camera where AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined:
            Task {
                _ = await AVCaptureDevice.requestAccess(for: .video)
                refresh()
            }
        case .bluetooth where CBManager.authorization == .notDetermined:
            bluetooth = CBCentralManager() // creating one shows the prompt
        case .downloads where Self.canListDownloads: // listing shows the prompt if macOS hasn't asked yet
            refresh()
        default:
            NSWorkspace.shared.open(permission.settingsURL)
        }
    }
}
