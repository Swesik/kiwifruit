import Foundation

struct UserPreferences: Codable, Equatable {
    var defaultSessionLengthMinutes: Int

    static let `default` = UserPreferences(
        defaultSessionLengthMinutes: 30
    )
}

