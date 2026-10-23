import Foundation

enum MockData {
    static let sampleUser = User(
        id: UUID().uuidString,
        username: "kiwi_botanist",
        displayName: "Kiwi Lover",
        avatarURL: URL(string: "https://picsum.photos/seed/avatar/100")
    )

}
