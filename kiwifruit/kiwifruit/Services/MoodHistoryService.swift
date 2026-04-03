import Foundation
import HealthKit

/// Service for reading mood/cognitive state from Apple HealthKit (iPhone 16 Neural Engine).
/// Falls back gracefully when HealthKit is unavailable or not authorized.
final class MoodHistoryService {
    static let shared = MoodHistoryService()

    private let healthStore = HKHealthStore()

    private init() {}

    // MARK: - Authorization

    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        guard isHealthKitAvailable else {
            throw MoodHistoryError.healthKitNotAvailable
        }

        let cognitiveTypes: Set<HKObjectType> = [
            HKObjectType.categoryType(forIdentifier: .cognitiveState)!
        ]

        try await healthStore.requestAuthorization(toShare: [], read: cognitiveTypes)
    }

    // MARK: - Fetch Cognitive State Samples

    /// Fetches cognitive state samples within the given date range, grouped by day.
    func fetchCognitiveStates(from startDate: Date, to endDate: Date) async throws -> [DayCognitiveSummary] {
        guard isHealthKitAvailable else { return [] }

        guard let cognitiveType = HKObjectType.categoryType(forIdentifier: .cognitiveState) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: true
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: cognitiveType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let allSamples = (samples as? [HKCategorySample]) ?? []
                let grouped = Dictionary(grouping: allSamples) { sample -> Date in
                    Calendar.current.startOfDay(for: sample.startDate)
                }

                let summaries = grouped.map { date, samples in
                    DayCognitiveSummary(date: date, samples: samples)
                }
                .sorted { $0.date < $1.date }

                continuation.resume(returning: summaries)
            }
            healthStore.execute(query)
        }
    }

    /// Fetches all available cognitive state samples from the earliest record up to now.
    func fetchAllCognitiveStates() async throws -> [DayCognitiveSummary] {
        let startDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        return try await fetchCognitiveStates(from: startDate, to: Date())
    }
}

// MARK: - Models

struct DayCognitiveSummary: Identifiable {
    let id = UUID()
    let date: Date
    let samples: [HKCategorySample]

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: date)
    }

    var shortDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    var sessionCount: Int {
        samples.count
    }

    /// Maps Apple cognitive states to QuickMood where possible.
    /// Falls back to `.inspired` for engaged states and `.tired` for distracted/fatigued.
    var mappedMoods: [QuickMood] {
        samples.map { sample in
            switch sample.value {
            case HKCategoryValueCognitiveState.engaged:
                return .inspired
            case HKCategoryValueCognitiveState.distracted:
                return .tired
            case HKCategoryValueCognitiveState.fatigued:
                return .tired
            case HKCategoryValueCognitiveState.focused:
                return .focused
            default:
                return .inspired
            }
        }
    }

    /// Primary mood for the day (most frequent sample value).
    var primaryMood: QuickMood? {
        guard !samples.isEmpty else { return nil }
        let moods = mappedMoods
        let counts = Dictionary(grouping: moods, by: { $0 }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    var focusedMinutes: Int {
        let seconds = samples.reduce(0.0) { total, sample in
            if sample.value == HKCategoryValueCognitiveState.focused || sample.value == HKCategoryValueCognitiveState.engaged {
                return total + sample.endDate.timeIntervalSince(sample.startDate)
            }
            return total
        }
        return Int(seconds / 60)
    }
}

// MARK: - Errors

enum MoodHistoryError: LocalizedError {
    case healthKitNotAvailable
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .healthKitNotAvailable:
            return "HealthKit is not available on this device."
        case .notAuthorized:
            return "Not authorized to access HealthKit data."
        }
    }
}
