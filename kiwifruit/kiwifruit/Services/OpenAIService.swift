import Foundation

final class OpenAIService {
    static let shared = OpenAIService()
    private init() {}

    private var apiKey: String? {
        if let env = ProcessInfo.processInfo.environment["OPEN_AI_KEY"], !env.isEmpty { return env }
        if let info = Bundle.main.object(forInfoDictionaryKey: "OPEN_AI_KEY") as? String, !info.isEmpty { return info }
        if let url = Bundle.main.url(forResource: "Keys", withExtension: "plist"), let dict = NSDictionary(contentsOf: url), let val = dict["OPEN_AI_KEY"] as? String, !val.isEmpty { return val }
        return nil
    }

    struct LLMResult: Codable {
        let title: String?
        let description: String?
        let hint: String?
    }

    struct PlaceResult: Codable {
        let country: String?
        let place: String?
    }

    /// Ask the LLM to rewrite/generate natural-sounding title/description/hint for a challenge.
    func enhanceChallenge(_ challenge: Challenge, context: String) async -> LLMResult? {
        guard let key = apiKey else { return nil }
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Prompt: ask for JSON with title, description, hint and use few-shot examples demonstrating location-aware rewriting.
        let system = "You are a concise creative writing assistant that rewrites short challenge titles and descriptions to be natural, evocative, and mobile-friendly. Use the provided location context and current date to make the challenge culturally or regionally relevant. Respond with JSON only, no commentary."
        let examples = """
        Example 1 Input Context: location='United States', date='March 17'
        Input title: 'Local Discovery Read', description: 'Temp: 60°F. Find a short piece that matches the mood and read for 20 minutes.'
        Desired JSON output: {"title":"Saint Patrick's Day Green Read","description":"It's Saint Patrick's Day in the United States — read something green or related to the holiday for 20 minutes.","hint":"Seek a short story or poem with green imagery."}

        Example 2 Input Context: location='Japan', date='December 31'
        Input title: 'Local Discovery Read', description: 'Cold evening — find a contemplative piece and read for 30 minutes.'
        Desired JSON output: {"title":"Year-End Reflection Read","description":"In Japan on New Year's Eve, choose a reflective essay or short story and read for 30 minutes to close the year.","hint":"Pick something about endings or renewal."}
        """
        let user = "Context: \(context). Examples:\n\(examples)\n\nNow rewrite this challenge:\nTitle: \(challenge.title)\nDescription: \(challenge.description)\nRespond with a JSON object with keys: \"title\", \"description\", \"hint\". Keep each field concise (under 200 chars)."

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [["role": "system", "content": system], ["role": "user", "content": user]],
            "temperature": 0.8,
            "max_tokens": 300
        ]

        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

            // Parse chat-completion response: choices[0].message.content
            if let top = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = top["choices"] as? [[String: Any]],
               let first = choices.first,
               let message = first["message"] as? [String: Any],
               let content = message["content"] as? String {
                // Try to decode JSON from content directly
                if let jsonData = content.data(using: .utf8), let decoded = try? JSONDecoder().decode(LLMResult.self, from: jsonData) {
                    return decoded
                }
                // Sometimes the assistant wraps JSON in markdown or text; attempt to extract the JSON object between the first '{' and last '}'
                if let start = content.firstIndex(of: "{"), let end = content.lastIndex(of: "}") {
                    let sub = String(content[start...end])
                    if let subData = sub.data(using: .utf8), let decoded2 = try? JSONDecoder().decode(LLMResult.self, from: subData) {
                        return decoded2
                    }
                }
                // As a last resort, try a very small heuristic: find lines starting with "title:", "description:", "hint:" and build a result
                var title: String?
                var desc: String?
                var hint: String?
                let lines = content.components(separatedBy: .newlines)
                for line in lines {
                    let l = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if l.lowercased().hasPrefix("title:") { title = String(l.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines) }
                    if l.lowercased().hasPrefix("description:") { desc = String(l.dropFirst(12)).trimmingCharacters(in: .whitespacesAndNewlines) }
                    if l.lowercased().hasPrefix("hint:") { hint = String(l.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines) }
                }
                if title != nil || desc != nil || hint != nil { return LLMResult(title: title, description: desc, hint: hint) }
            }
        } catch {
            return nil
        }

        return nil
    }

    /// Ask the LLM to infer a nearby place and country for a latitude/longitude.
    func lookupPlace(lat: Double, lon: Double) async -> PlaceResult? {
        guard let key = apiKey else { return nil }
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let system = "You are a helpful geolocation assistant. Given latitude and longitude, return a JSON object with keys 'country' and 'place' (nearest city or region). Respond with JSON only, no commentary."
        let examples = """
        Example: lat=40.71, lon=-74.00 -> {"country":"United States","place":"New York City"}
        Example: lat=35.68, lon=139.69 -> {"country":"Japan","place":"Tokyo"}
        """
        let user = "Coordinates: lat=\(String(format: \"%.6f\", lat)), lon=\(String(format: \"%.6f\", lon)). Examples:\n\(examples)\nReturn JSON: {\"country\":..., \"place\":...}"

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [["role": "system", "content": system], ["role": "user", "content": user]],
            "temperature": 0.0,
            "max_tokens": 80
        ]

        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

            if let top = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = top["choices"] as? [[String: Any]],
               let first = choices.first,
               let message = first["message"] as? [String: Any],
               let content = message["content"] as? String {
                // Try to decode JSON directly
                if let jsonData = content.data(using: .utf8), let decoded = try? JSONDecoder().decode(PlaceResult.self, from: jsonData) {
                    return decoded
                }
                // Try to extract between braces
                if let start = content.firstIndex(of: "{"), let end = content.lastIndex(of: "}") {
                    let sub = String(content[start...end])
                    if let subData = sub.data(using: .utf8), let decoded2 = try? JSONDecoder().decode(PlaceResult.self, from: subData) {
                        return decoded2
                    }
                }
            }
        } catch {
            return nil
        }
        return nil
    }
}
