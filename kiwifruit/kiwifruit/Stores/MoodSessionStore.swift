import Foundation
import Observation
import SwiftUI

/// UserDefaults storage key
private let moodMapSessionsKey = "kiwifruit.moodmap.sessions"

/// Reading/emotion session storage manager
/// Manages Mood Map state, session data persistence, and calendar display functionality
@Observable
@MainActor
public final class MoodSessionStore {
    /// Mood Map state: idle or capturing
    public private(set) var moodMapState: MoodMapState = .idle

    /// Start time of current capture (only valid during capture)
    public private(set) var moodMapStartedAt: Date?

    /// Saved Mood Map session list (used for calendar and personalized display)
    public private(set) var savedSessions: [MoodMapSession] = []

    public init() {}

    // MARK: - Mood Map Capture

    /// Start Mood Map capture (open camera)
    public func startMoodMap() {
        guard case .idle = moodMapState else { return }
        moodMapStartedAt = Date()
        moodMapState = .capturing
    }

    /// End Mood Map capture and save session (mood is selected by user in MoodCaptureSheet)
    public func endMoodMap() {
        loadSessionsIfNeeded()
        moodMapState = .idle
        moodMapStartedAt = nil
    }

    /// Cancel the current mood map capture without saving (user dismissed the camera).
    public func cancelMoodMap() {
        moodMapState = .idle
        moodMapStartedAt = nil
    }

    /// Save a mood session directly
    public func saveSession(_ session: MoodMapSession) {
        loadSessionsIfNeeded()
        savedSessions.insert(session, at: 0)
        persistSessions()
    }

    /// Replace `postSessionMood` on the most recently saved session.
    public func updateMostRecentSessionMood(_ mood: QuickMood) {
        loadSessionsIfNeeded()
        guard var first = savedSessions.first else { return }
        first.postSessionMood = mood
        savedSessions[0] = first
        persistSessions()
    }

    /// Load saved sessions from disk if not yet loaded (e.g., when opening Focus tab)
    public func refreshSessionsIfNeeded() {
        loadSessionsIfNeeded()
    }

    /// Flag indicating whether sessions have been loaded
    private var _hasLoadedSessions = false

    /// Load sessions if not yet loaded
    private func loadSessionsIfNeeded() {
        guard !_hasLoadedSessions else { return }
        _hasLoadedSessions = true
        loadSessions()
    }

    /// Load sessions from UserDefaults
    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: moodMapSessionsKey),
              let decoded = try? JSONDecoder().decode([MoodMapSession].self, from: data) else {
            return
        }
        savedSessions = decoded
    }

    /// Persist sessions to UserDefaults
    public func persistSessions() {
        guard let data = try? JSONEncoder().encode(savedSessions) else { return }
        UserDefaults.standard.set(data, forKey: moodMapSessionsKey)
    }

    // MARK: - Calendar / Personalization

    /// Get sessions that ended on the specified date (for calendar emotion display)
    public func sessions(byDate date: Date) -> [MoodMapSession] {
        loadSessionsIfNeeded()
        let cal = Calendar.current
        return savedSessions.filter { cal.isDate($0.endedAt, inSameDayAs: date) }
    }
}

// MARK: - Environment

/// EnvironmentKey for SwiftUI dependency injection
@MainActor
private struct MoodSessionStoreKey: EnvironmentKey {
    static let defaultValue: MoodSessionStore = MoodSessionStore()
}

extension EnvironmentValues {
    /// Read session store Environment value
    var moodSessionStore: MoodSessionStore {
        get { self[MoodSessionStoreKey.self] }
        set { self[MoodSessionStoreKey.self] = newValue }
    }
}
