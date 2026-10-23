import Foundation
import Observation
import SwiftUI

/// Observable store exposing user preferences to SwiftUI views.
@Observable
final class UserPreferencesStore {
    private let storageKey = "kiwifruit.userPreferences"

    /// Daily reading goal, in minutes.
    var dailyGoalMinutes: Int = UserPreferences().dailyGoalMinutes
    /// Preferred genres for the recommendation system.
    var preferredGenres: [String] = UserPreferences().preferredGenres
    /// Speed reading words per minute.
    var speedReadingWpm: Int = UserPreferences().speedReadingWpm
    /// Words shown per segment during speed reading (1–7).
    var wordsPerSegment: Int = UserPreferences().wordsPerSegment

    init() {
        loadFromLocalStorage()
    }

    /// Loads preferences from this device.
    func load() async {
        loadFromLocalStorage()
    }

    /// Updates preferences and persists them on this device.
    func update(dailyGoal: Int, genres: [String]) async {
        dailyGoalMinutes = dailyGoal
        preferredGenres = genres
        await save()
    }

    /// Persists all current preference values on this device.
    func save() async {
        let prefs = UserPreferences(
            dailyGoalMinutes: dailyGoalMinutes,
            preferredGenres: preferredGenres,
            speedReadingWpm: speedReadingWpm,
            wordsPerSegment: wordsPerSegment
        )
        guard let data = try? JSONEncoder().encode(prefs) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func loadFromLocalStorage() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let prefs = try? JSONDecoder().decode(UserPreferences.self, from: data) else { return }
        dailyGoalMinutes = prefs.dailyGoalMinutes
        preferredGenres = prefs.preferredGenres
        speedReadingWpm = prefs.speedReadingWpm
        wordsPerSegment = prefs.wordsPerSegment
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
