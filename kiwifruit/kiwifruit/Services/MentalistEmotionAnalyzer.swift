import Foundation
import CoreImage
import Vision
import UIKit
import Mentalist

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
            return nil
        }

        let analyses: [EmotionAnalysis]
        do {
            analyses = try Mentalist.analyze(cgImage: cgImage)
        } catch {
            return nil
        }

        guard let analysis = analyses.first else {
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

    /// Mentalist returns raw probability values (0~1), but different emotions have different baselines.
    /// happy tends to have higher confidence, disgust/fear tend to be lower, so normalization is needed.
    nonisolated private static func normalizeConfidence(original: Double, emotion: Emotion) -> Double {
        let boost: Double
        switch emotion {
        case .happy:    boost = 0.85
        case .surprise: boost = 0.78
        case .neutral:  boost = 0.70
        case .sad:      boost = 0.72
        case .angry:    boost = 0.68
        case .fear:     boost = 0.60
        case .disgust:  boost = 0.58
        }
        return min(0.95, original * boost / 0.57)
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
