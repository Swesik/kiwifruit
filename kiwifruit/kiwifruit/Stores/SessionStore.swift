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
    // Local guest sessions do not require server validation.
    private(set) var isValidSession: Bool = false
    // Whether the user is browsing as a guest (no account)
    private(set) var isGuest: Bool = false
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
        // Start directly in the local app experience. No stored account or network is needed.
        load()
        token = nil
        userId = nil
        currentUser = MockData.sampleUser
        isGuest = true
        isValidSession = true
        apiClient.setAuthToken(nil)
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
        isGuest = false
        isValidSession = true
        print("SessionStore.save: saved token=\(token.prefix(8)).. userId=\(user?.id ?? "<nil>") username=\(user?.username ?? "<nil>")")
    }

    func joinAsGuest() {
        clear()
        isGuest = true
        isValidSession = true
        print("SessionStore.joinAsGuest: entered guest mode")
    }

    func clear() {
        token = nil
        userId = nil
        currentUser = nil
        isValidSession = false
        isGuest = false
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        UserDefaults.standard.removeObject(forKey: userJSONKey)
        apiClient.setAuthToken(nil)
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
