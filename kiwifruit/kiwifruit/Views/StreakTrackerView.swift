import SwiftUI

struct StreakTrackerView: View {
    let streakDays: Int

    // Mock: days of current month that had reading activity
    private let activeDays: Set<Int> = [3, 11, 12, 17]

    private var calendarDays: [Int?] {
        let calendar = Calendar.current
        let now = Date()
        guard
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
            let range = calendar.range(of: .day, in: .month, for: now)
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
                    .fill(Color(hex: "A3C985"))
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
                    Text("Current month")
                        .font(.title2).fontWeight(.black)
                        .foregroundColor(Color(hex: "2D3748"))

                    let dayHeaders = ["S", "M", "T", "W", "T", "F", "S"]
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                        ForEach(0..<dayHeaders.count, id: \.self) { i in
                            Text(dayHeaders[i])
                                .font(.subheadline).fontWeight(.black)
                                .foregroundColor(Color(hex: "2D3748"))
                        }

                        ForEach(calendarDays.indices, id: \.self) { i in
                            let day = calendarDays[i]
                            let isActive = day.map { activeDays.contains($0) } ?? false
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
}

#Preview {
    NavigationStack {
        StreakTrackerView(streakDays: 1)
    }
}
