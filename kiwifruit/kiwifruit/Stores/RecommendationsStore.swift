import Foundation
import Observation
import SwiftUI

/// Loads Discover-tab recommendations from ``GET /recommendations``.
@Observable @MainActor
final class RecommendationsStore {
    private(set) var items: [BookRecommendation] = []
    private(set) var isLoading = false
    private(set) var loadError: String?

    /// SwiftUI previews: seed rows without depending on ``AppAPI`` / ``SessionStore``.
    static func previewPopulated() -> RecommendationsStore {
        let store = RecommendationsStore()
        store.items = [
            BookRecommendation(bookId: 1, title: "Preview Apple", author: "Alex Author", coverUrl: "https://images.unsplash.com/photo-1544947950-fa07a98d237f?auto=format&fit=crop&q=80&w=200&h=300"),
            BookRecommendation(bookId: 2, title: "Preview Birch", author: "Blake Booker", coverUrl: "https://images.unsplash.com/photo-1589829085413-56de8ae18c73?auto=format&fit=crop&q=80&w=200&h=300"),
        ]
        return store
    }

    /// Clears cached rows (e.g. on logout).
    func reset() {
        items = []
        loadError = nil
    }

    /// Fetches up to ``limit`` recommendations (default 8). Skips network if data exists unless ``force``.
    func load(limit: Int = 8, force: Bool = false) async {
        if !items.isEmpty && !force { return }
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let fetched = try await AppAPI.shared.fetchRecommendations(limit: limit)
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
