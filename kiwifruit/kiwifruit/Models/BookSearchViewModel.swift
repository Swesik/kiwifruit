
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
        // Ensure UI state changes happen on the main thread without annotating the whole class.
        DispatchQueue.main.async { [weak self] in
            self?.isSearching = true
            self?.errorMessage = nil
        }
        defer {
            DispatchQueue.main.async { [weak self] in self?.isSearching = false }
        }

        do {
            let fetched = try await api.searchBooks(query: query)
            DispatchQueue.main.async { [weak self] in
                self?.results = fetched
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Failed to search books."
            }
        }
    }
}
