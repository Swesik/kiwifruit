import SwiftUI

private enum MoodHistoryDesign {
    static let border = Color(hex: "2D3748")
    static let uiText = Color(hex: "2D3748")
    static let kiwi = Color(hex: "A3C985")
    static let kiwiLight = Color(hex: "E6F0DC")
    static let tealCard = Color(hex: "CFE6EC")
    static let tan = Color(hex: "D1BFAe")
}

/// Groups saved MoodMapSessions by calendar day for display.
struct DayMoodGroup: Identifiable {
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d, yyyy"
        return f
    }()

    let id = UUID()
    let date: Date
    let sessions: [MoodMapSession]

    var dateString: String {
        Self.dayFormatter.string(from: date)
    }

    var sessionCount: Int {
        sessions.count
    }

    var totalMinutes: Int {
        let seconds = sessions.reduce(0) { total, session in
            total + Int(session.endedAt.timeIntervalSince(session.startedAt))
        }
        return seconds / 60
    }

    /// Mood with the most occurrences that day.
    var primaryMood: QuickMood? {
        let moods = sessions.compactMap { $0.postSessionMood }
        guard !moods.isEmpty else { return nil }
        let counts = Dictionary(grouping: moods, by: { $0 }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}

struct MoodHistoryView: View {
    @Environment(\.moodSessionStore) private var moodStore: MoodSessionStore

    private var dayGroups: [DayMoodGroup] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: moodStore.savedSessions) { session -> Date in
            cal.startOfDay(for: session.endedAt)
        }
        return grouped
            .map { DayMoodGroup(date: $0.key, sessions: $0.value) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                headerSection

                if moodStore.savedSessions.isEmpty {
                    emptySection
                } else {
                    historyContentSection
                }

                Spacer(minLength: 48)
            }
        }
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
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

            if !dayGroups.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14, weight: .bold))
                    Text("\(dayGroups.count) day\(dayGroups.count == 1 ? "" : "s") of mood records")
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

    // MARK: - Empty

    private var emptySection: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(MoodHistoryDesign.kiwiLight)
            Text("No mood data yet")
                .font(.title3).fontWeight(.black)
                .foregroundColor(MoodHistoryDesign.uiText)
            Text("Your mood sessions recorded during reading will appear here.")
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
            ForEach(dayGroups) { group in
                dayGroupCard(group)
            }
        }
        .padding(.horizontal, 24)
    }

    private func dayGroupCard(_ group: DayMoodGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Day header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.dateString)
                        .font(.subheadline).fontWeight(.bold)
                        .foregroundColor(MoodHistoryDesign.uiText)
                    if group.totalMinutes > 0 {
                        Text("\(group.totalMinutes)m total")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundColor(MoodHistoryDesign.uiText.opacity(0.6))
                    }
                }
                Spacer()
                if let mood = group.primaryMood {
                    moodBadge(mood)
                }
                Text("\(group.sessionCount) session\(group.sessionCount == 1 ? "" : "s")")
                    .font(.caption2).fontWeight(.bold)
                    .foregroundColor(MoodHistoryDesign.uiText.opacity(0.4))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(MoodHistoryDesign.kiwiLight.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Individual session cards
            ForEach(group.sessions.sorted(by: { $0.endedAt > $1.endedAt })) { session in
                moodSessionCard(session)
            }
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private func moodSessionCard(_ session: MoodMapSession) -> some View {
        let timeFormatter = Self.timeFormatter

        let duration = Int(session.endedAt.timeIntervalSince(session.startedAt))
        let minutes = duration / 60
        let seconds = duration % 60

        return HStack(spacing: 12) {
            Text(timeFormatter.string(from: session.startedAt))
                .font(.caption).fontWeight(.bold)
                .foregroundColor(MoodHistoryDesign.uiText)
                .frame(width: 70, alignment: .leading)

            Text("\(minutes)m \(seconds)s")
                .font(.caption).fontWeight(.semibold)
                .foregroundColor(MoodHistoryDesign.uiText.opacity(0.6))
                .frame(width: 60, alignment: .leading)

            Spacer()

            if let mood = session.postSessionMood {
                moodBadge(mood)
            } else {
                Text("—")
                    .font(.caption).fontWeight(.bold)
                    .foregroundColor(MoodHistoryDesign.uiText.opacity(0.3))
            }
        }
        .padding(12)
        .background(MoodHistoryDesign.kiwiLight.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(MoodHistoryDesign.border.opacity(0.3), lineWidth: 1.5))
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
}

#Preview {
    MoodHistoryView()
        .environment(\.moodSessionStore, MoodSessionStore())
}
