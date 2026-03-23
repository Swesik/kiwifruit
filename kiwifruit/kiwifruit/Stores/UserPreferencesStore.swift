import Foundation
import Observation
import SwiftUI

/// Observable store exposing user preferences to SwiftUI views.
@Observable
@MainActor
final class UserPreferencesStore {
    /// Default reading session length, in minutes.
    var defaultSessionLengthMinutes: Int = UserPreferences.default.defaultSessionLengthMinutes
    /// Daily reading goal, in minutes.
    var dailyGoalMinutes: Int = UserPreferences.default.dailyGoalMinutes
    /// Preferred genres for the recommendation system.
    var preferredGenres: [String] = UserPreferences.default.preferredGenres

    /// Loads preferences from the server. Falls back silently on error.
    func load() async {
        do {
            let loaded = try await AppAPI.shared.fetchPreferences()
            defaultSessionLengthMinutes = loaded.defaultSessionLengthMinutes
            dailyGoalMinutes = loaded.dailyGoalMinutes
            preferredGenres = loaded.preferredGenres
        } catch {
            print("[UserPreferencesStore] load failed: \(error)")
        }
    }

    /// Updates preferences and persists them to the server.
    func update(sessionLength: Int, dailyGoal: Int, genres: [String]) async {
        defaultSessionLengthMinutes = sessionLength
        dailyGoalMinutes = dailyGoal
        preferredGenres = genres
        let prefs = UserPreferences(
            defaultSessionLengthMinutes: sessionLength,
            dailyGoalMinutes: dailyGoal,
            preferredGenres: genres
        )
        do {
            try await AppAPI.shared.savePreferences(prefs)
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
