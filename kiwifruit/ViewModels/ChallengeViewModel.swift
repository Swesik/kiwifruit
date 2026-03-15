import Foundation
import SwiftUI

@MainActor
public class ChallengeViewModel: ObservableObject {
    @Published public var activeChallenges: [Challenge] = []
    @Published public var recommendedChallenges: [Challenge] = []
    @Published public var streak: Int = 1

    public init() {}

    public func loadRecommendations() async {
        let recs = await ChallengeEngine.shared.recommend(limit: 4)
        self.recommendedChallenges = recs
    }

    public func join(_ challenge: Challenge) {
        if !activeChallenges.contains(where: { $0.id == challenge.id }) {
            var c = challenge
            c.progress = 0.0
            activeChallenges.append(c)
            // remove from recommended
            recommendedChallenges.removeAll { $0.id == c.id }
        }
    }

    public func abandon(_ challenge: Challenge) {
        activeChallenges.removeAll { $0.id == challenge.id }
    }

    public func updateProgress(challengeId: UUID, progress: Double) {
        if let idx = activeChallenges.firstIndex(where: { $0.id == challengeId }) {
            activeChallenges[idx].progress = min(max(progress, 0.0), 1.0)
        }
    }
}
import Foundation
import Combine

@MainActor
public class ChallengeViewModel: ObservableObject {
    @Published public var activeChallenges: [Challenge] = []
    @Published public var recommended: [Challenge] = []
    @Published public var streak: Int = 1

    private let engine: ChallengeEngine
    private var bank: [Challenge] = []

    public init(engine: ChallengeEngine = ChallengeEngine(), streak: Int = 1) {
        self.engine = engine
        self.streak = streak
        self.bank = Self.defaultBank()
        self.activeChallenges = []
    }

    public func loadRecommendations() async {
        let rec = await engine.recommended(from: bank)
        DispatchQueue.main.async {
            self.recommended = rec
        }
    }

    public func join(_ challenge: Challenge) {
        if !activeChallenges.contains(where: { $0.id == challenge.id }) {
            activeChallenges.append(challenge)
        }
    }

    public func abandon(_ challenge: Challenge) {
        activeChallenges.removeAll { $0.id == challenge.id }
    }

    public func updateProgress(challenge: Challenge, progress: Double) {
        if let idx = activeChallenges.firstIndex(where: { $0.id == challenge.id }) {
            activeChallenges[idx].progress = progress
        }
    }

    // Example static bank
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
