import Foundation

enum ChallengeState: String, Codable {
    case available
    case accepted
    case completed
}

struct RecommendedConditions: Codable, Equatable {
    var weather: String?
    var minTemperature: Double?
    var maxTemperature: Double?
    var timeOfDay: String?

    init(weather: String? = nil, minTemperature: Double? = nil, maxTemperature: Double? = nil, timeOfDay: String? = nil) {
        self.weather = weather
        self.minTemperature = minTemperature
        self.maxTemperature = maxTemperature
        self.timeOfDay = timeOfDay
    }
}

struct Challenge: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var description: String
    var category: String
    var difficulty: Int
    var progress: Double
    var rewardXP: Int
    var recommendedConditions: RecommendedConditions?
    var hint: String?
    var state: ChallengeState
    var recommendationExplanation: String?

    init(id: UUID = UUID(), title: String, description: String, category: String = "general", difficulty: Int = 1, progress: Double = 0.0, rewardXP: Int = 10, recommendedConditions: RecommendedConditions? = nil, hint: String? = nil, state: ChallengeState = .available, recommendationExplanation: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.difficulty = difficulty
        self.progress = progress
        self.rewardXP = rewardXP
        self.recommendedConditions = recommendedConditions
        self.hint = hint
        self.state = state
        self.recommendationExplanation = recommendationExplanation
    }
}
