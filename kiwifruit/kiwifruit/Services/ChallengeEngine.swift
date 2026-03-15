import Foundation

struct ChallengeScore {
    let challenge: Challenge
    let score: Double
}

final class ChallengeEngine {
    static let shared = ChallengeEngine()

    private let bank: [Challenge] = [
        Challenge(title: "Morning Momentum", description: "Read 10 pages before 10am", category: "time", difficulty: 1, rewardXP: 20, recommendedConditions: RecommendedConditions(timeOfDay: "morning")),
        Challenge(title: "Outdoor Reading", description: "Spend 15 minutes reading outside when you can", category: "outdoor", difficulty: 2, rewardXP: 35, recommendedConditions: RecommendedConditions(weather: "Clear", minTemperature: 60)),
        Challenge(title: "Night Owl", description: "Read after 9pm to unwind and relax", category: "time", difficulty: 2, rewardXP: 30, recommendedConditions: RecommendedConditions(timeOfDay: "night")),
        Challenge(title: "Sprint Reader", description: "Read 25 pages in one focused session", category: "sprint", difficulty: 3, rewardXP: 50, recommendedConditions: RecommendedConditions()),
        Challenge(title: "Cozy Tea Read", description: "Enjoy a cozy reading session with a warm drink", category: "indoor", difficulty: 1, rewardXP: 25, recommendedConditions: RecommendedConditions(weather: "Rain")),
        Challenge(title: "Lunchtime Bite", description: "Read during lunch for 15 minutes", category: "time", difficulty: 1, rewardXP: 15, recommendedConditions: RecommendedConditions(timeOfDay: "afternoon"))
    ]
    private let weatherService: WeatherService
    private let streak: Int

    init(weatherService: WeatherService = .shared, streak: Int = 1) {
        self.weatherService = weatherService
        self.streak = streak
    }

    func recommended(from bank: [Challenge], latitude: Double = 37.7749, longitude: Double = -122.4194, excludeIDs: Set<UUID> = []) async -> [Challenge] {
        do {
            let weather = try await weatherService.fetchWeather(lat: latitude, lon: longitude)
            // compute detailed scoring and explanation for each challenge
            let scoredWithExplanation: [ChallengeScore] = bank.map { challenge in
                let score = computeScore(for: challenge, weather: weather)

                var explanationParts: [String] = []
                explanationParts.append("weather: \(weather.weatherCondition) (\(Int(weather.temperature))°F)")
                if weather.rainProbability > 0.0 { explanationParts.append("rainProb: \(String(format: "%.2f", weather.rainProbability))") }
                explanationParts.append("randomness included")
                explanationParts.append("streak: \(streak)")

                let explanation = "Recommended because " + explanationParts.joined(separator: ", ") + "."

                var c = challenge
                c.recommendationExplanation = explanation

                return ChallengeScore(challenge: c, score: score)
            }

            // Filter out excluded IDs from bank
            let filteredBank = scoredWithExplanation.filter { !excludeIDs.contains($0.challenge.id) }

            // Prefer dynamic generation to keep recommendations fresh.
            // Keep at most 1 strong bank match (highest score) and fill the rest with dynamic challenges.
            var top: [Challenge] = []
            if let best = filteredBank.sorted(by: { $0.score > $1.score }).first {
                // only include if score is reasonably high
                if best.score > 0.5 {
                    top.append(best.challenge)
                }
            }

            // Fill remaining slots with dynamic challenges
            let desired = 5
            while top.count < desired {
                let dyn = await DynamicChallengeService.shared.generateDynamicChallenge()
                if !excludeIDs.contains(dyn.id) { top.append(dyn) }
            }

            // Ensure uniqueness by ID
            var seen = Set<UUID>()
            top = top.filter { seen.insert($0.id).inserted }

            return Array(top)
        } catch {
            return Array(bank.shuffled().prefix(4))
        }
    }

