import SwiftUI

private enum MoodStatsDesign {
    static let border = Color(hex: "2D3748")
    static let uiText = Color(hex: "2D3748")
    static let kiwi = Color(hex: "A3C985")
    static let kiwiLight = Color(hex: "E6F0DC")
    static let tealCard = Color(hex: "CFE6EC")
    static let tan = Color(hex: "D1BFAe")
}

struct MoodMapStatsView: View {
    @Environment(\.moodSessionStore) private var moodStore: MoodSessionStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                VStack(alignment: .leading, spacing: 32) {
                    statsOverview
                    if moodStore.savedSessions.isEmpty {
                        emptyState
                    } else {
                        recentSessionsSection
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { moodStore.refreshSessionsIfNeeded() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("close") { dismiss() }
                .font(.subheadline).fontWeight(.bold)
                .foregroundColor(MoodStatsDesign.uiText)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(MoodStatsDesign.tan)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(MoodStatsDesign.border, lineWidth: 2))
                .sketchShadow(cornerRadius: 20)

            Text("Mood Stats")
                .font(.system(size: 36, weight: .black))
                .foregroundColor(MoodStatsDesign.uiText)

            Text("Your emotional journey while reading")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundColor(MoodStatsDesign.uiText.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 48)
        .padding(.bottom, 24)
    }

    // MARK: - Stats Overview

    private var statsOverview: some View {
        HStack(spacing: 12) {
            statCard(mood: .focused, count: focusedCount)
            statCard(mood: .inspired, count: inspiredCount)
            statCard(mood: .tired, count: tiredCount)
        }
    }

    private func statCard(mood: QuickMood, count: Int) -> some View {
        let percentage = totalSessions > 0 ? Int(Double(count) / Double(totalSessions) * 100) : 0

        return VStack(spacing: 8) {
            Text("\(count)")
                .font(.system(size: 28, weight: .black))
                .foregroundColor(MoodStatsDesign.uiText)

            Text(mood.displayName)
                .font(.caption).fontWeight(.bold)
                .foregroundColor(MoodStatsDesign.uiText)

            Text("\(percentage)%")
                .font(.caption2).fontWeight(.semibold)
                .foregroundColor(MoodStatsDesign.uiText.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(moodCardColor(mood))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(MoodStatsDesign.border, lineWidth: 2))
        .sketchShadow()
    }

    private func moodCardColor(_ mood: QuickMood) -> Color {
        switch mood {
        case .focused: return MoodStatsDesign.tealCard
        case .inspired: return MoodStatsDesign.kiwiLight
        case .tired: return Color(hex: "F5E6D3")
        }
    }

    // MARK: - Recent Sessions

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent sessions")
                .font(.title2).fontWeight(.black)
                .foregroundColor(MoodStatsDesign.uiText)

            VStack(spacing: 12) {
                ForEach(moodStore.savedSessions.prefix(10)) { session in
                    sessionCard(session)
                }
            }
        }
    }

    private func sessionCard(_ session: MoodMapSession) -> some View {
        let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "MMM d, h:mm a"
            return f
        }()

        let duration = Int(session.endedAt.timeIntervalSince(session.startedAt))
        let minutes = duration / 60

        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.postSessionMood?.displayName ?? "No mood")
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundColor(MoodStatsDesign.uiText)
                Text(timeFormatter.string(from: session.endedAt))
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(MoodStatsDesign.uiText.opacity(0.6))
            }
            Spacer()
            Text("\(minutes)m")
                .font(.caption).fontWeight(.black)
                .foregroundColor(MoodStatsDesign.uiText)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(MoodStatsDesign.kiwiLight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(MoodStatsDesign.border, lineWidth: 2))
        }
        .padding(16)
        .background(MoodStatsDesign.tealCard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(MoodStatsDesign.border, lineWidth: 2))
        .sketchShadow()
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No mood sessions yet")
                .font(.title3).fontWeight(.black)
                .foregroundColor(MoodStatsDesign.uiText)
            Text("Start a mood capture during your next reading session to track how you feel.")
                .font(.subheadline).fontWeight(.medium)
                .foregroundColor(MoodStatsDesign.uiText.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Computed

    private var focusedCount: Int {
        moodStore.savedSessions.filter { $0.postSessionMood == .focused }.count
    }

    private var inspiredCount: Int {
        moodStore.savedSessions.filter { $0.postSessionMood == .inspired }.count
    }

    private var tiredCount: Int {
        moodStore.savedSessions.filter { $0.postSessionMood == .tired }.count
    }

    private var totalSessions: Int {
        moodStore.savedSessions.count
    }
}

#Preview {
    MoodMapStatsView()
        .environment(\.moodSessionStore, MoodSessionStore())
}
