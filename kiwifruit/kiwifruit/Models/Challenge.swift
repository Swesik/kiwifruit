import Foundation

enum ChallengeState: String, Codable {
    case available
    case accepted
    case completed
}

struct SessionHistoryEntry: Codable {
    let id: String
    let bookTitle: String
    let durationSeconds: Int
    let pagesRead: Int?
    let endedAt: String
}

struct CompletedBookEntry: Codable {
    let id: String
    let bookTitle: String
    let completedAt: String
}

struct Challenge: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var description: String
    /// e.g. "minutes/week", "books/month", "pages/month"
    var goalUnit: String
    var goalCount: Int
    var progress: Double = 0
    var rewardXP: Int = 20
    var state: ChallengeState = .available
    var joinedAt: Date? = nil

    var expiresAt: Date? {
        guard let joined = joinedAt else { return nil }
        let calendar = Calendar.current
        let lower = goalUnit.lowercased()
        if lower.contains("week") {
            return calendar.dateInterval(of: .weekOfYear, for: joined)?.end
        } else if lower.contains("month") {
            return calendar.dateInterval(of: .month, for: joined)?.end
        }
        return nil
    }

    var timeRemainingLabel: String? {
        guard let expiry = expiresAt else { return nil }
        let now = Date()
        guard expiry > now else { return "Expired" }
        let components = Calendar.current.dateComponents([.day, .hour], from: now, to: expiry)
        if let d = components.day, d > 0 { return "\(d)d left" }
        if let h = components.hour, h > 0 { return "\(h)h left" }
        return "Expires soon"
    }

    var isExpired: Bool {
        guard let expiry = expiresAt else { return false }
        return expiry < Date()
    }

    var windowLabel: String {
        let lower = goalUnit.lowercased()
        if lower.contains("week") { return "This week" }
        if lower.contains("month") { return "This month" }
        return ""
    }

    var subtitle: String {
        let lower = goalUnit.lowercased()
        if lower.contains("minute") { return "Consistency is key" }
        if lower.contains("book") { return "Reading challenge" }
        if lower.contains("page") { return "Page challenge" }
        return "Reading challenge"
    }

    var progressLabel: String {
        let done = Int((progress * Double(goalCount)).rounded())
        let lower = goalUnit.lowercased()
        if lower.contains("minute") { return "\(done)/\(goalCount) mins" }
        if lower.contains("book") { return "\(done)/\(goalCount) Books" }
        if lower.contains("page") { return "\(done)/\(goalCount) Pages" }
        return "\(Int(progress * 100))%"
    }
}

extension Challenge {
    /// Canonical challenge bank loaded from ChallengeBank.json.
    /// Stable UUIDs so UserDefaults persistence survives app restarts.
    static let bank: [Challenge] = {
        guard let url = Bundle.main.url(forResource: "ChallengeBank", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let challenges = try? JSONDecoder().decode([Challenge].self, from: data) else {
            return []
        }
        return challenges
    }()
}
