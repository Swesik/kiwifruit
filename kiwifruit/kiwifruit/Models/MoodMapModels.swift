import Foundation

// MARK: - Quick Emotion

/// Emotion labels: focused / inspired / tired. Used for personalization and calendar display.
public enum QuickMood: String, Codable, CaseIterable, Identifiable {
    case focused  // Focused
    case inspired // Inspired/Happy
    case tired    // Tired

    public var id: String { rawValue }

    /// Display name
    public var displayName: String {
        switch self {
        case .focused: return "Focused"
        case .inspired: return "Inspired"
        case .tired: return "Tired"
        }
    }
}

// MARK: - Mood Timeline Event

/// A single detected-mood change during a capture session, with elapsed time from session start.
public struct MoodTimelineEvent: Identifiable, Codable, Equatable {
    public let id: UUID
    /// Seconds elapsed from the start of the capture session when this mood was first detected.
    public let secondsFromStart: Double
    public let mood: QuickMood

    public init(id: UUID = UUID(), secondsFromStart: Double, mood: QuickMood) {
        self.id = id
        self.secondsFromStart = secondsFromStart
        self.mood = mood
    }
}

// MARK: - Mood Map Session

/// One Mood Map capture session with user-selected emotion.
public struct MoodMapSession: Identifiable, Codable {
    public let id: UUID
    /// Session start time
    public let startedAt: Date
    /// Session end time
    public let endedAt: Date
    /// User-selected emotion at end of capture
    public var postSessionMood: QuickMood?
    /// Frame vote counts per mood (QuickMood.rawValue → count). Nil if session wasn't camera-captured.
    public var moodDistribution: [String: Int]?
    /// Ordered list of mood changes detected during the session. Nil if session wasn't camera-captured.
    public var moodTimeline: [MoodTimelineEvent]?

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        postSessionMood: QuickMood? = nil,
        moodDistribution: [String: Int]? = nil,
        moodTimeline: [MoodTimelineEvent]? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.postSessionMood = postSessionMood
        self.moodDistribution = moodDistribution
        self.moodTimeline = moodTimeline
    }
}

// MARK: - Mood Map State

/// Mood Map capture state
public enum MoodMapState: Equatable {
    case idle      // Idle state
    case capturing // Capturing (camera open)
}
