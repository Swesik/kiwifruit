import Foundation

// Helper to build multipart body
fileprivate extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

protocol APIClientProtocol {
    func fetchPosts(page: Int, pageSize: Int) async throws -> [Post]
    /// Create a post. `imageData` is optional; if provided the client should upload it.
    func createPost(authorId: String, imageData: Data?, caption: String?) async throws -> Post
    func createSession(username: String, password: String) async throws -> (token: String, user: User)
    func createAccount(username: String, password: String, fullname: String?) async throws -> User
    func likePost(_ postId: String) async throws -> Int
    func unlikePost(_ postId: String) async throws -> Int
    func followUser(_ username: String) async throws -> Void
    func unfollowUser(_ username: String) async throws -> Void
    func fetchFollowers(username: String) async throws -> [User]
    func fetchFollowing(username: String) async throws -> [User]
    func fetchComments(postId: String) async throws -> [Comment]
    func createComment(postId: String, text: String) async throws -> Void
    func deleteComment(commentId: String) async throws -> Void
    func deletePost(_ postId: String) async throws -> Void
    func searchBooks(query: String) async throws -> [BookSearchResult]
    // MARK: - Reading Sessions
    /// Creates a new reading session for the current user and returns the persisted session object.
    func startReadingSession(bookTitle: String) async throws -> ReadingSession
    /// Marks the session as completed. Elapsed time is calculated server-side.
    func endReadingSession(sessionId: String, pagesRead: Int?) async throws -> Void
    /// Pauses an active session; server accumulates elapsed time via julianday.
    func pauseReadingSession(sessionId: String) async throws -> Void
    /// Resumes a paused session; server records resumed_at for the next interval.
    func resumeReadingSession(sessionId: String) async throws -> Void
    /// Returns all active/paused sessions belonging to users the current user follows.
    func fetchActiveFriendSessions() async throws -> [ActiveFriendSession]
    /// Adds the current user as a participant of the given session.
    func joinReadingSession(sessionId: String) async throws -> ReadingSession
    /// Removes the current user from a session they joined (does not end the host's session).
    func leaveReadingSession(sessionId: String, elapsedSeconds: Int, pagesRead: Int?, bookTitle: String?) async throws -> Void
    func sendBookScan(barcode: String?, ocrText: String?) async throws -> BookScanResponse
    /// Returns completed reading sessions for the current user (used for challenge progress).
    func fetchSessionHistory() async throws -> [SessionHistoryEntry]
    /// Records a book as fully read by the current user.
    func markBookCompleted(title: String) async throws
    /// Returns books the current user has marked as completed.
    func fetchCompletedBooks() async throws -> [CompletedBookEntry]
    /// Returns the current user's reading preferences.
    func fetchPreferences() async throws -> UserPreferences
    /// Creates or updates the current user's reading preferences.
    func savePreferences(_ preferences: UserPreferences) async throws
}

/// Simple in-memory/mock client used in previews and when no backend is configured.
final class MockAPIClient: APIClientProtocol {
    func fetchPosts(page: Int, pageSize: Int) async throws -> [Post] {
        try await Task.sleep(nanoseconds: 200 * 1_000_000)
        return MockData.makePosts(count: pageSize, page: page)
    }

    func createPost(authorId: String, imageData: Data?, caption: String?) async throws -> Post {
        try await Task.sleep(nanoseconds: 150 * 1_000_000)
        let imageURL: URL
        if let data = imageData {
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("kiwi_upload_\(UUID().uuidString).jpg")
            try data.write(to: tmp)
            imageURL = tmp
        } else {
            imageURL = URL(string: "https://picsum.photos/seed/kiwi/600/600")!
        }
        return Post(id: UUID().uuidString, author: MockData.sampleUser, imageURL: imageURL, caption: caption, likes: 0, createdAt: Date())
    }

    func likePost(_ postId: String) async throws -> Int { try await Task.sleep(nanoseconds: 80 * 1_000_000); return Int.random(in: 1...500) }
    func unlikePost(_ postId: String) async throws -> Int { try await Task.sleep(nanoseconds: 80 * 1_000_000); return Int.random(in: 0...499) }
    func followUser(_ username: String) async throws -> Void { try await Task.sleep(nanoseconds: 40 * 1_000_000); return }
    func unfollowUser(_ username: String) async throws -> Void { try await Task.sleep(nanoseconds: 40 * 1_000_000); return }
    func fetchFollowers(username: String) async throws -> [User] { try await Task.sleep(nanoseconds: 60 * 1_000_000); return [] }
    func fetchFollowing(username: String) async throws -> [User] { try await Task.sleep(nanoseconds: 60 * 1_000_000); return [] }

