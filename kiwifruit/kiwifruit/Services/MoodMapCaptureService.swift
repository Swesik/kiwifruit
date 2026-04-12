import AVFoundation
import Foundation
import Vision
import Observation

// MARK: - Pure face → mood (safe to call from any thread)

private enum FaceMoodAnalyzer {
    nonisolated static func analyzeV2(_ face: VNFaceObservation) -> (mood: QuickMood, confidence: Double) {
        let landmarks = face.landmarks

        let leftEAR  = eyeContourEAR(landmarks?.leftEye)
        let rightEAR = eyeContourEAR(landmarks?.rightEye)
        let avgEAR   = (leftEAR + rightEAR) / 2.0

        let smile = smileScore(landmarks)
        let browSig = eyebrowSignal(landmarks)

        let tilt = abs(face.yaw?.doubleValue ?? 0)

        if avgEAR < 0.25 {
            return (.tired, min(0.90, 0.40 + (0.25 - avgEAR) * 1.8))
        }
        // Looking away = not paying attention → tired.
        if tilt > 0.35 {
            let tiltConf = min(0.88, 0.30 + (0.35 - tilt) * -1.0)
            return (.tired, tiltConf)
        }

        // Energy: eye 54%, eyebrow 30%, smile 14%.
        let energy = avgEAR * 0.54 + browSig * 0.30 + max(0, smile) * 0.14
        let positivity = max(0, smile) * 0.60 + avgEAR * 0.25 + browSig * 0.15

        if energy > 0.55 && positivity > 0.45 {
            return (.inspired, min(0.90, (energy + positivity) / 2.0))
        }
        if energy > 0.45 && positivity < 0.50 {
            return (.focused, min(0.88, 0.40 + energy * 0.55))
        }
        if energy < 0.38 {
            return (.tired, min(0.82, (0.38 - energy) * 2.2))
        }
        return (.focused, 0.42 + avgEAR * 0.28)
    }

    nonisolated private static func eyeContourEAR(_ eye: VNFaceLandmarkRegion2D?) -> Double {
        guard let pts = eye?.normalizedPoints, pts.count >= 6 else { return 0.50 }
        let top    = pts[1]
        let bottom = pts[5]
        let left   = pts[0]
        let right  = pts[3]
        let vert  = abs(top.y - bottom.y)
        let horiz = abs(right.x - left.x)
        guard horiz > 0.001 else { return 0.50 }
        return min(1.0, (vert / horiz) / 0.40)
    }

    nonisolated private static func smileScore(_ landmarks: VNFaceLandmarks2D?) -> Double {
        guard let outer = landmarks?.outerLips?.normalizedPoints,
              let inner = landmarks?.innerLips?.normalizedPoints,
              !outer.isEmpty, !inner.isEmpty else { return 0.0 }
        let centerTop = inner.min(by: { $0.y < $1.y })?.y ?? 0.5
        let centerBot = inner.max(by: { $0.y < $1.y })?.y ?? 0.5
        let mouthOpenness = centerBot - centerTop
        let corners = outer.filter { $0.x < 0.25 || $0.x > 0.75 }
        guard corners.count >= 2 else { return 0.0 }
        let cornerAvgY = corners.map { $0.y }.reduce(0, +) / Double(corners.count)
        let curve = (centerTop - cornerAvgY) * 3.0
        let opennessBonus: Double = mouthOpenness > 0.10 ? 0.15 : 0.0
        return max(-1.0, min(1.0, curve + opennessBonus))
    }

    nonisolated private static func eyebrowSignal(_ landmarks: VNFaceLandmarks2D?) -> Double {
        guard let leftEye  = landmarks?.leftEye?.normalizedPoints,
              let rightEye = landmarks?.rightEye?.normalizedPoints,
              let leftBrow = landmarks?.leftEyebrow?.normalizedPoints,
              let rightBrow = landmarks?.rightEyebrow?.normalizedPoints,
              !leftEye.isEmpty, !rightEye.isEmpty,
              !leftBrow.isEmpty, !rightBrow.isEmpty else { return 0.50 }
        let leftGap  = (leftBrow.map  { $0.y }.min() ?? 0.5)  - (leftEye.map  { $0.y }.min() ?? 0.5)
        let rightGap = (rightBrow.map { $0.y }.min() ?? 0.5) - (rightEye.map { $0.y }.min() ?? 0.5)
        return min(1.0, max(0.0, (leftGap + rightGap) / 2.0 / 0.12))
    }
}

