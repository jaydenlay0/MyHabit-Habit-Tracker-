import SwiftUI
import SwiftData
import WidgetKit

struct HabitEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let habit: Habit?
    let nextOrder: Int
    @State private var name: String
    @State private var habitDescription: String
    @State private var trackingMode: String
    @State private var dailyTarget: Int
    @State private var symbol: String
    @State private var hasStreakGoal: Bool
    @State private var streakGoal: Int
    @State private var color: String
    @State private var reminders: HabitReminders
    @State private var saving = false
    @State private var reminderNotice: String?
    @State private var failure: String?
    init(habit: Habit? = nil, nextOrder: Int = 0) {
        self.habit = habit; self.nextOrder = nextOrder
        _reminders = State(initialValue: habit?.reminders ?? HabitReminders())
        _name = State(initialValue: habit?.name ?? "")
        _habitDescription = State(initialValue: habit?.habitDescription ?? "")
        _trackingMode = State(initialValue: habit?.trackingMode ?? "yesNo")
        _dailyTarget = State(initialValue: habit?.dailyTarget ?? 1)
        _symbol = State(initialValue: habit?.symbol ?? "checkmark")
        _hasStreakGoal = State(initialValue: habit?.hasStreakGoal ?? false)
        _streakGoal = State(initialValue: habit.flatMap { $0.hasStreakGoal ? $0.streakGoal : nil } ?? 30)
        _color = State(initialValue: habit?.colorHex ?? Palette.defaultColor)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("A small promise to yourself :)") {
                    TextField("Habit name", text: $name).onChange(of: name) { _, value in name = String(value.prefix(80)) }
                }.appSectionStyle()
                Section("Description") {
                    TextField("Add a description…", text: $habitDescription)
                        .onChange(of: habitDescription) { _, value in
                            habitDescription = Self.limitedDescription(value)
                        }
                        .accessibilityHint("Optional description, up to 50 words or 300 characters, whichever comes first")
                }.appSectionStyle()
                Section("Habit Tracking") {
                    Picker("Tracking type", selection: $trackingMode) {
                        Text("Yes/No").tag("yesNo")
                        Text("Counter").tag("counter")
                    }.pickerStyle(.segmented)
                    if trackingMode == "counter" {
                        Stepper("Daily target: \(dailyTarget)", value: $dailyTarget, in: 1...10000)
                        Text("Use + and − to track your daily count. Reach your target to complete the habit.")
                            .font(.caption).foregroundStyle(AppTheme.secondaryText)
                    } else {
                        Text("Tap the habit icon to mark it complete for the day. Tap again to undo your check-in.")
                            .font(.caption).foregroundStyle(AppTheme.secondaryText)
                    }
                }.appSectionStyle()
                Section {
                    Toggle("Streak Goal", isOn: $hasStreakGoal)
                    if hasStreakGoal {
                        Stepper("\(streakGoal)-day streak", value: $streakGoal, in: 1...3650)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 48))]) {
                            ForEach([7, 14, 30, 60, 90], id: \.self) { days in
                                Button("\(days)") { streakGoal = days }
                                    .buttonStyle(.bordered)
                                    .tint(streakGoal == days ? Color(habitHex: color) : .secondary)
                                    .accessibilityLabel("Set streak goal to \(days) days")
                                    .accessibilityAddTraits(streakGoal == days ? .isSelected : [])
                            }
                        }
                    }
                } header: {
                    Text("Set a Streak Goal")
                } footer: {
                    Text("Goals are optional. Your streak is tracked either way. You can add, change or remove a goal later without losing check-ins.")
                }.appSectionStyle()
                ReminderEditor(settings: $reminders)
                Section("Colour") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 4), count: 6), spacing: 8) {
                        ForEach(Palette.colors, id: \.self) { hex in
                            Button { color = hex } label: {
                                Circle().fill(Color(habitHex: hex)).frame(width: 34, height: 34)
                                    .overlay { if color == hex { Image(systemName: "checkmark").foregroundStyle(Palette.selectionInk(hex)) } }
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }.buttonStyle(.plain).accessibilityLabel(Palette.colorName(hex)).accessibilityAddTraits(color == hex ? .isSelected : [])
                        }
                    }
                }.appSectionStyle()
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 4), count: 6), spacing: 8) {
                        ForEach(Palette.symbols, id: \.self) { item in
                            Button { symbol = item } label: {
                                HabitSymbol(name: item).frame(minWidth: 44, minHeight: 44)
                                    .foregroundStyle(symbol == item ? Color(habitHex: color) : .secondary)
                                    .background(symbol == item ? Color(habitHex: color).opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(.plain).accessibilityLabel(Palette.symbolName(item)).accessibilityAddTraits(symbol == item ? .isSelected : [])
                        }
                    }
                }.appSectionStyle()
            }
            .disabled(saving)
            .interactiveDismissDisabled(saving)
            .appScreenStyle()
            .navigationTitle(habit == nil ? "New Habit" : "Edit habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") { Task { await save() } }
                        .disabled(saving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || reminders.validationMessage != nil)
                }
            }
            .alert(reminderNotice == nil ? "Couldn’t save" : "Habit saved", isPresented: Binding(get: { failure != nil || reminderNotice != nil }, set: { visible in
                if !visible {
                    if reminderNotice != nil { dismiss() }
                    failure = nil; reminderNotice = nil
                }
            })) {
                Button("OK") {}
            } message: { Text(failure ?? reminderNotice ?? "") }
        }
    }
    private static func limitedDescription(_ value: String) -> String {
        let capped = String(value.prefix(300))
        let words = capped.split(whereSeparator: { $0.isWhitespace })
        return words.count > 50 ? words.prefix(50).joined(separator: " ") : capped
    }

    @MainActor private func save() async {
        guard !saving else { return }
        guard reminders.validationMessage == nil else { failure = reminders.validationMessage; return }
        saving = true
        defer { saving = false }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedGoal = hasStreakGoal ? streakGoal : 0
        do {
            let allHabits = try context.fetch(FetchDescriptor<Habit>())
            var definitions = ReminderScheduler.definitions(allHabits.filter { $0.id != habit?.id })
            if reminders.enabled && !(habit?.archived ?? false) {
                definitions.append(ReminderDefinition(id: habit?.id ?? UUID(), name: trimmed, settings: reminders))
            }
            if reminders.enabled { try ReminderScheduler.validateCapacity(definitions) }
            let saved: Habit
            if let habit {
                saved = habit; habit.name = trimmed; habit.symbol = symbol
                habit.colorHex = color; habit.streakGoal = savedGoal
            } else {
                saved = Habit(name: trimmed, symbol: symbol, colorHex: color, order: nextOrder, streakGoal: savedGoal)
                context.insert(saved)
            }
            let description = Self.limitedDescription(habitDescription).trimmingCharacters(in: .whitespacesAndNewlines)
            saved.habitDescription = description.isEmpty ? nil : description
            saved.trackingMode = trackingMode
            saved.dailyTarget = dailyTarget
            saved.reminders = reminders
            try context.save()
            WidgetCenter.shared.reloadAllTimelines()
            let savedHabits = habit == nil ? allHabits + [saved] : allHabits
            if let notice = await ReminderScheduler.shared.reconcile(savedHabits, requestPermission: reminders.enabled) {
                reminderNotice = notice
            } else { dismiss() }
        } catch { context.rollback(); failure = error.localizedDescription }
    }
}
