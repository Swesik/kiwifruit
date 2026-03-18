import Foundation

struct ApiNinjasWeatherInfo: Codable {
    let temp: Double?
    let wind_speed: Double?
    let wind_degrees: Double?
    let humidity: Double?
    let clouds: Int?
    let description: String?
}

final class ApiNinjasWeatherService {
    static let shared = ApiNinjasWeatherService()
    private init() {}

    private var apiKey: String? {
        if let env = ProcessInfo.processInfo.environment["API_NINJAS_KEY"], !env.isEmpty { return env }
        if let stored = UserDefaults.standard.string(forKey: "API_NINJAS_KEY"), !stored.isEmpty { return stored }
        if let info = Bundle.main.object(forInfoDictionaryKey: "API_NINJAS_KEY") as? String, !info.isEmpty { return info }
        if let url = Bundle.main.url(forResource: "Keys", withExtension: "plist"), let dict = NSDictionary(contentsOf: url), let val = dict["API_NINJAS_KEY"] as? String, !val.isEmpty { return val }
        return nil
    }

    func fetchWeather(lat: Double, lon: Double) async throws -> ApiNinjasWeatherInfo {
        guard let key = apiKey else { throw URLError(.userAuthenticationRequired) }
        var comps = URLComponents(string: "https://api.api-ninjas.com/v1/weather")!
        comps.queryItems = [URLQueryItem(name: "lat", value: String(lat)), URLQueryItem(name: "lon", value: String(lon))]
        guard let url = comps.url else { throw URLError(.badURL) }

        var req = URLRequest(url: url)
        req.setValue(key, forHTTPHeaderField: "X-Api-Key")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }

        // Attempt to decode relevant fields; API returns a flat JSON object
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let temp = obj["temp"] as? Double ?? (obj["temperature"] as? Double)
            let wind = obj["wind_speed"] as? Double
            let windDeg = obj["wind_degrees"] as? Double
            let humidity = obj["humidity"] as? Double
            let clouds = obj["cloud_pct"] as? Int
            let desc = obj["weather"] as? String ?? obj["description"] as? String
            return ApiNinjasWeatherInfo(temp: temp, wind_speed: wind, wind_degrees: windDeg, humidity: humidity, clouds: clouds, description: desc)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(ApiNinjasWeatherInfo.self, from: data)
    }
}