    // Compatibility helper used by ViewModel
    func recommend(limit: Int = 4, lat: Double = 37.7749, lon: Double = -122.4194, excludeIDs: Set<UUID> = []) async -> [Challenge] {
        // Aim to always return `limit` recommendations. Strategy:
        // 1) include at most one strong weather-based bank item
        // 2) include at least one word-based and one quote-based dynamic challenge when possible
        // 3) fill remaining slots with additional dynamic generation
        do {
            let weather = try await weatherService.fetchWeather(lat: lat, lon: lon)

            // Score bank and pick best weather match (if any)
            let scored: [ChallengeScore] = bank.map { ch in
                var c = ch
                let score = computeScore(for: ch, weather: weather)
                // attach a compact weather explanation for bank items
                let weatherText = "\(weather.weatherCondition), \(Int(weather.temperature))°F"
                c.recommendationExplanation = "Weather-based: \(weatherText); streak=\(streak)"
                return ChallengeScore(challenge: c, score: score)
            }.filter { !excludeIDs.contains($0.challenge.id) }

            var results: [Challenge] = []

            if let best = scored.max(by: { $0.score < $1.score }), best.score > 0.6 {
                results.append(best.challenge)
            }

            // Helper to append unique challenges
            func appendUnique(_ candidate: Challenge) {
                if results.contains(where: { $0.id == candidate.id }) { return }
                if results.contains(where: { $0.title == candidate.title }) { return }
                if excludeIDs.contains(candidate.id) { return }
                results.append(candidate)
            }

            // Ensure at least one word and one quote dynamic challenge when possible
            var attempts = 0
            var needWord = true
            var needQuote = true
            while results.count < limit && attempts < 20 {
                attempts += 1
                let dyn: Challenge
                if needWord {
                    dyn = await DynamicChallengeService.shared.generateRandomWordChallenge()
                } else if needQuote {
                    dyn = await DynamicChallengeService.shared.generateQuoteChallenge()
                } else {
                    // alternate generation for variety
                    dyn = await DynamicChallengeService.shared.generateDynamicChallenge()
                }

                // simple classification and clearer explanation
                var candidate = dyn
                let titleLower = candidate.title.lowercased()
                if titleLower.contains("explore a word") {
                    // extract word from title (after ':') or from description
                    let word: String
                    if let idx = candidate.title.firstIndex(of: ":") {
                        word = String(candidate.title[candidate.title.index(after: idx)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    } else if let found = candidate.description.components(separatedBy: ":").last {
                        word = found.trimmingCharacters(in: .whitespacesAndNewlines)
                    } else { word = "word" }
                    candidate.recommendationExplanation = "Word-based: try books related to \"\(word)\""
                    appendUnique(candidate)
                    needWord = false
                } else if titleLower.contains("quote") || titleLower.contains("inspired by") {
                    // extract a short excerpt from description
                    var excerpt = candidate.description
                    let marker = "Read a book inspired by this quote: "
                    if candidate.description.contains(marker), let range = candidate.description.range(of: marker) {
                        excerpt = String(candidate.description[range.upperBound...])
                    }
                    let snippet = excerpt.count > 80 ? String(excerpt.prefix(77)) + "..." : excerpt
                    candidate.recommendationExplanation = "Quote-based: inspired by \"\(snippet)\""
                    appendUnique(candidate)
                    needQuote = false
                } else {
                    candidate.recommendationExplanation = "Dynamic suggestion"
                    appendUnique(candidate)
                }
            }

            // If still short, fill from remaining bank highest scores (non-excluded)
            if results.count < limit {
                let remainingBank = scored.map { $0 }.sorted(by: { $0.score > $1.score })
                for s in remainingBank {
                    if results.count >= limit { break }
                    appendUnique(s.challenge)
                }
            }

            // Logging for diagnostics
            print("[ChallengeEngine] returning \(results.count) recommendations: \(results.map { $0.title })")
            return Array(results.prefix(limit))
        } catch {
            // On error, fall back to simple dynamic generation
            var fallback: [Challenge] = []
            var attempts = 0
            while fallback.count < limit && attempts < 20 {
                let d = await DynamicChallengeService.shared.generateDynamicChallenge()
                if !fallback.contains(where: { $0.title == d.title }) { fallback.append(d) }
                attempts += 1
            }
            print("[ChallengeEngine] fallback returning \(fallback.count) dynamic recommendations: \(fallback.map { $0.title })")
            return Array(fallback.prefix(limit))
        }
    }

    private func computeScore(for challenge: Challenge, weather: WeatherInfo) -> Double {
        var weatherScore = 0.0

        if let rc = challenge.recommendedConditions {
            if let minT = rc.minTemperature, weather.temperature >= minT { weatherScore += 0.5 }
            if let maxT = rc.maxTemperature, weather.temperature <= maxT { weatherScore += 0.5 }
            if let w = rc.weather, weather.weatherCondition.lowercased().contains(w.lowercased()) { weatherScore += 0.7 }
            if let tod = rc.timeOfDay {
                let hour = Calendar.current.component(.hour, from: Date())
                if tod.lowercased().contains("morning") && hour < 12 { weatherScore += 0.5 }
                if tod.lowercased().contains("night") && hour >= 21 { weatherScore += 0.5 }
            }
        }

        if weather.temperature > 75 {
            if challenge.title.lowercased().contains("outdoor") || challenge.description.lowercased().contains("outside") { weatherScore += 1.0 }
        }
        if weather.rainProbability > 0.2 {
            if challenge.description.lowercased().contains("tea") || challenge.description.lowercased().contains("cozy") { weatherScore += 1.0 }
        }
        if weather.temperature < 40 {
            if challenge.description.lowercased().contains("short") || challenge.title.lowercased().contains("sprint") { weatherScore += 0.8 }
        }

        let randomness = Double.random(in: 0...0.3)
        let streakModifier = log(Double(streak) + 1.0)

        return weatherScore + randomness + streakModifier
    }
}
