import AVFoundation
import Foundation
import Vision
import Observation
import Synchronization
import Mentalist

// MARK: - Main service class: MoodMapCaptureService

/// Mood capture service: camera capture → Mentalist real-time emotion analysis → result output.
///
/// Core architecture:
/// - `AVCaptureSession` runs on a background thread and receives each frame via `captureOutput`.
/// - `VNDetectFaceRectanglesRequest` performs fast face detection (only detects face position, no expression analysis).
///   After successful detection, the face region is cropped and passed to Mentalist CoreML model for emotion classification.
/// - Mentalist is a third-party library (trained on FER2013 dataset) that returns 7 emotion types:
///   happy / angry / disgust / fear / sad / surprise / neutral.
/// - Emotion results are mapped to App's `QuickMood` type via `MentalistEmotionAnalyzer`.
/// - Uses a voting system to confirm stable emotions: UI state only switches after reaching ≥60% majority votes.
@Observable
final class MoodMapCaptureService: NSObject {

    // MARK: Published state (observed by SwiftUI views)

    /// Camera session (used to bind to PreviewLayer / AVPreviewLayer).
    private(set) var captureSession: AVCaptureSession?
    /// Camera error message; nil when there's no error.
    private(set) var cameraError: String?
    /// Current stable confirmed emotion type (requires 60% majority votes, used for final confirmation page).
    private(set) var detectedMood: QuickMood?
    /// Current emotion confidence (average confidence of votes for this emotion).
    private(set) var detectionConfidence: Double = 0.0
    /// Live emotion: outputs directly per frame during camera preview without waiting for vote threshold.
    private(set) var liveMood: QuickMood?
    /// Live emotion confidence.
    private(set) var liveConfidence: Double = 0.0
    /// Number of consecutive frames with the current emotion (used for UI stability display).
    private(set) var stableFrames: Int = 0
    /// Whether a face is detected (used for UI "please align your face" prompt).
    private(set) var faceDetected: Bool = false

    // MARK: Private state

    /// Video frame output delegate.
    private var videoOutput: AVCaptureVideoDataOutput?

    /// Video frame callback queue — background serial queue to avoid frame accumulation.
    private let videoQueue = DispatchQueue(label: "com.kiwifruit.moodmap.capture", qos: .userInteractive)

    /// Timestamp (CACurrentMediaTime seconds) of the most recently processed
    /// frame. Wrapped in a Mutex so the read-modify-write in
    /// ``captureOutput(_:didOutput:from:)`` is atomic, and so the field can
    /// be reached from the nonisolated delegate callback without the
    /// ``nonisolated(unsafe)`` escape hatch — the lock makes the concurrency
    /// contract explicit instead of relying on "the videoQueue is serial".
    @ObservationIgnored
    private let lastProcessedTimestamp = Mutex<TimeInterval>(0)

    /// Emotion vote counter.
    private var moodVotes: [QuickMood: Int] = [.focused: 0, .inspired: 0, .tired: 0]
    /// Emotion confidence accumulator.
    private var moodConfSum: [QuickMood: Double] = [.focused: 0.0, .inspired: 0.0, .tired: 0.0]
    /// Total frame count for the current session.
    private var totalFrames: Int = 0

    // Timeline tracking: records each stable mood change with elapsed seconds from session start.
    private var sessionStartTime: Date?
    private var moodTimeline: [MoodTimelineEvent] = []
    private var lastTimelineMood: QuickMood?

    override init() {
        super.init()
    }

    // MARK: Public API

    /// Starts the camera session.
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

    /// Clears the current error state.
    func clearError() {
        cameraError = nil
    }

    /// Stops the camera session and resets all state.
    func stopSession() {
        videoOutput?.setSampleBufferDelegate(nil, queue: nil)
        captureSession?.stopRunning()
        captureSession = nil
        videoOutput = nil

        detectedMood = nil
        faceDetected = false
        stableFrames = 0
        liveMood = nil
        liveConfidence = 0.0
        moodVotes = [.focused: 0, .inspired: 0, .tired: 0]
        moodConfSum = [.focused: 0.0, .inspired: 0.0, .tired: 0.0]
        totalFrames = 0
        lastProcessedTimestamp.withLock { $0 = 0 }
        sessionStartTime = nil
        moodTimeline = []
        lastTimelineMood = nil
    }

    // MARK: Session setup (private)

    private func setupSession() {
        sessionStartTime = Date()
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
        output.alwaysDiscardsLateVideoFrames = true

        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        videoOutput = output
        captureSession = session
        session.startRunning()
    }

    // MARK: Mood voting

