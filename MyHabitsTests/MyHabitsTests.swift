import XCTest
import SwiftData
@testable import MyHabits

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
        for goal in [0, -1, 3651] {
            invalid.habits[0].streakGoal = goal
            XCTAssertThrowsError(try invalid.validated())
        }
    }

}
