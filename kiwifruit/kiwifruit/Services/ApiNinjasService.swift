import Foundation

struct RandomQuote: Codable {
    let quote: String
    let author: String?
}

struct Riddle: Codable {
    let question: String
    let answer: String?
}

final class ApiNinjasService {
    static let shared = ApiNinjasService()
    private init() {}

    private var apiKey: String? {
        if let env = ProcessInfo.processInfo.environment["API_NINJAS_KEY"], !env.isEmpty { return env }
        if let info = Bundle.main.object(forInfoDictionaryKey: "API_NINJAS_KEY") as? String, !info.isEmpty { return info }
        if let url = Bundle.main.url(forResource: "Keys", withExtension: "plist"), let dict = NSDictionary(contentsOf: url), let val = dict["API_NINJAS_KEY"] as? String, !val.isEmpty { return val }
        return nil
    }

    func fetchRandomQuote() async throws -> RandomQuote {
        guard let key = apiKey else { throw URLError(.userAuthenticationRequired) }
        guard let url = URL(string: "https://api.api-ninjas.com/v2/randomquotes") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.setValue(key, forHTTPHeaderField: "X-Api-Key")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }

        // API returns an array of quotes; decode as array and pick first
        let decoder = JSONDecoder()
        if let arr = try? decoder.decode([RandomQuote].self, from: data), let first = arr.first {
            return first
        }
        return try decoder.decode(RandomQuote.self, from: data)
    }

    func fetchRiddle() async throws -> Riddle {
        guard let key = apiKey else { throw URLError(.userAuthenticationRequired) }
        guard let url = URL(string: "https://api.api-ninjas.com/v1/riddles") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.setValue(key, forHTTPHeaderField: "X-Api-Key")
        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }

        let decoder = JSONDecoder()
        if let arr = try? decoder.decode([Riddle].self, from: data), let first = arr.first {
            return first
        }
        return try decoder.decode(Riddle.self, from: data)
    }
}
