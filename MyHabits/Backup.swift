import Foundation
import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import WidgetKit

struct HabitRecord: Codable {
    var id: UUID
    var name: String
    var symbol: String
    var colorHex: String
    var createdAt: Date
    var order: Int
    var archived: Bool
    var days: [String]
    // Optional for compatibility with backups exported before streak goals.
    var streakGoal: Int?
    var resolvedStreakGoal: Int { streakGoal ?? 30 }
    init(_ habit: Habit) {
        id = habit.id; name = habit.name; symbol = habit.symbol; colorHex = habit.colorHex
        createdAt = habit.createdAt; order = habit.order; archived = habit.archived; days = habit.days; streakGoal = habit.streakGoal
    }
    func model() -> Habit { Habit(id: id, name: name, symbol: symbol, colorHex: colorHex, createdAt: createdAt, order: order, archived: archived, days: days, streakGoal: resolvedStreakGoal) }
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
                  Palette.symbols.contains(habit.symbol),
                  habit.colorHex.range(of: "^[0-9A-Fa-f]{6}$", options: .regularExpression) != nil,
                  habit.createdAt <= Date.now,
                  (1...3650).contains(habit.resolvedStreakGoal),
                  Set(habit.days).count == habit.days.count else { throw BackupError.invalid("Invalid habit fields.") }
            for day in habit.days {
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
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Habit.order) private var habits: [Habit]
    @State private var exporting = false
    @State private var importing = false
    @State private var document = BackupDocument()
    @State private var pending: HabitBackup?
    @State private var message: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Your data stays yours") {
                    Text("Unlimited habits. No accounts, subscriptions, analytics, or cloud sync. Habits and check-ins are stored locally in the shared app container.")
                    Text("Use backups to move your data or keep a safe copy. Backup files are plain JSON; store them somewhere you trust.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Backups") {
                    Button("Export all habits") {
                        do {
                            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                            document = BackupDocument(data: try encoder.encode(HabitBackup(habits: habits.map(HabitRecord.init))))
                            exporting = true
                        } catch { message = error.localizedDescription }
                    }
                    Button("Import backup") { importing = true }
                    Text("Import merges by habit ID. Matching habits are replaced by the backup; other habits are kept. Export first to preserve your current history.").font(.caption).foregroundStyle(.secondary)
                }
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
                }
            }
            .preferredColorScheme(appearance.colorScheme)
            .navigationTitle("Settings").toolbar { Button("Done") { dismiss() } }
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
            .alert("Backup", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("OK") {} } message: { Text(message ?? "") }
        }
    }
    private func merge() {
        guard let backup = pending else { return }
        do {
            let existing = Dictionary(uniqueKeysWithValues: habits.map { ($0.id, $0) })
            for record in backup.habits {
                if let habit = existing[record.id] {
                    habit.name = record.name; habit.symbol = record.symbol; habit.colorHex = record.colorHex
                    habit.createdAt = record.createdAt; habit.order = record.order; habit.archived = record.archived; habit.days = record.days; habit.streakGoal = record.resolvedStreakGoal
                } else { context.insert(record.model()) }
            }
            try context.save(); WidgetCenter.shared.reloadAllTimelines()
            message = "Imported \(backup.habits.count) habits."
        } catch { context.rollback(); message = error.localizedDescription }
        pending = nil
    }
}
