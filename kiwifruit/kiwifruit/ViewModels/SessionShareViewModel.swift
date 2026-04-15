import Foundation
import Observation

/// Owns the "Share this session" flow triggered from the reading-session
/// completion view: asks the server to assemble a summary, publishes it as
/// a feed post, and reports success/failure back to the View.
@Observable
final class SessionShareViewModel {
    var isSharing = false

    private let api: APIClientProtocol

    init(api: APIClientProtocol = AppAPI.shared) {
        self.api = api
    }

    /// Generates the summary for the just-completed session and publishes
    /// it as a feed post. Returns the created post on success, nil on any
    /// failure (network, auth, empty summary).
    @discardableResult
    func shareCompletedSession(
        userId: String,
        bookTitle: String,
        durationSeconds: Int,
        pagesRead: Int?,
        mood: String?
    ) async -> Post? {
        isSharing = true
        defer { isSharing = false }

        let durationMinutes = max(1, durationSeconds / 60)
        do {
            let summary = try await api.generateSessionSummary(
                bookTitle: bookTitle,
                durationMinutes: durationMinutes,
                pagesRead: pagesRead,
                mood: mood
            )
            guard !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return nil
            }
            return try await api.createPost(authorId: userId, imageData: nil, caption: summary)
        } catch {
            print("[SessionShareViewModel] share failed: \(error)")
            return nil
        }
    }
}
