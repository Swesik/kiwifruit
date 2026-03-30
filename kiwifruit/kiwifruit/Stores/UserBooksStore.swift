import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class UserBooksStore {
    private(set) var items: [UserBook] = []

    private let persistKey = "kiwifruit.userbooks.v1"

    init(loadSaved: Bool = true) {
        if loadSaved { loadFromDefaults() }
    }

    func add(_ book: UserBook) {
        // Prevent duplicates by isbn if available, otherwise by title+authors
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
