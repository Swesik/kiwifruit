import SwiftUI

private enum StreakDesign {
    static let border = Color(hex: "2D3748")
    static let uiText = Color(hex: "2D3748")
    static let kiwi = Color(hex: "A3C985")
    static let kiwiLight = Color(hex: "E6F0DC")
    static let tealCard = Color(hex: "CFE6EC")
    static let tan = Color(hex: "D1BFAe")
}

struct StreakTrackerView: View {
    @Environment(\.moodSessionStore) private var moodStore: MoodSessionStore

    let streakDays: Int
    let activeDays: Set<Int>
    let hasSessionToday: Bool
    let firstSessionMonth: Date?
    let sessionActiveDays: [String: Set<Int>]

    @State private var displayMonth: Date = Date()

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayMonth)
    }

    private var canGoBack: Bool {
        guard let firstSessionMonth else { return false }
        return calendar.compare(displayMonth, to: firstSessionMonth, toGranularity: .month) == .orderedDescending
    }

    private func activeDaysForMonth(_ month: Date) -> Set<Int> {
        let year = calendar.component(.year, from: month)
        let monthNum = calendar.component(.month, from: month)
        return sessionActiveDays["\(year)-\(monthNum)"] ?? []
    }

    private func calendarDaysForMonth(_ month: Date) -> [Int?] {
        guard
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
            let range = calendar.range(of: .day, in: .month, for: month)
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: startOfMonth) - 1
        var days: [Int?] = Array(repeating: nil, count: firstWeekday)
        days.append(contentsOf: range.map { Int($0) })
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private func dateForDay(_ day: Int) -> Date? {
        let y = calendar.component(.year, from: displayMonth)
        let m = calendar.component(.month, from: displayMonth)
        return calendar.date(from: DateComponents(year: y, month: m, day: day))
    }

    private func moodSessionsForDay(_ day: Int) -> [MoodMapSession] {
        guard let date = dateForDay(day) else { return [] }
        return moodStore.sessions(byDate: date)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 32) {
                // Streak circle
                Circle()
                    .fill(hasSessionToday ? StreakDesign.kiwi : StreakDesign.kiwiLight)
                    .frame(width: 200, height: 200)
                    .overlay(Circle().stroke(StreakDesign.border, lineWidth: 2))
                    .sketchShadowCircle()
                    .overlay {
                        VStack(spacing: 0) {
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text("\(streakDays)")
                                    .font(.system(size: 52, weight: .black))
                                Text("day")
                                    .font(.system(size: 20, weight: .bold))
                            }
                            Text("streak")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(StreakDesign.uiText)
                    }
                    .padding(.top, 24)

                // Calendar
                VStack(spacing: 16) {
                    // Month navigation
                    HStack {
                        Button(action: {
                            if let previousMonth = calendar.date(byAdding: .month, value: -1, to: displayMonth) {
                                displayMonth = previousMonth
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(StreakDesign.uiText)
                        }
                        .disabled(!canGoBack)
                        .opacity(canGoBack ? 1 : 0.3)

                        Text(monthYearString)
                            .font(.title2).fontWeight(.black)
                            .foregroundColor(StreakDesign.uiText)
                            .frame(maxWidth: .infinity)

                        Button(action: {
                            let now = Date()
                            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: displayMonth),
                               calendar.compare(nextMonth, to: now, toGranularity: .month) != .orderedDescending {
                                displayMonth = nextMonth
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(StreakDesign.uiText)
                        }
                        .disabled(calendar.compare(displayMonth, to: Date(), toGranularity: .month) == .orderedSame)
                        .opacity(calendar.compare(displayMonth, to: Date(), toGranularity: .month) != .orderedSame ? 1 : 0.3)
                    }
                    .padding(.horizontal, 16)

                    let dayHeaders = ["S", "M", "T", "W", "T", "F", "S"]
                    let displayActiveDays = activeDaysForMonth(displayMonth)
                    let displayCalendarDays = calendarDaysForMonth(displayMonth)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                        ForEach(0..<dayHeaders.count, id: \.self) { i in
                            Text(dayHeaders[i])
                                .font(.subheadline).fontWeight(.black)
                                .foregroundColor(StreakDesign.uiText)
                        }

                        ForEach(displayCalendarDays.indices, id: \.self) { i in
                            let day = displayCalendarDays[i]
                            let isActive = day.map { displayActiveDays.contains($0) } ?? false

                            if let day {
                                Circle()
                                    .fill(isActive ? StreakDesign.kiwi : Color.clear)
                                    .overlay(Circle().stroke(StreakDesign.border, lineWidth: 1.5))
                                    .frame(width: 32, height: 32)
                            } else {
                                Circle()
                                    .fill(Color.clear)
                                    .overlay(Circle().stroke(Color.clear, lineWidth: 1.5))
                                    .frame(width: 32, height: 32)
                                    .opacity(0)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Text("Tap a day to view mood session results")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundColor(StreakDesign.kiwi)
                    .padding(.top, -16)

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 24)
        }
        .background(Color.white)
        .navigationTitle("Streak")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            moodStore.refreshSessionsIfNeeded()
        }
    }

    private var calendar: Calendar {
        Calendar.current
    }
}

// MARK: - Mood Day Detail View

struct MoodDayDetailView: View {
    let date: Date
    let sessions: [MoodMapSession]
    let isReadingDay: Bool

    @Environment(\.dismiss) private var dismiss

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                VStack(alignment: .leading, spacing: 24) {
                    daySummarySection
                    if !sessions.isEmpty {
                        moodSessionsSection
                    } else {
                        emptySection
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .background(Color.white)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button("close") { dismiss() }
                .font(.subheadline).fontWeight(.bold)
                .foregroundColor(StreakDesign.uiText)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(StreakDesign.tan)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(StreakDesign.border, lineWidth: 2))
                .sketchShadow(cornerRadius: 20)

            Text(dateString)
                .font(.system(size: 30, weight: .black))
                .foregroundColor(StreakDesign.uiText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 48)
        .padding(.bottom, 24)
    }

    // MARK: - Day Summary

    private var daySummarySection: some View {
        summaryPill(
            icon: "face.smiling",
            label: sessions.isEmpty ? "No mood data" : "\(sessions.count) session\(sessions.count == 1 ? "" : "s")",
            color: sessions.isEmpty ? StreakDesign.kiwiLight : StreakDesign.tealCard
        )
    }

    private func summaryPill(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
            Text(label)
                .font(.caption).fontWeight(.bold)
        }
        .foregroundColor(StreakDesign.uiText)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(StreakDesign.border, lineWidth: 2))
        .sketchShadow()
    }

    // MARK: - Mood Sessions

    private var moodSessionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mood sessions")
                .font(.title2).fontWeight(.black)
                .foregroundColor(StreakDesign.uiText)

            VStack(spacing: 12) {
                ForEach(sessions.sorted(by: { $0.endedAt > $1.endedAt })) { session in
                    moodSessionCard(session)
                }
            }
        }
    }

    private func moodSessionCard(_ session: MoodMapSession) -> some View {
        let timeFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "h:mm a"
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
                        .foregroundColor(StreakDesign.uiText)
                    Text("\(minutes)m \(seconds)s")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(StreakDesign.uiText.opacity(0.6))
                }
                Spacer()
                if let mood = session.postSessionMood {
                    moodBadge(mood)
                } else {
                    Text("No mood")
                        .font(.caption).fontWeight(.bold)
                        .foregroundColor(StreakDesign.uiText.opacity(0.4))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(StreakDesign.kiwiLight)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(StreakDesign.border.opacity(0.3), lineWidth: 1.5))
                }
            }
        }
        .padding(16)
        .background(StreakDesign.tealCard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(StreakDesign.border, lineWidth: 2))
        .sketchShadow()
    }

    private func moodBadge(_ mood: QuickMood) -> some View {
        let color: Color = {
            switch mood {
            case .focused: return Color(hex: "88C0D0")
            case .inspired: return StreakDesign.kiwi
            case .tired: return StreakDesign.tan
            }
        }()

        return Text(mood.displayName)
            .font(.caption).fontWeight(.black)
            .foregroundColor(StreakDesign.uiText)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(StreakDesign.border, lineWidth: 2))
    }

    // MARK: - Empty

    private var emptySection: some View {
        VStack(spacing: 12) {
            Text("No mood sessions")
                .font(.title3).fontWeight(.black)
                .foregroundColor(StreakDesign.uiText)
            Text("Start a mood capture during your next reading session to track how you feel.")
                .font(.subheadline).fontWeight(.medium)
                .foregroundColor(StreakDesign.uiText.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

#Preview {
    NavigationStack {
        StreakTrackerView(
            streakDays: 5,
            activeDays: [3, 11, 12, 17],
            hasSessionToday: false,
            firstSessionMonth: Calendar.current.date(from: DateComponents(year: 2026, month: 3)),
            sessionActiveDays: ["2026-3": [3, 11, 12, 17]]
        )
        .environment(\.moodSessionStore, MoodSessionStore())
    }
}
