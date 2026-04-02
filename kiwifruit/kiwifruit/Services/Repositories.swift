import Foundation

// Lightweight session DTO for simple repository consumers.
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

protocol GeoRepository {
    func reverseGeocode(lat: Double, lon: Double) async -> GeoInfo
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
    private let authTokenProvider: () -> String?

    init(
        baseURL: String = "http://127.0.0.1:5000",
        authTokenProvider: @escaping () -> String? = { nil }
    ) {
        self.baseURL = baseURL
        self.authTokenProvider = authTokenProvider
    }

    func fetchReadingSessions(host: String, status: String?) async throws -> [ReadingSessionModel] {
        guard let url = URL(string: "\(baseURL)/reading-sessions/friends") else { return [] }
        var request = URLRequest(url: url)
        if let token = authTokenProvider(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        let friendSessions = try decoder.decode([ActiveFriendSession].self, from: data)

        return friendSessions
            .map { active in
                ReadingSessionModel(
                    session_id: active.session.id,
                    host: active.session.host.username,
                    book_title: active.session.bookTitle,
                    started_at: ISO8601DateFormatter().string(from: active.session.startedAt),
                    status: active.session.status,
                    elapsed_seconds: active.hostElapsedSeconds
                )
            }
            .filter { model in
                let hostMatches = host.isEmpty || model.host == host
                let statusMatches = (status == nil || status?.isEmpty == true) || model.status == status
                return hostMatches && statusMatches
            }
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

extension GeoService: GeoRepository {}
