import Foundation

struct UserPreferences: Codable, Equatable {
    var defaultSessionLengthMinutes: Int
    var dailyGoalMinutes: Int
    /// Preferred book genres for the recommendation system (e.g. ["Fantasy", "Sci-Fi"]).
    var preferredGenres: [String]

    static let `default` = UserPreferences(
        defaultSessionLengthMinutes: 30,
        dailyGoalMinutes: 30,
        preferredGenres: []
    )
}
