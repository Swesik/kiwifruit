import Foundation
import Observation
import SwiftUI

/// Observable store exposing user preferences to SwiftUI views.
@Observable
final class UserPreferencesStore {
    private let api: APIClientProtocol

    /// Daily reading goal, in minutes.
    var dailyGoalMinutes: Int = UserPreferences().dailyGoalMinutes
    /// Preferred genres for the recommendation system.
    var preferredGenres: [String] = UserPreferences().preferredGenres
    /// Speed reading words per minute.
    var speedReadingWpm: Int = UserPreferences().speedReadingWpm
    /// Words shown per segment during speed reading (1–7).
    var wordsPerSegment: Int = UserPreferences().wordsPerSegment

    init(api: APIClientProtocol = AppAPI.shared) {
        self.api = api
    }

    /// Loads preferences from the server. Falls back silently on error.
    func load() async {
        do {
            let loaded = try await api.fetchPreferences()
            dailyGoalMinutes = loaded.dailyGoalMinutes
            preferredGenres = loaded.preferredGenres
            speedReadingWpm = loaded.speedReadingWpm
            wordsPerSegment = loaded.wordsPerSegment
        } catch {
            print("[UserPreferencesStore] load failed: \(error)")
        }
    }

    /// Updates preferences and persists them to the server.
    func update(dailyGoal: Int, genres: [String]) async {
        dailyGoalMinutes = dailyGoal
        preferredGenres = genres
        await save()
    }

    /// Persists all current preference values to the server.
    func save() async {
        let prefs = UserPreferences(
            dailyGoalMinutes: dailyGoalMinutes,
            preferredGenres: preferredGenres,
            speedReadingWpm: speedReadingWpm,
            wordsPerSegment: wordsPerSegment
        )
        do {
            try await api.savePreferences(prefs)
        } catch {
            print("[UserPreferencesStore] save failed: \(error)")
        }
    }
}

private struct UserPreferencesStoreKey: EnvironmentKey {
    static let defaultValue = UserPreferencesStore()
}

extension EnvironmentValues {
    var userPreferencesStore: UserPreferencesStore {
        get { self[UserPreferencesStoreKey.self] }
        set { self[UserPreferencesStoreKey.self] = newValue }
    }
}
