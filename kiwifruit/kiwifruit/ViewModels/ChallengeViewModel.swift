import Foundation
import Observation

@Observable
final class ChallengeViewModel {
    var activeChallenges: [Challenge] = []
    var recommended: [Challenge] = []
    var streak: Int = 1
    var completedChallenges: [Challenge] = []
    var totalPoints: Int = 0
    var manualAdjustments: [String: Double] = [:]
    // Core challenge lists and state (no location tracking in skeletal product)

    private let engine: ChallengeEngine = .shared
    private var bank: [Challenge] = []
    private let totalPointsKey = "kiwifruit.totalPoints"
    private let completedIDsKey = "kiwifruit.completedChallengeIDs"
    private let persistedDynamicKey = "kiwifruit.persistedActiveDynamicChallenges"
    private let recommendedCacheKey = "kiwifruit.recommendedCache"
    private let adjustmentsKey = "kiwifruit.challengeAdjustments"

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

        // load manual adjustments
        if let dict = UserDefaults.standard.dictionary(forKey: adjustmentsKey) as? [String:Double] {
            manualAdjustments = dict
        }

        // no persisted location info in skeletal product
    }
    

    func loadRecommendations() async {
        // Always generate API-driven random challenges for Discover
        let desired = 4
        // Try cached recommendations first
        if let data = UserDefaults.standard.data(forKey: recommendedCacheKey), let cached = try? JSONDecoder().decode([Challenge].self, from: data) {
            self.recommended = cached
            // fetch fresh in background
            Task.detached { [weak self] in
                guard let self = self else { return }
                let generated = await DynamicChallengeService.shared.generateRandomChallenges(count: desired)
                var filtered: [Challenge] = []
                for var c in generated {
                    if self.completedChallenges.contains(where: { $0.id == c.id || $0.title == c.title }) { c.state = .completed; c.progress = 1.0 }
                    else if self.activeChallenges.contains(where: { $0.id == c.id || $0.title == c.title }) { c.state = .accepted }
                    else { c.state = .available }
                    if !self.activeChallenges.contains(where: { $0.id == c.id || $0.title == c.title }) && !self.completedChallenges.contains(where: { $0.id == c.id || $0.title == c.title }) {
                        filtered.append(c)
                    }
                }
                    let final = Array(filtered.prefix(desired))
                    Task { [weak self] in
                        guard let self = self else { return }
                        self.recommended = final
                        if let enc = try? JSONEncoder().encode(final) { UserDefaults.standard.set(enc, forKey: self.recommendedCacheKey) }
                    }
            }
            return
        }

        let generated = await DynamicChallengeService.shared.generateRandomChallenges(count: desired)
        // mark states appropriately and filter out active/completed
        var filtered: [Challenge] = []
        for var c in generated {
            if completedChallenges.contains(where: { $0.id == c.id || $0.title == c.title }) { c.state = .completed; c.progress = 1.0 }
            else if activeChallenges.contains(where: { $0.id == c.id || $0.title == c.title }) { c.state = .accepted }
            else { c.state = .available }
            if !activeChallenges.contains(where: { $0.id == c.id || $0.title == c.title }) && !completedChallenges.contains(where: { $0.id == c.id || $0.title == c.title }) {
                filtered.append(c)
            }
        }
        let final = Array(filtered.prefix(desired))
        self.recommended = final
        if let enc = try? JSONEncoder().encode(final) { UserDefaults.standard.set(enc, forKey: recommendedCacheKey) }
    }

    // Force-refresh: generate entirely new dynamic challenges (useful for "refresh" action)
    func refreshRecommendations() async {
        let desired = 4
        let generated = await DynamicChallengeService.shared.generateRandomChallenges(count: desired)
        var filtered: [Challenge] = []
        for var c in generated {
            if completedChallenges.contains(where: { $0.id == c.id || $0.title == c.title }) { c.state = .completed; c.progress = 1.0 }
            else if activeChallenges.contains(where: { $0.id == c.id || $0.title == c.title }) { c.state = .accepted }
            else { c.state = .available }
            if !activeChallenges.contains(where: { $0.id == c.id || $0.title == c.title }) && !completedChallenges.contains(where: { $0.id == c.id || $0.title == c.title }) {
                filtered.append(c)
            }
        }
        self.recommended = Array(filtered.prefix(desired))
    }

    // Create a new user-defined challenge and add it to activeChallenges (zeroed progress)
    func createChallenge(type: String, pagesPerWeek: Int? = nil, minutesPerWeek: Int? = nil, booksCount: Int? = nil) {
        var title = "Custom Challenge"
        var desc = ""
        var goal: Int? = nil
        var unit: String? = nil
        switch type {
        case "pages":
            title = "Read \(pagesPerWeek ?? 0) pages per week"
            desc = "Read at least \(pagesPerWeek ?? 0) pages each week."
            goal = pagesPerWeek
            unit = "pages/week"
        case "minutes":
            title = "Read \(minutesPerWeek ?? 0) minutes per week"
            desc = "Read at least \(minutesPerWeek ?? 0) minutes each week."
            goal = minutesPerWeek
            unit = "minutes/week"
        case "books":
            title = "Finish \(booksCount ?? 0) books this month"
            desc = "Complete \(booksCount ?? 0) books within a month."
            goal = booksCount
            unit = "books/month"
        default:
            title = "Custom Reading Challenge"
        }

        var c = Challenge(title: title, description: desc, category: "custom", difficulty: 1, progress: 0.0, rewardXP: 10, recommendedConditions: nil, hint: nil, goalCount: goal, goalUnit: unit, state: .accepted)
        // persist and add
        activeChallenges.append(c)
        persistActiveDynamicChallenges()
    }

    // Create a weather-driven challenge using external API and add as accepted with zeroed progress
    func createWeatherChallenge(lat: Double, lon: Double) async {
        // Try to fetch weather and build a combined reading challenge from it
        do {
            let w = try await ApiNinjasWeatherService.shared.fetchWeather(lat: lat, lon: lon)
            // Build a natural title/description combining weather and a reading task
            let temp = w.temp ?? 0.0
            let desc = w.description ?? ""
            let windStr = String(format: "%.1f", w.wind_speed ?? 0.0)
            let details = "Temp: \(Int(temp))°F. Wind: \(windStr) mph. \(desc)"
            var title = "Weather Read"
            var description = "Based on local weather (\(details)). Read a short piece that matches the mood for 20 minutes."
            // Set a reasonable XP and difficulty based on conditions
            let difficulty = difficultyForStreak(self.streak)
            let xp = rewardForDifficulty(10 + difficulty * 5, streak: self.streak)

            var c = Challenge(title: title, description: description, category: "weather", difficulty: difficulty, progress: 0.0, rewardXP: xp, recommendedConditions: nil, hint: nil, goalCount: nil, goalUnit: nil, state: .accepted)
            c.recommendationExplanation = "Generated from ApiNinjas weather: \(details)"
            c.hint = "Try a short story or essay that reflects the current weather."

            // Ask OpenAI to refine the title/description/hint for UX polish
            if let enhanced = await OpenAIService.shared.enhanceChallenge(c, context: "weather: \(details)") {
                if let t = enhanced.title { c.title = t }
                if let d = enhanced.description { c.description = d }
                if let h = enhanced.hint { c.hint = h }
            }

            // Add to user's active challenges and persist
            c.generatedLat = lat
            c.generatedLon = lon
            c.generatedLocationIsRandom = false
            if let geo = try? await GeoService.shared.reverseGeocode(lat: lat, lon: lon) {
                c.generatedLocationName = geo.displayName ?? geo.country
            }
            activeChallenges.append(c)
            persistActiveDynamicChallenges()
            return
        } catch {
            // On error, fall back to a dynamic item
        }

        // Fallback: use the dynamic generator and mark as fallback for diagnostics
        var c = await DynamicChallengeService.shared.generateDynamicChallenge(lat: lat, lon: lon, streak: self.streak)
        c.state = .accepted
        c.progress = 0.0
        c.recommendationExplanation = (c.recommendationExplanation ?? "") + " (fallback: weather fetch failed)"
        activeChallenges.append(c)
        persistActiveDynamicChallenges()
    }

    // Log progress for a custom challenge: amount is in the unit matching goalUnit (e.g., pages, minutes, books)
    func logProgress(challengeId: UUID, amount: Int) {
        guard let idx = activeChallenges.firstIndex(where: { $0.id == challengeId }) else { return }
        var c = activeChallenges[idx]
        guard c.category == "custom" else { return }
        let goal = max(1, c.goalCount ?? 1)
        let delta = Double(amount) / Double(goal)
        c.progress = min(1.0, c.progress + delta)
        activeChallenges[idx] = c
        if c.progress >= 1.0 { complete(c) }
        persistActiveDynamicChallenges()
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
        // do not auto-refresh recommendations; user must press refresh
        return true
    }

    func join(_ challenge: Challenge) {
        // alias for accept
        accept(challenge)
    }

    func abandon(_ challenge: Challenge) {
        activeChallenges.removeAll { $0.id == challenge.id }
        persistActiveDynamicChallenges()
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
        // do not auto-refresh recommendations; user must press refresh
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
        // persist active custom and dynamically-generated challenges
        let toPersist = activeChallenges.filter { $0.category == "dynamic" || $0.category == "custom" }
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(toPersist) {
            UserDefaults.standard.set(data, forKey: persistedDynamicKey)
        } else {
            UserDefaults.standard.removeObject(forKey: persistedDynamicKey)
        }
    }

    // Match DynamicChallengeService logic for difficulty/reward so ViewModel can compute values locally
    private func difficultyForStreak(_ streak: Int) -> Int {
        return min(5, 1 + (streak / 5))
    }

    private func rewardForDifficulty(_ base: Int, streak: Int) -> Int {
        return Int(Double(base) * (1.0 + Double(min(20, streak)) / 20.0))
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

    // MARK: - Manual adjustments

    func setManualAdjustment(for challengeId: UUID, adjustment: Double) {
        manualAdjustments[challengeId.uuidString] = adjustment
        UserDefaults.standard.set(manualAdjustments, forKey: adjustmentsKey)
        Task { await updateChallengeProgress() }
    }

    func removeManualAdjustment(for challengeId: UUID) {
        manualAdjustments.removeValue(forKey: challengeId.uuidString)
        UserDefaults.standard.set(manualAdjustments, forKey: adjustmentsKey)
        Task { await updateChallengeProgress() }
    }

    func manualAdjustment(for challengeId: UUID) -> Double {
        return manualAdjustments[challengeId.uuidString] ?? 0.0
    }

    // MARK: - Reading sessions integration

    private struct ReadingSession: Decodable {
        let session_id: String?
        let host: String?
        let book_title: String?
        let started_at: String?
        let status: String?
        let elapsed_seconds: Int?
    }

    private func fetchCompletedReadingSessions(host: String = "local") async throws -> [ReadingSession] {
        guard let url = URL(string: "http://127.0.0.1:5000/reading_sessions?host=\(host)") else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        let sessions = try decoder.decode([ReadingSession].self, from: data)
        return sessions
    }

    // Sum total completed minutes across sessions (elapsed_seconds -> minutes)
    func calculateMinutes(host: String = "local") async -> Int {
        do {
            let sessions = try await fetchCompletedReadingSessions(host: host)
            let totalSeconds = sessions.compactMap { $0.elapsed_seconds }.reduce(0, +)
            return Int(totalSeconds / 60)
        } catch {
            return 0
        }
    }

    // Count unique completed book titles
    func calculateBooks(host: String = "local") async -> Int {
        do {
            let sessions = try await fetchCompletedReadingSessions(host: host)
            let titles = sessions.compactMap { $0.book_title?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            let unique = Set(titles)
            return unique.count
        } catch {
            return 0
        }
    }

    // Update active challenge progress by reconciling server reading_sessions and manual adjustments
    func updateChallengeProgress(host: String = "local") async {
        // gather server metrics once
        let minutes = await calculateMinutes(host: host)
        let books = await calculateBooks(host: host)

        for idx in activeChallenges.indices {
            var c = activeChallenges[idx]
            let manual = manualAdjustments[c.id.uuidString] ?? 0.0
            var newProgress: Double = c.progress

            if let unit = c.goalUnit {
                let lower = unit.lowercased()
                if lower.contains("minute") {
                    if let goal = c.goalCount, goal > 0 {
                        let serverProgress = Double(minutes) / Double(goal)
                        newProgress = min(1.0, serverProgress + manual)
                    } else {
                        newProgress = min(1.0, manual)
                    }
                } else if lower.contains("book") {
                    if let goal = c.goalCount, goal > 0 {
                        let serverProgress = Double(books) / Double(goal)
                        newProgress = min(1.0, serverProgress + manual)
                    } else {
                        newProgress = min(1.0, manual)
                    }
                } else if lower.contains("page") {
                    // pages aren't tracked in reading_sessions; rely on manual adjustments
                    newProgress = min(1.0, manual)
                } else {
                    newProgress = min(1.0, manual)
                }
            } else {
                newProgress = min(1.0, manual)
            }

            // only update if meaningfully changed
            if abs(newProgress - c.progress) > 0.0001 {
                activeChallenges[idx].progress = newProgress
                if newProgress >= 1.0 {
                    complete(activeChallenges[idx])
                }
            }
        }
        // persist any changes to active dynamic challenges
        persistActiveDynamicChallenges()
    }

    
}