    func createSession(username: String, password: String) async throws -> (token: String, user: User) {
        try await Task.sleep(nanoseconds: 120 * 1_000_000)
        return (token: UUID().uuidString, user: MockData.sampleUser)
    }

    func createAccount(username: String, password: String, fullname: String?) async throws -> User {
        try await Task.sleep(nanoseconds: 150 * 1_000_000)
        return MockData.sampleUser
    }

    func fetchComments(postId: String) async throws -> [Comment] { try await Task.sleep(nanoseconds: 80 * 1_000_000); return MockData.makeComments(for: postId) }
    func createComment(postId: String, text: String) async throws -> Void { try await Task.sleep(nanoseconds: 80 * 1_000_000); return }
    func deleteComment(commentId: String) async throws -> Void { try await Task.sleep(nanoseconds: 60 * 1_000_000); return }
    func deletePost(_ postId: String) async throws -> Void { try await Task.sleep(nanoseconds: 120 * 1_000_000); return }
    func searchBooks(query: String) async throws -> [BookSearchResult] {
        try await Task.sleep(nanoseconds: 120 * 1_000_000)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }

        return [
            BookSearchResult(
                id: UUID().uuidString,
                title: "Mock result for \"\(trimmed)\"",
                authors: ["Kiwi Fruit"],
                isbn13: nil
            )
        ]
    }

    func startReadingSession(bookTitle: String) async throws -> ReadingSession {
        try await Task.sleep(nanoseconds: 120 * 1_000_000)
        return ReadingSession(
            id: UUID().uuidString,
            host: MockData.sampleUser,
            bookTitle: bookTitle,
            startedAt: Date(),
            status: "active",
            participants: []
        )
    }

    func endReadingSession(sessionId: String, pagesRead: Int?) async throws { try await Task.sleep(nanoseconds: 80 * 1_000_000) }
    func pauseReadingSession(sessionId: String) async throws { try await Task.sleep(nanoseconds: 50 * 1_000_000) }
    func resumeReadingSession(sessionId: String) async throws { try await Task.sleep(nanoseconds: 50 * 1_000_000) }

    func fetchActiveFriendSessions() async throws -> [ActiveFriendSession] {
        try await Task.sleep(nanoseconds: 100 * 1_000_000)
        let alice = User(id: "alice-id", username: "alice", displayName: "Alice", avatarURL: nil)
        let james = User(id: "james-id", username: "james", displayName: "James", avatarURL: nil)
        return [
            ActiveFriendSession(
                session: ReadingSession(id: "s1", host: alice, bookTitle: "Dune", startedAt: Date().addingTimeInterval(-1800), status: "active", participants: []),
                hostElapsedSeconds: 1800
            ),
            ActiveFriendSession(
                session: ReadingSession(id: "s2", host: james, bookTitle: "1984", startedAt: Date().addingTimeInterval(-3600), status: "active", participants: []),
                hostElapsedSeconds: 3600
            ),
        ]
    }

    func joinReadingSession(sessionId: String) async throws -> ReadingSession {
        try await Task.sleep(nanoseconds: 100 * 1_000_000)
        return ReadingSession(id: sessionId, host: MockData.sampleUser, bookTitle: "Mock Book", startedAt: Date().addingTimeInterval(-600), status: "active", participants: [MockData.sampleUser])
    }

    func leaveReadingSession(sessionId: String, elapsedSeconds: Int, pagesRead: Int?, bookTitle: String?) async throws { try await Task.sleep(nanoseconds: 80 * 1_000_000) }
    func fetchSessionHistory() async throws -> [SessionHistoryEntry] { return [] }
    func markBookCompleted(title: String) async throws {}
    func fetchCompletedBooks() async throws -> [CompletedBookEntry] { return [] }
    func fetchPreferences() async throws -> UserPreferences { return .default }
    func savePreferences(_ preferences: UserPreferences) async throws {}
    func sendBookScan(barcode: String?, ocrText: String?) async throws -> BookScanResponse {
        try await Task.sleep(nanoseconds: 120 * 1_000_000)
        return BookScanResponse(
            status: "ok",
            barcode: barcode,
            ocrText: ocrText
        )
    }
}

