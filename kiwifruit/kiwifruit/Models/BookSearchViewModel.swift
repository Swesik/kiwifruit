
import Foundation
import Observation

@Observable
final class BookSearchViewModel {
    var query: String = ""
    var results: [BookSearchResult] = []
    var isSearching: Bool = false
    var errorMessage: String?

    private let api: APIClientProtocol

    init(api: APIClientProtocol) {
        self.api = api
    }

    func submit() async {
        // Swift 6.2: @Observable types are main-actor isolated by default.
        // Rely on that implicit isolation instead of explicit actor hops.
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        do {
            results = try await api.searchBooks(query: query)
        } catch {
            results = []
            errorMessage = "Failed to search books."
        }
    }
}
