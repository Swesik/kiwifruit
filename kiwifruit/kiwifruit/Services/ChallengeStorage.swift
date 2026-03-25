import Foundation

/// Abstracts persistence of challenge state so ChallengeViewModel
/// does not depend on UserDefaults directly.
protocol ChallengeStorageProtocol: Sendable {
    func loadActiveChallenges() -> [Challenge]
    func loadCompletedChallenges() -> [Challenge]
    func save(active: [Challenge], completed: [Challenge])
}

/// Default implementation backed by UserDefaults.
struct UserDefaultsChallengeStorage: ChallengeStorageProtocol {
    private let activeKey = "kiwifruit.activeChallenges"
    private let completedKey = "kiwifruit.completedChallenges"

    func loadActiveChallenges() -> [Challenge] {
        guard let data = UserDefaults.standard.data(forKey: activeKey) else { return [] }
        return (try? JSONDecoder().decode([Challenge].self, from: data)) ?? []
    }

    func loadCompletedChallenges() -> [Challenge] {
        guard let data = UserDefaults.standard.data(forKey: completedKey) else { return [] }
        return (try? JSONDecoder().decode([Challenge].self, from: data)) ?? []
    }

    func save(active: [Challenge], completed: [Challenge]) {
        let encoder = JSONEncoder()
        if let activeData = try? encoder.encode(active) {
            UserDefaults.standard.set(activeData, forKey: activeKey)
        }
        if let completedData = try? encoder.encode(completed) {
            UserDefaults.standard.set(completedData, forKey: completedKey)
        }
    }
}
