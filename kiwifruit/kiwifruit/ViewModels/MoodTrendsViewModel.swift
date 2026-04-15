import Foundation
import Observation

/// Surfaces the server's mood-trend signal (declining / improving / stable)
/// for the "gentle nudge" banner. Generates a fresh nudge on every new
/// session. Dismissing just hides the current banner — the next session
/// that lands earns a fresh assessment.
@Observable
final class MoodTrendsViewModel {
    var suggestion: String? = nil
    var trend: String? = nil

    /// Transient flag: applies to whatever `suggestion` is currently held.
    /// A fresh fetch (new session) resets this so the new nudge can surface.
    private var isDismissed = false

    private var lastFetchedSessionCount: Int? = nil
    private let api: APIClientProtocol

    init(api: APIClientProtocol = AppAPI.shared) {
        self.api = api
    }

    /// Server already withholds a suggestion unless the trend is declining,
    /// so a non-empty suggestion implies declining.
    var shouldShowBanner: Bool {
        guard let suggestion, !suggestion.isEmpty else { return false }
        return !isDismissed
    }

    /// Fetches a fresh nudge only when the session-history count changed
    /// since our last look — i.e. a new session landed. Re-enables the
    /// banner if the user had dismissed the previous nudge, since this
    /// assessment is a new one.
    func loadIfNewSession(sessionCount: Int, days: Int = 14) async {
        if let last = lastFetchedSessionCount, last == sessionCount { return }
        lastFetchedSessionCount = sessionCount
        isDismissed = false

        do {
            let resp = try await api.fetchMoodTrends(days: days)
            trend = resp.trend
            suggestion = resp.suggestion
        } catch {
            print("[MoodTrendsViewModel] fetchMoodTrends failed: \(error)")
        }
    }

    func dismissBanner() {
        isDismissed = true
    }
}
