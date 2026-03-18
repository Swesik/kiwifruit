import Foundation
import Observation

@Observable @MainActor
final class ChallengeViewModel {
    var activeChallenges: [Challenge] = []
    var recommended: [Challenge] = []
    var streak: Int = 1
    var completedChallenges: [Challenge] = []
    var totalPoints: Int = 0
    // ambient location summary for the last refresh (e.g., "Iceland — Reykjavik (pop: 131k) — GMT")
    var lastLocationSummary: String? = nil
    var lastLat: Double? = nil
    var lastLon: Double? = nil

    // Set an explicit location for subsequent generation. This will attempt to resolve a place/country and update lastLocationSummary, then refresh recommendations.
    func setLocation(lat: Double, lon: Double) async {
        self.lastLat = lat
        self.lastLon = lon

        // try to resolve place via ReverseGeocodeService first, fall back to OpenAI
        var placeName: String? = nil
        var countryName: String? = nil
        if let rg = await ReverseGeocodeService.shared.reverse(lat: lat, lon: lon) {
            placeName = rg.place
            countryName = rg.country
        } else if let place = await OpenAIService.shared.lookupPlace(lat: lat, lon: lon) {
            placeName = place.place
            countryName = place.country
        }

        // timezone and population fetch as before
        var tz: String? = nil
        var pop: String? = nil
        do { tz = try await ApiNinjasTimezoneService.shared.fetchTimezone(lat: lat, lon: lon) } catch { tz = nil }
        do { pop = try await ApiNinjasPopulationService.shared.fetchPopulation(lat: lat, lon: lon) } catch { pop = nil }

        var parts: [String] = []
        if let p = placeName { parts.append(p) }
        if let c = countryName { parts.append(c) }
        if let p = pop { parts.append(p) }
        if let t = tz { parts.append(t) }

        let summary = parts.joined(separator: " — ")
        self.lastLocationSummary = summary.isEmpty ? "Lat: \(String(format: \"%.2f\", lat)), Lon: \(String(format: \"%.2f\", lon))" : summary

        // refresh recommendations to use this locked location
        Task { await self.refreshRecommendations() }
    }

