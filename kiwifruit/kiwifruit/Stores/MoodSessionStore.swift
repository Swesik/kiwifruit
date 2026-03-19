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

    /// CV emotion samples collected during current capture
    public private(set) var currentCvSamples: [MoodSample] = []

    /// Emotion recognized from facial recognition after last capture (shown in results); cleared when user dismisses
    public private(set) var lastRecognizedMood: QuickMood?

    /// Saved Mood Map session list (used for calendar and personalized display)
    public private(set) var savedSessions: [MoodMapSession] = []

    public init() {}

    // MARK: - Mood Map Capture

    /// Start Mood Map capture (open camera)
    public func startMoodMap() {
        guard case .idle = moodMapState else { return }
        moodMapStartedAt = Date()
        currentCvSamples = []
        moodMapState = .capturing
    }

    /// End Mood Map capture: aggregate facial recognition into a QuickMood, save session, set lastRecognizedMood for UI
    public func endMoodMap() {
        loadSessionsIfNeeded()
        guard case .capturing = moodMapState,
              let started = moodMapStartedAt else { return }
        let ended = Date()
        
        // Aggregate samples to get final emotion
        let recognized = aggregateSamplesToQuickMood(currentCvSamples)
        
        // Create new session
        let session = MoodMapSession(
            startedAt: started,
            endedAt: ended,
            cvSamples: currentCvSamples,
            postSessionMood: recognized
        )
        
        // Save to beginning of list
        savedSessions.insert(session, at: 0)
        persistSessions()
        
        // Set result emotion
        lastRecognizedMood = recognized
        moodMapState = .idle
        moodMapStartedAt = nil
        currentCvSamples = []
    }

    /// Append a CV emotion sample (called by camera/Vision service during capture)
    public func appendCvSample(_ sample: MoodSample) {
        currentCvSamples.append(sample)
    }

    /// Clear lastRecognizedMood when user dismisses results
    public func clearLastRecognizedMood() {
        lastRecognizedMood = nil
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
    private func persistSessions() {
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