/// A simple REST API client implementation using URLSession and async/await.
final class RESTAPIClient: APIClientProtocol {
    let baseURL: URL
    let session: URLSession
    private(set) var authToken: String?

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    private func debugLogRequest(_ req: URLRequest) {
        var out = "API Request -> "
        out += "\(req.httpMethod ?? "?") "
        out += "\(req.url?.absoluteString ?? "<no-url>")"
        if let headers = req.allHTTPHeaderFields, !headers.isEmpty { out += " headers:\(headers)" }
        if let body = req.httpBody, let s = String(data: body, encoding: .utf8) { out += " body:\(s)" }
        print(out)
    }

    func setAuthToken(_ token: String?) { self.authToken = token }

    func fetchPosts(page: Int, pageSize: Int) async throws -> [Post] {
        var comps = URLComponents(url: baseURL.appendingPathComponent("/posts"), resolvingAgainstBaseURL: false)!
        comps.queryItems = [ URLQueryItem(name: "page", value: String(page)), URLQueryItem(name: "pageSize", value: String(pageSize)) ]
        var req = URLRequest(url: comps.url!)
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, _) = try await session.data(for: req)
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase; decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Post].self, from: data)
    }

    func createPost(authorId: String, imageData: Data?, caption: String?) async throws -> Post {
        let url = baseURL.appendingPathComponent("/posts")
        var req = URLRequest(url: url); req.httpMethod = "POST"
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        if let data = imageData {
            let boundary = "Boundary-\(UUID().uuidString)"
            req.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            var body = Data()
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"authorId\"\r\n\r\n")
            body.appendString("\(authorId)\r\n")
            if let caption = caption {
                body.appendString("--\(boundary)\r\n")
                body.appendString("Content-Disposition: form-data; name=\"caption\"\r\n\r\n")
                body.appendString("\(caption)\r\n")
            }
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n")
            body.appendString("Content-Type: image/jpeg\r\n\r\n")
            body.append(data)
            body.appendString("\r\n--\(boundary)--\r\n")
            req.httpBody = body
        } else {
            req.addValue("application/json", forHTTPHeaderField: "Content-Type")
            var body: [String: Any] = [:]
            if let caption = caption { body["caption"] = caption }
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("createPost failed: HTTP \(http.statusCode) body: \(body)")
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase; decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Post.self, from: data)
    }

    func likePost(_ postId: String) async throws -> Int {
        let url = baseURL.appendingPathComponent("/posts/\(postId)/like")
        var req = URLRequest(url: url); req.httpMethod = "POST"
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("likePost failed HTTP \(http.statusCode): \(body)")
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let likes = decoded?["like_count"] as? Int { return likes }
        if let likes = decoded?["likes"] as? Int { return likes }
        throw URLError(.badServerResponse)
    }

    // Follow/unfollow and list implementations for REST client

    func unlikePost(_ postId: String) async throws -> Int {
        let url = baseURL.appendingPathComponent("/posts/\(postId)/like")
        var req = URLRequest(url: url); req.httpMethod = "DELETE"
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("unlikePost failed HTTP \(http.statusCode): \(body)")
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let likes = decoded?["like_count"] as? Int { return likes }
        if let likes = decoded?["likes"] as? Int { return likes }
        throw URLError(.badServerResponse)
    }

    func createSession(username: String, password: String) async throws -> (token: String, user: User) {
        let url = baseURL.appendingPathComponent("/sessions")
        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["username": username, "password": password]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await session.data(for: req)
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase; decoder.dateDecodingStrategy = .iso8601
        let wrapperAny = try JSONSerialization.jsonObject(with: data)
        guard let wrapper = wrapperAny as? [String: Any], let token = wrapper["token"] as? String else { throw URLError(.badServerResponse) }
        if let userDict = wrapper["user"] as? [String: Any], let userData = try? JSONSerialization.data(withJSONObject: userDict) {
            let user = try decoder.decode(User.self, from: userData)
            return (token: token, user: user)
        }
            if let idStr = (wrapper["userId"] as? String) ?? (wrapper["user_id"] as? String) ?? (wrapper["id"] as? String) {
                return (token: token, user: User(id: idStr, username: "", displayName: nil, avatarURL: nil))
        }
        throw URLError(.badServerResponse)
    }

    func createAccount(username: String, password: String, fullname: String?) async throws -> User {
        let url = baseURL.appendingPathComponent("/users")
        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["username": username, "password": password]
        if let fullname = fullname { body["fullname"] = fullname }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("createAccount failed: HTTP \(http.statusCode) body: \(body)")
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase; decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(User.self, from: data)
    }

    func fetchComments(postId: String) async throws -> [Comment] {
        let url = baseURL.appendingPathComponent("/posts/")
            .appendingPathComponent(postId)
            .appendingPathComponent("comments")
        var req = URLRequest(url: url)
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, _) = try await session.data(for: req)
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase; decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Comment].self, from: data)
    }

    func createComment(postId: String, text: String) async throws -> Void {
        let url = baseURL.appendingPathComponent("/comments")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        var comps = URLComponents()
        comps.queryItems = [ URLQueryItem(name: "operation", value: "create"), URLQueryItem(name: "postid", value: postidValue(postId)), URLQueryItem(name: "text", value: text) ]
        req.httpBody = comps.percentEncodedQuery?.data(using: .utf8)
        req.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("createComment failed HTTP \(http.statusCode): \(body)")
            throw URLError(.badServerResponse)
        }
    }

    func deleteComment(commentId: String) async throws -> Void {
        let url = baseURL.appendingPathComponent("/comments")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        var comps = URLComponents()
        comps.queryItems = [ URLQueryItem(name: "operation", value: "delete"), URLQueryItem(name: "commentid", value: commentId) ]
        req.httpBody = comps.percentEncodedQuery?.data(using: .utf8)
        req.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("deleteComment failed HTTP \(http.statusCode): \(body)")
            throw URLError(.badServerResponse)
        }
    }

    func deletePost(_ postId: String) async throws -> Void {
        let url = baseURL.appendingPathComponent("/posts/")
            .appendingPathComponent(postId)
        var req = URLRequest(url: url); req.httpMethod = "DELETE"
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        _ = try await session.data(for: req)
    }

    func followUser(_ username: String) async throws -> Void {
        let url = baseURL.appendingPathComponent("/users/").appendingPathComponent(username).appendingPathComponent("follow")
        var req = URLRequest(url: url); req.httpMethod = "POST"
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        _ = try await session.data(for: req)
    }

    func unfollowUser(_ username: String) async throws -> Void {
        let url = baseURL.appendingPathComponent("/users/").appendingPathComponent(username).appendingPathComponent("follow")
        var req = URLRequest(url: url); req.httpMethod = "DELETE"
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        _ = try await session.data(for: req)
    }

    func fetchFollowers(username: String) async throws -> [User] {
        let url = baseURL.appendingPathComponent("/users/").appendingPathComponent(username).appendingPathComponent("followers")
        var req = URLRequest(url: url)
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, _) = try await session.data(for: req)
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase; decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([User].self, from: data)
    }

    func fetchFollowing(username: String) async throws -> [User] {
        let url = baseURL.appendingPathComponent("/users/").appendingPathComponent(username).appendingPathComponent("following")
        var req = URLRequest(url: url)
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, _) = try await session.data(for: req)
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase; decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([User].self, from: data)
    }

    // Helper to normalize postid value if needed
    private func postidValue(_ id: String) -> String { return id }

    private var jsonDecoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }

    func startReadingSession(bookTitle: String) async throws -> ReadingSession {
        let url = baseURL.appendingPathComponent("/reading-sessions")
        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try JSONSerialization.data(withJSONObject: ["book_title": bookTitle])
        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            print("startReadingSession failed HTTP \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
            throw URLError(.badServerResponse)
        }
        return try jsonDecoder.decode(ReadingSession.self, from: data)
    }

    func endReadingSession(sessionId: String, pagesRead: Int?) async throws {
        let url = baseURL.appendingPathComponent("/reading-sessions/\(sessionId)/complete")
        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        var body: [String: Any] = ["status": "completed"]
        if let pages = pagesRead { body["pages_read"] = pages }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            print("endReadingSession failed HTTP \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
            throw URLError(.badServerResponse)
        }
    }

    func pauseReadingSession(sessionId: String) async throws {
        let url = baseURL.appendingPathComponent("/reading-sessions/\(sessionId)/pause")
        var req = URLRequest(url: url); req.httpMethod = "POST"
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            print("pauseReadingSession failed HTTP \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
            throw URLError(.badServerResponse)
        }
    }

    func resumeReadingSession(sessionId: String) async throws {
        let url = baseURL.appendingPathComponent("/reading-sessions/\(sessionId)/resume")
        var req = URLRequest(url: url); req.httpMethod = "POST"
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            print("resumeReadingSession failed HTTP \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
            throw URLError(.badServerResponse)
        }
    }

    func fetchActiveFriendSessions() async throws -> [ActiveFriendSession] {
        let url = baseURL.appendingPathComponent("/reading-sessions/friends")
        var req = URLRequest(url: url)
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            print("fetchActiveFriendSessions failed HTTP \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
            throw URLError(.badServerResponse)
        }
        return try jsonDecoder.decode([ActiveFriendSession].self, from: data)
    }

    func joinReadingSession(sessionId: String) async throws -> ReadingSession {
        let url = baseURL.appendingPathComponent("/reading-sessions/\(sessionId)/participants")
        var req = URLRequest(url: url); req.httpMethod = "POST"
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            print("joinReadingSession failed HTTP \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
            throw URLError(.badServerResponse)
        }
        return try jsonDecoder.decode(ReadingSession.self, from: data)
    }

    func leaveReadingSession(sessionId: String, elapsedSeconds: Int, pagesRead: Int?, bookTitle: String?) async throws {
        let url = baseURL.appendingPathComponent("/reading-sessions/\(sessionId)/participants")
        var req = URLRequest(url: url); req.httpMethod = "DELETE"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        var body: [String: Any] = ["elapsed_seconds": elapsedSeconds]
        if let pages = pagesRead { body["pages_read"] = pages }
        if let title = bookTitle { body["book_title"] = title }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        debugLogRequest(req)
        let (_, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
    }

    func fetchSessionHistory() async throws -> [SessionHistoryEntry] {
        let url = baseURL.appendingPathComponent("/session-history")
        var req = URLRequest(url: url)
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            print("fetchSessionHistory failed HTTP \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
            throw URLError(.badServerResponse)
        }
        return try jsonDecoder.decode([SessionHistoryEntry].self, from: data)
    }

    func markBookCompleted(title: String) async throws {
        let url = baseURL.appendingPathComponent("/completed-books")
        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try JSONSerialization.data(withJSONObject: ["book_title": title])
        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            print("markBookCompleted failed HTTP \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
            throw URLError(.badServerResponse)
        }
    }

    func fetchCompletedBooks() async throws -> [CompletedBookEntry] {
        let url = baseURL.appendingPathComponent("/completed-books")
        var req = URLRequest(url: url)
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            print("fetchCompletedBooks failed HTTP \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
            throw URLError(.badServerResponse)
        }
        return try jsonDecoder.decode([CompletedBookEntry].self, from: data)
    }

    func searchBooks(query: String) async throws -> [BookSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }

        var comps = URLComponents(
            url: baseURL.appendingPathComponent("/books/search"),
            resolvingAgainstBaseURL: false
        )!
        comps.queryItems = [URLQueryItem(name: "q", value: trimmed)]

        var req = URLRequest(url: comps.url!)
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)

        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("searchBooks failed HTTP \(http.statusCode): \(body)")
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([BookSearchResult].self, from: data)
    }
    func fetchPreferences() async throws -> UserPreferences {
        let url = baseURL.appendingPathComponent("/preferences")
        var req = URLRequest(url: url)
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            print("fetchPreferences failed HTTP \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
            throw URLError(.badServerResponse)
        }
        return try jsonDecoder.decode(UserPreferences.self, from: data)
    }

    func savePreferences(_ preferences: UserPreferences) async throws {
        let url = baseURL.appendingPathComponent("/preferences")
        var req = URLRequest(url: url); req.httpMethod = "PUT"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let encoder = JSONEncoder(); encoder.keyEncodingStrategy = .convertToSnakeCase
        req.httpBody = try encoder.encode(preferences)
        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            print("savePreferences failed HTTP \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
            throw URLError(.badServerResponse)
        }
    }

    func sendBookScan(barcode: String?, ocrText: String?) async throws -> BookScanResponse {
        let url = baseURL.appendingPathComponent("/books/scan")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body: [String: Any] = [:]
        if let barcode {
            body["barcode"] = barcode
        }
        if let ocrText {
            body["ocrText"] = ocrText
        }

        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)

        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let bodyText = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("sendBookScan failed HTTP \(http.statusCode): \(bodyText)")
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(BookScanResponse.self, from: data)
    }
}

enum AppAPI {
    /// Default shared client. Swap to `RESTAPIClient(baseURL:)` when you have a backend.
    static var shared: APIClientProtocol = RESTAPIClient(baseURL:
        URL(string: "http://127.0.0.1:5001")!)
}


