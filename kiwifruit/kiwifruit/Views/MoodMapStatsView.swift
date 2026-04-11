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
                    if let session = lastCameraSession {
                        lastSessionSummarySection(session)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Recent sessions")
                            .font(.title2).fontWeight(.black)
                            .foregroundColor(MoodStatsDesign.uiText)
                        statsOverview
                    }
                    if moodStore.savedSessions.isEmpty {
                        emptyState
                    } else {
                        sessionsList
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

    /// Most recent session that has camera-captured mood distribution data.
    private var lastCameraSession: MoodMapSession? {
        moodStore.savedSessions.first { ($0.moodDistribution?.values.reduce(0, +) ?? 0) > 0 }
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

    // MARK: - Last Session Summary

    private func lastSessionSummarySection(_ session: MoodMapSession) -> some View {
        let sessionDuration = session.endedAt.timeIntervalSince(session.startedAt)
        let distribution = session.moodDistribution ?? [:]
        let totalFrames = distribution.values.reduce(0, +)

        return VStack(alignment: .leading, spacing: 16) {
            // Section title
            VStack(alignment: .leading, spacing: 4) {
                Text("Last Session")
                    .font(.title2).fontWeight(.black)
                    .foregroundColor(MoodStatsDesign.uiText)
                Text(sessionDateLabel(session.endedAt))
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(MoodStatsDesign.uiText)
            }

            VStack(alignment: .leading, spacing: 16) {
                // Distribution bars
                if totalFrames > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mood Breakdown")
                            .font(.caption).fontWeight(.bold)
                            .foregroundColor(MoodStatsDesign.uiText)
                            .textCase(.uppercase)
                            .kerning(0.5)

                        ForEach(QuickMood.allCases) { mood in
                            let count = distribution[mood.rawValue] ?? 0
                            if count > 0 {
                                let pct = Double(count) / Double(totalFrames)
                                HStack(spacing: 10) {
                                    Text(moodEmoji(mood))
                                        .font(.system(size: 14))
                                    Text(mood.displayName)
                                        .font(.caption).fontWeight(.semibold)
                                        .foregroundColor(MoodStatsDesign.uiText)
                                        .frame(width: 58, alignment: .leading)
                                    Canvas { context, size in
                                        let trackRect = CGRect(origin: .zero, size: size)
                                        context.fill(
                                            Path(roundedRect: trackRect, cornerRadius: 4),
                                            with: .color(MoodStatsDesign.uiText.opacity(0.07))
                                        )
                                        let fillRect = CGRect(x: 0, y: 0, width: size.width * pct, height: size.height)
                                        let fillPath = Path(roundedRect: fillRect, cornerRadius: 4)
                                        context.fill(fillPath, with: .color(moodCardColor(mood)))
                                        context.stroke(fillPath, with: .color(MoodStatsDesign.border), lineWidth: 1)
                                    }
                                    .frame(height: 18)
                                    Text("\(Int((pct * 100).rounded()))%")
                                        .font(.caption).fontWeight(.bold)
                                        .foregroundColor(MoodStatsDesign.uiText)
                                        .frame(width: 30, alignment: .trailing)
                                }
                            }
                        }
                    }
                }

                // Timeline strip
                if let timeline = session.moodTimeline, timeline.count >= 1, sessionDuration > 0 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mood Timeline")
                            .font(.caption).fontWeight(.bold)
                            .foregroundColor(MoodStatsDesign.uiText)
                            .textCase(.uppercase)
                            .kerning(0.5)

                        Canvas { context, size in
                            var x: CGFloat = 0
                            for (idx, event) in timeline.enumerated() {
                                let nextStart = idx + 1 < timeline.count
                                    ? timeline[idx + 1].secondsFromStart
                                    : sessionDuration
                                let fraction = CGFloat(max(nextStart - event.secondsFromStart, 0) / sessionDuration)
                                let segRect = CGRect(x: x, y: 0, width: size.width * fraction, height: size.height)
                                context.fill(Path(segRect), with: .color(moodCardColor(event.mood)))
                                x += size.width * fraction
                            }
                            let border = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 6)
                            context.stroke(border, with: .color(MoodStatsDesign.border.opacity(0.25)), lineWidth: 1.5)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .frame(height: 28)

                        HStack {
                            Text(formatSeconds(0))
                            Spacer()
                            Text(formatSeconds(sessionDuration))
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(MoodStatsDesign.uiText)

                        let uniqueMoods = Array(Set(timeline.map(\.mood))).sorted { $0.rawValue < $1.rawValue }
                        HStack(spacing: 12) {
                            ForEach(uniqueMoods) { mood in
                                HStack(spacing: 4) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(moodCardColor(mood))
                                        .frame(width: 12, height: 12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 3)
                                                .stroke(MoodStatsDesign.border, lineWidth: 1)
                                        )
                                    Text(mood.displayName)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(MoodStatsDesign.uiText)
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(MoodStatsDesign.border, lineWidth: 2)
            )
            .sketchShadow()
        }
    }

    private func moodEmoji(_ mood: QuickMood) -> String {
        switch mood {
        case .focused: return "😌"
        case .inspired: return "😊"
        case .tired: return "😴"
        }
    }

    private func formatSeconds(_ seconds: Double) -> String {
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func sessionDateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d 'at' h:mm a"
        return f.string(from: date)
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

    private var sessionsList: some View {
        VStack(spacing: 12) {
            ForEach(moodStore.savedSessions.prefix(10)) { session in
                sessionCard(session)
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
