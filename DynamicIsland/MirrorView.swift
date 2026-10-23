import AVFoundation
import SwiftUI

/// Mirror tile in the expanded island: click to turn the camera preview on or off.
struct MirrorView: View {
    let mirror: CameraMirror

    var body: some View {
        ZStack {
            if mirror.isOn {
                CameraPreview(layer: mirror.previewLayer)
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
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(mirror.isOn ? "Turn off camera mirror" : "Camera mirror")
        .accessibilityAction { mirror.toggle() }
        .onDisappear { mirror.stop() } // camera off as soon as the island collapses
        .help(mirror.isDenied ? "Allow camera access in System Settings" : "Mirror")
    }
}

/// Hosts the mirror's long-lived preview layer; re-parented each time the tile appears.
private struct CameraPreview: NSViewRepresentable {
    let layer: AVCaptureVideoPreviewLayer

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        layer.frame = view.bounds
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer?.addSublayer(layer) // moves it out of any previous tile's view
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}
