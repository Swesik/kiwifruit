import Foundation

// Shared session model returned by the server
struct ReadingSessionModel: Codable {
    public let session_id: String?
    public let host: String?
    public let book_title: String?
    public let started_at: String?
    public let status: String?
    public let elapsed_seconds: Int?
}

// MARK: - Repository protocols

protocol SessionRepository {
    func fetchReadingSessions(host: String, status: String?) async throws -> [ReadingSessionModel]
}

protocol WeatherRepository {
    func fetchWeather(lat: Double, lon: Double) async throws -> ApiNinjasWeatherInfo
}

protocol GeoRepository {
    func reverseGeocode(lat: Double, lon: Double) async -> GeoInfo
}

protocol DynamicChallengeRepository {
    func generateRandomChallenges(count: Int) async -> [Challenge]
    func generateDynamicChallenge(lat: Double, lon: Double, streak: Int) async -> Challenge
}

protocol LLMRepository {
    func enhanceChallenge(_ c: Challenge, context: String) async -> OpenAIService.LLMResult?
}

protocol PersistenceRepository {
    func integer(forKey key: String) -> Int?
    func setInteger(_ value: Int, forKey key: String)
    func array(forKey key: String) -> [String]?
    func setArray(_ array: [String]?, forKey key: String)
    func data(forKey key: String) -> Data?
    func setData(_ data: Data?, forKey key: String)
    func dictionary(forKey key: String) -> [String:Double]?
    func setDictionary(_ dict: [String:Double]?, forKey key: String)
}

// MARK: - Default adapters

class ServerSessionRepository: SessionRepository {
    private let baseURL: String
    init(baseURL: String = "http://127.0.0.1:5000") {
        self.baseURL = baseURL
    }
    func fetchReadingSessions(host: String, status: String?) async throws -> [ReadingSessionModel] {
        var urlString = "\(baseURL)/reading_sessions?host=\(host)"
        if let s = status { urlString += "&status=\(s)" }
        guard let url = URL(string: urlString) else { return [] }
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        let sessions = try decoder.decode([ReadingSessionModel].self, from: data)
        return sessions
    }
}

class UserDefaultsPersistence: PersistenceRepository {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func integer(forKey key: String) -> Int? { return defaults.object(forKey: key) as? Int }
    func setInteger(_ value: Int, forKey key: String) { defaults.set(value, forKey: key) }
    func array(forKey key: String) -> [String]? { return defaults.array(forKey: key) as? [String] }
    func setArray(_ array: [String]?, forKey key: String) { defaults.set(array, forKey: key) }
    func data(forKey key: String) -> Data? { return defaults.data(forKey: key) }
    func setData(_ data: Data?, forKey key: String) { defaults.set(data, forKey: key) }
    func dictionary(forKey key: String) -> [String:Double]? { return defaults.dictionary(forKey: key) as? [String:Double] }
    func setDictionary(_ dict: [String:Double]?, forKey key: String) { defaults.set(dict, forKey: key) }
}

// MARK: - Conform existing services to protocols

extension ApiNinjasWeatherService: WeatherRepository {}
extension GeoService: GeoRepository {}
extension DynamicChallengeService: DynamicChallengeRepository {}
extension OpenAIService: LLMRepository {}

// The above extensions rely on the concrete classes' method names matching the protocol
// (they do in this codebase). ServerSessionRepository and UserDefaultsPersistence
// provide default implementations that can be injected into ViewModels.
