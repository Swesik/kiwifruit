import Foundation

struct UserPreferences: Codable, Equatable {
    var dailyGoalMinutes: Int = 30
    /// Preferred book genres for the recommendation system (e.g. ["Fantasy", "Sci-Fi"]).
    var preferredGenres: [String] = []
    /// Speed reading words per minute (must be > 0).
    var speedReadingWpm: Int = 240
    /// Number of words shown per segment during speed reading (1–7).
    var wordsPerSegment: Int = 1
}
