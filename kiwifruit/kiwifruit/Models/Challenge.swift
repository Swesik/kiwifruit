import Foundation

enum ChallengeState: String, Codable {
    case available
    case accepted
    case completed
}

struct SessionHistoryEntry: Codable, Identifiable {
    let id: String
    let bookTitle: String
    let durationSeconds: Int
    let pagesRead: Int?
    let mood: String?
    let endedAt: String
}

struct CompletedBookEntry: Codable {
    let id: String
    let bookTitle: String
    let completedAt: String
}

struct MoodTrendsResponse: Codable {
    let days: Int
    let totalSessions: Int
    let avgDurationMinutes: Double
    let trend: String
    let suggestion: String?
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
    /// True when this challenge was sourced from the adaptive recommender.
    /// Used to gate further adaptive recommendations until this one completes.
    var isAdaptive: Bool = false
    /// True when this challenge was generated from today's weather. Used to
    /// gate further weather recommendations until this one completes.
    var isWeather: Bool = false
    /// Server-provided rationale for adaptive/weather challenges. nil for
    /// regular challenges from the static bank.
    var reason: String? = nil

    // Static data sources (ChallengeBank.json) only carry the shape of a
    // challenge — title, description, goal, reward. Runtime-only fields
    // (progress, state, joinedAt, isAdaptive, isWeather, reason) are missing
    // there, so we decode them leniently with sensible defaults.
    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        goalUnit: String,
        goalCount: Int,
        progress: Double = 0,
        rewardXP: Int = 20,
        state: ChallengeState = .available,
        joinedAt: Date? = nil,
        isAdaptive: Bool = false,
        reason: String? = nil,
        isWeather: Bool = false
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
        self.isAdaptive = isAdaptive
        self.reason = reason
        self.isWeather = isWeather
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        description = try c.decode(String.self, forKey: .description)
        goalUnit = try c.decode(String.self, forKey: .goalUnit)
        goalCount = try c.decode(Int.self, forKey: .goalCount)
        progress = try c.decodeIfPresent(Double.self, forKey: .progress) ?? 0
        rewardXP = try c.decodeIfPresent(Int.self, forKey: .rewardXP) ?? 20
        state = try c.decodeIfPresent(ChallengeState.self, forKey: .state) ?? .available
        joinedAt = try c.decodeIfPresent(Date.self, forKey: .joinedAt)
        isAdaptive = try c.decodeIfPresent(Bool.self, forKey: .isAdaptive) ?? false
        isWeather = try c.decodeIfPresent(Bool.self, forKey: .isWeather) ?? false
        reason = try c.decodeIfPresent(String.self, forKey: .reason)
    }

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
    /// Canonical challenge bank loaded from ChallengeBank.json (bundled asset).
    /// Stable UUIDs so UserDefaults persistence survives app restarts.
    /// A parse failure indicates a corrupt or missing bundled resource — a
    /// build-time problem, so we fail fast rather than silently degrading.
    static let bank: [Challenge] = {
        guard let url = Bundle.main.url(forResource: "ChallengeBank", withExtension: "json") else {
            fatalError("ChallengeBank.json is missing from the app bundle")
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Challenge].self, from: data)
        } catch {
            fatalError("Failed to parse ChallengeBank.json: \(error)")
        }
    }()
}
