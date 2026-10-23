import AppKit
import AVFoundation
import Observation

/// Live front-camera preview for a quick look before a call. Off until clicked, and
/// switched off again whenever the island collapses.
@MainActor @Observable
final class CameraMirror {
    static let enabledKey = "mirrorEnabled"

    private(set) var isOn = false
    private(set) var isDenied = false
    /// Created once and attached up front, like Apple's AVCam: attaching a preview layer while
    /// the session starts on another thread crashes ("collection mutated while enumerated").
    @ObservationIgnored let previewLayer: AVCaptureVideoPreviewLayer
    @ObservationIgnored private let session = AVCaptureSession()
    /// Serial, so configure / start / stop never overlap even with fast clicks.
    @ObservationIgnored private let queue = DispatchQueue(label: "io.github.anushbandara.dynamicisland.camera")
    @ObservationIgnored private var wantsOn = false

    init() {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
    }

    func toggle() {
        if isDenied {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
        } else if wantsOn {
            stop()
        } else {
            wantsOn = true
            Task { await start() }
        }
    }

    func stop() {
        wantsOn = false
        guard isOn else { return }
        isOn = false
        nonisolated(unsafe) let session = session
        queue.async { session.stopRunning() }
    }

    private func start() async {
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            isDenied = true
            wantsOn = false
            return
        }
        guard wantsOn else { return } // the island closed while the permission prompt was up
        isOn = true
        nonisolated(unsafe) let session = session
        queue.async {
            if session.inputs.isEmpty, let camera = AVCaptureDevice.default(for: .video),
               let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input) {
                session.addInput(input)
            }
            session.startRunning()
        }
    }
}
