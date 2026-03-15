import Foundation

public actor ChallengeEngine {
    public static let shared = ChallengeEngine()
    private init() {}

    // Mock streak for now
    private let streak = 1

    // Static challenge bank
    public let bank: [Challenge] = [
        Challenge(title: "Morning Momentum", description: "Read 10 pages before 10am.", category: "time", difficulty: 1, rewardXP: 15, recommendedConditions: RecommendedConditions(timeOfDay: "morning")),
        Challenge(title: "Outdoor Reading", description: "Read outside for 15 minutes.", category: "outdoor", difficulty: 2, rewardXP: 25, recommendedConditions: RecommendedConditions(weather: "Clear", minTemperature: 60.0)),
        Challenge(title: "Night Owl", description: "Read after 9pm to unwind.", category: "time", difficulty: 1, rewardXP: 12, recommendedConditions: RecommendedConditions(timeOfDay: "night")),
        Challenge(title: "Sprint Reader", description: "Read 25 pages in one session.", category: "speed", difficulty: 3, rewardXP: 40, recommendedConditions: RecommendedConditions()),
        Challenge(title: "Cozy Pages", description: "Read 20 pages with a warm drink.", category: "indoor", difficulty: 1, rewardXP: 18, recommendedConditions: RecommendedConditions(weather: "Rain"))
    ]

    // On-the-fly generator (stretch)
    public func generateOnTheFly() -> Challenge {
        let pages = [5,10,15,20,25].randomElement() ?? 10
        let contexts = ["outside", "before bed", "during lunch", "while commuting"]
        let context = contexts.randomElement() ?? "during a break"
        return Challenge(title: "Read \(pages) pages \(context)", description: "A quick generated challenge: read \(pages) pages \(context).", category: "generated", difficulty: 1, rewardXP: max(10, pages))
    }

    // Recommendation scoring system
    public func recommend(limit: Int = 4, lat: Double = 37.7749, lon: Double = -122.4194) async -> [Challenge] {
        // fetch weather
        let weatherInfo: WeatherInfo
        do {
            weatherInfo = try await WeatherService.shared.fetchWeather(lat: lat, lon: lon)
        } catch {
            // fallback mock
            weatherInfo = WeatherInfo(temperature: 68.0, weatherCondition: "Clear", rainProbability: 0.0)
        }

        let rndBase = Double.random(in: 0...0.3)

        func weatherScore(for c: Challenge) -> Double {
            var score = 0.0
            if let cond = c.recommendedConditions?.weather?.lowercased() {
                if weatherInfo.weatherCondition.lowercased().contains(cond) { score += 0.8 }
            }
            if let minT = c.recommendedConditions?.minTemperature {
                if weatherInfo.temperature >= minT { score += 0.4 }
            }
            if let maxT = c.recommendedConditions?.maxTemperature {
                if weatherInfo.temperature <= maxT { score += 0.4 }
            }
            // example heuristic rules
            if weatherInfo.temperature > 75 && c.category == "outdoor" { score += 1.0 }
            if weatherInfo.weatherCondition.lowercased().contains("rain") && c.category == "indoor" { score += 1.0 }
            if weatherInfo.temperature < 40 && c.category == "speed" { score += 0.6 }
            return score
        }

        let streakModifier = log(Double(streak) + 1.0)

        // score challenges
        var scored: [(Challenge, Double)] = []
        for c in bank {
            let w = weatherScore(for: c)
            let randomness = Double.random(in: 0...0.3)
            let total = w + randomness + streakModifier
            scored.append((c, total))
        }

        // include one on-the-fly generated for variety
        var candidates = scored.sorted { $0.1 > $1.1 }.map { $0.0 }
        candidates.append(generateOnTheFly())

        return Array(candidates.prefix(limit))
    }
}
import Foundation

public struct ChallengeScore {
    public let challenge: Challenge
    public let score: Double
}

public class ChallengeEngine {
    private let weatherService: WeatherService
    private let streak: Int

    public init(weatherService: WeatherService = .shared, streak: Int = 1) {
        self.weatherService = weatherService
        self.streak = streak
    }

    // Main entry: returns ranked recommendations
    public func recommended(from bank: [Challenge], latitude: Double = 37.7749, longitude: Double = -122.4194) async -> [Challenge] {
        do {
            let weather = try await weatherService.fetchWeather(lat: latitude, lon: longitude)
            let scored = bank.map { (challenge) -> ChallengeScore in
                let score = computeScore(for: challenge, weather: weather)
                return ChallengeScore(challenge: challenge, score: score)
            }

            let top = scored.sorted { $0.score > $1.score }.prefix(5).map { $0.challenge }
            return Array(top)
        } catch {
            // fallback: shuffle and pick
            return Array(bank.shuffled().prefix(4))
        }
    }

    private func computeScore(for challenge: Challenge, weather: WeatherInfo) -> Double {
        var weatherScore = 0.0

        if let rc = challenge.recommendedConditions {
            if let minT = rc.minTemperature, weather.temperature >= minT { weatherScore += 0.5 }
            if let maxT = rc.maxTemperature, weather.temperature <= maxT { weatherScore += 0.5 }
            if let w = rc.weather, weather.weatherCondition.lowercased().contains(w.lowercased()) { weatherScore += 0.7 }
            if let tod = rc.timeOfDay {
                // Simple time-based scoring: morning/afternoon/night
                let hour = Calendar.current.component(.hour, from: Date())
                if tod.lowercased().contains("morning") && hour < 12 { weatherScore += 0.5 }
                if tod.lowercased().contains("night") && hour >= 21 { weatherScore += 0.5 }
            }
        }

        // Temperature heuristics
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
