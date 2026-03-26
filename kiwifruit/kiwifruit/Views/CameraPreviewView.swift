import SwiftUI
import AVFoundation

/// Wraps AVCaptureVideoPreviewLayer as a SwiftUI view for displaying camera feed.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.previewLayer.session = session
        uiView.updateOrientation()
    }
}

final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let preview = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("layerClass must be AVCaptureVideoPreviewLayer")
        }
        return preview
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateOrientation()
    }

    func updateOrientation() {
        if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
            let windowScene = window?.windowScene
            let interfaceOrientation = windowScene?.interfaceOrientation ?? .portrait
            let videoOrientation: AVCaptureVideoOrientation
            switch interfaceOrientation {
            case .portrait:       videoOrientation = .portrait
            case .portraitUpsideDown: videoOrientation = .portraitUpsideDown
            case .landscapeLeft:  videoOrientation = .landscapeRight
            case .landscapeRight: videoOrientation = .landscapeLeft
            default:              videoOrientation = .portrait
            }
            connection.videoOrientation = videoOrientation
        }
    }
}
