import AVFoundation
import SwiftUI
import UIKit

/// Full-screen camera preview view with "Capturing…" label and "Stop Mood Map" button.
/// Starts MoodMapCaptureService when appears, stops when disappears; samples passed to MoodSessionStore via onSample.
struct MoodMapCameraView: View {
    @Environment(\.moodSessionStore) private var moodStore: MoodSessionStore
    @Environment(\.dismiss) private var dismiss

    /// Capture service instance
    @State private var captureService: MoodMapCaptureService?

    var body: some View {
        // Camera preview view
        CameraPreviewView(session: captureService?.captureSession)
            .ignoresSafeArea()
            .overlay {
                VStack {
                    // Show capture status
                    Text("Mood Map capturing…")
                        .font(.headline)
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                    Spacer()
                    
                    // Stop button
                    Button("Stop Mood Map") {
                        captureService?.stopSession()
                        moodStore.endMoodMap()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 40)
                }
            }
            .onAppear {
                // Create and start capture service
                let service = MoodMapCaptureService { sample in
                    moodStore.appendCvSample(sample)
                }
                captureService = service
                service.startSession()
            }
            .onDisappear {
                // Stop capture service
                captureService?.stopSession()
            }
    }
}

/// Render AVCaptureSession as full-screen preview
private struct CameraPreviewView: UIViewControllerRepresentable {
    var session: AVCaptureSession?

    func makeUIViewController(context: Context) -> CameraPreviewViewController {
        let vc = CameraPreviewViewController()
        vc.session = session
        return vc
    }

    func updateUIViewController(_ uiViewController: CameraPreviewViewController, context: Context) {
        uiViewController.session = session
    }
}

/// Custom UIViewController for displaying camera preview
private final class CameraPreviewViewController: UIViewController {
    /// Capture session (automatically updates preview layer when set)
    var session: AVCaptureSession? {
        didSet { previewLayer.session = session }
    }

    /// Video preview layer
    private let previewLayer = AVCaptureVideoPreviewLayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
    }
}
