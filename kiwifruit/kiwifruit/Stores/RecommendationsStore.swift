import Foundation
import Observation
import SwiftUI

/// Loads Discover-tab recommendations from ``GET /recommendations``.
@Observable
final class RecommendationsStore {
    private let api: APIClientProtocol
    private(set) var items: [BookRecommendation] = []
    private(set) var isLoading = false
    private(set) var loadError: String?

    init(api: APIClientProtocol = AppAPI.shared) {
        self.api = api
    }

    /// SwiftUI previews: seed rows without depending on ``AppAPI`` / ``SessionStore``.
    static func previewPopulated() -> RecommendationsStore {
        let store = RecommendationsStore()
        store.items = [
            BookRecommendation(
                bookId: 1,
                title: BookRecommendationMockAssets.titles[0],
                author: BookRecommendationMockAssets.authors[0],
                coverUrl: BookRecommendationMockAssets.coverUrl(forMockIndex: 0)
            ),
            BookRecommendation(
                bookId: 2,
                title: BookRecommendationMockAssets.titles[1],
                author: BookRecommendationMockAssets.authors[1],
                coverUrl: BookRecommendationMockAssets.coverUrl(forMockIndex: 1)
            ),
        ]
        return store
    }

    /// Clears cached rows (e.g. on logout).
    func reset() {
        items = []
        loadError = nil
    }

    /// Fetches up to ``limit`` recommendations (default 8).
    func load(limit: Int = 8) async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let fetched = try await api.fetchRecommendations(limit: limit)
            items = fetched
        } catch {
            loadError = "Could not load recommendations."
            print("RecommendationsStore: load failed: \(error)")
        }
    }
}

private struct RecommendationsStoreKey: EnvironmentKey {
    static let defaultValue = RecommendationsStore()
}

extension EnvironmentValues {
    var recommendationsStore: RecommendationsStore {
        get { self[RecommendationsStoreKey.self] }
        set { self[RecommendationsStoreKey.self] = newValue }
    }
}
