import Foundation

public struct RecommendedConditions: Codable {
    public var weather: String?
    public var minTemperature: Double?
    public var maxTemperature: Double?
    public var timeOfDay: String?

    public init(weather: String? = nil, minTemperature: Double? = nil, maxTemperature: Double? = nil, timeOfDay: String? = nil) {
        self.weather = weather
        self.minTemperature = minTemperature
        self.maxTemperature = maxTemperature
        self.timeOfDay = timeOfDay
    }
}

public struct Challenge: Identifiable, Codable, Equatable {
    public let id: UUID
    public var title: String
    public var description: String
    public var category: String
    public var difficulty: Int
    public var progress: Double
    public var rewardXP: Int
    public var recommendedConditions: RecommendedConditions?

    public init(id: UUID = UUID(), title: String, description: String, category: String = "general", difficulty: Int = 1, progress: Double = 0.0, rewardXP: Int = 10, recommendedConditions: RecommendedConditions? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.difficulty = difficulty
        self.progress = progress
        self.rewardXP = rewardXP
        self.recommendedConditions = recommendedConditions
    }
}
