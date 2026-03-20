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

    // Injected dependencies (useful for testing and to satisfy AI_RULES.md)
    private let sessionRepo: SessionRepository
    private let weatherRepo: WeatherRepository
    private let geoRepo: GeoRepository
    private let persistence: PersistenceRepository
    private let dynamicRepo: DynamicChallengeRepository
    private let llmRepo: LLMRepository

    init(
        streak: Int = 1,
        sessionRepo: SessionRepository = ServerSessionRepository(),
        weatherRepo: WeatherRepository = ApiNinjasWeatherService.shared,
        geoRepo: GeoRepository = GeoService.shared,
        persistence: PersistenceRepository = UserDefaultsPersistence(),
        dynamicRepo: DynamicChallengeRepository = DynamicChallengeService.shared,
        llmRepo: LLMRepository = OpenAIService.shared
    ) {
        self.streak = streak
        self.sessionRepo = sessionRepo
        self.weatherRepo = weatherRepo
        self.geoRepo = geoRepo
        self.persistence = persistence
        self.dynamicRepo = dynamicRepo
        self.llmRepo = llmRepo
        // Use the engine's canonical bank so IDs and titles remain stable
        self.bank = engine.bank
        self.activeChallenges = []
        // load persisted points and completed ids via injected persistence
        if let pts = persistence.integer(forKey: totalPointsKey) { totalPoints = pts }
        if let ids = persistence.array(forKey: completedIDsKey) {
            let uuidSet = Set(ids.compactMap { UUID(uuidString: $0) })
            // mark completed in bank (match by id)
            let completed = bank.filter { uuidSet.contains($0.id) }
            completedChallenges = completed.map { var c = $0; c.state = .completed; c.progress = 1.0; return c }
        }
        // restore any previously-accepted dynamic challenges
        loadPersistedDynamicChallenges()

        // load manual adjustments
        if let dict = persistence.dictionary(forKey: adjustmentsKey) as? [String:Double] {
            manualAdjustments = dict
        }

        // no persisted location info in skeletal product
    }
    

    // Returns a list of recommended challenges without mutating UI state.
    func loadRecommendations() async -> [Challenge] {
        // Always generate API-driven random challenges for Discover
        let desired = 4
        // Try cached recommendations first
        if let data = persistence.data(forKey: recommendedCacheKey), let cached = try? JSONDecoder().decode([Challenge].self, from: data) {
            // Return cached immediately and kick off a background refresh
            let cachedList = cached
            Task { [weak self] in
                guard let self = self else { return }
                let generated = await self.dynamicRepo.generateRandomChallenges(count: desired)
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
                if let enc = try? JSONEncoder().encode(final) { self.persistence.setData(enc, forKey: self.recommendedCacheKey) }
            }
            // return cached immediately
            return Array(cachedList.prefix(desired))
        }

        let generated = await dynamicRepo.generateRandomChallenges(count: desired)
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
        if let enc = try? JSONEncoder().encode(final) { persistence.setData(enc, forKey: recommendedCacheKey) }
        return final
    }

    // Force-refresh: generate entirely new dynamic challenges (useful for "refresh" action)
    func refreshRecommendations() async -> [Challenge] {
        let desired = 4
        let generated = await dynamicRepo.generateRandomChallenges(count: desired)
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
        return final
    }

    // Create a new user-defined challenge and return it. Does NOT mutate UI state;
    // caller (UI) should apply the returned challenge to `activeChallenges` on
    // the main actor and call `applyPersistActiveDynamicChallenges()` to persist.
    func createChallenge(type: String, pagesPerWeek: Int? = nil, minutesPerWeek: Int? = nil, booksCount: Int? = nil) -> Challenge {
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

        let c = Challenge(title: title, description: desc, category: "custom", difficulty: 1, progress: 0.0, rewardXP: 10, recommendedConditions: nil, hint: nil, goalCount: goal, goalUnit: unit, state: .accepted)
        return c
    }

    // Create a weather-driven challenge and return it. Does NOT mutate state.
    func createWeatherChallenge(lat: Double, lon: Double, placeName: String? = nil) async -> Challenge {
        // Try to fetch weather and build a combined reading challenge from it
        do {
            let w = try await weatherRepo.fetchWeather(lat: lat, lon: lon)
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

            // Build richer context including temperature and place for the LLM
            let placeContext: String
            if let pn = placeName, !pn.isEmpty {
                placeContext = "location='\(pn)'"
            } else {
                placeContext = "lat=\(String(format: "%.2f", lat)), lon=\(String(format: "%.2f", lon))"
            }
            let userContext = "Temperature=\(Int(temp))F; wind=\(windStr)mph; humidity=\(Int(w.humidity ?? 0)); \(placeContext); date=\(Date()). Create a short, mobile-friendly reading challenge title, description (one-sentence), and a hint specifically tailored to the temperature. Respond with JSON {\"title\", \"description\", \"hint\"}."
            if let enhanced = await llmRepo.enhanceChallenge(c, context: userContext) {
                if let t = enhanced.title { c.title = t }
                if let d = enhanced.description { c.description = d }
                if let h = enhanced.hint { c.hint = h }
            } else {
                // Fallback: adapt description by temperature
                if temp > 75 {
                    c.description = "It's warm — take a 20-minute outdoor reading session that suits the weather."
                    c.hint = "Find a short, bright story or essay to enjoy outside."
                } else if temp < 50 {
                    c.description = "It's cool — cozy up indoors and read for 25 minutes."
                    c.hint = "Choose a comforting essay or short story."
                } else if (w.humidity ?? 0) > 80 || (desc.lowercased().contains("rain")) {
                    c.description = "Rainy or humid — make a cozy 25-minute indoor reading plan."
                    c.hint = "Pick a short, contemplative piece and a warm drink."
                } else {
                    c.description = "A moderate day — read a short piece for 20 minutes that matches the local mood."
                    c.hint = "Try a short story or poem reflecting the scene."
                }
            }

            // Ensure weather challenges track minutes so they listen to session data
            // by default (e.g., 20 minutes/week). This allows updateChallengeProgress
            // to attribute session minutes to these weather challenges.
            c.goalUnit = "minutes/week"
            c.goalCount = 20

            // Add to user's active challenges and persist
            c.generatedLat = lat
            c.generatedLon = lon
            c.generatedLocationIsRandom = false
            if let pn = placeName, !pn.isEmpty {
                c.generatedLocationName = pn
            } else if let geo = try? await geoRepo.reverseGeocode(lat: lat, lon: lon) {
                c.generatedLocationName = geo.displayName ?? geo.country
            }
            return c
        } catch {
            // On error, fall back to a dynamic item
        }

        // Fallback: use the dynamic generator and mark as fallback for diagnostics
        var c = await dynamicRepo.generateDynamicChallenge(lat: lat, lon: lon, streak: self.streak)
        c.state = .accepted
        c.progress = 0.0
        c.recommendationExplanation = (c.recommendationExplanation ?? "") + " (fallback: weather fetch failed)"
        return c
    }

    // Log progress for a custom challenge and return the updated progress and
    // whether it completed. Does NOT mutate state.
    func logProgress(challengeId: UUID, amount: Int) -> (newProgress: Double, didComplete: Bool)? {
        guard let idx = activeChallenges.firstIndex(where: { $0.id == challengeId }) else { return nil }
        var c = activeChallenges[idx]
        guard c.category == "custom" else { return nil }
        let goal = max(1, c.goalCount ?? 1)
        let delta = Double(amount) / Double(goal)
        let newProgress = min(1.0, c.progress + delta)
        let didComplete = newProgress >= 1.0
        // return values; caller should apply mutation on the main actor
        return (newProgress, didComplete)
    }

    // Prepare acceptance of a challenge: returns (success, preparedChallenge).
    // Does NOT mutate state; caller should apply the prepared challenge on the main actor.
    func accept(_ challenge: Challenge) -> (success: Bool, prepared: Challenge?) {
        let maxActive = 3
        if activeChallenges.contains(where: { $0.id == challenge.id }) { return (true, nil) }
        if activeChallenges.count >= maxActive { return (false, nil) }
        var c = challenge
        c.state = .accepted
        c.progress = 0.0
        return (true, c)
    }

    func join(_ challenge: Challenge) -> (success: Bool, prepared: Challenge?) {
        return accept(challenge)
    }

    // Prepare abandonment: caller should remove and persist on the main actor.
    func abandon(_ challenge: Challenge) -> Bool {
        return activeChallenges.contains(where: { $0.id == challenge.id })
    }

    // Prepare a simple progress update for a challenge (no mutation).
    func updateProgress(challenge: Challenge, progress: Double) -> Bool {
        if let idx = activeChallenges.firstIndex(where: { $0.id == challenge.id }) {
            return true
        }
        return false
    }

    // Prepare completion result for a challenge. Does NOT mutate state.
    // Returns the completed challenge and points awarded so the caller can apply
    // UI mutations on the main actor and then call persistence helpers.
    func complete(_ challenge: Challenge) -> (completed: Challenge, points: Int)? {
        guard let idx = activeChallenges.firstIndex(where: { $0.id == challenge.id }) else { return nil }
        var c = activeChallenges[idx]
        c.progress = 1.0
        c.state = .completed
        let points = c.rewardXP
        return (c, points)
    }

    private func persistTotals() {
        persistence.setInteger(totalPoints, forKey: totalPointsKey)
        let ids = completedChallenges.map { $0.id.uuidString }
        persistence.setArray(ids, forKey: completedIDsKey)
    }

    // Persist currently active dynamic challenges to UserDefaults
    private func persistActiveDynamicChallenges() {
        // persist active custom and dynamically-generated challenges
        let toPersist = activeChallenges.filter { $0.category == "dynamic" || $0.category == "custom" }
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(toPersist) {
            persistence.setData(data, forKey: persistedDynamicKey)
        } else {
            persistence.setData(nil, forKey: persistedDynamicKey)
        }
    }

    // MARK: - UI apply helpers (mutate observable state; must be called on MainActor)

    // Apply acceptance on the MainActor. Returns true when applied,
    // false if capacity prevents accepting (enforced here for safety).
    func applyAccept(_ challenge: Challenge) -> Bool {
        let maxActive = 3
        if activeChallenges.contains(where: { $0.id == challenge.id }) { return true }
        if activeChallenges.count >= maxActive { return false }
        activeChallenges.append(challenge)
        recommended.removeAll { $0.id == challenge.id || $0.title == challenge.title }
        persistActiveDynamicChallenges()
        return true
    }

    func applyAbandon(_ challenge: Challenge) {
        activeChallenges.removeAll { $0.id == challenge.id }
        persistActiveDynamicChallenges()
    }

    func applyLogProgress(challengeId: UUID, newProgress: Double) {
        if let idx = activeChallenges.firstIndex(where: { $0.id == challengeId }) {
            activeChallenges[idx].progress = newProgress
            if newProgress >= 1.0 {
                if let (completed, points) = complete(activeChallenges[idx]) {
                    // apply completion
                    activeChallenges.removeAll { $0.id == completed.id }
                    completedChallenges.append(completed)
                    totalPoints += points
                    persistTotals()
                }
            }
            persistActiveDynamicChallenges()
        }
    }

    func applyComplete(challengeId: UUID) {
        if let idx = activeChallenges.firstIndex(where: { $0.id == challengeId }) {
            var c = activeChallenges.remove(at: idx)
            c.progress = 1.0
            c.state = .completed
            completedChallenges.append(c)
            totalPoints += c.rewardXP
            persistTotals()
            recommended.removeAll { $0.id == c.id || $0.title == c.title }
            persistActiveDynamicChallenges()
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
        guard let data = persistence.data(forKey: persistedDynamicKey) else { return }
        let decoder = JSONDecoder()
        if let dynamics = try? decoder.decode([Challenge].self, from: data) {
            let maxActive = 3
            for var c in dynamics {
                c.state = .accepted
                // avoid duplicates and enforce capacity
                if !activeChallenges.contains(where: { $0.id == c.id || $0.title == c.title }) {
                    if activeChallenges.count < maxActive {
                        activeChallenges.append(c)
                    } else {
                        break
                    }
                }
            }
        }
    }

    // MARK: - Manual adjustments

    func setManualAdjustment(for challengeId: UUID, adjustment: Double) {
        manualAdjustments[challengeId.uuidString] = adjustment
        persistence.setDictionary(manualAdjustments, forKey: adjustmentsKey)
        Task { await updateChallengeProgress() }
    }

    func removeManualAdjustment(for challengeId: UUID) {
        manualAdjustments.removeValue(forKey: challengeId.uuidString)
        persistence.setDictionary(manualAdjustments, forKey: adjustmentsKey)
        Task { await updateChallengeProgress() }
    }

    func manualAdjustment(for challengeId: UUID) -> Double {
        return manualAdjustments[challengeId.uuidString] ?? 0.0
    }

    // MARK: - Reading sessions integration

    // Reading sessions are provided by the injected `SessionRepository`.

    // Sum total completed minutes across sessions (elapsed_seconds -> minutes)
    // Calculate total completed minutes for a host within the given lookback
    // window in days. Uses both active and completed sessions (status=any)
    // so UI reflects near-real-time progress.
    func calculateMinutes(host: String = "local", days: Int = 7) async -> Int {
        do {
            let sessions = try await sessionRepo.fetchReadingSessions(host: host, status: "any")
            let iso = ISO8601DateFormatter()
            let now = Date()
            let cutoff = now.addingTimeInterval(-TimeInterval(days * 24 * 60 * 60))
            var totalSeconds = 0
            for s in sessions {
                if let started = s.started_at, let dt = iso.date(from: started) {
                    if dt >= cutoff {
                        totalSeconds += s.elapsed_seconds ?? 0
                    }
                } else {
                    // If started_at missing or unparsable, conservatively include
                    totalSeconds += s.elapsed_seconds ?? 0
                }
            }
            return Int(totalSeconds / 60)
        } catch {
            return 0
        }
    }

    // Count unique completed book titles within the given lookback window in days.
    // Uses both active and completed sessions (status=any) to reflect near-real-time progress.
    func calculateBooks(host: String = "local", days: Int = 30) async -> Int {
        do {
            let sessions = try await sessionRepo.fetchReadingSessions(host: host, status: "any")
            let iso = ISO8601DateFormatter()
            let now = Date()
            let cutoff = now.addingTimeInterval(-TimeInterval(days * 24 * 60 * 60))
            var titles: [String] = []
            for s in sessions {
                if let started = s.started_at, let dt = iso.date(from: started) {
                    if dt >= cutoff {
                        if let t = s.book_title?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty { titles.append(t) }
                    }
                } else {
                    if let t = s.book_title?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty { titles.append(t) }
                }
            }
            return Set(titles).count
        } catch {
            return 0
        }
    }

    // Update active challenge progress by reconciling server reading_sessions and manual adjustments
    func updateChallengeProgress(host: String = "local") async {
        // Fetch metrics concurrently to minimize latency. Use windows:
        // minutes/pages -> last 7 days; books -> last 30 days.
        async let minutesTask = calculateMinutes(host: host, days: 7)
        async let booksTask = calculateBooks(host: host, days: 30)
        let minutes = await minutesTask
        let books = await booksTask

        // Collect IDs of challenges that should be completed; do not mutate the
        // `activeChallenges` array while iterating its indices to avoid index
        // invalidation and subtle bugs. Apply completions after reporting updates.
        var toCompleteIDs: [UUID] = []

        // Iterate normally but avoid mutating during enumeration by collecting
        // completion IDs; apply them after the loop.
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
                    // Pages are not tracked directly. Use session minutes as a
                    // heuristic where possible: assume ~1 page per minute to
                    // estimate progress from session lengths over the last 7 days.
                    if let goal = c.goalCount, goal > 0 {
                        let pagesPerMinute = 1.0
                        let estimatedPages = Double(minutes) * pagesPerMinute
                        let serverProgress = estimatedPages / Double(goal)
                        newProgress = min(1.0, serverProgress + manual)
                    } else {
                        newProgress = min(1.0, manual)
                    }
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
                    toCompleteIDs.append(c.id)
                }
            }
        }

        // Apply completions on the main actor to mutate UI state safely.
        for id in toCompleteIDs {
            await MainActor.run {
                applyComplete(challengeId: id)
            }
        }

        // persist any changes to active dynamic challenges
        persistActiveDynamicChallenges()
    }

    // Provide a small helper so Views don't call networking services directly.
    func reverseGeocode(lat: Double, lon: Double) async -> String? {
        if let geo = try? await GeoService.shared.reverseGeocode(lat: lat, lon: lon) {
            return geo.displayName ?? geo.country
        }
        return nil
    }

    
}
