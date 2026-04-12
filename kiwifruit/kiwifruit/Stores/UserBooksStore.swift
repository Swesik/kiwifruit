import Foundation
import Observation
import SwiftUI

/// Local library persisted in UserDefaults.
///
/// **This branch:** only ``RecommendationDetailView`` adds books here (recommendations flow).
/// **After merge:** Varun’s Discover search “ADD” can call the same store—do not duplicate search-row UI here; merge brings it.
@Observable
final class UserBooksStore {
    private(set) var items: [UserBook] = []

    private let persistKey = "kiwifruit.userbooks.v1"

    init(loadSaved: Bool = true) {
        if loadSaved { loadFromDefaults() }
    }

    func add(_ book: UserBook) {
        if let isbn = book.isbn13, !isbn.isEmpty {
            if items.contains(where: { $0.isbn13 == isbn }) { return }
        } else {
            if items.contains(where: { $0.title == book.title && $0.authors == book.authors }) { return }
        }
        items.insert(book, at: 0)
        saveToDefaults()
    }

    func remove(id: String) {
        items.removeAll { $0.id == id }
        saveToDefaults()
    }

    func reset() {
        items = []
        UserDefaults.standard.removeObject(forKey: persistKey)
    }

    private func saveToDefaults() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: persistKey)
        } catch {
            print("UserBooksStore: failed to encode items: \(error)")
        }
    }

    private func loadFromDefaults() {
        guard let data = UserDefaults.standard.data(forKey: persistKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([UserBook].self, from: data)
            items = decoded
        } catch {
            print("UserBooksStore: failed to decode saved items: \(error)")
        }
    }
}

private struct UserBooksStoreKey: EnvironmentKey {
    static let defaultValue = UserBooksStore()
}

extension EnvironmentValues {
    var userBooksStore: UserBooksStore {
        get { self[UserBooksStoreKey.self] }
        set { self[UserBooksStoreKey.self] = newValue }
    }
}
