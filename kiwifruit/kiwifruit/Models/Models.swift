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
}

struct ReadingSessionSummary: Codable, Hashable {
    let id: Int?
    let bookId: String?
    let durationSeconds: Int
    let completed: Bool
    let startedAt: Date?
    let endedAt: Date?
    let source: String?
    let createdAt: Date?
}

struct MoodSummary: Codable, Hashable {
    let id: Int?
    let readingSessionId: Int
    let avgValence: Double?
    let volatility: Double?
    let dominantEmotion: String?
    let framesObserved: Int?
    let createdAt: Date?
}

struct Recommendation: Identifiable, Codable, Hashable {
    let id: String
    let bookId: String
    let title: String
    let reasonTags: [String]
    let score: Double

    init(bookId: String, title: String, reasonTags: [String], score: Double) {
        self.id = bookId
        self.bookId = bookId
        self.title = title
        self.reasonTags = reasonTags
        self.score = score
    }
}
