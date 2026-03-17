import Foundation
import Observation
import SwiftUI

/// Abstraction for loading and saving user preferences from a backing store.
protocol UserPreferencesRepository {
    func load() async throws -> UserPreferences
    func save(_ preferences: UserPreferences) async throws
}

/// User preferences repository backed by UserDefaults.
struct UserDefaultsUserPreferencesRepository: UserPreferencesRepository {
    private let defaults: UserDefaults
    private let defaultSessionLengthKey = "kiwifruit.preferences.defaultSessionLengthMinutes"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Loads preferences from UserDefaults, falling back to the global default.
    func load() async throws -> UserPreferences {
        let storedMinutes = defaults.integer(forKey: defaultSessionLengthKey)
        if storedMinutes <= 0 {
            return .default
        }
        return UserPreferences(defaultSessionLengthMinutes: storedMinutes)
    }

    /// Persists the given preferences to UserDefaults.
    func save(_ preferences: UserPreferences) async throws {
        defaults.set(preferences.defaultSessionLengthMinutes, forKey: defaultSessionLengthKey)
    }
}

/// Observable store exposing user preferences to SwiftUI views.
@Observable
@MainActor
final class UserPreferencesStore {
    private let repository: any UserPreferencesRepository

    /// Default reading session length, in minutes.
    var defaultSessionLengthMinutes: Int

    /// Creates a store with the given repository and kicks off an async load.
    init(repository: some UserPreferencesRepository) {
        self.repository = repository
        self.defaultSessionLengthMinutes = UserPreferences.default.defaultSessionLengthMinutes

        Task {
            await load()
        }
    }

    /// Loads preferences from the repository and applies them to the store.
    func load() async {
        do {
            let loaded = try await repository.load()
            apply(loaded)
        } catch {
        }
    }

    /// Updates the default session length and persists the change.
    func updateDefaultSessionLength(_ minutes: Int) async {
        defaultSessionLengthMinutes = minutes
        let preferences = UserPreferences(defaultSessionLengthMinutes: minutes)

        do {
            try await repository.save(preferences)
        } catch {
        }
    }

    private func apply(_ preferences: UserPreferences) {
        defaultSessionLengthMinutes = preferences.defaultSessionLengthMinutes
    }
}

/// Environment key used to inject a shared UserPreferencesStore.
private struct UserPreferencesStoreKey: EnvironmentKey {
    static let defaultValue = UserPreferencesStore(
        repository: UserDefaultsUserPreferencesRepository()
    )
}

extension EnvironmentValues {
    /// Shared user preferences store available in the SwiftUI environment.
    var userPreferencesStore: UserPreferencesStore {
        get { self[UserPreferencesStoreKey.self] }
        set { self[UserPreferencesStoreKey.self] = newValue }
    }
}


