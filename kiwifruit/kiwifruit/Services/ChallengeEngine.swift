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
        let rec = await recommended(from: bank, latitude: lat, longitude: lon, excludeIDs: excludeIDs)
        // Build explanations per challenge
            var rec = await recommended(from: bank, latitude: lat, longitude: lon, excludeIDs: excludeIDs)
            // If the engine returned fewer than requested, generate additional dynamic challenges to fill the gap
            if rec.count < limit {
                var attempts = 0
                while rec.count < limit && attempts < 10 {
                    let dyn = await DynamicChallengeService.shared.generateDynamicChallenge()
                    if !excludeIDs.contains(dyn.id) && !rec.contains(where: { $0.title == dyn.title }) {
                        rec.append(dyn)
                    }
                    attempts += 1
                }
            }

            // Build explanations per challenge and trim to requested limit
            let explained = rec.prefix(limit).map { ch -> Challenge in
            var c = ch
            let weatherText = "weather=\(c.recommendedConditions?.weather ?? "any"), tempRange=\(String(describing: c.recommendedConditions?.minTemperature))..\(String(describing: c.recommendedConditions?.maxTemperature))"
            let randomnessNote = "random factor used"
            let streakNote = "streak=\(streak)"
            c.recommendationExplanation = "Recommended because of: \(weatherText); \(randomnessNote); \(streakNote)"
            return c
        }

        return Array(explained)
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
