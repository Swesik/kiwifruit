import Foundation
import Observation
import SwiftUI

enum FocusSessionStatus {
    case idle
    case active
    case paused
    case completed
}

/// Manages the state and timing of a single in-app focus reading session,
/// and syncs session lifecycle events with the backend.
@Observable
@MainActor
final class FocusSessionStore {
    private var timerTask: Task<Void, Never>?
    /// Holds the in-flight POST /reading-sessions task so stopSession can await it
    /// if the user stops before the server has responded.
    private var startSessionTask: Task<ReadingSession?, Never>?

    var status: FocusSessionStatus = .idle
    var elapsedSeconds: Int = 0
    var completedSeconds: Int = 0

    /// The persisted session object returned by the server after starting/joining.
    var currentSession: ReadingSession?
    /// Book title for the active session.
    var bookTitle: String?
    /// Friends who have joined this session (populated from currentSession.participants).
    var participants: [User] { currentSession?.participants ?? [] }
    /// Active sessions from people the current user follows (shown in the "Join" feed).
    var activeFriendSessions: [ActiveFriendSession] = []

    /// True when the current user is the host (started the session).
    /// False when they joined someone else's session.
    private(set) var isHost = true

    // MARK: - Start (own session)

    func startSession(bookTitle: String) {
        cancelTimerTaskIfNeeded()
        cancelStartSessionTask()

        isHost = true
        self.bookTitle = bookTitle
        self.currentSession = nil
        status = .active
        elapsedSeconds = 0

        startTimer()

        // Fire the API call and hold the Task so stopSession can await it if needed.
        startSessionTask = Task {
            do {
                return try await AppAPI.shared.startReadingSession(bookTitle: bookTitle)
            } catch {
                print("FocusSessionStore: startReadingSession failed: \(error)")
                return nil
            }
        }

        Task {
            if let session = await startSessionTask?.value {
                // Only apply if we're still in the same session (not stopped/reset)
                if status == .active || status == .paused {
                    self.currentSession = session
                }
            }
        }
    }

    // MARK: - Pause / Resume

    func togglePause() {
        switch status {
        case .active:  status = .paused
        case .paused:  status = .active
        default: break
        }
    }

    // MARK: - Stop

    func stopSession() {
        cancelTimerTaskIfNeeded()

        completedSeconds = elapsedSeconds
        status = .completed

        let elapsed = elapsedSeconds
        let alreadyKnownSession = currentSession
        let wasHost = isHost
        let inFlightTask = startSessionTask
        startSessionTask = nil

        Task {
            // Wait for the start API call if it's still in flight (race condition: fast stop).
            let session: ReadingSession?
            if let known = alreadyKnownSession {
                session = known
            } else {
                session = await inFlightTask?.value
            }

            guard let sessionId = session?.id else {
                // Server never responded — nothing to clean up remotely.
                return
            }

            do {
                if wasHost {
                    // Host stops → mark the whole session completed and record elapsed time.
                    try await AppAPI.shared.endReadingSession(sessionId: sessionId, elapsedSeconds: elapsed)
                } else {
                    // Participant stops → just leave; the host's session continues.
                    try await AppAPI.shared.leaveReadingSession(sessionId: sessionId)
                }
            } catch {
                print("FocusSessionStore: stopSession remote call failed: \(error)")
            }
        }
    }

    // MARK: - Join (someone else's session)

    func joinSession(_ friendSession: ActiveFriendSession) {
        // Cancel any existing timer before starting a new one.
        cancelTimerTaskIfNeeded()
        cancelStartSessionTask()

        Task {
            do {
                let joined = try await AppAPI.shared.joinReadingSession(sessionId: friendSession.session.id)
                isHost = false
                bookTitle = joined.bookTitle
                currentSession = joined
                // Timer starts at zero — independent of the host's elapsed time.
                status = .active
                elapsedSeconds = 0
                startTimer()
            } catch {
                print("FocusSessionStore: joinReadingSession failed: \(error)")
            }
        }
    }

    // MARK: - Reset after completion screen

    func closeCompletion() {
        status = .idle
        elapsedSeconds = 0
        completedSeconds = 0
        currentSession = nil
        bookTitle = nil
        isHost = true
    }

    // MARK: - Friends feed

    func loadFriendSessions() {
        Task {
            do {
                activeFriendSessions = try await AppAPI.shared.fetchActiveFriendSessions()
            } catch {
                print("FocusSessionStore: fetchActiveFriendSessions failed: \(error)")
            }
        }
    }

    // MARK: - Private helpers

    private func startTimer() {
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { break }
                if status == .active {
                    elapsedSeconds += 1
                }
            }
        }
    }

    private func cancelTimerTaskIfNeeded() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func cancelStartSessionTask() {
        startSessionTask?.cancel()
        startSessionTask = nil
    }
}

private struct FocusSessionStoreKey: EnvironmentKey {
    static let defaultValue: FocusSessionStore = FocusSessionStore()
}

extension EnvironmentValues {
    var focusSessionStore: FocusSessionStore {
        get { self[FocusSessionStoreKey.self] }
        set { self[FocusSessionStoreKey.self] = newValue }
    }
}
