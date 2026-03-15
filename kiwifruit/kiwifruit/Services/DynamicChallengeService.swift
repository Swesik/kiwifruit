import Foundation

/// Service to generate dynamic challenges using external APIs (api-ninjas). Keys optional; falls back to mock text when missing.
final class DynamicChallengeService {
    static let shared = DynamicChallengeService()
    private init() {}

    private var apiKey: String? {
        if let env = ProcessInfo.processInfo.environment["API_NINJAS_KEY"], !env.isEmpty { return env }
        if let url = Bundle.main.url(forResource: "Keys", withExtension: "plist"), let dict = NSDictionary(contentsOf: url), let val = dict["API_NINJAS_KEY"] as? String, !val.isEmpty { return val }
        return nil
    }

    private func randomXP() -> Int { Int.random(in: 5...25) }

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
        var c = Challenge(title: title, description: desc, category: "dynamic", difficulty: 1, progress: 0.0, rewardXP: xp, recommendedConditions: nil, state: .available)
        c.recommendationExplanation = "Quote-based suggestion"
        return c
    }

    func generateDynamicChallenge() async -> Challenge {
        if Bool.random() {
            return await generateRandomWordChallenge()
        } else {
            return await generateQuoteChallenge()
        }
    }
}
