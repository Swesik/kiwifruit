import Foundation
import Observation
import SwiftUI

enum FocusSessionStatus {
    case idle
    case active
    case paused
    case completed
}

/// Manages the state and timing of a single in-app focus reading session.
@Observable
@MainActor
final class ReadingSessionStore {
    private var timerTask: Task<Void, Never>?

    var status: FocusSessionStatus = .idle
    var elapsedSeconds: Int = 0
    var completedSeconds: Int = 0

    func startSession() {
        cancelTimerTaskIfNeeded()

        status = .active
        elapsedSeconds = 0

        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))

                if Task.isCancelled {
                    break
                }

                if status == .active {
                    elapsedSeconds += 1
                }
            }
        }
    }

    func togglePause() {
        switch status {
        case .active:
            status = .paused
        case .paused:
            status = .active
        default:
            break
        }
    }

    func stopSession() {
        cancelTimerTaskIfNeeded()

        completedSeconds = elapsedSeconds
        status = .completed
    }

    func closeCompletion() {
        status = .idle
        elapsedSeconds = 0
        completedSeconds = 0
    }

    private func cancelTimerTaskIfNeeded() {
        timerTask?.cancel()
        timerTask = nil
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

