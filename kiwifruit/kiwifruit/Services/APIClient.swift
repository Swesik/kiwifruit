import Foundation

// Helper to build multipart/form-data requests.
fileprivate extension Data {
    mutating func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

/// Builds a multipart/form-data body from text fields and an optional file attachment.
fileprivate struct MultipartFormData {
    let boundary = "Boundary-\(UUID().uuidString)"
    private var body = Data()

    var contentType: String { "multipart/form-data; boundary=\(boundary)" }
    var data: Data { body }

    mutating func addField(name: String, value: String) {
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        body.appendString("\(value)\r\n")
    }

    mutating func addFile(name: String, filename: String, mimeType: String, data fileData: Data) {
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        body.appendString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        body.appendString("\r\n")
    }

    mutating func finalize() {
        body.appendString("--\(boundary)--\r\n")
    }
}

protocol APIClientProtocol: Sendable {
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
    /// Rule-based recommendations from catalog + session history (requires auth).
    func fetchRecommendations(limit: Int) async throws -> [BookRecommendation]
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
    /// Uploads an epub file to the server for background parsing.
    func uploadEpub(fileData: Data, filename: String) async throws -> EpubUploadResponse
    /// Returns all epubs belonging to the current user.
    func fetchEpubs() async throws -> [EpubUploadResponse]
    /// Returns the status/detail of a single epub.
    func fetchEpubDetail(epubId: String) async throws -> EpubUploadResponse
    /// Returns the list of chapters for an epub.
    func fetchChapters(epubId: String) async throws -> [EpubChapter]
    /// Returns the plaintext content of a single chapter.
    func fetchChapterText(epubId: String, chapterNumber: Int) async throws -> String
    /// Returns the user's saved reading position in an epub.
    func getSpeedReadingProgress(epubId: String) async throws -> SpeedReadingProgress
    /// Updates the user's reading position in an epub.
    func updateSpeedReadingProgress(epubId: String, chapter: Int, wordIndex: Int) async throws
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
            guard let fallback = URL(string: "https://picsum.photos/seed/kiwi/600/600") else {
                throw URLError(.badURL)
            }
            imageURL = fallback
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
                isbn13: nil,
                coverUrl: nil
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

    func fetchRecommendations(limit: Int) async throws -> [BookRecommendation] {
        try await Task.sleep(nanoseconds: 120 * 1_000_000)
        guard limit > 0 else {
            throw URLError(.badURL)
        }
        let count = min(limit, 8)
        return Array(BookRecommendationMockAssets.items.prefix(count))
    }

    func fetchSessionHistory() async throws -> [SessionHistoryEntry] { return [] }
    func markBookCompleted(title: String) async throws {}
    func fetchCompletedBooks() async throws -> [CompletedBookEntry] { return [] }
    func fetchPreferences() async throws -> UserPreferences { return UserPreferences() }
    func savePreferences(_ preferences: UserPreferences) async throws {}
    func sendBookScan(barcode: String?, ocrText: String?) async throws -> BookScanResponse {
        try await Task.sleep(nanoseconds: 120 * 1_000_000)
        return BookScanResponse(
            status: "ok",
            barcode: barcode,
            ocrText: ocrText
        )
    }
    func uploadEpub(fileData: Data, filename: String) async throws -> EpubUploadResponse {
        return EpubUploadResponse(id: "1", title: "Mock Book", author: "Mock Author", status: "LOADING", originalFilename: filename, createdAt: "2026-01-01T00:00:00Z")
    }
    func fetchEpubs() async throws -> [EpubUploadResponse] {
        return [
            EpubUploadResponse(id: "1", title: "Mock Book", author: "Mock Author", status: "PARSED", originalFilename: "mock.epub", createdAt: "2026-01-01T00:00:00Z")
        ]
    }
    func fetchEpubDetail(epubId: String) async throws -> EpubUploadResponse {
        return EpubUploadResponse(id: epubId, title: "Mock Book", author: "Mock Author", status: "PARSED", originalFilename: "mock.epub", createdAt: "2026-01-01T00:00:00Z")
    }
    func fetchChapters(epubId: String) async throws -> [EpubChapter] {
        return [
            EpubChapter(id: "1", chapterNumber: 1, title: "Chapter 1"),
            EpubChapter(id: "2", chapterNumber: 2, title: "Chapter 2"),
        ]
    }
    func fetchChapterText(epubId: String, chapterNumber: Int) async throws -> String {
        return "The quick brown fox jumps over the lazy dog. Speed reading is a technique for rapidly processing text by focusing your eyes on key words."
    }
    func getSpeedReadingProgress(epubId: String) async throws -> SpeedReadingProgress {
        return SpeedReadingProgress(chapterNumber: 1, wordIndex: 0)
    }
    func updateSpeedReadingProgress(epubId: String, chapter: Int, wordIndex: Int) async throws {}
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
        guard var comps = URLComponents(url: baseURL.appendingPathComponent("/posts"), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        comps.queryItems = [ URLQueryItem(name: "page", value: String(page)), URLQueryItem(name: "pageSize", value: String(pageSize)) ]
        guard let url = comps.url else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, _) = try await session.data(for: req)
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase; decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Post].self, from: data)
    }

    func createPost(authorId: String, imageData: Data?, caption: String?) async throws -> Post {
        let url = baseURL.appendingPathComponent("/posts")
        var req = URLRequest(url: url); req.httpMethod = "POST"
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        if let imageData {
            var form = MultipartFormData()
            form.addField(name: "authorId", value: authorId)
            if let caption { form.addField(name: "caption", value: caption) }
            form.addFile(name: "file", filename: "image.jpg", mimeType: "image/jpeg", data: imageData)
            form.finalize()
            req.addValue(form.contentType, forHTTPHeaderField: "Content-Type")
            req.httpBody = form.data
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
        let normalized = trimmed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        // First try the app backend search endpoint; if it fails or returns nothing,
        // fall back to querying Open Library (no API key required) for metadata.
        do {
            guard var comps = URLComponents(
                url: baseURL.appendingPathComponent("/books/search"),
                resolvingAgainstBaseURL: false
            ) else { throw URLError(.badURL) }
            comps.queryItems = [URLQueryItem(name: "q", value: normalized)]

            guard let searchURL = comps.url else { throw URLError(.badURL) }
            var req = URLRequest(url: searchURL)
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
            let results = try decoder.decode([BookSearchResult].self, from: data)
            if !results.isEmpty { return results }
            // If backend returned empty list, fall through to Open Library fallback below.
        } catch {
            print("searchBooks: backend search failed, falling back to Open Library: \(error)")
        }

        return try await searchOpenLibrary(query: normalized)
    }

    /// Query Open Library's public search API for basic metadata
    private func searchOpenLibrary(query: String) async throws -> [BookSearchResult] {
        guard var comps = URLComponents(string: "https://openlibrary.org/search.json") else { throw URLError(.badURL) }
        comps.queryItems = [ URLQueryItem(name: "q", value: query) ]
        guard let url = comps.url else { throw URLError(.badURL) }

        let (data, resp) = try await session.data(from: url)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }

        struct OLDoc: Codable {
            let key: String?
            let title: String?
            let author_name: [String]?
            let isbn: [String]?
            let cover_i: Int?
        }
        struct OLResponse: Codable {
            let docs: [OLDoc]
        }

        let decoder = JSONDecoder()
        let ol = try decoder.decode(OLResponse.self, from: data)
        let docs = ol.docs.prefix(20)

        // First pass: map Open Library data and collect indices that need a Google cover lookup.
        struct Partial {
            let index: Int
            let id: String
            let title: String
            let authors: [String]?
            let isbn13: String?
            var coverUrl: String?
        }

        var partials: [Partial] = []
        partials.reserveCapacity(docs.count)

        for (idx, doc) in docs.enumerated() {
            let id = doc.key ?? "ol_\(idx)_\(UUID().uuidString)"
            let title = doc.title ?? "Unknown title"
            let authors = doc.author_name
            var isbn13: String? = nil
            if let isbns = doc.isbn {
                if let exact13 = isbns.first(where: { $0.count == 13 }) { isbn13 = exact13 }
                else { isbn13 = isbns.first }
            }
            var coverUrl: String? = nil
            if let coverId = doc.cover_i {
                coverUrl = "https://covers.openlibrary.org/b/id/\(coverId)-M.jpg"
            }
            partials.append(Partial(index: idx, id: id, title: title, authors: authors, isbn13: isbn13, coverUrl: coverUrl))
        }

        // Second pass: fetch missing covers from Google Books concurrently.
        let needsCover = partials.filter { $0.coverUrl == nil && $0.isbn13 != nil }
        if !needsCover.isEmpty {
            let covers = await withTaskGroup(of: (Int, String?).self) { group in
                for p in needsCover {
                    let isbn = p.isbn13!
                    let idx = p.index
                    group.addTask { (idx, try? await self.fetchGoogleBooksCover(isbn13: isbn)) }
                }
                var results: [Int: String] = [:]
                for await (idx, url) in group {
                    if let url { results[idx] = url }
                }
                return results
            }
            for (idx, url) in covers {
                partials[idx].coverUrl = url
            }
        }

        return partials.map { BookSearchResult(id: $0.id, title: $0.title, authors: $0.authors, isbn13: $0.isbn13, coverUrl: $0.coverUrl) }
    }

    /// Try Google Books volumes API to obtain a thumbnail for an ISBN.
    private func fetchGoogleBooksCover(isbn13: String) async throws -> String? {
        guard !isbn13.isEmpty else { return nil }
        guard var comps = URLComponents(string: "https://www.googleapis.com/books/v1/volumes") else { return nil }
        comps.queryItems = [ URLQueryItem(name: "q", value: "isbn:\(isbn13)") ]
        guard let url = comps.url else { return nil }

        let (data, resp) = try await session.data(from: url)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            return nil
        }

        struct GBImageLinks: Codable { let smallThumbnail: String?; let thumbnail: String? }
        struct GBVolumeInfo: Codable { let imageLinks: GBImageLinks? }
        struct GBItem: Codable { let volumeInfo: GBVolumeInfo? }
        struct GBResponse: Codable { let items: [GBItem]? }

        let decoder = JSONDecoder()
        if let gb = try? decoder.decode(GBResponse.self, from: data), let first = gb.items?.first, let links = first.volumeInfo?.imageLinks {
            // Prefer thumbnail then smallThumbnail
            if let thumb = links.thumbnail { return thumb.replacingOccurrences(of: "http://", with: "https://") }
            if let small = links.smallThumbnail { return small.replacingOccurrences(of: "http://", with: "https://") }
        }
        return nil
    }

    func fetchRecommendations(limit: Int) async throws -> [BookRecommendation] {
        guard limit > 0 else {
            throw URLError(.badURL)
        }
        let capped = min(limit, 20)
        var comps = URLComponents(
            url: baseURL.appendingPathComponent("/recommendations"),
            resolvingAgainstBaseURL: false
        )
        comps?.queryItems = [URLQueryItem(name: "limit", value: String(capped))]
        guard let url = comps?.url else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        if let token = authToken {
            req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("fetchRecommendations failed HTTP \(http.statusCode): \(body)")
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([BookRecommendation].self, from: data)
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

    func uploadEpub(fileData: Data, filename: String) async throws -> EpubUploadResponse {
        let url = baseURL.appendingPathComponent("/epub")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        var form = MultipartFormData()
        form.addFile(name: "file", filename: filename, mimeType: "application/epub+zip", data: fileData)
        form.finalize()
        req.addValue(form.contentType, forHTTPHeaderField: "Content-Type")
        req.httpBody = form.data

        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let bodyText = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("uploadEpub failed HTTP \(http.statusCode): \(bodyText)")
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(EpubUploadResponse.self, from: data)
    }

    func fetchEpubs() async throws -> [EpubUploadResponse] {
        let url = baseURL.appendingPathComponent("/epubs")
        var req = URLRequest(url: url)
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([EpubUploadResponse].self, from: data)
    }

    func fetchEpubDetail(epubId: String) async throws -> EpubUploadResponse {
        let url = baseURL.appendingPathComponent("/epub/\(epubId)")
        var req = URLRequest(url: url)
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(EpubUploadResponse.self, from: data)
    }

    func fetchChapters(epubId: String) async throws -> [EpubChapter] {
        let url = baseURL.appendingPathComponent("/epub/\(epubId)/chapters")
        var req = URLRequest(url: url)
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode([EpubChapter].self, from: data)
    }

    func fetchChapterText(epubId: String, chapterNumber: Int) async throws -> String {
        let url = baseURL.appendingPathComponent("/epub/\(epubId)/chapter/\(chapterNumber)/text")
        var req = URLRequest(url: url)
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["text"] as? String ?? ""
    }

    func getSpeedReadingProgress(epubId: String) async throws -> SpeedReadingProgress {
        let url = baseURL.appendingPathComponent("/speed-reading/progress/\(epubId)")
        var req = URLRequest(url: url)
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(SpeedReadingProgress.self, from: data)
    }

    func updateSpeedReadingProgress(epubId: String, chapter: Int, wordIndex: Int) async throws {
        let url = baseURL.appendingPathComponent("/speed-reading/progress/\(epubId)")
        var req = URLRequest(url: url); req.httpMethod = "PUT"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken { req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let body: [String: Int] = ["chapterNumber": chapter, "wordIndex": wordIndex]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        debugLogRequest(req)
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            print("updateSpeedReadingProgress failed HTTP \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
            throw URLError(.badServerResponse)
        }
    }
}

enum AppAPI {
    /// Default API server base URL for local development.
    static let defaultBaseURL: URL = {
        guard let url = URL(string: "http://127.0.0.1:5000") else {
            fatalError("Invalid default API base URL")
        }
        return url
    }()

    /// Default shared client. Swap to `RESTAPIClient(baseURL:)` when you have a backend.
    static var shared: APIClientProtocol = RESTAPIClient(baseURL: defaultBaseURL)
}
