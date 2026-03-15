import Foundation
import Observation

@Observable @MainActor
final class ChallengeViewModel {
    var activeChallenges: [Challenge] = []
    var recommended: [Challenge] = []
    var streak: Int = 1

    private let engine: ChallengeEngine = .shared
    private var bank: [Challenge] = []

    init(streak: Int = 1) {
        self.streak = streak
        self.bank = Self.defaultBank()
        self.activeChallenges = []
    }

    func loadRecommendations() async {
        let rec = await engine.recommend(limit: 4)
        self.recommended = rec
    }

    func join(_ challenge: Challenge) {
        if !activeChallenges.contains(where: { $0.id == challenge.id }) {
            var c = challenge
            c.progress = 0.0
            activeChallenges.append(c)
            recommended.removeAll { $0.id == c.id }
        }
    }

    func abandon(_ challenge: Challenge) {
        activeChallenges.removeAll { $0.id == challenge.id }
    }

    func updateProgress(challenge: Challenge, progress: Double) {
        if let idx = activeChallenges.firstIndex(where: { $0.id == challenge.id }) {
            activeChallenges[idx].progress = progress
        }
    }

    private static func defaultBank() -> [Challenge] {
        return [
            Challenge(title: "Morning Momentum", description: "Read 10 pages before 10am", category: "time", difficulty: 1, rewardXP: 20, recommendedConditions: RecommendedConditions(timeOfDay: "morning")),
            Challenge(title: "Outdoor Reading", description: "Read outside for 15 minutes", category: "outdoor", difficulty: 2, rewardXP: 35, recommendedConditions: RecommendedConditions(weather: "Clear", minTemperature: 60)),
            Challenge(title: "Night Owl", description: "Read after 9pm for 20 minutes", category: "time", difficulty: 2, rewardXP: 30, recommendedConditions: RecommendedConditions(timeOfDay: "night")),
            Challenge(title: "Sprint Reader", description: "Read 25 pages in one session", category: "sprint", difficulty: 3, rewardXP: 50, recommendedConditions: RecommendedConditions()),
            Challenge(title: "Cozy Tea Read", description: "Read 20 pages with tea while it's raining", category: "indoor", difficulty: 1, rewardXP: 25, recommendedConditions: RecommendedConditions(weather: "Rain")),
            Challenge(title: "Lunchtime Bite", description: "Read during lunch for 15 minutes", category: "time", difficulty: 1, rewardXP: 15, recommendedConditions: RecommendedConditions(timeOfDay: "afternoon"))
        ]
    }
}
