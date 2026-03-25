import Foundation
import Observation
import SwiftUI

@Observable @MainActor
final class ChallengeViewModel {
    var activeChallenges: [Challenge] = []
    var discoverChallenges: [Challenge] = []
    var completedChallenges: [Challenge] = []
    var weatherChallenge: Challenge? = nil
    var streak: Int = 0
    var activeDays: Set<Int> = []
    var recentlyCompleted: [Challenge] = []
    var sessionHistory: [SessionHistoryEntry] = []
    var hasSessionToday: Bool = false
    var firstSessionMonth: Date? = nil
    var sessionActiveDays: [String: Set<Int>] = [:]

    private let activeKey = "kiwifruit.activeChallenges"
    private let completedKey = "kiwifruit.completedChallenges"

    init() {
        loadPersisted()
        refreshDiscover()
    }

    // MARK: - Accept / Abandon

    func accept(_ challenge: Challenge) {
        guard activeChallenges.count < 3 else { return }
        guard !activeChallenges.contains(where: { $0.id == challenge.id }) else { return }
        var c = challenge
        c.state = .accepted
        c.joinedAt = Date()
        c.progress = 0
        activeChallenges.append(c)
        discoverChallenges.removeAll { $0.id == c.id }
        persistState()
    }

    func markBookCompleted(title: String) async {
        do {
            try await AppAPI.shared.markBookCompleted(title: title)
            await updateProgress()
        } catch {
            print("[ChallengeViewModel] markBookCompleted failed: \(error) — progress will update on next refresh")
        }
    }

    func createCustomChallenge(title: String, description: String, goalUnit: String, goalCount: Int) {
        let challenge = Challenge(
            title: title,
            description: description,
            goalUnit: goalUnit,
            goalCount: goalCount,
            rewardXP: 25,
            state: .accepted,
            joinedAt: Date()
        )
        guard activeChallenges.count < 3 else { return }
        activeChallenges.append(challenge)
        persistState()
    }

    func abandon(_ challenge: Challenge) {
        activeChallenges.removeAll { $0.id == challenge.id }
        refreshDiscover()
        persistState()
    }

    // MARK: - Progress update from server

    func updateProgress() async {
        async let weatherTask = WeatherChallengeService.shared.fetchWeatherChallenge()
        do {
            async let historyTask = AppAPI.shared.fetchSessionHistory()
            async let completedTask = AppAPI.shared.fetchCompletedBooks()
            let (history, completedBooks) = try await (historyTask, completedTask)
            sessionHistory = history
            applyProgress(history: history, completedBooks: completedBooks)
            checkExpiry()
            promoteCompleted()
            updateStreak(from: history)
            persistState()
        } catch {
            print("[ChallengeViewModel] updateProgress fetch failed: \(error)")
        }
        weatherChallenge = await weatherTask
        refreshDiscover()
    }

    private func applyProgress(history: [SessionHistoryEntry], completedBooks: [CompletedBookEntry]) {
        let iso = ISO8601DateFormatter()
        for idx in activeChallenges.indices {
            let c = activeChallenges[idx]
            let since = c.joinedAt ?? Date.distantPast
            let until = c.expiresAt ?? Date()
            let goal = max(1, c.goalCount)
            let lower = c.goalUnit.lowercased()

            let windowHistory = history.filter { entry in
                guard let date = iso.date(from: entry.endedAt) else { return false }
                return date >= since && date <= until
            }
            let windowCompleted = completedBooks.filter { entry in
                guard let date = iso.date(from: entry.completedAt) else { return false }
                return date >= since && date <= until
            }

            let newProgress: Double
            if lower.contains("minute") {
                let minutes = windowHistory.reduce(0) { $0 + $1.durationSeconds / 60 }
                newProgress = min(1.0, Double(minutes) / Double(goal))
            } else if lower.contains("book") {
                newProgress = min(1.0, Double(windowCompleted.count) / Double(goal))
            } else if lower.contains("page") {
                let pages = windowHistory.reduce(0) { $0 + ($1.pagesRead ?? 0) }
                newProgress = min(1.0, Double(pages) / Double(goal))
            } else {
                newProgress = c.progress
            }
            activeChallenges[idx].progress = newProgress
        }
    }