    /// Most-voted mood over the session; confidence = average for that mood's votes.
    func snapshotSuggestion() -> (mood: QuickMood?, confidence: Double) {
        guard totalFrames > 0 else { return (nil, 0.0) }
        guard let mood = moodVotes.max(by: { $0.value < $1.value })?.key else {
            return (nil, 0.0)
        }
        let votes = moodVotes[mood] ?? 0
        let avgConf = votes > 0 ? (moodConfSum[mood] ?? 0.0) / Double(votes) : 0.0

        if mood == .tired, Double(votes) <= Double(totalFrames) * 0.30 {
            let focusedVotes = moodVotes[.focused] ?? 0
            let focusedConf = (moodConfSum[.focused] ?? 0.0) / Double(max(1, focusedVotes))
            return (.focused, focusedConf)
        }

        return (mood, avgConf)
    }

    /// Full session snapshot: dominant mood, confidence, per-mood frame distribution, and timeline.
    /// Call this BEFORE stopSession() — all data is wiped on stop.
    func snapshotFull() -> (mood: QuickMood?, confidence: Double, distribution: [String: Int], timeline: [MoodTimelineEvent]) {
        let snap = snapshotSuggestion()
        let distribution = Dictionary(
            uniqueKeysWithValues: moodVotes.compactMap { mood, count in count > 0 ? (mood.rawValue, count) : nil }
        )
        return (snap.mood, snap.confidence, distribution, moodTimeline)
    }

    private func ingestNoFace() {
        faceDetected = false
        detectedMood = nil
        stableFrames = 0
    }

    private func ingestFace(mood: QuickMood, confidence: Double) {
        faceDetected = true

        // Live output: updates directly per frame without waiting for votes.
        liveMood = mood
        liveConfidence = confidence

        moodVotes[mood, default: 0] += 1
        moodConfSum[mood, default: 0.0] += confidence
        totalFrames += 1

        guard let (dominantMood, count) = moodVotes.max(by: { $0.value < $1.value }) else {
            return
        }
        let dominantPct = Double(count) / Double(totalFrames)

        if let tiredVotes = moodVotes[.tired], Double(tiredVotes) <= Double(totalFrames) * 0.30 {
            detectedMood = .focused
            let focusedVotes = moodVotes[.focused] ?? 0
            detectionConfidence = focusedVotes > 0 ? (moodConfSum[.focused] ?? 0.0) / Double(focusedVotes) : 0.0
            stableFrames = 0
            return
        }

        guard dominantPct >= 0.60 else {
            detectedMood = nil
            stableFrames = 0
            return
        }

        // Record a timeline event whenever the stable dominant mood changes.
        if dominantMood != lastTimelineMood {
            let elapsed = sessionStartTime.map { Date().timeIntervalSince($0) } ?? 0
            moodTimeline.append(MoodTimelineEvent(secondsFromStart: elapsed, mood: dominantMood))
            lastTimelineMood = dominantMood
        }

        detectedMood = dominantMood
        detectionConfidence = (moodConfSum[dominantMood] ?? 0.0) / Double(count)
        stableFrames = count
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension MoodMapCaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Frame rate limit: at least 0.15 seconds between processing (~6-7 fps).
        // Read-modify-write atomically so two overlapping delegate callbacks
        // can never both pass the gate in the same window.
        let now = CACurrentMediaTime()
        let shouldSkip = lastProcessedTimestamp.withLock { last -> Bool in
            if now - last < 0.15 { return true }
            last = now
            return false
        }
        if shouldSkip { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Step 1: Use Vision to quickly detect the face rectangle. We do NOT
        // capture `self` in this outer (task-isolated) closure — Swift 6
        // flags capturing a MainActor-isolated `self` from a nonisolated
        // context as a data race risk. Instead, compute the emotion result
        // locally here and hand it off through a fresh `[weak self]`
        // capture inside the MainActor hop.
        let request = VNDetectFaceRectanglesRequest { request, error in
            let faceFound: Bool
            if error != nil {
                faceFound = false
            } else if let observations = request.results as? [VNFaceObservation], !observations.isEmpty {
                faceFound = true
            } else {
                faceFound = false
            }

            let emotionResult: (mood: QuickMood, confidence: Double)?
            if faceFound {
                emotionResult = MentalistEmotionAnalyzer.analyze(
                    pixelBuffer: pixelBuffer,
                    orientation: .leftMirrored
                )
            } else {
                emotionResult = nil
            }

            Task { @MainActor [weak self] in
                guard let self else { return }
                if let (mood, confidence) = emotionResult {
                    self.ingestFace(mood: mood, confidence: confidence)
                } else {
                    self.ingestNoFace()
                }
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
}
