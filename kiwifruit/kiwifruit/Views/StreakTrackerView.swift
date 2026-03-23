import SwiftUI

struct StreakTrackerView: View {
    let streakDays: Int
    let activeDays: Set<Int>
    let sessionHistory: [SessionHistoryEntry]

    @State private var displayMonth: Date = Date()

    private var hasCompletedTodaysSession: Bool {
        let today = Calendar.current.component(.day, from: Date())
        return activeDays.contains(today)
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayMonth)
    }

    private var canGoBack: Bool {
        let calendar = Calendar.current
        let firstSessionMonth = firstSessionMonthDate
        guard let firstSessionMonth = firstSessionMonth else { return false }
        return calendar.compare(displayMonth, to: firstSessionMonth, toGranularity: .month) == .orderedDescending // displayMonth after firstSessionMonth
    }

    private var firstSessionMonthDate: Date? {
        let iso = ISO8601DateFormatter()
        let calendar = Calendar.current
        var earliestDate: Date?

        for entry in sessionHistory {
            guard let date = iso.date(from: entry.endedAt) else { continue }
            if earliestDate == nil || date < earliestDate! {
                earliestDate = date
            }
        }

        guard let earliestDate = earliestDate else { return nil }
        return calendar.date(from: calendar.dateComponents([.year, .month], from: earliestDate))
    }

    private func activeDaysForMonth(_ month: Date) -> Set<Int> {
        let iso = ISO8601DateFormatter()
        let calendar = Calendar.current
        let monthComponents = calendar.dateComponents([.year, .month], from: month)

        var activeDaysInMonth: Set<Int> = []
        for entry in sessionHistory {
            guard let date = iso.date(from: entry.endedAt) else { continue }
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            if components.year == monthComponents.year && components.month == monthComponents.month {
                if let day = components.day {
                    activeDaysInMonth.insert(day)
                }
            }
        }
        return activeDaysInMonth
    }

    private func calendarDaysForMonth(_ month: Date) -> [Int?] {
        let calendar = Calendar.current
        guard
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
            let range = calendar.range(of: .day, in: .month, for: month)
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: startOfMonth) - 1 // 0 = Sunday
        var days: [Int?] = Array(repeating: nil, count: firstWeekday)
        days.append(contentsOf: range.map { Int($0) })
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 32) {
                // Streak circle
                Circle()
                    .fill(hasCompletedTodaysSession ? Color(hex: "A3C985") : Color(hex: "E6F0DC"))
                    .frame(width: 200, height: 200)
                    .overlay(Circle().stroke(Color(hex: "2D3748"), lineWidth: 2))
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
                        .foregroundColor(Color(hex: "2D3748"))
                    }
                    .padding(.top, 24)

                // Calendar
                VStack(spacing: 16) {
                    // Month navigation
                    HStack {
                        Button(action: { 
                            let calendar = Calendar.current
                            if let previousMonth = calendar.date(byAdding: .month, value: -1, to: displayMonth) {
                                displayMonth = previousMonth
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "2D3748"))
                        }
                        .disabled(!canGoBack)
                        .opacity(canGoBack ? 1 : 0.3)

                        Text(monthYearString)
                            .font(.title2).fontWeight(.black)
                            .foregroundColor(Color(hex: "2D3748"))
                            .frame(maxWidth: .infinity)

                        Button(action: {
                            let calendar = Calendar.current
                            let now = Date()
                            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: displayMonth),
                               calendar.compare(nextMonth, to: now, toGranularity: .month) != .orderedDescending {
                                displayMonth = nextMonth
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(hex: "2D3748"))
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
                                .foregroundColor(Color(hex: "2D3748"))
                        }

                        ForEach(displayCalendarDays.indices, id: \.self) { i in
                            let day = displayCalendarDays[i]
                            let isActive = day.map { displayActiveDays.contains($0) } ?? false
                            Circle()
                                .fill(isActive ? Color(hex: "A3C985") : Color.clear)
                                .overlay(Circle().stroke(Color(hex: "2D3748"), lineWidth: 1.5))
                                .frame(width: 32, height: 32)
                                .opacity(day == nil ? 0 : 1)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 24)
        }
        .background(Color.white)
        .navigationTitle("Streak")
        .navigationBarTitleDisplayMode(.large)
    }

    private var calendar: Calendar {
        Calendar.current
    }
}

#Preview {
    NavigationStack {
        StreakTrackerView(
            streakDays: 5,
            activeDays: [3, 11, 12, 17],
            sessionHistory: [
                SessionHistoryEntry(
                    id: "1",
                    bookTitle: "Test",
                    durationSeconds: 1800,
                    pagesRead: 10,
                    endedAt: "2026-03-03T10:30:00Z"
                ),
                SessionHistoryEntry(
                    id: "2",
                    bookTitle: "Test",
                    durationSeconds: 1800,
                    pagesRead: 10,
                    endedAt: "2026-03-11T10:30:00Z"
                ),
                SessionHistoryEntry(
                    id: "3",
                    bookTitle: "Test",
                    durationSeconds: 1800,
                    pagesRead: 10,
                    endedAt: "2026-03-12T10:30:00Z"
                ),
                SessionHistoryEntry(
                    id: "4",
                    bookTitle: "Test",
                    durationSeconds: 1800,
                    pagesRead: 10,
                    endedAt: "2026-03-17T10:30:00Z"
                )
            ]
        )
    }
}
