import Foundation
import SwiftUI

struct User: Identifiable, Codable, Hashable {
    let id: String
    let username: String
    let displayName: String?
    let avatarURL: URL?
}

struct Post: Identifiable, Codable, Hashable {
    let id: String
    let author: User
    let imageURL: URL
    let caption: String?
    var likes: Int
    let createdAt: Date?
    // Optional fields returned by the server for the MVP shape
    var commentCount: Int?
    var likedByMe: Bool?
}

struct Comment: Identifiable, Codable, Hashable {
    let id: String
    // Server responses may omit postId; make optional to be tolerant
    let postId: String?
    let author: User
    let text: String
    let createdAt: Date
}

struct BookSearchResult: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let authors: [String]?
    let isbn13: String?
    let coverUrl: String?
}

/// A book saved by the user from discovery/search results.
struct UserBook: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let authors: [String]?
    let isbn13: String?
    let addedAt: Date
    let coverUrl: String?

    init(id: String = UUID().uuidString, title: String, authors: [String]?, isbn13: String?, coverUrl: String? = nil) {
        self.id = id
        self.title = title
        self.authors = authors
        self.isbn13 = isbn13
        self.addedAt = Date()
        self.coverUrl = coverUrl
    }
}

/// Server-driven personalized recommendation row (GET /recommendations).
/// Property is ``coverUrl`` so JSON `cover_url` decodes with ``JSONDecoder.keyDecodingStrategy.convertFromSnakeCase`` (maps to `coverUrl`, not `coverURL`).
struct BookRecommendation: Identifiable, Codable, Hashable {
    let bookId: Int
    let title: String
    let author: String
    /// HTTPS URL string for cover art (`cover_url` in JSON).
    let coverUrl: String

    var id: Int { bookId }
}

/// A live reading session created by a user and optionally joined by friends.
struct ReadingSession: Identifiable, Codable, Hashable {
    let id: String
    let host: User
    let bookTitle: String
    let startedAt: Date
    /// "active" | "completed"
    var status: String
    /// Friends who have joined this session.
    var participants: [User]
}

/// A friend's active session as returned by the feed endpoint, with server-calculated elapsed time.
struct ActiveFriendSession: Identifiable, Codable, Hashable {
    let session: ReadingSession
    /// How many seconds the host has been reading (calculated server-side from startedAt).
    let hostElapsedSeconds: Int

    var id: String { session.id }
}

/// Response from POST /api/epub upload.
struct EpubUploadResponse: Identifiable, Codable {
    let id: String
    let title: String
    let author: String
    let status: String
    let originalFilename: String
    let createdAt: String
}

/// A chapter entry from the epub chapters endpoint.
struct EpubChapter: Identifiable, Codable {
    let id: String
    let chapterNumber: Int
    let title: String
}

/// Speed reading progress for a given epub.
struct SpeedReadingProgress: Codable {
    let chapterNumber: Int
    let wordIndex: Int
}

// MARK: - Adaptive Challenges & Reflections

struct AdaptiveChallengeData: Codable {
    let title: String
    let description: String
    let goalUnit: String
    let goalCount: Int
    let rewardXP: Int
    let reason: String
}

struct AdaptiveChallengeResponse: Codable {
    let available: Bool
    let challenge: AdaptiveChallengeData?
}

struct ReflectionPromptResponse: Codable {
    let prompt: String
    let mood: String?
}
