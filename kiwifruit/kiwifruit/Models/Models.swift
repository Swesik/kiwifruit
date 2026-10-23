import Foundation
import SwiftUI

struct User: Identifiable, Codable, Hashable {
    let id: String
    let username: String
    let displayName: String?
    let avatarURL: URL?
}

struct BookSearchResult: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let authors: [String]?
    let isbn13: String?
    let genres: [String]?

/// Local library row (UserDefaults). Populated from recommendation detail on this branch; search-row ADD comes from Varun merge (same type).
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
    /// AI-generated explanation for why this book is recommended (50-100 words)
    let whyRecommended: String?

    var id: Int { bookId }
}

/// A live solo reading session.
struct ReadingSession: Identifiable, Codable, Hashable {
    let id: String
    let host: User
    let bookTitle: String
    let startedAt: Date
    /// "active" | "completed"
    var status: String
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

struct WeatherChallengeData: Codable {
    let title: String
    let description: String
    let goalUnit: String
    let goalCount: Int
    let rewardXP: Int
    let reason: String
    let conditionLabel: String?
}

struct WeatherChallengeResponse: Codable {
    let available: Bool
    let challenge: WeatherChallengeData?
}

struct ReflectionPromptResponse: Codable {
    let prompt: String
}
