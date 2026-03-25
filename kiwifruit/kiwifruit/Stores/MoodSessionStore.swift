import Foundation
import Observation
import SwiftUI

/// Abstracts persistence of mood map sessions so MoodSessionStore
/// does not depend on UserDefaults directly.
public protocol MoodSessionStorageProtocol: Sendable {
    func loadSessions() -> [MoodMapSession]
    func saveSessions(_ sessions: [MoodMapSession])
}

/// Default implementation backed by UserDefaults.
public struct UserDefaultsMoodSessionStorage: MoodSessionStorageProtocol {
    public init() {}

    private let key = "kiwifruit.moodmap.sessions"

    public func loadSessions() -> [MoodMapSession] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([MoodMapSession].self, from: data) else {
            return []
        }
        return decoded
    }

    public func saveSessions(_ sessions: [MoodMapSession]) {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

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

    private let storage: MoodSessionStorageProtocol

    public init(storage: MoodSessionStorageProtocol = UserDefaultsMoodSessionStorage()) {
        self.storage = storage
    }

    // MARK: - Mood Map Capture

    /// Start Mood Map capture (open camera)
    public func startMoodMap() {
        guard case .idle = moodMapState else { return }
        moodMapStartedAt = Date()
        moodMapState = .capturing
    }

    /// End Mood Map capture and save session (mood is selected by user in MoodCaptureSheet)
    public func endMoodMap() {
        guard let startedAt = moodMapStartedAt else {
            moodMapState = .idle
            moodMapStartedAt = nil
            return
        }
        loadSessionsIfNeeded()
        let session = MoodMapSession(
            startedAt: startedAt,
            endedAt: Date(),
            postSessionMood: nil
        )
        savedSessions.insert(session, at: 0)
        persistSessions()
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

    // MARK: - Calendar / Personalization

    /// Get sessions that ended on the specified date (for calendar emotion display)
    public func sessions(byDate date: Date) -> [MoodMapSession] {
        loadSessionsIfNeeded()
        let cal = Calendar.current
        return savedSessions.filter { cal.isDate($0.endedAt, inSameDayAs: date) }
    }

    // MARK: - Private

    private var _hasLoadedSessions = false

    private func loadSessionsIfNeeded() {
        guard !_hasLoadedSessions else { return }
        _hasLoadedSessions = true
        savedSessions = storage.loadSessions()
    }

    private func persistSessions() {
        storage.saveSessions(savedSessions)
    }
}

// MARK: - Environment

@MainActor
private struct MoodSessionStoreKey: EnvironmentKey {
    static let defaultValue: MoodSessionStore = MoodSessionStore()
}

extension EnvironmentValues {
    var moodSessionStore: MoodSessionStore {
        get { self[MoodSessionStoreKey.self] }
        set { self[MoodSessionStoreKey.self] = newValue }
    }
}
