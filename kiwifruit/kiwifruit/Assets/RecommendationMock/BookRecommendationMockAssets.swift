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
