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
final class ReadingSessionStore {
    private let api: APIClientProtocol
    private var timerTask: Task<Void, Never>?
    /// Holds the in-flight POST /reading-sessions task so stopSession can await it
    /// if the user stops before the server has responded.
    private var startSessionTask: Task<ReadingSession?, Never>?
    
    /// Optional callback triggered when a session completes successfully (for refreshing recommendations, etc.)
    var onSessionCompleted: (() -> Void)?

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

    /// Page the user was on when they started the session.
    var startingPage: Int? = nil
    /// Pages read this session, set after the user inputs their ending page on stop.
    private(set) var completedPagesRead: Int? = nil
    /// Set if the stop/leave API call fails so the UI can show an error alert.
    var saveError: String? = nil

    init(api: APIClientProtocol = AppAPI.shared) {
        self.api = api
    }

    // MARK: - Start (own session)

    func startSession(bookTitle: String, startingPage: Int? = nil) {
        cancelTimerTaskIfNeeded()
        cancelStartSessionTask()

        isHost = true
        self.bookTitle = bookTitle
        self.startingPage = startingPage
        self.currentSession = nil
        status = .active
        elapsedSeconds = 0

        startTimer()

        // Fire the API call and hold the Task so stopSession can await it if needed.
        startSessionTask = Task {
            do {
                return try await api.startReadingSession(bookTitle: bookTitle)
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
        case .active:
            status = .paused
            if isHost, let sessionId = currentSession?.id {
                Task {
                    do { try await api.pauseReadingSession(sessionId: sessionId) }
                    catch { print("ReadingSessionStore: pauseReadingSession failed: \(error)") }
                }
            }
        case .paused:
            status = .active
            if isHost, let sessionId = currentSession?.id {
                Task {
                    do { try await api.resumeReadingSession(sessionId: sessionId) }
                    catch { print("ReadingSessionStore: resumeReadingSession failed: \(error)") }
                }
            }
        default: break
        }
    }

    // MARK: - Stop

    func stopSession(endingPage: Int? = nil) {
        cancelTimerTaskIfNeeded()

        completedSeconds = elapsedSeconds
        status = .completed

        let capturedElapsed = elapsedSeconds
        let pagesRead: Int?
        if let end = endingPage, let start = startingPage, end > start {
            pagesRead = end - start
        } else {
            pagesRead = nil
        }
        completedPagesRead = pagesRead

        let alreadyKnownSession = currentSession
        let wasHost = isHost
        let capturedBookTitle = bookTitle
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
                    try await api.endReadingSession(sessionId: sessionId, pagesRead: pagesRead)
                } else {
                    // Send the joiner's own book title so session_history records what they read.
                    try await api.leaveReadingSession(sessionId: sessionId, elapsedSeconds: capturedElapsed, pagesRead: pagesRead, bookTitle: capturedBookTitle)
                }
                
                // Session saved successfully — trigger refresh of recommendations
                // (new reading session affects behavioral signals)
                onSessionCompleted?()
                
            } catch {
                print("FocusSessionStore: stopSession remote call failed: \(error)")
                saveError = "Your session couldn't be saved. Please check your connection and try again."
            }
        }
    }

    // MARK: - Join (someone else's session)

    func joinSession(_ friendSession: ActiveFriendSession, bookTitle: String? = nil, startingPage: Int? = nil) {
        // Cancel any existing timer before starting a new one.
        cancelTimerTaskIfNeeded()
        cancelStartSessionTask()

        self.startingPage = startingPage

        Task {
            do {
                let joined = try await api.joinReadingSession(sessionId: friendSession.session.id)
                isHost = false
                // Use the user's own book title if provided; fall back to the session's book.
                self.bookTitle = bookTitle ?? joined.bookTitle
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
        startingPage = nil
        completedPagesRead = nil
        saveError = nil
    }

    // MARK: - Friends feed

    func loadFriendSessions() {
        Task {
            do {
                activeFriendSessions = try await api.fetchActiveFriendSessions()
            } catch {
                print("FocusSessionStore: fetchActiveFriendSessions failed: \(error)")
            }
        }
    }

    // MARK: - Validation helpers

    func canStartSession(bookTitle: String, startingPage: String) -> Bool {
        !bookTitle.trimmingCharacters(in: .whitespaces).isEmpty
            && Int(startingPage.trimmingCharacters(in: .whitespaces)) != nil
    }

    func canJoinSession(bookTitle: String, startingPage: String) -> Bool {
        canStartSession(bookTitle: bookTitle, startingPage: startingPage)
    }

    func canSubmitEndPage(_ endingPage: String) -> Bool {
        guard let end = Int(endingPage.trimmingCharacters(in: .whitespaces)) else { return false }
        if let start = startingPage { return end > start }
        return true
    }

    func otherParticipants(currentUserId: String?) -> [User] {
        let joiners = participants.filter { $0.id != currentUserId }
        if isHost { return joiners }
        if let host = currentSession?.host { return [host] + joiners }
        return joiners
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

private struct ReadingSessionStoreKey: EnvironmentKey {
    static let defaultValue: ReadingSessionStore = ReadingSessionStore()
}

extension EnvironmentValues {
    var readingSessionStore: ReadingSessionStore {
        get { self[ReadingSessionStoreKey.self] }
        set { self[ReadingSessionStoreKey.self] = newValue }
    }
}
