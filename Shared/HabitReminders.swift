import Foundation

struct HabitReminders: Codable, Equatable {
    var enabled = false
    // Calendar weekday numbers: Sunday = 1 ... Saturday = 7.
    var weekdays = Array(1...7)
    // Minutes after local midnight. Up to three distinct times per selected day.
    var times = [10 * 60]
    var usesWindow = false
    var windowStart = 10 * 60
    var windowEnd = 18 * 60
    var windowCount = 1

    var scheduledMinutes: [Int] {
        guard usesWindow else { return times.sorted() }
        guard windowCount > 1 else { return [(windowStart + windowEnd) / 2] }
        let count: Int = min(windowCount, 3)
        let span: Double = Double(windowEnd - windowStart)
        let segments: Double = Double(windowCount - 1)
        var minutes: [Int] = []
        for index in 0..<count {
            let offset: Int = Int((span * Double(index) / segments).rounded())
            minutes.append(windowStart + offset)
        }
        return minutes
    }
    var hasValidStoredValues: Bool {
        weekdays.count <= 7 && Set(weekdays).count == weekdays.count && weekdays.allSatisfy({ (1...7).contains($0) })
            && (1...3).contains(times.count) && times.allSatisfy({ (0..<1440).contains($0) })
            && (0..<1440).contains(windowStart) && (0..<1440).contains(windowEnd) && (1...3).contains(windowCount)
    }
    var validationMessage: String? {
        guard enabled else { return nil }
        guard hasValidStoredValues else { return "Choose valid reminder days and times." }
        guard !weekdays.isEmpty, weekdays.count <= 7,
              Set(weekdays).count == weekdays.count, weekdays.allSatisfy({ (1...7).contains($0) }) else {
            return "Choose at least one weekday."
        }
        if usesWindow {
            guard (0..<1440).contains(windowStart), (0..<1440).contains(windowEnd),
                  windowEnd > windowStart, (1...3).contains(windowCount) else {
                return "Choose an end time later than the start time, and one to three reminders. Time windows must stay within one day."
            }
        } else {
            guard (1...3).contains(times.count), times.allSatisfy({ (0..<1440).contains($0) }) else {
                return "Choose one to three reminder times."
            }
        }
        guard Set(scheduledMinutes).count == scheduledMinutes.count else {
            return "Reminder times must be different. Widen the time window or choose distinct times."
        }
        return nil
    }
    // Every-day reminders use one repeating notification per time, rather than seven.
    var notificationSlots: Int { enabled ? scheduledMinutes.count * (weekdays.count == 7 ? 1 : weekdays.count) : 0 }
}

extension Habit {
    var reminders: HabitReminders {
        get {
            guard let reminderData else { return HabitReminders() }
            return (try? JSONDecoder().decode(HabitReminders.self, from: reminderData)) ?? HabitReminders()
        }
        set { reminderData = try? JSONEncoder().encode(newValue) }
    }
}
