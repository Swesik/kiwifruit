import Foundation

struct ChallengeScore {
    let challenge: Challenge
    let score: Double
}

final class ChallengeEngine {
    static let shared = ChallengeEngine()

    // Public canonical bank so IDs remain stable across recommendations
    let bank: [Challenge] = [
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

        // Enrich with personalized hints (quotes or riddles) using ApiNinjas
        var enriched: [Challenge] = Array(explained)

        await withTaskGroup(of: (Int, String?).self) { group in
            for (idx, ch) in enriched.enumerated() {
                group.addTask {
                    // Choose source: harder challenges -> riddles, else quotes
                    do {
                        if ch.difficulty >= 3 {
                            let r = try await ApiNinjasService.shared.fetchRiddle()
                            return (idx, "Riddle: \(r.question)")
                        } else {
                            let q = try await ApiNinjasService.shared.fetchRandomQuote()
                            let author = q.author ?? ""
                            return (idx, "\(q.quote) \(author.isEmpty ? "" : "— \(author)")")
                        }
                    } catch {
                        return (idx, nil)
                    }
                }
            }

            for await result in group {
                let (idx, hint) = result
                if let h = hint, enriched.indices.contains(idx) {
                    enriched[idx].hint = h
                }
            }
        }

        var result: [Challenge] = enriched

        // Dynamically generate some on-the-fly challenges using ApiNinjas (quotes/riddles)
        // These are separate from the canonical bank and are meant to provide fresh, ephemeral discoverables.
        var dynamic: [Challenge] = []
        await withTaskGroup(of: Challenge?.self) { dynGroup in
            // try two quotes
            for _ in 0..<2 {
                dynGroup.addTask {
                    do {
                        let q = try await ApiNinjasService.shared.fetchRandomQuote()
                        let title = "Quote Prompt"
                        let desc = "Reflect: \"\(q.quote)\""
                        return Challenge(title: title, description: desc, category: "prompt", difficulty: 1, rewardXP: 10, recommendedConditions: nil)
                    } catch {
                        return nil
                    }
                }
            }
            // one riddle for higher difficulty
            dynGroup.addTask {
                do {
                    let r = try await ApiNinjasService.shared.fetchRiddle()
                    let title = "Riddle Challenge"
                    let desc = "Solve: \(r.question)"
                    return Challenge(title: title, description: desc, category: "puzzle", difficulty: 3, rewardXP: 40, recommendedConditions: nil)
                } catch {
                    return nil
                }
            }

            for await maybe in dynGroup {
                if let c = maybe { dynamic.append(c) }
            }
        }

        // append dynamic items to the recommended set, but limit to 'limit'
        result.append(contentsOf: dynamic)
        return Array(result.prefix(limit))
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
