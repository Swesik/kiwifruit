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
    let id: UUID
    var title: String
    var description: String
    /// e.g. "minutes/week", "books/month", "pages/month"
    var goalUnit: String
    var goalCount: Int
    var progress: Double
    var rewardXP: Int
    var state: ChallengeState
    var joinedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        goalUnit: String,
        goalCount: Int,
        progress: Double = 0,
        rewardXP: Int = 20,
        state: ChallengeState = .available,
        joinedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.goalUnit = goalUnit
        self.goalCount = goalCount
        self.progress = progress
        self.rewardXP = rewardXP
        self.state = state
        self.joinedAt = joinedAt
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
    /// Canonical challenge bank — stable UUIDs so UserDefaults persistence survives app restarts.
    static let bank: [Challenge] = [
        Challenge(
            id: UUID(uuidString: "B0000001-0000-0000-0000-000000000000") ?? UUID(),
            title: "Read 5 books in a month",
            description: "Complete 5 books within a month. Your consistency will unlock special badges!",
            goalUnit: "books/month",
            goalCount: 5,
            rewardXP: 50
        ),
        Challenge(
            id: UUID(uuidString: "B0000002-0000-0000-0000-000000000000") ?? UUID(),
            title: "Daily 30 mins",
            description: "Build a daily reading habit by dedicating at least 30 minutes every day.",
            goalUnit: "minutes/week",
            goalCount: 210,
            rewardXP: 30
        ),
        Challenge(
            id: UUID(uuidString: "B0000003-0000-0000-0000-000000000000") ?? UUID(),
            title: "Fantasy marathon: 1000 pages",
            description: "Dive deep into magical realms and read 1000 pages this month.",
            goalUnit: "pages/month",
            goalCount: 1000,
            rewardXP: 100
        ),
        Challenge(
            id: UUID(uuidString: "B0000004-0000-0000-0000-000000000000") ?? UUID(),
            title: "Read a classic",
            description: "Time to tackle those must-reads. Finish one classic this month.",
            goalUnit: "books/month",
            goalCount: 1,
            rewardXP: 20
        ),
    ]
}
