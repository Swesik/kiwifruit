import Foundation
import CoreImage
import Vision
import UIKit
import OSLog
import Mentalist

// MARK: - MentalistEmotionAnalyzer

/// Wrapper around the Mentalist third-party emotion analysis library.
///
/// Mentalist is a CoreML model trained on the FER2013 dataset, classifying face images into:
/// happy / angry / disgust / fear / sad / surprise / neutral
///
/// This service maps Mentalist's 7 emotion types to the App's internal QuickMood type.
final class MentalistEmotionAnalyzer {

    /// Logger for per-frame analysis failures. Runs at .debug so high-frequency
    /// misses stay out of the default log stream but remain inspectable when
    /// debugging camera/permission/model issues.
    private static let log = Logger(subsystem: "com.kiwifruit.moodmap", category: "MentalistEmotionAnalyzer")

    // MARK: - Public API

    /// Analyzes a given pixel buffer using Mentalist and returns the App's emotion type and confidence.
    ///
    /// - Parameters:
    ///   - pixelBuffer: Raw video frame captured from the camera (CVPixelBuffer).
    ///   - orientation: Image orientation for front camera capture, defaults to .leftMirrored.
    /// - Returns: (emotion type, confidence), or nil if analysis fails.
    nonisolated static func analyze(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation = .leftMirrored) -> (mood: QuickMood, confidence: Double)? {
        guard let cgImage = pixelBuffer.cgImage(orientation: orientation) else {
            log.debug("analyze: failed to convert pixel buffer to CGImage")
            return nil
        }

        let analyses: [EmotionAnalysis]
        do {
            analyses = try Mentalist.analyze(cgImage: cgImage)
        } catch {
            log.debug("analyze: Mentalist.analyze threw: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        guard let analysis = analyses.first else {
            // Common case: no face in frame — quiet log.
            log.debug("analyze: Mentalist returned no analyses (likely no face detected)")
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

    /// Per-emotion multiplicative boost. Mentalist's raw class probabilities
    /// are skewed — happy tends to score near 0.9 on positives while
    /// disgust/fear rarely clear 0.3 even when dominant. These factors pull
    /// each class's "typical" output toward a common perceived-confidence
    /// baseline (see ``confidenceReferenceBaseline``). Tuned empirically
    /// against our labeled sample set.
    nonisolated private static let emotionConfidenceBoost: [Emotion: Double] = [
        .happy:    0.85,
        .surprise: 0.78,
        .sad:      0.72,
        .neutral:  0.70,
        .angry:    0.68,
        .fear:     0.60,
        .disgust:  0.58,
    ]

    /// Reference baseline that the boosts normalize into — roughly the
    /// average dominant probability we see across all emotions in-the-wild.
    nonisolated private static let confidenceReferenceBaseline: Double = 0.57

    /// Upper clamp on normalized confidence. Keeps UI confidence readings
    /// from reading "100%" even when the raw probability is near 1.0 — avoids
    /// over-promising certainty on what is ultimately a 48x48 FER2013 model.
    nonisolated private static let maxNormalizedConfidence: Double = 0.95

    /// Normalizes Mentalist's raw probability so that UI confidence % reads
    /// comparably across emotions, and caps it below 1.0.
    nonisolated private static func normalizeConfidence(original: Double, emotion: Emotion) -> Double {
        let boost = emotionConfidenceBoost[emotion] ?? confidenceReferenceBaseline
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
