import Foundation
import Observation
import SwiftUI

/// Observable store exposing user preferences to SwiftUI views.
@Observable
@MainActor
final class UserPreferencesStore {
    private let api: APIClientProtocol

    /// Daily reading goal, in minutes.
    var dailyGoalMinutes: Int = UserPreferences.default.dailyGoalMinutes
    /// Preferred genres for the recommendation system.
    var preferredGenres: [String] = UserPreferences.default.preferredGenres

    init(api: APIClientProtocol = AppAPI.shared) {
        self.api = api
    }

    /// Loads preferences from the server. Falls back silently on error.
    func load() async {
        do {
            let loaded = try await api.fetchPreferences()
            dailyGoalMinutes = loaded.dailyGoalMinutes
            preferredGenres = loaded.preferredGenres
        } catch {
            print("[UserPreferencesStore] load failed: \(error)")
        }
    }

    /// Updates preferences and persists them to the server.
    func update(dailyGoal: Int, genres: [String]) async {
        dailyGoalMinutes = dailyGoal
        preferredGenres = genres
        let prefs = UserPreferences(
            dailyGoalMinutes: dailyGoal,
            preferredGenres: genres
        )
        do {
            try await api.savePreferences(prefs)
        } catch {
            print("[UserPreferencesStore] update failed: \(error)")
        }
    }
}

@MainActor
private struct UserPreferencesStoreKey: EnvironmentKey {
    static let defaultValue = UserPreferencesStore()
}

extension EnvironmentValues {
    @MainActor var userPreferencesStore: UserPreferencesStore {
        get { self[UserPreferencesStoreKey.self] }
        set { self[UserPreferencesStoreKey.self] = newValue }
    }
}
