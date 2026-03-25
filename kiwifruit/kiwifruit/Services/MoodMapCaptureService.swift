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

    init() {}

    /// Start the front camera
    func startSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
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

    /// Stop the camera
    func stopSession() {
        captureSession?.stopRunning()
        captureSession = nil
    }
}
