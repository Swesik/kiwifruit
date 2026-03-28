import Foundation

struct UserPreferences: Codable, Equatable {
    var dailyGoalMinutes: Int
    /// Preferred book genres for the recommendation system (e.g. ["Fantasy", "Sci-Fi"]).
    var preferredGenres: [String]

    init(dailyGoalMinutes: Int = 30, preferredGenres: [String] = []) {
        self.dailyGoalMinutes = dailyGoalMinutes
        self.preferredGenres = preferredGenres
    }
}
