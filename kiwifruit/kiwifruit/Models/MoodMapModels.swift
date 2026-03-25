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

    public init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        postSessionMood: QuickMood? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.postSessionMood = postSessionMood
    }
}

// MARK: - Mood Map State

/// Mood Map capture state
public enum MoodMapState: Equatable {
    case idle      // Idle state
    case capturing // Capturing (camera open)
}
