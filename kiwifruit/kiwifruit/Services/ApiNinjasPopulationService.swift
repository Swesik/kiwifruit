import Foundation

final class ApiNinjasPopulationService {
    static let shared = ApiNinjasPopulationService()
    private init() {}

    private var apiKey: String? {
        if let env = ProcessInfo.processInfo.environment["API_NINJAS_KEY"], !env.isEmpty { return env }
        if let stored = UserDefaults.standard.string(forKey: "API_NINJAS_KEY"), !stored.isEmpty { return stored }
        if let info = Bundle.main.object(forInfoDictionaryKey: "API_NINJAS_KEY") as? String, !info.isEmpty { return info }
        if let url = Bundle.main.url(forResource: "Keys", withExtension: "plist"), let dict = NSDictionary(contentsOf: url), let val = dict["API_NINJAS_KEY"] as? String, !val.isEmpty { return val }
        return nil
    }

    /// Try to fetch nearest population info by lat/lon. Returns a readable string like "Reykjavik (pop: 131000)" or "Unknown" on failure.
    func fetchPopulation(lat: Double, lon: Double) async throws -> String {
        guard let key = apiKey else { throw URLError(.userAuthenticationRequired) }
        var comps = URLComponents(string: "https://api.api-ninjas.com/v1/population")!
        comps.queryItems = [URLQueryItem(name: "lat", value: String(lat)), URLQueryItem(name: "lon", value: String(lon))]
        guard let url = comps.url else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.setValue(key, forHTTPHeaderField: "X-Api-Key")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }

        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let pop = obj["population"] as? Int, let name = obj["name"] as? String {
                return "\(name) (pop: \(pop))"
            }
            if let pop = obj["population"] as? Int {
                return "Population: \(pop)"
            }
        }

        if let s = String(data: data, encoding: .utf8) { return s }
        throw URLError(.cannotParseResponse)
    }
}