/// Camera + Vision run off the main thread; all `@Observable` mutations happen on MainActor
/// so SwiftUI / Observation never see cross-queue writes (avoids `_dispatch_assert_queue_fail`).
@MainActor
@Observable
final class MoodMapCaptureService: NSObject {
    private(set) var captureSession: AVCaptureSession?
    private(set) var cameraError: String?

    private(set) var detectedMood: QuickMood?
    private(set) var detectionConfidence: Double = 0.0
    private(set) var stableFrames: Int = 0
    private(set) var faceDetected: Bool = false

    private var videoOutput: AVCaptureVideoDataOutput?
    private let videoQueue = DispatchQueue(label: "moodCapture.video", qos: .userInitiated)

    @ObservationIgnored
    nonisolated(unsafe) private var lastProcessedTimestamp: TimeInterval = 0

    // Voting: each face-detected frame adds one vote (updated only on MainActor).
    private var moodVotes: [QuickMood: Int] = [.focused: 0, .inspired: 0, .tired: 0]
    private var moodConfSum: [QuickMood: Double] = [.focused: 0.0, .inspired: 0.0, .tired: 0.0]
    private var totalFrames: Int = 0

    override init() {
        super.init()
    }

    func startSession() {
        cameraError = nil
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    if granted {
                        self.setupSession()
                    } else {
                        self.cameraError = "Camera access was denied. Go to Settings > Privacy > Camera to enable it."
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
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        videoOutput = output
        captureSession = session
        session.startRunning()
    }

    func clearError() {
        cameraError = nil
    }

    func stopSession() {
        videoOutput?.setSampleBufferDelegate(nil, queue: nil)
        captureSession?.stopRunning()
        captureSession = nil
        videoOutput = nil
        detectedMood = nil
        faceDetected = false
        stableFrames = 0
        moodVotes = [.focused: 0, .inspired: 0, .tired: 0]
        moodConfSum = [.focused: 0.0, .inspired: 0.0, .tired: 0.0]
        totalFrames = 0
        lastProcessedTimestamp = 0
    }

    /// Most-voted mood over the session; confidence = average for that mood's votes.
    func snapshotSuggestion() -> (mood: QuickMood?, confidence: Double) {
        guard totalFrames > 0 else { return (nil, 0.0) }
        guard let mood = moodVotes.max(by: { $0.value < $1.value })?.key else {
            return (nil, 0.0)
        }
        let votes = moodVotes[mood] ?? 0
        let avgConf = votes > 0 ? (moodConfSum[mood] ?? 0.0) / Double(votes) : 0.0
        return (mood, avgConf)
    }

    private func ingestNoFace() {
        faceDetected = false
        detectedMood = nil
        stableFrames = 0
    }

    private func ingestFace(mood: QuickMood, confidence: Double) {
        faceDetected = true
        moodVotes[mood, default: 0] += 1
        moodConfSum[mood, default: 0.0] += confidence
        totalFrames += 1

        guard let (dominantMood, count) = moodVotes.max(by: { $0.value < $1.value }),
              Double(count) >= Double(totalFrames) * 0.60 else {
            detectedMood = nil
            stableFrames = 0
            return
        }

        detectedMood = dominantMood
        detectionConfidence = (moodConfSum[dominantMood] ?? 0.0) / Double(count)
        stableFrames = count
    }
}

// MARK: - Video delegate (runs on videoQueue; Vision completion may use another queue)

extension MoodMapCaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CACurrentMediaTime()
        if now - lastProcessedTimestamp < 0.15 { return }
        lastProcessedTimestamp = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectFaceLandmarksRequest { request, error in
            if error != nil {
                Task { @MainActor [weak self] in
                    self?.ingestNoFace()
                }
                return
            }

            guard let observations = request.results as? [VNFaceObservation],
                  let face = observations.first else {
                Task { @MainActor [weak self] in
                    self?.ingestNoFace()
                }
                return
            }

            let result = FaceMoodAnalyzer.analyzeV2(face)
            Task { @MainActor [weak self] in
                self?.ingestFace(mood: result.mood, confidence: result.confidence)
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
}
