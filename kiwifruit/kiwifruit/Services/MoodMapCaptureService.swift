import AVFoundation
import Foundation
import os
import Vision
import Observation

// MARK: - Pure face → mood (safe to call from any thread)

private enum FaceMoodAnalyzer {

    static func analyzeV2(_ face: VNFaceObservation) -> (mood: QuickMood, confidence: Double) {
        let landmarks = face.landmarks

        // Signal 1: eye openness via outer contour EAR (more reliable than bounding box).
        let leftEAR  = eyeContourEAR(landmarks?.leftEye)
        let rightEAR = eyeContourEAR(landmarks?.rightEye)
        let avgEAR   = (leftEAR + rightEAR) / 2.0

        // Signal 2: smile score (-1 frown → +1 smile).
        let smile = smileScore(landmarks)

        // Signal 3: eyebrow gap → alertness.
        let browSig = eyebrowSignal(landmarks)

        // Signal 4: face tilt (small = face-on, large = looking away).
        let tilt = abs(face.yaw?.doubleValue ?? 0)
        let tiltScore = max(0, 1.0 - tilt / 0.35)

        // Energy: how awake/stimulated.
        //   Weight: eye 45%, eyebrow 25%, tilt 20%, smile 10%.
        let energy = avgEAR * 0.45 + browSig * 0.25 + tiltScore * 0.20 + max(0, smile) * 0.10

        // Positivity: happy vs. neutral/negative.
        //   Weight: smile 60%, eye 25%, eyebrow 15%.
        let positivity = max(0, smile) * 0.60 + avgEAR * 0.25 + browSig * 0.15

        // Decision logic.
        if avgEAR < 0.25 {
            return (.tired, min(0.90, 0.40 + (0.25 - avgEAR) * 1.8))
        }
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

    // EAR from 6-point outer eye contour. Fully open ≈ 0.35–0.45.
    private static func eyeContourEAR(_ eye: VNFaceLandmarkRegion2D?) -> Double {
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

    // Smile: −1 (frown/neutral) → +1 (smile).
    private static func smileScore(_ landmarks: VNFaceLandmarks2D?) -> Double {
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

    // Eyebrow gap → alertness: 0.0 (furrowed) → 1.0 (raised).
    private static func eyebrowSignal(_ landmarks: VNFaceLandmarks2D?) -> Double {
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

/// Opens the front camera, runs Vision face landmark detection on a background queue,
/// and publishes results to observable properties for SwiftUI consumption.
@Observable
final class MoodMapCaptureService: NSObject {
    private(set) var captureSession: AVCaptureSession?
    private(set) var cameraError: String?

    private(set) var detectedMood: QuickMood?
    private(set) var detectionConfidence: Double = 0.0
    private(set) var stableFrames: Int = 0
    private(set) var faceDetected: Bool = false

    private var videoOutput: AVCaptureVideoDataOutput?
    /// Throttled on the video output queue; guarded by `timestampLock`.
    @ObservationIgnored
    private var _lastProcessedTimestamp: TimeInterval = 0
    @ObservationIgnored
    private let timestampLock = OSAllocatedUnfairLock()

    private var recentMoods: [(mood: QuickMood, confidence: Double)] = []
    private let recentWindow = 8

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
                // Justified @MainActor: updating @Observable UI state from AVFoundation callback thread.
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
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "moodCapture.video", qos: .userInitiated))
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
        recentMoods.removeAll()
        timestampLock.withLock { _lastProcessedTimestamp = 0 }
    }

    /// Snapshot for handing off to the post-session mood picker.
    func snapshotSuggestion() -> (mood: QuickMood?, confidence: Double) {
        (detectedMood, detectionConfidence)
    }

    private func ingestNoFace() {
        faceDetected = false
        detectedMood = nil
        stableFrames = 0
        recentMoods.removeAll()
    }

    private func ingestFace(mood: QuickMood, confidence: Double) {
        faceDetected = true
        recentMoods.append((mood, confidence))
        if recentMoods.count > recentWindow {
            recentMoods.removeFirst()
        }

        // Dominant mood by weighted frequency.
        let moodCounts = Dictionary(grouping: recentMoods) { $0.mood }
            .mapValues { entries in
                entries.reduce(0.0) { $0 + $1.confidence }
            }
        guard let (dominantMood, totalWeight) = moodCounts.max(by: { $0.value < $1.value }) else { return }

        // Require dominant mood to appear in 60%+ of recent frames.
        let dominantCount = recentMoods.filter { $0.mood == dominantMood }.count
        let isDominantEnough = Double(dominantCount) >= Double(recentMoods.count) * 0.60

        if !isDominantEnough {
            detectedMood = nil
            stableFrames = 0
            return
        }

        let avgConfidence = totalWeight / Double(recentMoods.count)
        detectedMood = dominantMood
        detectionConfidence = avgConfidence
        stableFrames = dominantCount
    }
}

// MARK: - Video delegate

extension MoodMapCaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CACurrentMediaTime()
        let shouldSkip = timestampLock.withLock { now - _lastProcessedTimestamp < 0.15 }
        if shouldSkip { return }
        timestampLock.withLock { _lastProcessedTimestamp = now }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Justified @MainActor: Vision callback runs on video queue;
        // must hop to main thread to mutate @Observable properties for SwiftUI.
        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            if error != nil {
                Task { @MainActor in self?.ingestNoFace() }
                return
            }

            guard let observations = request.results as? [VNFaceObservation],
                  let face = observations.first else {
                Task { @MainActor in self?.ingestNoFace() }
                return
            }

            let result = FaceMoodAnalyzer.analyzeV2(face)
            Task { @MainActor in
                self?.ingestFace(mood: result.mood, confidence: result.confidence)
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
}
