import Foundation

struct WeatherInfo {
    let temperature: Double
    let weatherCondition: String
    let rainProbability: Double
}

// Minimal OpenWeather response models
private struct OWMain: Codable { let temp: Double }
private struct OWWeather: Codable { let main: String; let description: String }
private struct OWResponse: Codable {
    let main: OWMain
    let weather: [OWWeather]
    let rain: [String: Double]?
}

final class WeatherService {
    static let shared = WeatherService()
    private init() {}

    private var apiKey: String? {
        if let env = ProcessInfo.processInfo.environment["password"], !env.isEmpty { return env }
        if let stored = UserDefaults.standard.string(forKey: "password"), !stored.isEmpty { return stored }
        if let info = Bundle.main.object(forInfoDictionaryKey: "password") as? String, !info.isEmpty { return info }
        if let url = Bundle.main.url(forResource: "Keys", withExtension: "plist"), let dict = NSDictionary(contentsOf: url), let val = dict["password"] as? String, !val.isEmpty { return val }
        return nil
    }

    func fetchWeather(lat: Double = 37.7749, lon: Double = -122.4194) async throws -> WeatherInfo {
        guard let apiKey = apiKey else {
            return WeatherInfo(temperature: 68.0, weatherCondition: "Clear", rainProbability: 0.0)
        }

        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(lat)&lon=\(lon)&appid=\(apiKey)&units=imperial"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }

        let decoder = JSONDecoder()
        let root = try decoder.decode(OWResponse.self, from: data)

        let temp = root.main.temp
        let condition = root.weather.first?.main ?? "Clear"
        let rainProb = root.rain?["1h"] ?? 0.0

        return WeatherInfo(temperature: temp, weatherCondition: condition, rainProbability: rainProb)
    }
}
