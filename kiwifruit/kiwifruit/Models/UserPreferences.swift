import Foundation

struct UserPreferences: Codable, Equatable {
    var dailyGoalMinutes: Int = 30
    /// Preferred book genres for the recommendation system (e.g. ["Fantasy", "Sci-Fi"]).
    var preferredGenres: [String] = []
    /// Speed reading words per minute (must be > 0).
    var speedReadingWpm: Int = 240
    /// Number of words shown per segment during speed reading (1–7).
    var wordsPerSegment: Int = 1
    /// Seconds to seek when double tapping during speed reading.
    var doubleTapSeekSeconds: Int = 5

    init(
        dailyGoalMinutes: Int = 30,
        preferredGenres: [String] = [],
        speedReadingWpm: Int = 240,
        wordsPerSegment: Int = 1,
        doubleTapSeekSeconds: Int = 5
    ) {
        self.dailyGoalMinutes = dailyGoalMinutes
        self.preferredGenres = preferredGenres
        self.speedReadingWpm = speedReadingWpm
        self.wordsPerSegment = wordsPerSegment
        self.doubleTapSeekSeconds = doubleTapSeekSeconds
    }

    private enum CodingKeys: String, CodingKey {
        case dailyGoalMinutes, preferredGenres, speedReadingWpm, wordsPerSegment, doubleTapSeekSeconds
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        dailyGoalMinutes = try values.decodeIfPresent(Int.self, forKey: .dailyGoalMinutes) ?? 30
        preferredGenres = try values.decodeIfPresent([String].self, forKey: .preferredGenres) ?? []
        speedReadingWpm = try values.decodeIfPresent(Int.self, forKey: .speedReadingWpm) ?? 240
        wordsPerSegment = try values.decodeIfPresent(Int.self, forKey: .wordsPerSegment) ?? 1
        doubleTapSeekSeconds = try values.decodeIfPresent(Int.self, forKey: .doubleTapSeekSeconds) ?? 5
    }
}
