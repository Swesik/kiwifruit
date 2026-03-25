import AVFoundation
import Foundation
import Observation

/// Opens the front camera and exposes the capture session for live preview.
/// No face detection or emotion analysis — mood selection is manual.
@Observable
@MainActor
final class MoodMapCaptureService {
    /// Camera capture session
    private(set) var captureSession: AVCaptureSession?

    /// Error message when camera access fails
    private(set) var cameraError: String?

    init() {}

    /// Start the front camera. Sets `cameraError` if permission denied or setup fails.
    func startSession() {
        cameraError = nil
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor [weak self] in
                    if granted {
                        self?.setupSession()
                    } else {
                        self?.cameraError = "Camera access was denied. Go to Settings > Privacy > Camera to enable it."
                    }
                }
            }
        case .denied, .restricted:
            cameraError = "Camera access is not available. Go to Settings > Privacy > Camera to enable it."
        @unknown default:
            cameraError = "Unable to access the camera."
        }
    }

    private func setupSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            cameraError = "No front camera found on this device."
            return
        }

        guard let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            cameraError = "Unable to set up camera input."
            return
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        captureSession = session

        Task.detached { [weak session] in
            session?.startRunning()
        }
    }

    /// Clear the error state
    func clearError() {
        cameraError = nil
    }

    /// Stop the camera
    func stopSession() {
        captureSession?.stopRunning()
        captureSession = nil
    }
}
