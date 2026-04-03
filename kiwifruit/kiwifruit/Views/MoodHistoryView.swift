import SwiftUI

private enum MoodHistoryDesign {
    static let border = Color(hex: "2D3748")
    static let uiText = Color(hex: "2D3748")
    static let kiwi = Color(hex: "A3C985")
    static let kiwiLight = Color(hex: "E6F0DC")
    static let tealCard = Color(hex: "CFE6EC")
    static let tan = Color(hex: "D1BFAe")
}

struct MoodHistoryView: View {
    @Environment(\.moodSessionStore) private var moodStore: MoodSessionStore
    @State private var cognitiveSummaries: [DayCognitiveSummary] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isRequestingAuth = false

    private let healthService = MoodHistoryService.shared

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                headerSection

                if isLoading {
                    loadingSection
                } else if let error = errorMessage {
                    errorSection(error)
                } else if cognitiveSummaries.isEmpty && moodStore.savedSessions.isEmpty {
                    emptySection
                } else {
                    historyContentSection
                }

                Spacer(minLength: 48)
            }
        }
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await loadData()
        }
        .onAppear {
            moodStore.refreshSessionsIfNeeded()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mood Session History")
                .font(.system(size: 30, weight: .black))
                .foregroundColor(MoodHistoryDesign.uiText)
                .padding(.top, 48)

            if !cognitiveSummaries.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14, weight: .bold))
                    Text("\(cognitiveSummaries.count) day\(cognitiveSummaries.count == 1 ? "" : "s") of cognitive data")
                        .font(.caption).fontWeight(.bold)
                }
                .foregroundColor(MoodHistoryDesign.uiText)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(MoodHistoryDesign.tealCard)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(MoodHistoryDesign.border, lineWidth: 2))
                .sketchShadow()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(MoodHistoryDesign.kiwi)
            Text("Loading mood history...")
                .font(.subheadline).fontWeight(.bold)
                .foregroundColor(MoodHistoryDesign.uiText.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }

    // MARK: - Error

    private func errorSection(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(MoodHistoryDesign.tan)
            Text(message)
                .font(.subheadline).fontWeight(.bold)
                .foregroundColor(MoodHistoryDesign.uiText.opacity(0.6))
                .multilineTextAlignment(.center)

            if healthService.isHealthKitAvailable && errorMessage == "HealthKit is not available on this device." {
                Button("Grant Access") {
                    Task { await requestAuth() }
                }
                .font(.subheadline).fontWeight(.black)
                .foregroundColor(MoodHistoryDesign.uiText)
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(MoodHistoryDesign.kiwi)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(MoodHistoryDesign.border, lineWidth: 2))
                .sketchShadow()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 32)
    }

    // MARK: - Empty

    private var emptySection: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(MoodHistoryDesign.kiwiLight)
            Text("No mood data yet")
                .font(.title3).fontWeight(.black)
                .foregroundColor(MoodHistoryDesign.uiText)
            Text("Your cognitive state will appear here after reading sessions using iPhone 16's Neural Engine.")
                .font(.subheadline).fontWeight(.medium)
                .foregroundColor(MoodHistoryDesign.uiText.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 32)
    }

    // MARK: - History Content

    private var historyContentSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Cognitive state sections from HealthKit
            if !cognitiveSummaries.isEmpty {
                Text("Cognitive State")
                    .font(.title2).fontWeight(.black)
                    .foregroundColor(MoodHistoryDesign.uiText)
                    .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    ForEach(cognitiveSummaries.reversed()) { summary in
                        cognitiveDayCard(summary)
                    }
                }
                .padding(.horizontal, 24)
            }

            // Local mood session sections
            if !moodStore.savedSessions.isEmpty {
                Text("Mood Sessions")
                    .font(.title2).fontWeight(.black)
                    .foregroundColor(MoodHistoryDesign.uiText)
                    .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    ForEach(moodStore.savedSessions.sorted(by: { $0.endedAt > $1.endedAt })) { session in
                        moodSessionCard(session)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }

    private func cognitiveDayCard(_ summary: DayCognitiveSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.dateString)
                        .font(.subheadline).fontWeight(.bold)
                        .foregroundColor(MoodHistoryDesign.uiText)
                    if summary.focusedMinutes > 0 {
                        Text("\(summary.focusedMinutes)m focused")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundColor(MoodHistoryDesign.uiText.opacity(0.6))
                    }
                }
                Spacer()
                if let mood = summary.primaryMood {
                    moodBadge(mood)
                }
            }

            HStack(spacing: 6) {
                ForEach(Array(summary.mappedMoods.enumerated()), id: \.offset) { _, mood in
                    Text(mood.displayName)
                        .font(.caption2).fontWeight(.bold)
                        .foregroundColor(MoodHistoryDesign.uiText.opacity(0.7))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(moodColor(mood).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Spacer()
                Text("\(summary.sessionCount) sample\(summary.sessionCount == 1 ? "" : "s")")
                    .font(.caption2).fontWeight(.bold)
                    .foregroundColor(MoodHistoryDesign.uiText.opacity(0.4))
            }
        }
        .padding(16)
        .background(MoodHistoryDesign.tealCard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(MoodHistoryDesign.border, lineWidth: 2))
        .sketchShadow()
    }

    private func moodSessionCard(_ session: MoodMapSession) -> some View {
        let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "MMM d, h:mm a"
            return f
        }()

        let duration = Int(session.endedAt.timeIntervalSince(session.startedAt))
        let minutes = duration / 60
        let seconds = duration % 60

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(timeFormatter.string(from: session.startedAt))
                        .font(.subheadline).fontWeight(.bold)
                        .foregroundColor(MoodHistoryDesign.uiText)
                    Text("\(minutes)m \(seconds)s")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(MoodHistoryDesign.uiText.opacity(0.6))
                }
                Spacer()
                if let mood = session.postSessionMood {
                    moodBadge(mood)
                } else {
                    Text("No mood")
                        .font(.caption).fontWeight(.bold)
                        .foregroundColor(MoodHistoryDesign.uiText.opacity(0.4))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(MoodHistoryDesign.kiwiLight)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(MoodHistoryDesign.border.opacity(0.3), lineWidth: 1.5))
                }
            }
        }
        .padding(16)
        .background(MoodHistoryDesign.tealCard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(MoodHistoryDesign.border, lineWidth: 2))
        .sketchShadow()
    }

    private func moodBadge(_ mood: QuickMood) -> some View {
        let color: Color = {
            switch mood {
            case .focused: return Color(hex: "88C0D0")
            case .inspired: return MoodHistoryDesign.kiwi
            case .tired: return MoodHistoryDesign.tan
            }
        }()

        return Text(mood.displayName)
            .font(.caption).fontWeight(.black)
            .foregroundColor(MoodHistoryDesign.uiText)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(MoodHistoryDesign.border, lineWidth: 2))
    }

    private func moodColor(_ mood: QuickMood) -> Color {
        switch mood {
        case .focused: return Color(hex: "88C0D0")
        case .inspired: return MoodHistoryDesign.kiwi
        case .tired: return MoodHistoryDesign.tan
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            if healthService.isHealthKitAvailable {
                try await healthService.requestAuthorization()
                cognitiveSummaries = try await healthService.fetchAllCognitiveStates()
            } else {
                cognitiveSummaries = []
            }
        } catch let error as MoodHistoryError {
            errorMessage = error.errorDescription
            cognitiveSummaries = []
        } catch {
            errorMessage = error.localizedDescription
            cognitiveSummaries = []
        }

        isLoading = false
    }

    private func requestAuth() async {
        isRequestingAuth = true
        await loadData()
        isRequestingAuth = false
    }
}

#Preview {
    MoodHistoryView()
        .environment(\.moodSessionStore, MoodSessionStore())
}
