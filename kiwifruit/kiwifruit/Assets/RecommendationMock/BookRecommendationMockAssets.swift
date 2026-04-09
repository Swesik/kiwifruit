import Foundation

/// Mock recommendation rows use bundled images from ``Assets.xcassets`` instead of remote URLs.
/// ``coverUrl`` is `mock-asset://` + the asset catalog name (e.g. `RecommendationMockCover01`).
enum BookRecommendationMockAssets {
    static let mockSchemePrefix = "mock-asset://"

    /// Names of images in `Assets.xcassets` (RecommendationMockCover01 … RecommendationMockCover08).
    static let catalogImageNames: [String] = (1...8).map { String(format: "RecommendationMockCover%02d", $0) }

    static let titles = [
        "Mock Apple", "Mock Birch", "Mock Cedar", "Mock Dogwood", "Mock Elm", "Mock Fig", "Mock Grove", "Mock Hazel",
    ]

    static let authors = [
        "Alex Author", "Blake Booker", "Casey Crane", "Dana Draft", "Eden Editor", "Frank Fable", "Gale Genre", "Harper Haiku",
    ]

    static let mockExplanations = [
        "Based on your recent interest in fiction, you'll love this compelling narrative that explores themes of identity and growth.",
        "As a frequent reader spending 30+ minutes per session, this epic will keep you engaged for hours.",
        "Your reading history shows you enjoy character-driven stories—this novel delivers that in spades.",
        "You've completed 12 books in sci-fi this year—this author's signature style matches your preferences perfectly.",
        "Your average reading session is 45 minutes, and this gripping page-turner won't let you put it down.",
        "Given your recent exploration of mystery genres, this thrilling whodunit is right up your alley.",
        "You're a daily reader who values rich prose—this literary fiction showcases beautiful, intricate writing.",
        "Your reading pattern suggests you love immersive worlds and complex characters, both abundant here.",
    ]

    static let items: [BookRecommendation] = (0..<8).map { i in
        BookRecommendation(
            bookId: i + 1,
            title: titles[i],
            author: authors[i],
            coverUrl: mockSchemePrefix + catalogImageNames[i],
            whyRecommended: mockExplanations[i]
        )
    }

    static func coverUrl(forMockIndex index: Int) -> String {
        let i = min(max(index, 0), catalogImageNames.count - 1)
        return mockSchemePrefix + catalogImageNames[i]
    }

    /// Returns the asset catalog image name if ``coverUrl`` is a mock-asset reference.
    static func mockAssetImageName(from coverUrl: String) -> String? {
        guard coverUrl.hasPrefix(mockSchemePrefix) else { return nil }
        return String(coverUrl.dropFirst(mockSchemePrefix.count))
    }
}
