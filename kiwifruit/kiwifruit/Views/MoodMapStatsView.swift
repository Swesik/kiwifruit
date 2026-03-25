import SwiftUI

struct MoodMapStatsView: View {
    @Environment(\.moodSessionStore) private var moodStore: MoodSessionStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    statsOverview
                    sessionsList
                }
                .padding()
            }
            .background(Color(hex: "FAFAFA"))
            .navigationTitle("Mood Map Stats")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            moodStore.refreshSessionsIfNeeded()
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Your Reading Moods")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color(hex: "2D3748"))

            Text("Track your emotional journey while reading")
                .font(.subheadline)
                .foregroundStyle(Color(hex: "2D3748").opacity(0.6))
        }
        .padding(.top)
    }

    private var statsOverview: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                statCard(
                    mood: .focused,
                    count: focusedCount,
                    total: totalSessions
                )
                statCard(
                    mood: .inspired,
                    count: inspiredCount,
                    total: totalSessions
                )
                statCard(
                    mood: .tired,
                    count: tiredCount,
                    total: totalSessions
                )
            }
        }
    }

    private func statCard(mood: QuickMood, count: Int, total: Int) -> some View {
        let percentage = total > 0 ? Double(count) / Double(total) * 100 : 0

        return         VStack(spacing: 8) {
            Text(moodEmoji(mood))
                .font(.system(size: 28))

            Text("\(count)")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(Color(hex: "2D3748"))

            Text(mood.displayName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color(hex: "2D3748").opacity(0.7))

            Text(String(format: "%.0f%%", percentage))
                .font(.caption2)
                .foregroundStyle(Color(hex: "2D3748").opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "2D3748").opacity(0.2), lineWidth: 1))
        )
    }

    private var sessionsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Sessions")
                .font(.headline)
                .foregroundStyle(Color(hex: "2D3748"))
                .padding(.top, 8)

            if moodStore.savedSessions.isEmpty {
                emptyState
            } else {
                ForEach(moodStore.savedSessions.prefix(10)) { session in
                    sessionRow(session: session)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "face.dashed")
                .font(.system(size: 48))
                .foregroundStyle(Color(hex: "2D3748").opacity(0.3))

            Text("No mood sessions yet")
                .font(.headline)
                .foregroundStyle(Color(hex: "2D3748").opacity(0.5))

            Text("Start a mood session during your next reading to track your emotions")
                .font(.subheadline)
                .foregroundStyle(Color(hex: "2D3748").opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func sessionRow(session: MoodMapSession) -> some View {
        HStack(spacing: 12) {
            if let mood = session.postSessionMood {
                Text(moodEmoji(mood))
                    .font(.system(size: 24))
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(moodColor(mood).opacity(0.15))
                    )
            } else {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.gray)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.gray.opacity(0.15))
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(session.postSessionMood?.displayName ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(hex: "2D3748"))

                Text(formattedDate(session.endedAt))
                    .font(.caption)
                    .foregroundStyle(Color(hex: "2D3748").opacity(0.5))
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "2D3748").opacity(0.1), lineWidth: 1))
        )
    }

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

    private func moodEmoji(_ mood: QuickMood) -> String {
        switch mood {
        case .focused: return "🎯"
        case .inspired: return "✨"
        case .tired: return "😴"
        }
    }

    private func moodColor(_ mood: QuickMood) -> Color {
        switch mood {
        case .focused: return Color(hex: "88C0D0")
        case .inspired: return Color(hex: "A3C985")
        case .tired: return Color(hex: "D1BFAe")
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    MoodMapStatsView()
}
