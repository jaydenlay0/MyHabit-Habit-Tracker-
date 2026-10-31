import Foundation

struct HabitCompletionSummary {
    let completed: Int
    let total: Int
    var fraction: Double { total > 0 ? Double(completed) / Double(total) : 0 }
    var allDone: Bool { total > 0 && completed == total }

    init(habits: [Habit], today: Date, weekly: Bool, calendar: Calendar = .current) {
        let end = calendar.startOfDay(for: today)
        let start = weekly ? (calendar.dateInterval(of: .weekOfYear, for: end)?.start ?? end) : end
        var complete = 0
        var eligible = 0
        var day = start
        while day <= end {
            for habit in habits where !habit.archived && calendar.startOfDay(for: habit.createdAt) <= day {
                eligible += 1
                if habit.isComplete(day) { complete += 1 }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        completed = complete; total = eligible
    }
}
