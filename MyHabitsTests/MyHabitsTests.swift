import XCTest
import SwiftData
import UserNotifications
#if PERSONAL_TEAM
@testable import MyHabitsPersonal
#else
@testable import MyHabits
#endif

final class MyHabitsTests: XCTestCase {
    func date(_ offset: Int) -> Date { Day.adding(offset, to: .now) }
    func testToggleIsReversibleAndUnique() {
        let habit = Habit(name: "Read")
        habit.toggle(); XCTAssertTrue(habit.isComplete()); XCTAssertEqual(habit.days.count, 1)
        habit.toggle(); XCTAssertFalse(habit.isComplete()); XCTAssertTrue(habit.days.isEmpty)
    }
    func testStreakSurvivesUnfinishedToday() {
        let habit = Habit(name: "Read", createdAt: date(-4), days: [-4, -3, -2, -1].map { Day.key(date($0)) })
        let stats = HabitStats(habit: habit)
        XCTAssertEqual(stats.current, 4); XCTAssertEqual(stats.longest, 4); XCTAssertEqual(stats.percentage, 80)
    }
    func testGapBreaksCurrentButKeepsLongest() {
        let habit = Habit(name: "Walk", createdAt: date(-5), days: [-5, -4, -3, 0].map { Day.key(date($0)) })
        let stats = HabitStats(habit: habit)
        XCTAssertEqual(stats.current, 1); XCTAssertEqual(stats.longest, 3); XCTAssertEqual(stats.percentage, 67)
    }
    func testEmptyAndNewHabit() {
        let stats = HabitStats(habit: Habit(name: "New"))
        XCTAssertEqual(stats.current, 0); XCTAssertEqual(stats.longest, 0); XCTAssertEqual(stats.percentage, 0)
    }
    func testDatesUseCalendarDaysAcrossDST() {
        let start = Day.calendar.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        let dates = Day.dates(from: start, through: Day.adding(3, to: start))
        XCTAssertEqual(dates.count, 4); XCTAssertEqual(Set(dates.map(Day.key)).count, 4)
    }
    func testBackupRoundTripAndInvalidVersion() throws {
        let habit = Habit(name: "Read", createdAt: date(-2)); habit.toggle()
        let backup = HabitBackup(habits: [HabitRecord(habit)])
        let decoded = try JSONDecoder().decode(HabitBackup.self, from: JSONEncoder().encode(backup)).validated()
        XCTAssertEqual(decoded.habits.first?.days, habit.days)
        XCTAssertEqual(decoded.habits.first?.id, habit.id)
        var invalid = backup; invalid.version = 2
        XCTAssertThrowsError(try invalid.validated())
        invalid = backup; invalid.habits.append(invalid.habits[0])
        XCTAssertThrowsError(try invalid.validated())
        invalid = backup; invalid.habits[0].days = ["2026-02-30"]
        XCTAssertThrowsError(try invalid.validated())
    }
    @MainActor func testPersistenceAcrossContextsAndArchive() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Habit.self, configurations: config)
        let first = ModelContext(container)
        let habit = Habit(name: "Walk"); habit.toggle(); habit.archived = true
        first.insert(habit); try first.save()
        let second = ModelContext(container)
        let loaded = try XCTUnwrap(second.fetch(FetchDescriptor<Habit>()).first)
        XCTAssertEqual(loaded.name, "Walk"); XCTAssertTrue(loaded.isComplete()); XCTAssertTrue(loaded.archived)
    }
    @MainActor func testDiskStoreReopensWithHistoryAndOrder() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.store")
        let id = UUID()
        do {
            let config = ModelConfiguration(url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: Habit.self, configurations: config)
            let context = ModelContext(container)
            let habit = Habit(id: id, name: "Read", order: 7, streakGoal: 60)
            habit.toggle(); context.insert(habit); try context.save()
        }
        let config = ModelConfiguration(url: url, cloudKitDatabase: .none)
        let reopened = try ModelContainer(for: Habit.self, configurations: config)
        let context = ModelContext(reopened)
        let saved = try XCTUnwrap(context.fetch(FetchDescriptor<Habit>()).first)
        XCTAssertEqual(saved.id, id); XCTAssertEqual(saved.order, 7); XCTAssertEqual(saved.streakGoal, 60); XCTAssertTrue(saved.isComplete())
    }

    func testGoalProgressAtAndBeyondTarget() {
        let incomplete = StreakGoalProgress(current: 7, goal: 30)
        XCTAssertEqual(incomplete.remaining, 23)
        XCTAssertEqual(incomplete.fraction, 7.0 / 30, accuracy: 0.0001)
        XCTAssertFalse(incomplete.reached)
        for current in [30, 35] {
            let reached = StreakGoalProgress(current: current, goal: 30)
            XCTAssertTrue(reached.reached); XCTAssertEqual(reached.remaining, 0)
            XCTAssertEqual(reached.fraction, 1)
            XCTAssertEqual(reached.current, current)
        }
    }
    func testBrokenStreakRestartsGoalProgressWithoutErasingBest() {
        let habit = Habit(name: "Read", createdAt: date(-4), days: [-4, -3, -2].map { Day.key(date($0)) }, streakGoal: 7)
        let stats = HabitStats(habit: habit)
        let progress = StreakGoalProgress(current: stats.current, goal: habit.streakGoal)
        XCTAssertEqual(progress.current, 0); XCTAssertEqual(progress.remaining, 7)
        XCTAssertEqual(stats.longest, 3)
    }
    func testGoalBackupsAndLegacyCompatibility() throws {
        let habit = Habit(name: "Read", streakGoal: 90)
        let encoder = JSONEncoder()
        let backup = HabitBackup(habits: [HabitRecord(habit)])
        let data = try encoder.encode(backup)
        let decoded = try JSONDecoder().decode(HabitBackup.self, from: data).validated()
        XCTAssertEqual(decoded.habits[0].model().streakGoal, 90)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var records = try XCTUnwrap(legacy["habits"] as? [[String: Any]])
        records[0].removeValue(forKey: "streakGoal")
        legacy["habits"] = records
        let legacyData = try JSONSerialization.data(withJSONObject: legacy)
        let imported = try JSONDecoder().decode(HabitBackup.self, from: legacyData).validated()
        XCTAssertEqual(imported.habits[0].model().streakGoal, 30)
        var invalid = backup
        for goal in [-1, 3651] {
            invalid.habits[0].streakGoal = goal
            XCTAssertThrowsError(try invalid.validated())
        }
    }

    func testNewHabitNeedsNoGoalAndGoalRemovalKeepsHistory() {
        let habit = Habit(name: "Walk", createdAt: date(-1))
        XCTAssertFalse(habit.hasStreakGoal)
        XCTAssertEqual(habit.streakGoal, 0)
        habit.toggle(date(-1)); habit.toggle()
        habit.streakGoal = 7
        XCTAssertTrue(habit.hasStreakGoal)
        let history = habit.days
        habit.streakGoal = 0
        XCTAssertFalse(habit.hasStreakGoal)
        XCTAssertEqual(habit.days, history)
        XCTAssertEqual(HabitStats(habit: habit).current, 2)
    }
    @MainActor func testNoGoalSurvivesPersistenceAndBackup() throws {
        let container = try ModelContainer(for: Habit.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let habit = Habit(name: "Meditate")
        habit.toggle(); context.insert(habit); try context.save()
        let otherContext = ModelContext(container)
        let saved = try XCTUnwrap(otherContext.fetch(FetchDescriptor<Habit>()).first)
        XCTAssertFalse(saved.hasStreakGoal); XCTAssertTrue(saved.isComplete())
        let backup = HabitBackup(habits: [HabitRecord(saved)])
        let data = try JSONEncoder().encode(backup)
        let decoded = try JSONDecoder().decode(HabitBackup.self, from: data).validated()
        let imported = decoded.habits[0].model()
        XCTAssertEqual(imported.streakGoal, 0)
        XCTAssertFalse(imported.hasStreakGoal)
        XCTAssertEqual(imported.days, saved.days)
    }

    @MainActor func testTickExpiresWithoutUndoingSavedCompletion() throws {
        let container = try ModelContainer(for: Habit.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let now = Date.now
        let habit = Habit(name: "Read")
        context.insert(habit); habit.toggle(now); try context.save()
        let feedback = CompletionFeedback()
        feedback.complete(habit.id, at: now)
        let moment = try XCTUnwrap(feedback.moments[habit.id])
        XCTAssertTrue(feedback.showsTick(habit.id, on: now, now: now.addingTimeInterval(1)))
        XCTAssertFalse(feedback.showsTick(habit.id, on: now, now: now.addingTimeInterval(2)))
        feedback.finishTick(habit.id, token: moment.id)
        XCTAssertNil(feedback.moments[habit.id])
        let otherContext = ModelContext(container)
        XCTAssertTrue(try XCTUnwrap(otherContext.fetch(FetchDescriptor<Habit>()).first).isComplete(now))
    }
    @MainActor func testRapidUndoAndRecompletionIgnoreOldCleanupTasks() throws {
        let feedback = CompletionFeedback(), id = UUID()
        let now = Date.now
        feedback.complete(id, at: now)
        let oldMoment = try XCTUnwrap(feedback.moments[id])
        let oldBurst = try XCTUnwrap(feedback.bursts.last)
        feedback.undo(id)
        XCTAssertTrue(feedback.bursts.isEmpty); XCTAssertNil(feedback.moments[id])
        XCTAssertEqual(feedback.hapticTrigger, 1)
        feedback.complete(id, at: now.addingTimeInterval(0.2))
        let newMoment = try XCTUnwrap(feedback.moments[id])
        let newBurst = try XCTUnwrap(feedback.bursts.last)
        feedback.finishTick(id, token: oldMoment.id)
        feedback.finishBurst(token: oldBurst.id)
        XCTAssertEqual(feedback.moments[id]?.id, newMoment.id)
        XCTAssertEqual(feedback.bursts.last?.id, newBurst.id)
        XCTAssertEqual(feedback.hapticTrigger, 2)
    }
    @MainActor func testCelebrationsStayIndependentAcrossHabitsAndStopOnBackground() throws {
        let feedback = CompletionFeedback(), first = UUID(), second = UUID()
        let now = Date.now
        feedback.complete(first, at: now); feedback.complete(second, at: now)
        let secondBurst = try XCTUnwrap(feedback.bursts.last)
        feedback.undo(first)
        XCTAssertNil(feedback.moments[first])
        XCTAssertNotNil(feedback.moments[second])
        XCTAssertEqual(feedback.bursts.last?.id, secondBurst.id)
        XCTAssertFalse(feedback.showsTick(second, on: Day.adding(1, to: now), now: now))
        feedback.stop()
        XCTAssertTrue(feedback.bursts.isEmpty); XCTAssertTrue(feedback.moments.isEmpty)
        XCTAssertEqual(feedback.hapticTrigger, 2)
    }

    @MainActor func testConfettiShowersOverlapWithoutRestartingEarlierOne() throws {
        let feedback = CompletionFeedback()
        let start = Date.now
        let firstHabit = UUID(), secondHabit = UUID()
        feedback.complete(firstHabit, at: start)
        let first = try XCTUnwrap(feedback.bursts.first)
        feedback.complete(secondHabit, at: start.addingTimeInterval(1))
        XCTAssertEqual(feedback.bursts.count, 2)
        XCTAssertEqual(feedback.bursts[0].id, first.id)
        XCTAssertEqual(feedback.bursts[0].startedAt, start)
        let second = feedback.bursts[1]
        XCTAssertEqual(second.startedAt, start.addingTimeInterval(1))
        feedback.finishBurst(token: first.id)
        XCTAssertEqual(feedback.bursts.map(\.id), [second.id])
        // A repeated cleanup from the first shower must not cancel the second.
        feedback.finishBurst(token: first.id)
        XCTAssertEqual(feedback.bursts.map(\.id), [second.id])
        feedback.finishBurst(token: second.id)
        XCTAssertTrue(feedback.bursts.isEmpty)
    }

    func testRemindersDefaultToOffAndTenAM() {
        let settings = Habit(name: "Read").reminders
        XCTAssertFalse(settings.enabled)
        XCTAssertEqual(settings.times, [600])
        XCTAssertEqual(settings.weekdays, Array(1...7))
    }
    func testReminderWindowAndValidation() {
        var settings = HabitReminders()
        settings.enabled = true; settings.usesWindow = true
        settings.windowStart = 600; settings.windowEnd = 1080; settings.windowCount = 3
        XCTAssertEqual(settings.scheduledMinutes, [600, 840, 1080])
        XCTAssertNil(settings.validationMessage)
        settings.windowCount = 1
        XCTAssertEqual(settings.scheduledMinutes, [840])
        settings.windowEnd = 599
        XCTAssertNotNil(settings.validationMessage)
        settings.usesWindow = false; settings.times = [600, 600]
        XCTAssertNotNil(settings.validationMessage)
        settings.times = [600]; settings.weekdays = []
        XCTAssertNotNil(settings.validationMessage)
    }
    @MainActor func testDailyAndWeekdayNotificationTriggers() throws {
        var daily = HabitReminders(); daily.enabled = true; daily.times = [600, 840, 1080]
        let id = UUID()
        let requests = try ReminderScheduler.requests(for: [ReminderDefinition(id: id, name: "Read", settings: daily)])
        XCTAssertEqual(requests.count, 3)
        for request in requests {
            let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
            XCTAssertTrue(trigger.repeats); XCTAssertNil(trigger.dateComponents.weekday)
            XCTAssertNil(trigger.dateComponents.timeZone)
            XCTAssertEqual(request.content.title, "Read")
        }
        var weekdays = daily; weekdays.weekdays = [2, 4, 6]
        let weekly = try ReminderScheduler.requests(for: [ReminderDefinition(id: id, name: "Read", settings: weekdays)])
        XCTAssertEqual(weekly.count, 9)
        XCTAssertEqual(Set(weekly.map(\.identifier)).count, 9)
        let days = weekly.compactMap { ($0.trigger as? UNCalendarNotificationTrigger)?.dateComponents.weekday }
        XCTAssertEqual(Set(days), Set([2, 4, 6]))
        XCTAssertEqual(requests[0].identifier, try ReminderScheduler.requests(for: [ReminderDefinition(id: id, name: "Renamed", settings: daily)])[0].identifier)
    }
    @MainActor func testArchiveAndDisableRemoveHabitFromReminderPlan() throws {
        let habit = Habit(name: "Walk")
        var settings = HabitReminders(); settings.enabled = true
        habit.reminders = settings
        XCTAssertEqual(ReminderScheduler.definitions([habit]).count, 1)
        habit.archived = true
        XCTAssertTrue(ReminderScheduler.definitions([habit]).isEmpty)
        habit.archived = false; settings.enabled = false; habit.reminders = settings
        XCTAssertTrue(ReminderScheduler.definitions([habit]).isEmpty)
    }
    @MainActor func testNotificationCapacityExplainsOverflow() throws {
        var settings = HabitReminders(); settings.enabled = true; settings.times = [600, 840, 1080]
        let definitions = (0..<21).map { ReminderDefinition(id: UUID(), name: "Habit \($0)", settings: settings) }
        XCTAssertEqual(try ReminderScheduler.requests(for: definitions).count, 63)
        XCTAssertThrowsError(try ReminderScheduler.requests(for: definitions + [ReminderDefinition(id: UUID(), name: "Extra", settings: settings)]))
    }
    @MainActor func testReminderSettingsPersistAndRoundTripInBackup() throws {
        let container = try ModelContainer(for: Habit.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let habit = Habit(name: "Read")
        var settings = HabitReminders(); settings.enabled = true; settings.weekdays = [2, 4, 6]; settings.times = [600, 1080]
        habit.reminders = settings; context.insert(habit); try context.save()
        let other = ModelContext(container)
        let loaded = try XCTUnwrap(other.fetch(FetchDescriptor<Habit>()).first)
        XCTAssertEqual(loaded.reminders, settings)
        let backup = HabitBackup(habits: [HabitRecord(loaded)])
        let data = try JSONEncoder().encode(backup)
        let decoded = try JSONDecoder().decode(HabitBackup.self, from: data).validated()
        XCTAssertEqual(decoded.habits[0].model().reminders, settings)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var records = try XCTUnwrap(legacy["habits"] as? [[String: Any]])
        records[0].removeValue(forKey: "reminders"); legacy["habits"] = records
        let oldBackup = try JSONDecoder().decode(HabitBackup.self, from: JSONSerialization.data(withJSONObject: legacy)).validated()
        XCTAssertFalse(oldBackup.habits[0].model().reminders.enabled)
        var invalid = backup; var invalidSettings = settings; invalidSettings.times = [1440]
        invalid.habits[0].reminders = invalidSettings
        XCTAssertThrowsError(try invalid.validated())
    }

    @MainActor func testUnchangedRemindersAreNotRescheduledButEditsAre() throws {
        var settings = HabitReminders(); settings.enabled = true
        let id = UUID()
        let old = try ReminderScheduler.requests(for: [ReminderDefinition(id: id, name: "Read", settings: settings)])
        let unchanged = try ReminderScheduler.requests(for: [ReminderDefinition(id: id, name: "Read", settings: settings)])
        XCTAssertTrue(ReminderScheduler.requestsNeedingUpdate(unchanged, existing: old).isEmpty)
        let renamed = try ReminderScheduler.requests(for: [ReminderDefinition(id: id, name: "Read a chapter", settings: settings)])
        XCTAssertEqual(ReminderScheduler.requestsNeedingUpdate(renamed, existing: old).count, 1)
        settings.times = [660]
        let rescheduled = try ReminderScheduler.requests(for: [ReminderDefinition(id: id, name: "Read", settings: settings)])
        XCTAssertEqual(ReminderScheduler.requestsNeedingUpdate(rescheduled, existing: old).count, 1)
        XCTAssertEqual(ReminderScheduler.requestsNeedingUpdate(old, existing: []).count, 1)
    }

}
