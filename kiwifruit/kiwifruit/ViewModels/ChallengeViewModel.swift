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
    private let completedIDsKey = "kiwifruit.completedChallengeIDs"

    init(streak: Int = 1) {
        self.streak = streak
        // Use the engine's canonical bank so IDs and titles remain stable
        self.bank = engine.bank
        self.activeChallenges = []
        // load persisted points and completed ids
        if let pts = UserDefaults.standard.object(forKey: totalPointsKey) as? Int {
            totalPoints = pts
        }
        if let ids = UserDefaults.standard.array(forKey: completedIDsKey) as? [String] {
            let uuidSet = Set(ids.compactMap { UUID(uuidString: $0) })
            // mark completed in bank (match by id)
            let completed = bank.filter { uuidSet.contains($0.id) }
            completedChallenges = completed.map { var c = $0; c.state = .completed; c.progress = 1.0; return c }
        }
    }
    

    func loadRecommendations() async {
        let rec = await engine.recommend(limit: 6)
        // reconcile state with accepted/completed
        var mapped = rec.map { (ch) -> Challenge in
            var c = ch
            // match by id or title to avoid duplicate/discrepant IDs between banks
            if completedChallenges.contains(where: { $0.id == c.id || $0.title == c.title }) { c.state = .completed; c.progress = 1.0 }
            else if activeChallenges.contains(where: { $0.id == c.id || $0.title == c.title }) { c.state = .accepted }
            else { c.state = .available }
            return c
        }
        // Ensure recommended doesn't include already accepted ones (by id or title)
        self.recommended = mapped.filter { candidate in
            !activeChallenges.contains(where: { $0.id == candidate.id || $0.title == candidate.title })
        }
    }

    func accept(_ challenge: Challenge) -> Bool {
        // Enforce a maximum number of active challenges (e.g., 3)
        let maxActive = 3
        if activeChallenges.contains(where: { $0.id == challenge.id }) { return true }
        if activeChallenges.count >= maxActive { return false }

        var c = challenge
        c.state = .accepted
        c.progress = 0.0
        activeChallenges.append(c)
        // Remove any recommended entries that match by id or title to avoid duplication in Discover
        recommended.removeAll { $0.id == c.id || $0.title == c.title }
        return true
    }

    func join(_ challenge: Challenge) {
        // alias for accept
        accept(challenge)
    }

    func abandon(_ challenge: Challenge) {
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
        // ensure completed challenge is not shown in recommendations
        recommended.removeAll { $0.id == c.id || $0.title == c.title }
    }

    private func persistTotals() {
        UserDefaults.standard.set(totalPoints, forKey: totalPointsKey)
        let ids = completedChallenges.map { $0.id.uuidString }
        UserDefaults.standard.set(ids, forKey: completedIDsKey)
    }

    
}
