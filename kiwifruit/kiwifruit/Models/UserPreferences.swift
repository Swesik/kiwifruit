import Foundation

struct UserPreferences: Codable, Equatable {
    var dailyGoalMinutes: Int
    /// Preferred book genres for the recommendation system (e.g. ["Fantasy", "Sci-Fi"]).
    var preferredGenres: [String]

    static let `default` = UserPreferences(
        dailyGoalMinutes: 30,
        preferredGenres: []
    )
}
