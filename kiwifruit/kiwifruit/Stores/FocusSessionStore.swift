import Foundation
import Observation
import SwiftUI

enum FocusSessionStatus {
    case idle
    case active
    case paused
    case completed
}

@Observable
@MainActor
final class FocusSessionStore {
    private var timerTask: Task<Void, Never>?

    var status: FocusSessionStatus = .idle
    var elapsedSeconds: Int = 0
    var completedSeconds: Int = 0

    func startSession() {
        cancelTimerTaskIfNeeded()

        status = .active
        elapsedSeconds = 0

        timerTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))

                if Task.isCancelled {
                    break
                }

                if self.status == .active {
                    self.elapsedSeconds += 1
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

private struct FocusSessionStoreKey: EnvironmentKey {
    static let defaultValue: FocusSessionStore = FocusSessionStore()
}

extension EnvironmentValues {
    var focusSessionStore: FocusSessionStore {
        get { self[FocusSessionStoreKey.self] }
        set { self[FocusSessionStoreKey.self] = newValue }
    }
}

