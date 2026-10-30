import Foundation
import SwiftData

@Model
final class Habit {
    @Attribute(.unique) var id: UUID
    var name: String
    var habitDescription: String? = nil
    var trackingMode: String = "yesNo"
    var dailyTarget: Int = 1
    var counterData: Data? = nil
    var symbol: String
    var colorHex: String
    var createdAt: Date
    var order: Int
    var archived: Bool
    // Keep the stored default for existing installations; zero means no goal.
    var streakGoal: Int = 30
    // Optional additive storage: existing habits start with reminders disabled.
    var reminderData: Data? = nil
    // Day keys follow the user's local calendar; travel never shifts past check-ins.
    var days: [String]

    init(id: UUID = UUID(), name: String, symbol: String = "checkmark", colorHex: String = "63D6A3", createdAt: Date = .now, order: Int = 0, archived: Bool = false, days: [String] = [], streakGoal: Int = 0) {
        self.id = id; self.name = name; self.symbol = symbol; self.colorHex = colorHex
        self.createdAt = createdAt; self.order = order; self.archived = archived; self.days = days
        self.streakGoal = streakGoal
    }
    var isCounter: Bool { trackingMode == "counter" }
    var counts: [String: Int] {
        get {
            guard let counterData else { return [:] }
            return (try? JSONDecoder().decode([String: Int].self, from: counterData)) ?? [:]
        }
        set { counterData = try? JSONEncoder().encode(newValue) }
    }
    func count(on date: Date = .now) -> Int {
        counts[Day.key(date)] ?? (isComplete(date) ? max(1, dailyTarget) : 0)
    }
    func adjustCount(by amount: Int, on date: Date = .now) {
        let key = Day.key(date)
        let value = min(max(1, dailyTarget), max(0, count(on: date) + amount))
        var updated = counts
        updated[key] = value
        counts = updated
        days.removeAll { $0 == key }
        if value >= max(1, dailyTarget) { days.append(key) }
    }
    var hasStreakGoal: Bool { streakGoal > 0 }

    func isComplete(_ date: Date = .now) -> Bool { days.contains(Day.key(date)) }
    func toggle(_ date: Date = .now) {
        if isCounter {
            if isComplete(date) { adjustCount(by: -count(on: date), on: date) }
            else { adjustCount(by: max(1, dailyTarget) - count(on: date), on: date) }
            return
        }
        let key = Day.key(date)
        if days.contains(key) { days.removeAll { $0 == key } } else { days.append(key) }
    }
}

enum Day {
    static var calendar: Calendar { Calendar.current }
    static func key(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    static func adding(_ count: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: count, to: calendar.startOfDay(for: date))!
    }
    static func dates(from start: Date, through end: Date) -> [Date] {
        let start = calendar.startOfDay(for: start), end = calendar.startOfDay(for: end)
        guard start <= end else { return [] }
        let count = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return (0...count).map { adding($0, to: start) }
    }
}

struct HabitStats {
    let current: Int
    let longest: Int
    let percentage: Int
    init(habit: Habit, today: Date = .now) {
        let dates = Day.dates(from: habit.createdAt, through: today)
        let completed = Set(habit.days)
        var run = 0, best = 0, total = 0
        for date in dates {
            if completed.contains(Day.key(date)) { run += 1; total += 1; best = max(best, run) }
            else { run = 0 }
        }
        var cursor = Day.calendar.startOfDay(for: today)
        if !completed.contains(Day.key(cursor)) { cursor = Day.adding(-1, to: cursor) }
        var streak = 0
        let first = Day.calendar.startOfDay(for: habit.createdAt)
        while cursor >= first && completed.contains(Day.key(cursor)) {
            streak += 1; cursor = Day.adding(-1, to: cursor)
        }
        current = streak; longest = best
        percentage = dates.isEmpty ? 0 : Int((Double(total) / Double(dates.count) * 100).rounded())
    }
}

struct StreakGoalProgress {
    let current: Int
    let goal: Int
    var remaining: Int { max(0, goal - current) }
    var reached: Bool { current >= goal }
    var fraction: Double { min(1, Double(current) / Double(goal)) }

    init(current: Int, goal: Int) {
        self.current = max(0, current)
        self.goal = max(1, goal)
    }
}
