import AVFoundation
import Foundation
import Observation
import Vision

/// Capture camera frames and run Vision emotion recognition; pass MoodSample to MoodSessionStore via callback.
/// Starts when MoodMapCameraView appears, stops when disappears.
@Observable
@MainActor
final class MoodMapCaptureService: NSObject {
    /// Callback function to pass emotion samples to storage layer
    private let onSample: (MoodSample) -> Void
    /// Camera capture session
    private(set) var captureSession: AVCaptureSession?
    /// Throttle interval (seconds) - capture once every 2 seconds
    private static let throttleInterval: CFTimeInterval = 2.0
    /// Last capture time (not thread-safe)
    nonisolated(unsafe) private var lastCaptureTime: CFTimeInterval = 0
    /// Dedicated serial queue for AVFoundation sample buffer callbacks (required by AVCaptureVideoDataOutput)
    private let sampleBufferQueue = DispatchQueue(label: "kiwifruit.moodmap.samplebuffer", qos: .userInitiated)

    init(onSample: @escaping (MoodSample) -> Void) {
        self.onSample = onSample
        super.init()
    }

    /// Start capture session (open camera)
    func startSession() {
        // Create capture session
        let session = AVCaptureSession()
        session.sessionPreset = .medium
        
        // Get front camera
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            return
        }
        session.addInput(input)
        
        // Configure video output
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: sampleBufferQueue)
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        captureSession = session
        
        // Start session on background thread
        Task.detached { [weak session] in
            session?.startRunning()
        }
    }

    /// Stop capture session (close camera)
    func stopSession() {
        captureSession?.stopRunning()
        captureSession = nil
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension MoodMapCaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {
    /// Called when a video frame is captured
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CACurrentMediaTime()
        // Check if throttle interval has elapsed
        guard now - lastCaptureTime >= Self.throttleInterval else { return }
        lastCaptureTime = now

        // Get pixel buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        processFrame(pixelBuffer: pixelBuffer)
    }

    /// Uses VNDetectFaceRectanglesRequest (available on all iOS versions). When a face is detected,
    /// adds a "neutral" sample, which maps to Focused; does not depend on iOS 17+ emotion API.
    private nonisolated func processFrame(pixelBuffer: CVPixelBuffer) {
        // Create face detection request
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return
        }
        
        // If face detected, create sample
        guard let results = request.results, !results.isEmpty else { return }
        let sample = MoodSample(
            timestamp: Date(),
            dominantEmotion: "neutral",  // Currently simplified to neutral, maps to Focused
            confidence: 0.6
        )
        
        // Invoke callback on main thread
        Task { @MainActor in
            self.onSample(sample)
        }
    }
}
