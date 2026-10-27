import SwiftUI
import SwiftData
import WidgetKit
import AppIntents

struct CheckInIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle habit for today"
    static var openAppWhenRun = false
    @Parameter(title: "Habit identifier") var habitID: String
    init() {}
    init(habitID: String) { self.habitID = habitID }
    @MainActor func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: habitID) else { return .result() }
        let container = try SharedStore.make()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.id == id })
        if let habit = try context.fetch(descriptor).first, !habit.archived {
            habit.toggle(); try context.save(); SharedStore.markWidgetWrite()
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
struct WidgetHabit: Identifiable {
    var id: UUID; var name: String; var symbol: String; var colorHex: String; var done: Bool
}
struct HabitEntry: TimelineEntry {
    let date: Date
    let habits: [WidgetHabit]
    var failed = false
}
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> HabitEntry {
        HabitEntry(date: .now, habits: [WidgetHabit(id: UUID(), name: "Read a little", symbol: "book.closed", colorHex: "63D6A3", done: false)])
    }
    func getSnapshot(in context: Context, completion: @escaping (HabitEntry) -> Void) { completion(context.isPreview ? placeholder(in: context) : load()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitEntry>) -> Void) {
        let nextDay = Day.adding(1, to: .now)
        completion(Timeline(entries: [load()], policy: .after(nextDay)))
    }
    private func load() -> HabitEntry {
        do {
            let container = try SharedStore.make()
            let context = ModelContext(container)
            var descriptor = FetchDescriptor<Habit>(predicate: #Predicate { !$0.archived }, sortBy: [SortDescriptor(\Habit.order)])
            descriptor.fetchLimit = 6
            let habits = try context.fetch(descriptor).map { WidgetHabit(id: $0.id, name: $0.name, symbol: $0.symbol, colorHex: $0.colorHex, done: $0.isComplete()) }
            return HabitEntry(date: .now, habits: habits)
        } catch { return HabitEntry(date: .now, habits: [], failed: true) }
    }
}
struct HabitsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HabitEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text("MyHabits").font(.headline); Spacer(); Text(entry.date, format: .dateTime.day().month(.abbreviated)).font(.caption).foregroundStyle(.secondary) }
            if entry.habits.isEmpty {
                Text(entry.failed ? "Open MyHabits to check shared storage." : "Add your first habit in MyHabits.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(Array(entry.habits.prefix(family == .systemLarge ? 6 : (family == .systemSmall ? 2 : 3)))) { habit in
                    Button(intent: CheckInIntent(habitID: habit.id.uuidString)) {
                        HStack {
                            Image(systemName: habit.symbol)
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 28, height: 28)
                                .foregroundStyle(habit.done ? Palette.selectionInk(habit.colorHex) : Color(habitHex: habit.colorHex))
                                .background(Color(habitHex: habit.colorHex).opacity(habit.done ? 1 : 0.14), in: RoundedRectangle(cornerRadius: 8))
                            Text(habit.name).lineLimit(1).foregroundStyle(.primary)
                            Spacer()
                            if !habit.done { Image(systemName: "circle").foregroundStyle(.secondary) }
                        }.font(.subheadline).frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                    }.buttonStyle(.plain).accessibilityLabel("\(habit.done ? "Undo" : "Complete") \(habit.name)")
                        .accessibilityValue(habit.done ? "Completed" : "Not completed")
                }
            }
            Spacer(minLength: 0)
        }.containerBackground(.background, for: .widget)
    }
}
@main
struct MyHabitsWidget: Widget {
    let kind = "MyHabitsWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { HabitsWidgetView(entry: $0) }
            .configurationDisplayName("Daily habits")
            .description("Check in without opening MyHabits. Shows your first active habits in list order.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
