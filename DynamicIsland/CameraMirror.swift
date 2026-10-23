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
    @ObservationIgnored let session = AVCaptureSession()

    func toggle() {
        if isDenied {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
        } else if isOn {
            stop()
        } else {
            Task { await start() }
        }
    }

    func stop() {
        guard isOn else { return }
        isOn = false
        run { $0.stopRunning() }
    }

    private func start() async {
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            isDenied = true
            return
        }
        if session.inputs.isEmpty, let camera = AVCaptureDevice.default(for: .video),
           let input = try? AVCaptureDeviceInput(device: camera), session.canAddInput(input) {
            session.addInput(input)
        }
        isOn = true
        run { $0.startRunning() }
    }

    /// startRunning/stopRunning block, so keep them off the main thread.
    private func run(_ body: @escaping @Sendable (AVCaptureSession) -> Void) {
        nonisolated(unsafe) let session = session // AVCaptureSession is safe to start/stop from any thread
        DispatchQueue.global(qos: .userInitiated).async { body(session) }
    }
}
