import SwiftUI
import AVFoundation

// MARK: - CameraPreviewView

/// A SwiftUI wrapper around `AVCaptureVideoPreviewLayer` that displays
/// a live camera feed. Used by the mood capture flow to show the front
/// camera while the user records a mood session.
///
/// This view bridges UIKit's `AVCaptureSession` into SwiftUI using
/// `UIViewRepresentable`. The underlying `CameraPreviewUIView` overrides
/// `layerClass` so that its root `CALayer` is an
/// `AVCaptureVideoPreviewLayer`, which is the standard Apple pattern for
/// displaying a camera preview without managing a separate sublayer.
struct CameraPreviewView: UIViewRepresentable {
    /// The capture session whose video output should be displayed.
    let session: AVCaptureSession

    /// Creates the backing UIKit view and connects the capture session
    /// to its preview layer.
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    /// Called when SwiftUI state changes — keeps the session reference
    /// in sync and refreshes the video orientation.
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.previewLayer.session = session
        uiView.updateOrientation()
    }
}

// MARK: - CameraPreviewUIView

/// A UIView subclass whose root layer is `AVCaptureVideoPreviewLayer`.
///
/// By overriding `layerClass`, UIKit allocates an
/// `AVCaptureVideoPreviewLayer` as the view's backing layer instead of
/// a plain `CALayer`. This avoids manually adding and resizing a
/// sublayer — the preview layer automatically matches the view's bounds.
///
/// This is the approach recommended by Apple's AVFoundation documentation.
final class CameraPreviewUIView: UIView {

    /// Tell UIKit to use `AVCaptureVideoPreviewLayer` as this view's
    /// root layer class. This is set once at class level and cannot fail.
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    /// Provides typed access to the view's root layer.
    ///
    /// Because `layerClass` is overridden above, `self.layer` is always
    /// an `AVCaptureVideoPreviewLayer`. The `guard let ... as?` cast
    /// replaces a force cast (`as!`) to comply with the project's AI
    /// Rules, which prohibit force unwraps and force casts. In practice
    /// this cast cannot fail, so the `fatalError` acts as a compile-time
    /// safety net rather than a runtime concern.
    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let preview = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("layerClass is AVCaptureVideoPreviewLayer but cast failed — this should never happen")
        }
        return preview
    }

    /// Ensures the video orientation stays correct after layout changes
    /// (e.g. device rotation).
    override func layoutSubviews() {
        super.layoutSubviews()
        updateOrientation()
    }

    /// Reads the current interface orientation from the window scene and
    /// maps it to the corresponding `AVCaptureVideoOrientation` so the
    /// camera preview is always right-side up.
    func updateOrientation() {
        guard let connection = previewLayer.connection,
              connection.isVideoOrientationSupported else { return }

        let windowScene = window?.windowScene
        let interfaceOrientation = windowScene?.interfaceOrientation ?? .portrait

        let videoOrientation: AVCaptureVideoOrientation
        switch interfaceOrientation {
        case .portrait:           videoOrientation = .portrait
        case .portraitUpsideDown: videoOrientation = .portraitUpsideDown
        case .landscapeLeft:      videoOrientation = .landscapeRight
        case .landscapeRight:     videoOrientation = .landscapeLeft
        default:                  videoOrientation = .portrait
        }
        connection.videoOrientation = videoOrientation
    }
}
