import AVFoundation
import SwiftUI

/// Mirror tile in the expanded island: click to turn the camera preview on or off.
struct MirrorView: View {
    let mirror: CameraMirror

    var body: some View {
        ZStack {
            if mirror.isOn {
                CameraPreview(session: mirror.session)
            } else {
                Image(systemName: mirror.isDenied ? "video.slash" : "camera.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 100, height: 100)
        .background(.white.opacity(0.08))
        .clipShape(.rect(cornerRadius: 16))
        .contentShape(.rect)
        .onTapGesture { mirror.toggle() }
        .onDisappear { mirror.stop() } // camera off as soon as the island collapses
        .help(mirror.isDenied ? "Allow camera access in System Settings" : "Mirror")
    }
}

private struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer = layer
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}
