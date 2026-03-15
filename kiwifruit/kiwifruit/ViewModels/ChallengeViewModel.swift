import Foundation
import Observation

@Observable @MainActor
final class ChallengeViewModel {
    var activeChallenges: [Challenge] = []
    var recommended: [Challenge] = []
    var streak: Int = 1
    var completedChallenges: [Challenge] = []
    var totalPoints: Int = 0

    private let engine: ChallengeEngine = .shared
    private var bank: [Challenge] = []
    private let totalPointsKey = "kiwifruit.totalPoints"
    private let completedIDsKey = "kiwifruit.completedChallengeIDs" // legacy fallback
    private let completedChallengesKey = "kiwifruit.completedChallenges_v1"

    init(streak: Int = 1) {
        self.streak = streak
        self.bank = Self.defaultBank()
        self.activeChallenges = []
        // load persisted points and completed challenges (full objects preferred)
        if let pts = UserDefaults.standard.object(forKey: totalPointsKey) as? Int {
            totalPoints = pts
        }

        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: completedChallengesKey), let decoded = try? decoder.decode([Challenge].self, from: data) {
            completedChallenges = decoded
            // ensure state/progress
            for idx in completedChallenges.indices { completedChallenges[idx].state = .completed; completedChallenges[idx].progress = 1.0 }
            // ensure totalPoints matches persisted or recompute
            if totalPoints == 0 { totalPoints = completedChallenges.reduce(0) { $0 + $1.rewardXP } }
        } else if let ids = UserDefaults.standard.array(forKey: completedIDsKey) as? [String] {
            // legacy fallback: reconstruct from bank by IDs
            let uuidSet = Set(ids.compactMap { UUID(uuidString: $0) })
            let completed = bank.filter { uuidSet.contains($0.id) }
            completedChallenges = completed.map { var c = $0; c.state = .completed; c.progress = 1.0; return c }
            if totalPoints == 0 { totalPoints = completedChallenges.reduce(0) { $0 + $1.rewardXP } }
        }
    }
    

    func loadRecommendations() async {
        let completedIDs = Set(completedChallenges.map { $0.id })
        let activeIDs = Set(activeChallenges.map { $0.id })
        let exclude = completedIDs.union(activeIDs)

        // ask for extra candidates to increase chances of getting 4 after filtering
        let rec = await engine.recommend(limit: 6, excludeIDs: exclude)
        print("[ChallengeViewModel] excludeIDs=\(exclude.map { $0.uuidString })  engine returned \(rec.count) candidates")
        print("[ChallengeViewModel] engine titles=\(rec.map { $0.title })")
        // reconcile state with accepted/completed and filter out completed/active
        // avoid returning exact duplicates by id or title (be less aggressive than substring matching)
        let completedTitles = Set(completedChallenges.map { $0.title.lowercased() })
        let activeTitles = Set(activeChallenges.map { $0.title.lowercased() })

        var mapped = rec.compactMap { (ch) -> Challenge? in
            // exclude by id
            if completedIDs.contains(ch.id) { return nil }
            if activeIDs.contains(ch.id) { return nil }

            // exclude exact title matches only (avoid over-filtering by description substrings)
            let titleLower = ch.title.lowercased()
            if completedTitles.contains(titleLower) { return nil }
            if activeTitles.contains(titleLower) { return nil }

            var c = ch
            if activeIDs.contains(c.id) { c.state = .accepted }
            else { c.state = .available }
            return c
        }

        // If still short, generate additional dynamic challenges to fill to 4
        if mapped.count < 4 {
            var attempts = 0
            while mapped.count < 4 && attempts < 20 {
                let dyn = await DynamicChallengeService.shared.generateDynamicChallenge()
                if exclude.contains(dyn.id) || mapped.contains(where: { $0.title == dyn.title }) { attempts += 1; continue }
                var c = dyn
                c.state = .available
                mapped.append(c)
                attempts += 1
            }
        }

        if mapped.count > 4 { mapped = Array(mapped.prefix(4)) }
        print("[ChallengeViewModel] final recommended count=\(mapped.count) titles=\(mapped.map { $0.title })")
        self.recommended = mapped
    }

    /// Refresh recommendations explicitly (get a new set)
    func refreshRecommendations() async {
        await loadRecommendations()
    }

    /// Attempts to accept a challenge. Returns true on success, false if limit reached or already accepted.
    func accept(_ challenge: Challenge) -> Bool {
        // enforce max 3 active challenges
        if activeChallenges.contains(where: { $0.id == challenge.id }) { return true }
        if activeChallenges.count >= 3 { return false }

        var c = challenge
        c.state = .accepted
        c.progress = 0.0
        activeChallenges.append(c)
        recommended.removeAll { $0.id == c.id }
        return true
    }

    func join(_ challenge: Challenge) -> Bool {
        // alias for accept
        return accept(challenge)
    }

    func abandon(_ challenge: Challenge) {
        // only allow abandoning if currently active/accepted
        activeChallenges.removeAll { $0.id == challenge.id }
    }

    func updateProgress(challenge: Challenge, progress: Double) {
        if let idx = activeChallenges.firstIndex(where: { $0.id == challenge.id }) {
            activeChallenges[idx].progress = progress
        }
    }

    func complete(_ challenge: Challenge) {
        guard let idx = activeChallenges.firstIndex(where: { $0.id == challenge.id }) else { return }
        var c = activeChallenges.remove(at: idx)
        c.progress = 1.0
        c.state = .completed
        completedChallenges.append(c)
        // award points
        totalPoints += c.rewardXP
        // persist
        persistTotals()
        // remove from recommended/discover so it doesn't reappear
        recommended.removeAll { $0.id == c.id }
    }

    private func persistTotals() {
        UserDefaults.standard.set(totalPoints, forKey: totalPointsKey)
        // persist full completed challenge objects
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(completedChallenges) {
            UserDefaults.standard.set(data, forKey: completedChallengesKey)
        } else {
            // fallback to legacy ID storage
            let ids = completedChallenges.map { $0.id.uuidString }
            UserDefaults.standard.set(ids, forKey: completedIDsKey)
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
