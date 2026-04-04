import AVFoundation
import Foundation
import Vision
import Observation

// MARK: - Pure face → mood (safe to call from any thread)

private enum FaceMoodAnalyzer {
    /// Runs on the Vision/video queue; must not be MainActor-isolated (see module default isolation).
    // Replaced by analyzeV2 below.
    nonisolated static func analyze(_ face: VNFaceObservation) -> (mood: QuickMood, confidence: Double) {
        guard let landmarks = face.landmarks else {
            let aspect = face.boundingBox.width / face.boundingBox.height
            let mood: QuickMood = aspect > 0.75 ? .inspired : .focused
            return (mood, 0.35)
        }

        let leftEyeOpen = eyeOpennessRatio(landmarks.leftEye)
        let rightEyeOpen = eyeOpennessRatio(landmarks.rightEye)
        let avgEyeOpenness = (leftEyeOpen + rightEyeOpen) / 2.0
        let mouthCurve = mouthCurvature(landmarks)
        let browRaise = eyebrowRaise(landmarks)
        let tilt = abs(face.yaw?.doubleValue ?? 0)

        let energyScore: Double
        if avgEyeOpenness > 0.65 {
            energyScore = 0.85
        } else if avgEyeOpenness > 0.40 {
            energyScore = 0.50
        } else {
            energyScore = 0.15
        }

        let happinessScore: Double
        if mouthCurve > 0.30 {
            happinessScore = 0.90
        } else if mouthCurve > 0.10 {
            happinessScore = 0.55
        } else if mouthCurve < -0.30 {
            happinessScore = 0.10
        } else {
            happinessScore = 0.40
        }

        let alertnessScore: Double
        if browRaise > 0.20 && tilt < 0.15 {
            alertnessScore = 0.85
        } else if browRaise > 0.05 {
            alertnessScore = 0.55
        } else {
            alertnessScore = 0.25
        }

        let energy = energyScore * 0.50 + alertnessScore * 0.30 + (1.0 - tilt) * 0.20
        let positivity = happinessScore * 0.60 + alertnessScore * 0.40

        let mood: QuickMood
        let confidence: Double

        if avgEyeOpenness < 0.30 {
            mood = .tired
            confidence = Double(0.30 + (1.0 - avgEyeOpenness) * 0.60)
        } else if energy > 0.68 && positivity > 0.60 {
            mood = .inspired
            confidence = min(0.95, (energy + positivity) / 2.0)
        } else if energy > 0.45 && positivity < 0.55 {
            mood = .focused
            confidence = min(0.90, energy * 1.2)
        } else if energy < 0.40 {
            mood = .tired
            confidence = min(0.85, (1.0 - energy) * 1.1)
        } else {
            mood = .focused
            confidence = 0.45 + avgEyeOpenness * 0.30
        }

        return (mood, min(1.0, max(0.0, confidence)))
    }

    nonisolated private static func eyeOpennessRatio(_ eye: VNFaceLandmarkRegion2D?) -> Double {
        guard let points = eye?.normalizedPoints, points.count >= 4 else { return 0.5 }
        let minX = points.map { $0.x }.min() ?? 0
        let maxX = points.map { $0.x }.max() ?? 1
        let minY = points.map { $0.y }.min() ?? 0
        let maxY = points.map { $0.y }.max() ?? 1
        let width = maxX - minX
        let height = maxY - minY
        guard width > 0.001 else { return 0.5 }
        let ear = height / width
        return min(1.0, ear / 0.45)
    }

    nonisolated private static func mouthCurvature(_ landmarks: VNFaceLandmarks2D) -> Double {
        guard let outerLips = landmarks.outerLips,
              let innerLips = landmarks.innerLips,
              let outerPoints = Optional(outerLips.normalizedPoints),
              let innerPoints = Optional(innerLips.normalizedPoints),
              !outerPoints.isEmpty, !innerPoints.isEmpty else {
            return 0.0
        }
        let topCenter = innerPoints.min(by: { $0.y < $1.y }).map { $0.y } ?? 0.5
        let bottomCenter = innerPoints.max(by: { $0.y < $1.y }).map { $0.y } ?? 0.5
        let mouthOpen = bottomCenter - topCenter
        let leftCorner = outerPoints.first { $0.x < 0.3 }?.y ?? 0.5
        let rightCorner = outerPoints.last { $0.x > 0.7 }?.y ?? 0.5
        let avgCornerY = (leftCorner + rightCorner) / 2.0
        let curve = (avgCornerY - (topCenter + bottomCenter) / 2.0) * 4.0
        return max(-1.0, min(1.0, curve + mouthOpen * 1.5))
    }

    nonisolated private static func eyebrowRaise(_ landmarks: VNFaceLandmarks2D) -> Double {
        guard let leftEye = landmarks.leftEye?.normalizedPoints,
              let rightEye = landmarks.rightEye?.normalizedPoints,
              let leftBrow = landmarks.leftEyebrow?.normalizedPoints,
              let rightBrow = landmarks.rightEyebrow?.normalizedPoints,
              !leftEye.isEmpty, !rightEye.isEmpty,
                !leftBrow.isEmpty, !rightBrow.isEmpty else {
            return 0.5
        }
        let eyeTop = (leftEye + rightEye).map { $0.y }.min() ?? 0.5
        let browBottom = (leftBrow + rightBrow).map { $0.y }.min() ?? 0.5
        let gap = browBottom - eyeTop
        return min(1.0, gap / 0.15)
    }

    // MARK: - Improved analyzer (v2)

    nonisolated static func analyzeV2(_ face: VNFaceObservation) -> (mood: QuickMood, confidence: Double) {
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
            return (.tired, 0.40 + (0.25 - avgEAR) * 1.8)
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

    // Smile: −1 (frown/neutral) → +1 (smile).
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
        // Vision Y: smaller = higher (closer to forehead).
        let curve = (centerTop - cornerAvgY) * 3.0
        let opennessBonus: Double = mouthOpenness > 0.10 ? 0.15 : 0.0
        return max(-1.0, min(1.0, curve + opennessBonus))
    }

    // Eyebrow gap → alertness: 0.0 (furrowed) → 1.0 (raised).
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

/// Opens the front camera, runs Vision face landmark detection on a background queue,
/// and publishes results on the main actor (Swift 6 / MainActor default isolation safe).
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
    /// Throttled on the video output queue (not MainActor); not part of UI observation.
    @ObservationIgnored
    nonisolated(unsafe) private var lastProcessedTimestamp: TimeInterval = 0

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
        captureSession?.stopRunning()
        captureSession = nil
        videoOutput = nil
        detectedMood = nil
        faceDetected = false
        stableFrames = 0
        recentMoods.removeAll()
        lastProcessedTimestamp = 0
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

        // Require at least 3 consecutive frames of the same dominant mood.
        let consecutiveCount = recentMoods.reduce(0) { count, entry in
            entry.mood == dominantMood ? count + 1 : 0
        }
        // Also accept if dominant mood is 60%+ of the window (non-consecutive but clearly dominant).
        let isDominantEnough = Double(consecutiveCount) >= Double(recentMoods.count) * 0.60

        if !isDominantEnough {
            detectedMood = nil
            stableFrames = 0
            return
        }

        let avgConfidence = totalWeight / Double(recentMoods.count)
        detectedMood = dominantMood
        detectionConfidence = avgConfidence
        stableFrames = consecutiveCount
    }
}

// MARK: - Video delegate (runs off MainActor)

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
