import Foundation
import Observation
import SwiftUI

@Observable
final class ChallengeViewModel {
    var activeChallenges: [Challenge] = []
    var discoverChallenges: [Challenge] = []
    var completedChallenges: [Challenge] = []
    var weatherChallenge: Challenge? = nil
    var adaptiveChallenge: Challenge? = nil
    var streak: Int = 0
    var activeDays: Set<Int> = []
    var recentlyCompleted: [Challenge] = []
    var sessionHistory: [SessionHistoryEntry] = []
    var hasSessionToday: Bool = false
    var firstSessionMonth: Date? = nil
    var sessionActiveDays: [String: Set<Int>] = [:]

    private let api: APIClientProtocol
    private let storage: ChallengeStorageProtocol
    private let weatherService: WeatherChallengeServiceProtocol

    init(
        api: APIClientProtocol = AppAPI.shared,
        storage: ChallengeStorageProtocol = UserDefaultsChallengeStorage(),
        weatherService: WeatherChallengeServiceProtocol = WeatherChallengeService.shared
    ) {
        self.api = api
        self.storage = storage
        self.weatherService = weatherService
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
            try await api.markBookCompleted(title: title)
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

    func updateProgress(forceRefreshAdaptive: Bool = false) async {
        refreshWeather(forceRefresh: forceRefreshAdaptive)
        await refreshSessionData()
        await refreshAdaptiveRecommendation(forceRefresh: forceRefreshAdaptive)
        refreshDiscover()
    }

    /// Weather challenge rules:
    ///   1. If the user has accepted one that's still in flight → clear any
    ///      recommendation card and skip entirely.
    ///   2. If we already fetched one today (persisted) → keep it.
    ///   3. Otherwise fetch a new one and persist the date so we won't hit
    ///      the server again until tomorrow (unless forceRefresh is set).
    private func refreshWeather(forceRefresh: Bool) {
        if hasActiveWeatherChallenge {
            weatherChallenge = nil
            return
        }
        let cached = storage.loadCachedWeatherChallenge()
        let fetchedToday = cached.map { Calendar.current.isDate($0.fetchedAt, inSameDayAs: Date()) } ?? false

        if fetchedToday && !forceRefresh {
            if weatherChallenge == nil, let cached {
                weatherChallenge = cached.challenge
            }
            return
        }
        // @Observable + SwiftUI infers main-actor isolation; Task{} inherits,
        // so we write straight onto the main actor.
        Task { [weak self] in
            guard let self else { return }
            let w = await self.weatherService.fetchWeatherChallenge()
            self.weatherChallenge = w
            self.storage.saveCachedWeatherChallenge(w, fetchedAt: Date())
        }
    }

    private func refreshSessionData() async {
        do {
            async let historyTask = api.fetchSessionHistory()
            async let completedTask = api.fetchCompletedBooks()
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
    }

    /// Adaptive fetch rules:
    ///   1. User has an in-flight adaptive → clear any stale recommendation
    ///      and skip.
    ///   2. We already have a cached recommendation and caller didn't ask
    ///      for a fresh one → keep it stable (avoids a new OpenAI roll
    ///      every time the user navigates back to the tab).
    ///   3. Otherwise → fetch a new one.
    private func refreshAdaptiveRecommendation(forceRefresh: Bool) async {
        if hasActiveAdaptiveChallenge {
            adaptiveChallenge = nil
            return
        }
        if adaptiveChallenge != nil && !forceRefresh { return }

        do {
            let resp = try await api.fetchAdaptiveChallenge()
            if resp.available, let data = resp.challenge {
                adaptiveChallenge = Challenge(
                    title: data.title,
                    description: data.description,
                    goalUnit: data.goalUnit,
                    goalCount: data.goalCount,
                    rewardXP: data.rewardXP,
                    isAdaptive: true,
                    reason: data.reason
                )
            } else {
                adaptiveChallenge = nil
            }
        } catch {
            print("[ChallengeViewModel] fetchAdaptiveChallenge failed: \(error)")
        }
    }

    /// True when an adaptive challenge is already in-flight (accepted, not yet
    /// completed). Used to suppress further recommendations.
    var hasActiveAdaptiveChallenge: Bool {
        activeChallenges.contains { $0.isAdaptive && $0.state != .completed }
    }

    /// True when a weather challenge is already in-flight (accepted, not yet
    /// completed). Used to suppress further weather recommendations.
    var hasActiveWeatherChallenge: Bool {
        activeChallenges.contains { $0.isWeather && $0.state != .completed }
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

        var sessionDays: Set<DateComponents> = []
        var activeDaysByMonth: [String: Set<Int>] = [:]
        var earliestDate: Date?

        for entry in history {
            guard let date = iso.date(from: entry.endedAt) else { continue }
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            sessionDays.insert(components)
            if let earliest = earliestDate {
                if date < earliest { earliestDate = date }
            } else {
                earliestDate = date
            }
            if let year = components.year, let month = components.month, let day = components.day {
                let key = "\(year)-\(month)"
                activeDaysByMonth[key, default: []].insert(day)
            }
        }

        sessionActiveDays = activeDaysByMonth

        if let earliest = earliestDate {
            firstSessionMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: earliest))
        } else {
            firstSessionMonth = nil
        }

        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        activeDays = activeDaysByMonth["\(currentYear)-\(currentMonth)"] ?? []

        let todayDC = calendar.dateComponents([.year, .month, .day], from: now)
        hasSessionToday = sessionDays.contains(todayDC)

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
        storage.save(active: activeChallenges, completed: completedChallenges)
    }

    private func loadPersisted() {
        activeChallenges = storage.loadActiveChallenges()
        completedChallenges = storage.loadCompletedChallenges()
        // Rehydrate today's cached weather challenge (if any) so the card is
        // available before updateProgress runs.
        if let cached = storage.loadCachedWeatherChallenge(),
           Calendar.current.isDate(cached.fetchedAt, inSameDayAs: Date()) {
            weatherChallenge = cached.challenge
        }
    }

    private func refreshDiscover() {
        // Weather is now surfaced in the "Recommended for you" section along
        // with adaptive, so it's no longer injected into Discover.
        discoverChallenges = Challenge.bank.filter { c in
            !activeChallenges.contains(where: { $0.id == c.id }) &&
            !completedChallenges.contains(where: { $0.id == c.id })
        }
    }
}

private struct ChallengeViewModelKey: EnvironmentKey {
    static let defaultValue = ChallengeViewModel()
}

extension EnvironmentValues {
    var challengeViewModel: ChallengeViewModel {
        get { self[ChallengeViewModelKey.self] }
        set { self[ChallengeViewModelKey.self] = newValue }
    }
}
