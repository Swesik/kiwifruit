import Foundation

struct ChallengeScore {
    let challenge: Challenge
    let score: Double
}

final class ChallengeEngine {
    static let shared = ChallengeEngine()

    private let bank: [Challenge] = [
        Challenge(title: "Morning Momentum", description: "Read 10 pages before 10am", category: "time", difficulty: 1, rewardXP: 20, recommendedConditions: RecommendedConditions(timeOfDay: "morning")),
        Challenge(title: "Outdoor Reading", description: "Read outside for 15 minutes", category: "outdoor", difficulty: 2, rewardXP: 35, recommendedConditions: RecommendedConditions(weather: "Clear", minTemperature: 60)),
        Challenge(title: "Night Owl", description: "Read after 9pm for 20 minutes", category: "time", difficulty: 2, rewardXP: 30, recommendedConditions: RecommendedConditions(timeOfDay: "night")),
        Challenge(title: "Sprint Reader", description: "Read 25 pages in one session", category: "sprint", difficulty: 3, rewardXP: 50, recommendedConditions: RecommendedConditions()),
        Challenge(title: "Cozy Tea Read", description: "Read 20 pages with tea while it's raining", category: "indoor", difficulty: 1, rewardXP: 25, recommendedConditions: RecommendedConditions(weather: "Rain")),
        Challenge(title: "Lunchtime Bite", description: "Read during lunch for 15 minutes", category: "time", difficulty: 1, rewardXP: 15, recommendedConditions: RecommendedConditions(timeOfDay: "afternoon"))
    ]
    private let weatherService: WeatherService
    private let streak: Int

    init(weatherService: WeatherService = .shared, streak: Int = 1) {
        self.weatherService = weatherService
        self.streak = streak
    }

    func recommended(from bank: [Challenge], latitude: Double = 37.7749, longitude: Double = -122.4194) async -> [Challenge] {
        do {
            let weather = try await weatherService.fetchWeather(lat: latitude, lon: longitude)
            let scored = bank.map { (challenge) -> ChallengeScore in
                let score = computeScore(for: challenge, weather: weather)
                return ChallengeScore(challenge: challenge, score: score)
            }

            let top = scored.sorted { $0.score > $1.score }.prefix(5).map { $0.challenge }
            return Array(top)
        } catch {
            return Array(bank.shuffled().prefix(4))
        }
    }

    // Compatibility helper used by ViewModel
    func recommend(limit: Int = 4, lat: Double = 37.7749, lon: Double = -122.4194) async -> [Challenge] {
        let rec = await recommended(from: bank, latitude: lat, longitude: lon)
        // Build explanations per challenge
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
