import Foundation
import Observation
import SwiftUI

@Observable @MainActor
final class RecommendationsStore {
    private(set) var items: [Recommendation] = []
    private(set) var isLoading = false
    private(set) var lastError: Error?

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            items = try await AppAPI.shared.fetchRecommendations()
        } catch {
            lastError = error
            print("RecommendationsStore.load failed: \(error)")
        }
    }
}

private struct RecommendationsStoreKey: EnvironmentKey {
    static let defaultValue: RecommendationsStore = RecommendationsStore()
}

extension EnvironmentValues {
    var recommendationsStore: RecommendationsStore {
        get { self[RecommendationsStoreKey.self] }
        set { self[RecommendationsStoreKey.self] = newValue }
    }
}

