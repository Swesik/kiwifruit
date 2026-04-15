import Foundation

/// Abstracts persistence of challenge state so ChallengeViewModel
/// does not depend on UserDefaults directly.
protocol ChallengeStorageProtocol: Sendable {
    func loadActiveChallenges() -> [Challenge]
    func loadCompletedChallenges() -> [Challenge]
    func save(active: [Challenge], completed: [Challenge])
    func loadCachedWeatherChallenge() -> (challenge: Challenge, fetchedAt: Date)?
    func saveCachedWeatherChallenge(_ challenge: Challenge?, fetchedAt: Date)
}

/// Default implementation backed by UserDefaults.
struct UserDefaultsChallengeStorage: ChallengeStorageProtocol {
    private let activeKey = "kiwifruit.activeChallenges"
    private let completedKey = "kiwifruit.completedChallenges"
    private let weatherKey = "kiwifruit.cachedWeatherChallenge"

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

    private struct WeatherCacheEnvelope: Codable {
        let challenge: Challenge
        let fetchedAt: Date
    }

    func loadCachedWeatherChallenge() -> (challenge: Challenge, fetchedAt: Date)? {
        guard let data = UserDefaults.standard.data(forKey: weatherKey),
              let env = try? JSONDecoder().decode(WeatherCacheEnvelope.self, from: data) else {
            return nil
        }
        return (env.challenge, env.fetchedAt)
    }

    func saveCachedWeatherChallenge(_ challenge: Challenge?, fetchedAt: Date) {
        guard let challenge else {
            UserDefaults.standard.removeObject(forKey: weatherKey)
            return
        }
        let env = WeatherCacheEnvelope(challenge: challenge, fetchedAt: fetchedAt)
        if let data = try? JSONEncoder().encode(env) {
            UserDefaults.standard.set(data, forKey: weatherKey)
        }
    }
}