    private let engine: ChallengeEngine = .shared
    private var bank: [Challenge] = []
    private let totalPointsKey = "kiwifruit.totalPoints"
    private let completedIDsKey = "kiwifruit.completedChallengeIDs"
    private let persistedDynamicKey = "kiwifruit.persistedActiveDynamicChallenges"

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
        // restore any previously-accepted dynamic challenges
        loadPersistedDynamicChallenges()
    }
    

    func loadRecommendations() async {
        let desired = 4
        var rec = await engine.recommend(limit: desired)
        // reconcile state with accepted/completed
        var mapped = rec.map { (ch) -> Challenge in
            var c = ch
            // match by id or title to avoid duplicate/discrepant IDs between banks
            if completedChallenges.contains(where: { $0.id == c.id || $0.title == c.title }) { c.state = .completed; c.progress = 1.0 }
            else if activeChallenges.contains(where: { $0.id == c.id || $0.title == c.title }) { c.state = .accepted }
            else { c.state = .available }
            return c
        }
        // Ensure recommended doesn't include already accepted or completed ones (by id or title)
        var filtered = mapped.filter { candidate in
            let isActive = activeChallenges.contains(where: { $0.id == candidate.id || $0.title == candidate.title })
            let isCompleted = completedChallenges.contains(where: { $0.id == candidate.id || $0.title == candidate.title })
            return !isActive && !isCompleted
        }

        // If we have fewer than desired, generate dynamic fill-ins
        while filtered.count < desired {
            let dyn = await DynamicChallengeService.shared.generateDynamicChallenge()
            // avoid duplicates by title
            let isCompleted = completedChallenges.contains(where: { $0.title == dyn.title })
            if !filtered.contains(where: { $0.title == dyn.title }) && !activeChallenges.contains(where: { $0.title == dyn.title }) && !isCompleted {
                filtered.append(dyn)
            }
            // safety: break if we loop too many times
            if filtered.count >= desired { break }
        }

        self.recommended = Array(filtered.prefix(desired))
    }

    // Force-refresh: generate entirely new dynamic challenges (useful for "refresh" action)
    func refreshRecommendations() async {
        let desired = 4
        // Use an explicit location if set; otherwise pick a random coordinate for ambient consistency
        let lat: Double
        let lon: Double
        if let l = self.lastLat, let o = self.lastLon {
            lat = l; lon = o
        } else {
            let coord = DynamicChallengeService.shared.randomCoordinatePublic()
            lat = coord.0; lon = coord.1
        }

        // Try to fetch timezone and population for the chosen location to create a coherent ambiance
        var tz: String? = nil
        var pop: String? = nil
        do {
            tz = try await ApiNinjasTimezoneService.shared.fetchTimezone(lat: lat, lon: lon)
        } catch {
            tz = nil
        }
        do {
            pop = try await ApiNinjasPopulationService.shared.fetchPopulation(lat: lat, lon: lon)
        } catch {
            pop = nil
        }

        // Build a readable summary
        var summaryParts: [String] = []
        if let pop = pop { summaryParts.append(pop) }
        if let tz = tz { summaryParts.append(tz) }
        let summary = summaryParts.joined(separator: " — ")
        self.lastLocationSummary = summary.isEmpty ? "Lat: \(String(format: "%.2f", lat)), Lon: \(String(format: "%.2f", lon))" : summary
        self.lastLat = lat
        self.lastLon = lon

        var generated = await DynamicChallengeService.shared.generateDynamicChallengesForLocation(lat: lat, lon: lon, streak: streak, count: desired)

        // Attach location summary to each generated challenge's explanation/hint
        for i in 0..<generated.count {
            var g = generated[i]
            let locnote = summary.isEmpty ? "Location: (\(String(format: "%.2f", lat)), \(String(format: "%.2f", lon)))" : summary
            if var expl = g.recommendationExplanation {
                expl += " | \(locnote)"
                g.recommendationExplanation = expl
            } else {
                g.recommendationExplanation = locnote
            }
            if g.hint == nil { g.hint = locnote }
            generated[i] = g
        }

        // Filter out any that clash with active/completed
        generated.removeAll { c in
            activeChallenges.contains(where: { $0.id == c.id || $0.title == c.title }) ||
            completedChallenges.contains(where: { $0.id == c.id || $0.title == c.title })
        }

        // If we have fewer than desired after filtering, fill using engine
        if generated.count < desired {
            let remaining = desired - generated.count
            let rec = await engine.recommend(limit: remaining)
            for r in rec where !activeChallenges.contains(where: { $0.id == r.id }) && !completedChallenges.contains(where: { $0.id == r.id }) {
                generated.append(r)
                if generated.count >= desired { break }
            }
        }

        self.recommended = Array(generated.prefix(desired))
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
        // persist accepted dynamic challenges so they survive app restarts
        persistActiveDynamicChallenges()
        // refill discover asynchronously so user sees 4 items consistently
        Task { await loadRecommendations() }
        return true
    }

    func join(_ challenge: Challenge) {
        // alias for accept
        accept(challenge)
    }

    func abandon(_ challenge: Challenge) {
        activeChallenges.removeAll { $0.id == challenge.id }
        persistActiveDynamicChallenges()
        Task { await loadRecommendations() }
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
        // refill discover asynchronously to maintain constant discover size
        Task { await loadRecommendations() }
        // persist removal of any dynamic challenges no longer active
        persistActiveDynamicChallenges()
    }

    private func persistTotals() {
        UserDefaults.standard.set(totalPoints, forKey: totalPointsKey)
        let ids = completedChallenges.map { $0.id.uuidString }
        UserDefaults.standard.set(ids, forKey: completedIDsKey)
    }

    // Persist currently active dynamic challenges to UserDefaults
    private func persistActiveDynamicChallenges() {
        let dynamics = activeChallenges.filter { $0.category == "dynamic" }
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(dynamics) {
            UserDefaults.standard.set(data, forKey: persistedDynamicKey)
        } else {
            UserDefaults.standard.removeObject(forKey: persistedDynamicKey)
        }
    }

    // Load previously persisted dynamic challenges and restore them as accepted
    private func loadPersistedDynamicChallenges() {
        guard let data = UserDefaults.standard.data(forKey: persistedDynamicKey) else { return }
        let decoder = JSONDecoder()
        if let dynamics = try? decoder.decode([Challenge].self, from: data) {
            for var c in dynamics {
                c.state = .accepted
                // avoid duplicates
                if !activeChallenges.contains(where: { $0.id == c.id || $0.title == c.title }) {
                    activeChallenges.append(c)
                }
            }
        }
    }

    
}
