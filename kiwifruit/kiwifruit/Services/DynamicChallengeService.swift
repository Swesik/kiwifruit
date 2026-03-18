import Foundation

/// Service to generate dynamic challenges using external APIs (api-ninjas). Keys optional; falls back to mock text when missing.
final class DynamicChallengeService {
    static let shared = DynamicChallengeService()
    private init() {}

    private var apiKey: String? {
        if let env = ProcessInfo.processInfo.environment["API_NINJAS_KEY"], !env.isEmpty { return env }
        if let stored = UserDefaults.standard.string(forKey: "API_NINJAS_KEY"), !stored.isEmpty { return stored }
        if let url = Bundle.main.url(forResource: "Keys", withExtension: "plist"), let dict = NSDictionary(contentsOf: url), let val = dict["API_NINJAS_KEY"] as? String, !val.isEmpty { return val }
        return nil
    }

    private func randomXP() -> Int { Int.random(in: 5...25) }

    private func randomCoordinate() -> (Double, Double) {
        // Uniform random lat/lon; could be improved to bias to land areas
        let lat = Double.random(in: -85.0...85.0)
        let lon = Double.random(in: -180.0...180.0)
        return (lat, lon)
    }

    // Public accessor for a random coordinate so callers can ensure consistency across multiple API calls
    func randomCoordinatePublic() -> (Double, Double) { randomCoordinate() }

    /// Generate multiple dynamic challenges for the same location using a single weather API call (if available).
    func generateDynamicChallengesForLocation(lat: Double, lon: Double, streak: Int, count: Int) async -> [Challenge] {
        var results: [Challenge] = []

        var weatherInfo: ApiNinjasWeatherInfo? = nil
        if apiKey != nil {
            do {
                weatherInfo = try await ApiNinjasWeatherService.shared.fetchWeather(lat: lat, lon: lon)
            } catch {
                weatherInfo = nil
            }
        }

        for i in 0..<count {
            // Slight variation per item
            let difficulty = difficultyForStreak(streak)
            let baseXP = 10 + difficulty * 10
            let xp = rewardForDifficulty(baseXP + i*5, streak: streak)

            if let w = weatherInfo {
                let temp = w.temp ?? 70.0
                let wind = w.wind_speed ?? 0.0
                let humidity = w.humidity ?? 50.0
                let desc = w.description ?? ""

                var challengeTitle = "Local Discovery Read"
                var challengeDesc = "Temp: \(Int(temp))°F, Wind: \(String(format: "%.1f", wind)) mph, Humidity: \(Int(humidity))%. \(desc)"

                // create variations by index
                switch i % 4 {
                case 0:
                    challengeTitle = "Ambient Read: Experience the local weather"
                    challengeDesc += " Find a short piece that matches the mood and read for 20 minutes."
                case 1:
                    challengeTitle = "Micro-Challenge: Weather Sketch"
                    challengeDesc += " Read a short passage and write a 3-sentence reflection inspired by the weather."
                case 2:
                    challengeTitle = "Focused Session: Shelter & Read"
                    challengeDesc += " Choose a comfortable spot and read for 25 minutes."
                default:
                    challengeTitle = "Local Riddle Prompt"
                    challengeDesc += " Solve a small riddle or find a poem inspired by the scene."
                }

                var c = Challenge(title: challengeTitle, description: challengeDesc, category: "dynamic", difficulty: difficulty, progress: 0.0, rewardXP: xp, recommendedConditions: nil, state: .available)
                c.recommendationExplanation = "Generated from ApiNinjas weather."
                c.hint = "Weather snapshot: Temp=\(Int(temp))°F Wind=\(String(format: "%.1f", wind))mph"

                // Build location-aware context (include lat/lon and approximate date) for the LLM to craft a culturally-aware challenge
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .long
                let today = dateFormatter.string(from: Date())
                let locationContext = "lat=\(String(format: "%.2f", lat)), lon=\(String(format: "%.2f", lon)); date=\(today)"

                // Ask LLM to enhance the challenge using the location context (few-shot handled in OpenAIService)
                if let enhanced = await OpenAIService.shared.enhanceChallenge(c, context: locationContext) {
                    if let t = enhanced.title { c.title = t }
                    if let d = enhanced.description { c.description = d }
                    if let h = enhanced.hint { c.hint = h }
                }

                results.append(c)
            } else {
                // fallback variations using quotes/words
                if i % 2 == 0 {
                    var c = await generateRandomWordChallenge()
                    c.difficulty = difficulty
                    c.rewardXP = xp
                    results.append(c)
                } else {
                    var c = await generateQuoteChallenge()
                    c.difficulty = difficulty
                    c.rewardXP = xp
                    results.append(c)
                }
            }
        }

        return results
    }

