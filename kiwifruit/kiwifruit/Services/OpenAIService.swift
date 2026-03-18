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

    /// Ask the LLM to rewrite/generate natural-sounding title/description/hint for a challenge.
    func enhanceChallenge(_ challenge: Challenge, context: String) async -> LLMResult? {
        guard let key = apiKey else { return nil }
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Prompt: ask for JSON with title, description, hint
        let system = "You are a concise creative writing assistant that rewrites short challenge titles and descriptions to be natural, evocative, and mobile-friendly. Respond with JSON only."
        let user = "Given this challenge: title='\(challenge.title)', description='\(challenge.description)'. Context: \(context). Produce a JSON object with keys: \"title\" (short), \"description\" (one or two sentences), \"hint\" (one short hint). Keep text under 200 characters each."

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
}
