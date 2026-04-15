import Foundation

struct UserPreferences: Codable, Equatable {
    var dailyGoalMinutes: Int
    /// Preferred book genres for the recommendation system (e.g. ["Fantasy", "Sci-Fi"]).
    var preferredGenres: [String]
    /// Speed reading words per minute (must be > 0).
    var speedReadingWpm: Int
    /// Number of words shown per segment during speed reading (1–7).
    var wordsPerSegment: Int

    init(
        dailyGoalMinutes: Int = 30,
        preferredGenres: [String] = [],
        speedReadingWpm: Int = 240,
        wordsPerSegment: Int = 1
    ) {
        self.dailyGoalMinutes = dailyGoalMinutes
        self.preferredGenres = preferredGenres
        self.speedReadingWpm = speedReadingWpm
        self.wordsPerSegment = wordsPerSegment
    }
}