    private func checkExpiry() {
        let now = Date()
        activeChallenges.removeAll { c in
            guard let expiry = c.expiresAt else { return false }
            return expiry < now && c.progress < 1.0
        }
    }

    private func promoteCompleted() {
        let toComplete = activeChallenges.filter { $0.progress >= 1.0 }.map { $0.id }
        for id in toComplete {
            if let idx = activeChallenges.firstIndex(where: { $0.id == id }) {
                var c = activeChallenges.remove(at: idx)
                c.state = .completed
                c.progress = 1.0
                completedChallenges.append(c)
                recentlyCompleted.append(c)
            }
        }
    }

    func clearRecentlyCompleted() {
        recentlyCompleted = []
    }

    var canAcceptChallenge: Bool {
        activeChallenges.count < 3
    }

    // MARK: - Streak

    private func updateStreak(from history: [SessionHistoryEntry]) {
        let calendar = Calendar.current
        let iso = ISO8601DateFormatter()
        let now = Date()

        // Collect unique calendar days (as date components) that had sessions
        var sessionDays: Set<DateComponents> = []
        var activeDaysByMonth: [String: Set<Int>] = [:]
        var earliestDate: Date?

        for entry in history {
            guard let date = iso.date(from: entry.endedAt) else { continue }
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            sessionDays.insert(components)
            if earliestDate == nil || date < earliestDate! {
                earliestDate = date
            }
            if let year = components.year, let month = components.month, let day = components.day {
                let key = "\(year)-\(month)"
                activeDaysByMonth[key, default: []].insert(day)
            }
        }

        sessionActiveDays = activeDaysByMonth

        // First session month
        if let earliest = earliestDate {
            firstSessionMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: earliest))
        } else {
            firstSessionMonth = nil
        }

        // Active days in current month (day numbers)
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        activeDays = activeDaysByMonth["\(currentYear)-\(currentMonth)"] ?? []

        // Today check
        let todayDC = calendar.dateComponents([.year, .month, .day], from: now)
        hasSessionToday = sessionDays.contains(todayDC)

        // Streak: count consecutive days ending yesterday, then check today
        var streakCount = 0
        let todayStart = calendar.startOfDay(for: now)
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart) {
            var checkDate = yesterday
            while true {
                let dc = calendar.dateComponents([.year, .month, .day], from: checkDate)
                if sessionDays.contains(dc) {
                    streakCount += 1
                    guard let previous = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                    checkDate = previous
                } else {
                    break
                }
            }
        }
        if hasSessionToday { streakCount += 1 }
        streak = streakCount
    }

    // MARK: - Persistence

    private func persistState() {
        let encoder = JSONEncoder()
        do {
            UserDefaults.standard.set(try encoder.encode(activeChallenges), forKey: activeKey)
            UserDefaults.standard.set(try encoder.encode(completedChallenges), forKey: completedKey)
        } catch {
            print("[ChallengeViewModel] persistState failed: \(error)")
        }
    }

    private func loadPersisted() {
        let decoder = JSONDecoder()
        do {
            if let data = UserDefaults.standard.data(forKey: activeKey) {
                activeChallenges = try decoder.decode([Challenge].self, from: data)
            }
            if let data = UserDefaults.standard.data(forKey: completedKey) {
                completedChallenges = try decoder.decode([Challenge].self, from: data)
            }
        } catch {
            print("[ChallengeViewModel] loadPersisted failed: \(error)")
        }
    }

    private func refreshDiscover() {
        var discover = Challenge.bank.filter { c in
            !activeChallenges.contains(where: { $0.id == c.id }) &&
            !completedChallenges.contains(where: { $0.id == c.id })
        }
        if let wc = weatherChallenge,
           !activeChallenges.contains(where: { $0.id == wc.id }),
           !completedChallenges.contains(where: { $0.id == wc.id }) {
            discover.insert(wc, at: 0)
        }
        discoverChallenges = discover
    }
}

@MainActor
private struct ChallengeViewModelKey: EnvironmentKey {
    static let defaultValue = ChallengeViewModel()
}

extension EnvironmentValues {
    @MainActor var challengeViewModel: ChallengeViewModel {
        get { self[ChallengeViewModelKey.self] }
        set { self[ChallengeViewModelKey.self] = newValue }
    }
}
