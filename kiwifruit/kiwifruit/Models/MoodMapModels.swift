import Foundation

// MARK: - Quick Emotion (three results from facial recognition)

/// Emotion labels from facial recognition: focused / inspired / tired. Used for personalization and calendar display.
public enum QuickMood: String, Codable, CaseIterable, Identifiable {
    case focused  // Focused
    case inspired // Inspired/Happy
    case tired    // Tired

    public var id: String { rawValue }

    /// Display name
    public var displayName: String {
        switch self {
        case .focused: return "Focused"   // Focused
        case .inspired: return "Inspired"  // Inspired
        case .tired: return "Tired"       // Tired
        }
    }
}

// MARK: - CV Emotion Sample (during capture)

// Single camera capture emotion result (from Vision or face-api backend).
public struct MoodSample: Codable, Sendable {
    /// Sample timestamp
    public let timestamp: Date
    /// Main emotion label, e.g., "happy", "neutral", "sad" (aligned with Vision / face-api)
    public let dominantEmotion: String
    /// Confidence 0...1
    public let confidence: Float

    public init(timestamp: Date, dominantEmotion: String, confidence: Float) {
        self.timestamp = timestamp
        self.dominantEmotion = dominantEmotion
        self.confidence = confidence
    }
}

// MARK: - Mood Map Session (one capture)

// One Mood Map capture: CV samples during capture + recognized emotion at end.
public struct MoodMapSession: Identifiable, Codable {
    public let id: UUID
    /// Session start time
    public let startedAt: Date
    /// Session end time
    public let endedAt: Date
    /// Emotion samples collected from camera during this capture (empty if none)
    public var cvSamples: [MoodSample]
    /// Emotion recognized from facial recognition at end of capture
    public var postSessionMood: QuickMood?

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        cvSamples: [MoodSample] = [],
        postSessionMood: QuickMood? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.cvSamples = cvSamples
        self.postSessionMood = postSessionMood
    }
}

// MARK: - Mood Map State (standalone)

// Mood Map capture state
public enum MoodMapState: Equatable {
    case idle      // Idle state
    case capturing // Capturing
}

// MARK: - Map Vision emotion to QuickMood (three results)

// Maps a single Vision emotion label to one of focused / inspired / tired.
public func mapVisionEmotionToQuickMood(_ emotion: String) -> QuickMood {
    let lower = emotion.lowercased()
    // Positive, high arousal -> inspired
    if lower.contains("happy") || lower.contains("surprised") || lower.contains("joy") {
        return .inspired
    }
    // Negative, low energy -> tired
    if lower.contains("sad") || lower.contains("angry") || lower.contains("fearful")
        || lower.contains("disgusted") || lower.contains("contempt") {
        return .tired
    }
    // Neutral, calm -> focused (includes neutral and unmatched cases)
    return .focused
}

/// Aggregate samples into a QuickMood using confidence-weighted majority vote
public func aggregateSamplesToQuickMood(_ samples: [MoodSample]) -> QuickMood? {
    guard !samples.isEmpty else { return nil }
    var score: [QuickMood: Float] = [.focused: 0, .inspired: 0, .tired: 0]
    for s in samples {
        let mood = mapVisionEmotionToQuickMood(s.dominantEmotion)
        score[mood, default: 0] += s.confidence
    }
    return score.max(by: { $0.value < $1.value })?.key
}
