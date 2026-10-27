import SwiftUI

struct MiniHeatmap: View {
    let habit: Habit
    let today: Date
    var body: some View {
        HStack(spacing: 3) {
            ForEach(-27...0, id: \.self) { offset in
                let done = habit.isComplete(Day.adding(offset, to: today))
                RoundedRectangle(cornerRadius: 2).fill(Color(habitHex: habit.colorHex).opacity(done ? 1 : 0.12)).frame(height: 8)
            }
        }.accessibilityElement(children: .ignore).accessibilityLabel("Last 28 days: \((-27...0).filter { habit.isComplete(Day.adding($0, to: today)) }.count) completed")
    }
}

struct HeatmapView: View {
    let habit: Habit
    let today: Date
    let weekly: Bool
    let toggle: (Date) -> Void
    private var dates: [Date] {
        let today = Day.calendar.startOfDay(for: self.today)
        let startOfWeek = Day.calendar.dateInterval(of: .weekOfYear, for: today)!.start
        let start = Day.adding(-77, to: startOfWeek)
        return (0..<84).map { Day.adding($0, to: start) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text(dates[0], format: .dateTime.month(.abbreviated)); Spacer(); Text(today, format: .dateTime.month(.abbreviated).year()) }.font(.caption).foregroundStyle(.secondary)
            if weekly {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(0..<12) { week in
                        let slice = Array(dates[(week * 7)..<(week * 7 + 7)])
                        let eligible = slice.filter { $0 <= today && $0 >= Day.calendar.startOfDay(for: habit.createdAt) }
                        let count = eligible.filter { habit.isComplete($0) }.count
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 5).fill(Color(habitHex: habit.colorHex).opacity(count == 0 ? 0.12 : 0.2 + Double(count) / 7 * 0.8))
                                .frame(height: 72)
                            Text("\(count)").font(.caption2.monospacedDigit())
                        }.accessibilityElement(children: .ignore).accessibilityLabel("Week of \(slice[0].formatted(date: .abbreviated, time: .omitted)): \(count) of \(eligible.count) days")
                    }
                }
            } else {
                // Columns are weeks; rows follow the locale's first weekday.
                HStack(alignment: .top, spacing: 5) {
                    ForEach(0..<12) { week in
                        VStack(spacing: 5) {
                            ForEach(0..<7) { weekday in
                                let date = dates[week * 7 + weekday]
                                let eligible = date <= today && date >= Day.calendar.startOfDay(for: habit.createdAt)
                                Button { toggle(date) } label: {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(habitHex: habit.colorHex).opacity(habit.isComplete(date) ? 1 : 0.12))
                                        .aspectRatio(1, contentMode: .fit).opacity(eligible ? 1 : 0.2)
                                }.buttonStyle(.plain).disabled(!eligible)
                                    .accessibilityLabel("\(date.formatted(date: .complete, time: .omitted)), \(habit.isComplete(date) ? "complete, undo" : "incomplete, complete")")
                            }
                        }
                    }
                }
            }
            Text(weekly ? "Each column is a week. Brighter means more completed days." : "12 weeks · Tap a day to update its check-in.").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct StreakGoalView: View {
    let current: Int
    let goal: Int
    let colorHex: String
    private var progress: StreakGoalProgress { StreakGoalProgress(current: current, goal: goal) }
    private var status: String {
        if progress.reached { return "Goal reached!" }
        return "\(progress.remaining) \(progress.remaining == 1 ? "day" : "days") to goal"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if goal > 0 {
                Text("\(progress.current)-day streak · \(status)")
                    .font(.caption.weight(.medium)).monospacedDigit()
                    .foregroundStyle(Color(habitHex: colorHex))
                    .fixedSize(horizontal: false, vertical: true)
                ProgressView(value: progress.fraction)
                    .tint(Color(habitHex: colorHex))
                    .accessibilityHidden(true)
                Text("Goal: \(progress.goal) consecutive \(progress.goal == 1 ? "day" : "days")")
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("\(max(0, current))-day streak")
                    .font(.caption.weight(.medium)).monospacedDigit()
                    .foregroundStyle(Color(habitHex: colorHex))
            }
        }
        .accessibilityElement(children: .combine)
    }
}
