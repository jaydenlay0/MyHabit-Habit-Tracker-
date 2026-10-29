import Foundation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import WidgetKit
import UIKit
import UserNotifications

struct HabitRecord: Codable {
    var id: UUID
    var name: String
    var trackingMode: String?
    var dailyTarget: Int?
    var counts: [String: Int]?
    var habitDescription: String?
    var symbol: String
    var colorHex: String
    var createdAt: Date
    var order: Int
    var archived: Bool
    var days: [String]
    // Missing means a legacy 30-day goal; explicit zero means no goal.
    var streakGoal: Int?
    var reminders: HabitReminders?
    var resolvedStreakGoal: Int { streakGoal ?? 30 }
    init(_ habit: Habit) {
        trackingMode = habit.trackingMode; dailyTarget = habit.dailyTarget; counts = habit.counts
        habitDescription = habit.habitDescription
        id = habit.id; name = habit.name; symbol = habit.symbol; colorHex = habit.colorHex
        createdAt = habit.createdAt; order = habit.order; archived = habit.archived; days = habit.days; streakGoal = habit.streakGoal; reminders = habit.reminders
    }
    func model() -> Habit {
        let habit = Habit(id: id, name: name, symbol: symbol, colorHex: colorHex, createdAt: createdAt, order: order, archived: archived, days: days, streakGoal: resolvedStreakGoal)
        habit.trackingMode = trackingMode ?? "yesNo"; habit.dailyTarget = dailyTarget ?? 1; habit.counts = counts ?? [:]
        habit.habitDescription = habitDescription
        habit.reminders = reminders ?? HabitReminders()
        return habit
    }
}
struct HabitBackup: Codable {
    var version = 1
    var exportedAt = Date.now
    var habits: [HabitRecord]
    func validated() throws -> HabitBackup {
        guard version == 1 else { throw BackupError.invalid("Unsupported backup version.") }
        guard Set(habits.map(\.id)).count == habits.count else { throw BackupError.invalid("Duplicate habit identifiers.") }
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.calendar = Calendar(identifier: .gregorian)
        parser.dateFormat = "yyyy-MM-dd"; parser.isLenient = false
        for habit in habits {
            guard !habit.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, habit.name.count <= 80,
                  ["yesNo", "counter"].contains(habit.trackingMode ?? "yesNo"),
                  (1...10000).contains(habit.dailyTarget ?? 1),
                  (habit.counts ?? [:]).values.allSatisfy({ (0...1_000_000).contains($0) }),
                  Palette.symbols.contains(habit.symbol),
                  habit.colorHex.range(of: "^[0-9A-Fa-f]{6}$", options: .regularExpression) != nil,
                  habit.createdAt <= Date.now,
                  (0...3650).contains(habit.resolvedStreakGoal),
                  Set(habit.days).count == habit.days.count else { throw BackupError.invalid("Invalid habit fields.") }
            if let reminders = habit.reminders {
                guard reminders.hasValidStoredValues, reminders.validationMessage == nil else {
                    throw BackupError.invalid(reminders.validationMessage ?? "Invalid reminder settings.")
                }
            }
            let recordedDays = Set(habit.days).union((habit.counts ?? [:]).keys)
            for day in recordedDays {
                guard day.range(of: "^[0-9]{4}-[0-9]{2}-[0-9]{2}$", options: .regularExpression) != nil,
                      let date = parser.date(from: day), parser.string(from: date) == day,
                      day >= Day.key(habit.createdAt), day <= Day.key(.now) else { throw BackupError.invalid("Invalid check-in date.") }
            }
        }
        return self
    }
}
enum BackupError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
struct BackupView: View {
    var showsDoneButton = true
    @State private var notificationScheduler = ReminderScheduler.shared
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Habit.order) private var habits: [Habit]
    @State private var exporting = false
    @State private var importing = false
    @State private var clearingArchive = false
    @State private var document = BackupDocument()
    @State private var pending: HabitBackup?
    @State private var message: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Your data stays yours") {
                    Text("Unlimited habits. No accounts, subscriptions, analytics, or cloud sync. Habits and check-ins are stored locally in the shared app container.")
                    Text("Use backups to move your data or keep a safe copy. Backup files are plain JSON; store them somewhere you trust.").font(.caption).foregroundStyle(AppTheme.secondaryText)
                }.appSectionStyle()
                Section {
                    LabeledContent("Archived habits", value: "\(habits.filter { $0.archived }.count)")
                    Button("Delete archived habits", role: .destructive) { clearingArchive = true }
                        .disabled(!habits.contains { $0.archived })
                } header: {
                    Text("Archive storage")
                } footer: {
                    Text("Archived habits stay out of your daily focus. They are kept in backups, but cannot be browsed or restored here.")
                }.appSectionStyle()
                .confirmationDialog("Permanently delete all archived habits and their check-ins? Active habits will be kept.", isPresented: $clearingArchive, titleVisibility: .visible) {
                    Button("Delete archived habits", role: .destructive) { deleteArchivedHabits() }
                    Button("Cancel", role: .cancel) {}
                }
                Section("Notifications") {
                    Text("Reminders default to 10:00 am. Set up to three times per day, weekdays or a time window in New Habit or Edit.")
                        .font(.subheadline)
                    Text("iOS supports 64 scheduled notification slots per app. Every-day reminders use fewer slots than individual weekdays. Focus modes and notification settings can delay delivery.")
                        .font(.caption).foregroundStyle(AppTheme.secondaryText)
                    if let notice = notificationScheduler.notice {
                        Text(notice).font(.caption).foregroundStyle(AppTheme.secondaryText)
                    }
                    if notificationScheduler.authorization == .notDetermined && habits.contains(where: { !$0.archived && $0.reminders.enabled }) {
                        Button("Enable notifications") {
                            Task { _ = await notificationScheduler.reconcile(habits, requestPermission: true) }
                        }
                    }
                    if notificationScheduler.authorization == .denied {
                        Link("Open iPhone notification settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                    }
                }.appSectionStyle()
                Section("Backups") {
                    Button("Export all habits") {
                        do {
                            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                            document = BackupDocument(data: try encoder.encode(HabitBackup(habits: habits.map(HabitRecord.init))))
                            exporting = true
                        } catch { message = error.localizedDescription }
                    }
                    Button("Import backup") { importing = true }
                    Text("Import merges by habit ID. Matching habits are replaced by the backup; other habits are kept. Export first to preserve your current history.").font(.caption).foregroundStyle(AppTheme.secondaryText)
                }.appSectionStyle()
                Section {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(AppAppearance.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("System follows your iPhone’s appearance. Your choice is saved on this device.")
                }.appSectionStyle()
            }
            .tracksNavigationScroll()
            .task {
                _ = await notificationScheduler.reconcile(habits)
            }
            .appScreenStyle()
            .preferredColorScheme(appearance.colorScheme)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if showsDoneButton { Button("Done") { dismiss() } }
            }
            .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "MyHabits-\(Day.key(.now))") { result in
                if case .failure(let error) = result { message = error.localizedDescription }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= 20_000_000 else { throw BackupError.invalid("Backup exceeds the 20 MB import safety limit.") }
                    pending = try JSONDecoder().decode(HabitBackup.self, from: Data(contentsOf: url)).validated()
                } catch { message = error.localizedDescription }
            }
            .confirmationDialog("Merge \(pending?.habits.count ?? 0) habits? Matching habits will be overwritten.", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }), titleVisibility: .visible) {
                Button("Import and merge", role: .destructive) { merge() }
                Button("Cancel", role: .cancel) { pending = nil }
            }
            .alert("Settings", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") {} } message: { Text(message ?? "") }
        }
    }
    private func deleteArchivedHabits() {
        do {
            for habit in habits where habit.archived { context.delete(habit) }
            try context.save()
            WidgetCenter.shared.reloadAllTimelines()
        } catch { context.rollback(); message = error.localizedDescription }
    }
    private func merge() {
        guard let backup = pending else { return }
        do {
            let existing = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0) })
            for record in backup.habits {
                if let habit = existing[record.id] {
                    habit.trackingMode = record.trackingMode ?? "yesNo"; habit.dailyTarget = record.dailyTarget ?? 1; habit.counts = record.counts ?? [:]
                    habit.habitDescription = record.habitDescription
                    habit.name = record.name; habit.symbol = record.symbol; habit.colorHex = record.colorHex
                    habit.createdAt = record.createdAt; habit.order = record.order; habit.archived = record.archived; habit.days = record.days; habit.streakGoal = record.resolvedStreakGoal; habit.reminders = record.reminders ?? HabitReminders()
                } else { context.insert(record.model()) }
            }
            try context.save(); WidgetCenter.shared.reloadAllTimelines()
            message = "Imported \(backup.habits.count) habits."
            if let all = try? context.fetch(FetchDescriptor<Habit>()) {
                Task { _ = await notificationScheduler.reconcile(all) }
            }
        } catch { context.rollback(); message = error.localizedDescription }
        pending = nil
    }
}
