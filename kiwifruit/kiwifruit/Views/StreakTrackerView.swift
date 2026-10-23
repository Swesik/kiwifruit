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
            hasSessionToday: false,
            firstSessionMonth: Calendar.current.date(from: DateComponents(year: 2026, month: 3)),
            sessionActiveDays: ["2026-3": [3, 11, 12, 17]]
        )
    }
}
