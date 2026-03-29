import Foundation
import Observation
import SwiftUI

@Observable
final class SessionStore {
    private let tokenKey = "kiwifruit.session.token"
    private let userKey = "kiwifruit.session.userId"
    private let userJSONKey = "kiwifruit.session.user"
    

    private(set) var token: String? = nil
    private(set) var userId: String? = nil
    private(set) var currentUser: User? = nil
    // Whether the saved token/session has been validated against the server
    private(set) var isValidSession: Bool = false
    // (no forced-login flag)

    let apiClient: RESTAPIClient

    // Default to local dev server. Change `baseURL` when pointing to a deployed API.
    // If your Flask server runs on a different port, set that here
    // or set the `KIWIFRUIT_API_URL` env var and pass it when creating the store.
    
    init(baseURL: URL = AppAPI.defaultBaseURL, previewLoggedIn: Bool = false) {
        self.apiClient = RESTAPIClient(baseURL: baseURL)
        if previewLoggedIn {
            isValidSession = true
            userId = MockData.sampleUser.id
            currentUser = MockData.sampleUser
            AppAPI.shared = MockAPIClient()
            apiClient.setAuthToken(nil)
            return
        }
        load()
        // Ensure global API client uses this REST client by default
        AppAPI.shared = apiClient
        apiClient.setAuthToken(token)
        // If we have a token loaded, validate it against the server.
        // Uses GET /users/me which requires auth — an expired/deleted token correctly fails
        // and triggers clear(), forcing the login screen.
        if token != nil {
            Task {
                do {
                    let user = try await fetchCurrentSessionUser()
                    self.currentUser = user
                    self.isValidSession = true
                } catch {
                    self.clear()
                }
            }
        }
    }

    func save(token: String, user: User?) {
        self.token = token
        self.currentUser = user
        self.userId = user?.id
        UserDefaults.standard.set(token, forKey: tokenKey)
        UserDefaults.standard.set(user?.id, forKey: userKey)
        if let user = user, let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: userJSONKey)
        } else {
            UserDefaults.standard.removeObject(forKey: userJSONKey)
        }
        apiClient.setAuthToken(token)
        AppAPI.shared = apiClient
        isValidSession = true
        print("SessionStore.save: saved token=\(token.prefix(8)).. userId=\(user?.id ?? "<nil>") username=\(user?.username ?? "<nil>")")
    }

    func clear() {
        token = nil
        userId = nil
        currentUser = nil
        isValidSession = false
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        UserDefaults.standard.removeObject(forKey: userJSONKey)
        apiClient.setAuthToken(nil)
        // Keep the REST client as the shared API so login/sign-up still talk to the backend.
        AppAPI.shared = apiClient
        print("SessionStore.clear: cleared session")
    }

    private func load() {
        if let token = UserDefaults.standard.string(forKey: tokenKey) {
            self.token = token
        }
        if let userIdStr = UserDefaults.standard.string(forKey: userKey) {
            self.userId = userIdStr
        }
        if let data = UserDefaults.standard.data(forKey: userJSONKey) {
            if let user = try? JSONDecoder().decode(User.self, from: data) {
                self.currentUser = user
            }
        }
        print("SessionStore.load: token=\(token != nil ? "present" : "nil") userId=\(userId ?? "nil") currentUser=\(currentUser?.username ?? "nil")")
    }

    /// Validates the stored token by calling GET /users/me (requires auth).
    /// Throws if the token is missing, expired, or not in the sessions table.
    private func fetchCurrentSessionUser() async throws -> User {
        let url = apiClient.baseURL.appendingPathComponent("/users/me")
        var req = URLRequest(url: url)
        if let token = token { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, resp) = try await apiClient.session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.userAuthenticationRequired)
        }
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase; decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(User.self, from: data)
    }

    // removed force-fresh-login API
}

// Environment key for SessionStore
private struct SessionStoreKey: EnvironmentKey {
    static let defaultValue: SessionStore = SessionStore()
}

extension EnvironmentValues {
    var sessionStore: SessionStore {
        get { self[SessionStoreKey.self] }
        set { self[SessionStoreKey.self] = newValue }
    }
}