    /// Generate N random challenges using available APIs. Always prefer live API content; never return static generic bank items.
    func generateRandomChallenges(count: Int) async -> [Challenge] {
        var results: [Challenge] = []
        for i in 0..<count {
            // Attempt weather-driven challenge occasionally, otherwise quote/word driven
            if Bool.random() {
                let (lat, lon) = randomCoordinate()
                let c = await generateDynamicChallenge(lat: lat, lon: lon, streak: 1)
                results.append(c)
            } else if i % 2 == 0 {
                let c = await generateRandomWordChallenge()
                results.append(c)
            } else {
                let c = await generateQuoteChallenge()
                results.append(c)
            }
        }
        return results
    }

    private func difficultyForStreak(_ streak: Int) -> Int {
        // Increase difficulty slowly with streak (every 5 days increases difficulty)
        return min(5, 1 + (streak / 5))
    }

    private func rewardForDifficulty(_ base: Int, streak: Int) -> Int {
        return Int(Double(base) * (1.0 + Double(min(20, streak)) / 20.0))
    }

    func generateRandomWordChallenge() async -> Challenge {
        let word: String
        if let key = apiKey {
            var req = URLRequest(url: URL(string: "https://api.api-ninjas.com/v2/randomword")!)
            req.setValue(key, forHTTPHeaderField: "X-Api-Key")
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                if (response as? HTTPURLResponse)?.statusCode == 200, let s = String(data: data, encoding: .utf8) {
                    word = s.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: "")
                } else { word = "story" }
            } catch { word = "story" }
        } else {
            word = ["journey","mystery","garden","memory","ocean"].randomElement() ?? "story"
        }

        let xp = randomXP()
        let title = "Explore a word: \(word)"
        let desc = "Read a book related to the word: \(word). Dynamic XP: \(xp)."
        var c = Challenge(title: title, description: desc, category: "dynamic", difficulty: 1, progress: 0.0, rewardXP: xp, recommendedConditions: nil, state: .available)
        c.recommendationExplanation = "Generated via Random Word API (word=\(word))."
        return c
    }

    func generateQuoteChallenge() async -> Challenge {
        let quoteText: String
        if let key = apiKey {
            var req = URLRequest(url: URL(string: "https://api.api-ninjas.com/v2/quotes")!)
            req.setValue(key, forHTTPHeaderField: "X-Api-Key")
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                if (response as? HTTPURLResponse)?.statusCode == 200 {
                    // API returns JSON array of quotes
                    if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String:Any]], let first = arr.first, let q = first["quote"] as? String {
                        quoteText = q
                    } else { quoteText = "Be curious and read." }
                } else { quoteText = "Be curious and read." }
            } catch { quoteText = "Be curious and read." }
        } else {
            quoteText = ["Read to find yourself.", "Words change worlds.", "Seek a short escape."].randomElement() ?? "Be curious and read."
        }

        let xp = randomXP()
        // create a short excerpt for title so quote-based challenges have unique titles
        let excerpt = quoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let short = excerpt.count > 30 ? String(excerpt.prefix(27)) + "..." : excerpt
        let title = "Inspired: \"\(short)\""
        let desc = "Read a book inspired by this quote: \(quoteText). Dynamic XP: \(xp)."
        var c = Challenge(title: title, description: desc, category: "quote", difficulty: 1, progress: 0.0, rewardXP: xp, recommendedConditions: nil, state: .available)
        c.recommendationExplanation = "Quote-based suggestion"
        // Enhance with LLM if available
        if let enhanced = await OpenAIService.shared.enhanceChallenge(c, context: "quote excerpt") {
            if let t = enhanced.title { c.title = t }
            if let d = enhanced.description { c.description = d }
            if let h = enhanced.hint { c.hint = h }
        }
        return c
    }

    func generateDynamicChallenge() async -> Challenge {
        // Default: generate using a random coordinate so we exercise the weather API when available
        let (lat, lon) = randomCoordinate()
        return await generateDynamicChallenge(lat: lat, lon: lon, streak: 1)
    }

    func generateDynamicChallenge(streak: Int) async -> Challenge {
        let (lat, lon) = randomCoordinate()
        return await generateDynamicChallenge(lat: lat, lon: lon, streak: streak)
    }

    func generateDynamicChallenge(lat: Double, lon: Double, streak: Int) async -> Challenge {
        // If weather API available, use it to tailor the challenge
        if apiKey != nil {
            do {
                let w = try await ApiNinjasWeatherService.shared.fetchWeather(lat: lat, lon: lon)
                // build challenge based on weather
                let temp = w.temp ?? 70.0
                let wind = w.wind_speed ?? 0.0
                let humidity = w.humidity ?? 50.0
                let desc = w.description ?? ""

                let difficulty = difficultyForStreak(streak)
                let baseXP = 10 + difficulty * 10
                let xp = rewardForDifficulty(baseXP, streak: streak)

                var title = "Explore: Local weather at (\(String(format: "%.2f", lat)), \(String(format: "%.2f", lon)))"
                var details = "Temp: \(Int(temp))°F, Wind: \(String(format: "%.1f", wind)) mph, Humidity: \(Int(humidity))%"
                if !desc.isEmpty { details += " — \(desc)" }

                // pick task type depending on conditions
                var challengeTitle = title
                var challengeDesc = "Based on local weather: \(details)."
                if temp > 75.0 {
                    challengeTitle = "Sunny Read: Take it outside"
                    challengeDesc += " It's warm — try a 20-minute outdoor reading session."
                } else if (w.wind_speed ?? 0) > 20 {
                    challengeTitle = "Windy Focus Session"
                    challengeDesc += " Windy conditions — find a sheltered spot and read for 15 minutes."
                } else if (w.humidity ?? 0) > 80 || (w.description?.lowercased().contains("rain") ?? false) {
                    challengeTitle = "Cozy Indoor Read"
                    challengeDesc += " Cozy time — make a warm drink and read for 25 minutes."
                } else {
                    challengeTitle = "Local Discovery Read"
                    challengeDesc += " Find a short story inspired by the local vibes and read for 20 minutes."
                }

                var c = Challenge(title: challengeTitle, description: challengeDesc, category: "weather", difficulty: difficulty, progress: 0.0, rewardXP: xp, recommendedConditions: nil, state: .available)
                c.recommendationExplanation = "Generated from ApiNinjas weather at (\(String(format: "%.2f", lat)), \(String(format: "%.2f", lon)))."
                c.hint = "Weather snapshot: \(details)"

                // Use LLM to enhance text if available
                if let enhanced = await OpenAIService.shared.enhanceChallenge(c, context: "temp=\(Int(temp)), wind=\(String(format: "%.1f", wind))") {
                    if let t = enhanced.title { c.title = t }
                    if let d = enhanced.description { c.description = d }
                    if let h = enhanced.hint { c.hint = h }
                }

                return c
            } catch {
                // fall through to simpler generation on error
            }
        }

        // Fallback: use quote or random word
        if Bool.random() {
            var c = await generateRandomWordChallenge()
            c.difficulty = difficultyForStreak(streak)
            c.rewardXP = rewardForDifficulty(c.rewardXP, streak: streak)
            return c
        } else {
            var c = await generateQuoteChallenge()
            c.difficulty = difficultyForStreak(streak)
            c.rewardXP = rewardForDifficulty(c.rewardXP, streak: streak)
            if let enhanced = await OpenAIService.shared.enhanceChallenge(c, context: "quote excerpt") {
                if let t = enhanced.title { c.title = t }
                if let d = enhanced.description { c.description = d }
                if let h = enhanced.hint { c.hint = h }
            }
            return c
        }
    }
}
