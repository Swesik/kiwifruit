import Foundation
import CoreImage
import Vision
import UIKit
import OSLog
import Mentalist

// File-scope logger. Explicitly `nonisolated` because the project is
// configured with default-MainActor isolation (Swift 6.2) — otherwise
// this `let` would inherit MainActor and the `nonisolated static`
// analyze() entry point below couldn't reach it. Logger is Sendable.
nonisolated private let analyzerLog = Logger(subsystem: "com.kiwifruit.moodmap", category: "MentalistEmotionAnalyzer")

// MARK: - MentalistEmotionAnalyzer

/// Wrapper around the Mentalist third-party emotion analysis library.
///
/// Mentalist is a CoreML model trained on the FER2013 dataset, classifying face images into:
/// happy / angry / disgust / fear / sad / surprise / neutral
///
/// This service maps Mentalist's 7 emotion types to the App's internal QuickMood type.
final class MentalistEmotionAnalyzer {

    // MARK: - Public API

    /// Analyzes a given pixel buffer using Mentalist and returns the App's emotion type and confidence.
    ///
    /// - Parameters:
    ///   - pixelBuffer: Raw video frame captured from the camera (CVPixelBuffer).
    ///   - orientation: Image orientation for front camera capture, defaults to .leftMirrored.
    /// - Returns: (emotion type, confidence), or nil if analysis fails.
    nonisolated static func analyze(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation = .leftMirrored) -> (mood: QuickMood, confidence: Double)? {
        guard let cgImage = pixelBuffer.cgImage(orientation: orientation) else {
            analyzerLog.debug("analyze: failed to convert pixel buffer to CGImage")
            return nil
        }

        let analyses: [EmotionAnalysis]
        do {
            analyses = try Mentalist.analyze(cgImage: cgImage)
        } catch {
            analyzerLog.debug("analyze: Mentalist.analyze threw: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        guard let analysis = analyses.first else {
            // Common case: no face in frame — quiet log.
            analyzerLog.debug("analyze: Mentalist returned no analyses (likely no face detected)")
            return nil
        }

        let dominant = analysis.dominantEmotion
        let confidence = analysis.emotion[dominant] ?? 0.0

        let mood = mapToQuickMood(dominant)
        let normalizedConfidence = normalizeConfidence(original: confidence, emotion: dominant)

        return (mood, normalizedConfidence)
    }

    // MARK: - Emotion Mapping

    /// Maps Mentalist's 7 emotion types to App's 3 QuickMood types.
    ///
    /// Mapping rules:
    /// - happy / surprise → .inspired (positive emotions)
    /// - neutral → .focused (neutral, default focus)
    /// - sad / angry / fear / disgust → .tired (negative emotions)
    nonisolated private static func mapToQuickMood(_ emotion: Emotion) -> QuickMood {
        switch emotion {
        case .happy, .surprise:
            return .inspired
        case .neutral:
            return .focused
        case .sad, .angry, .fear, .disgust:
            return .tired
        }
    }

    // MARK: - Confidence normalization

    /// Reference baseline that the per-emotion boosts below normalize into —
    /// roughly the average dominant probability across all emotions.
    nonisolated private static let confidenceReferenceBaseline: Double = 0.57

    /// Upper clamp on normalized confidence. Keeps UI confidence readings
    /// from hitting 100% even when raw probability is near 1.0 — avoids
    /// over-promising certainty on what is ultimately a 48×48 FER2013 model.
    nonisolated private static let maxNormalizedConfidence: Double = 0.95

    /// Per-emotion multiplicative boost. Mentalist's raw class probabilities
    /// are skewed — happy tends to score near 0.9 on positives while
    /// disgust/fear rarely clear 0.3 even when dominant. These factors pull
    /// each class's "typical" output toward `confidenceReferenceBaseline`.
    /// Kept as a switch (rather than a dictionary) because `Mentalist.Emotion`
    /// isn't declared `Sendable` and wrapping it in a static `[Emotion: Double]`
    /// would need `nonisolated(unsafe)`. Tuned empirically against our
    /// labeled sample set.
    nonisolated private static func emotionConfidenceBoost(_ emotion: Emotion) -> Double {
        switch emotion {
        case .happy:    return 0.85
        case .surprise: return 0.78
        case .sad:      return 0.72
        case .neutral:  return 0.70
        case .angry:    return 0.68
        case .fear:     return 0.60
        case .disgust:  return 0.58
        }
    }

    /// Normalizes Mentalist's raw probability so that UI confidence % reads
    /// comparably across emotions, and caps it below 1.0.
    nonisolated private static func normalizeConfidence(original: Double, emotion: Emotion) -> Double {
        let boost = emotionConfidenceBoost(emotion)
        return min(maxNormalizedConfidence, original * boost / confidenceReferenceBaseline)
    }
}

// MARK: - CVPixelBuffer Extension

private extension CVPixelBuffer {
    nonisolated func cgImage(orientation: CGImagePropertyOrientation) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: self).oriented(orientation)
        let context = CIContext()
        return context.createCGImage(ciImage, from: ciImage.extent)
    }
}
