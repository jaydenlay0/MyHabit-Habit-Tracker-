import SwiftUI
import SwiftData
import WidgetKit

struct HabitEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let habit: Habit?
    let nextOrder: Int
    @State private var name: String
    @State private var symbol: String
    @State private var hasStreakGoal: Bool
    @State private var streakGoal: Int
    @State private var color: String
    @State private var failure: String?
    init(habit: Habit? = nil, nextOrder: Int = 0) {
        self.habit = habit; self.nextOrder = nextOrder
        _name = State(initialValue: habit?.name ?? "")
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
                }
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
                }
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
                }
                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
                        ForEach(Palette.symbols, id: \.self) { item in
                            Button { symbol = item } label: {
                                Image(systemName: item).frame(minWidth: 44, minHeight: 44)
                                    .foregroundStyle(symbol == item ? Color(habitHex: color) : .secondary)
                                    .background(symbol == item ? Color(habitHex: color).opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(.plain).accessibilityLabel(Palette.symbolName(item)).accessibilityAddTraits(symbol == item ? .isSelected : [])
                        }
                    }
                }
            }
            .navigationTitle(habit == nil ? "New Habit" : "Edit habit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Couldn’t save", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) { Button("OK") {} } message: { Text(failure ?? "") }
        }
    }
    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedGoal = hasStreakGoal ? streakGoal : 0
        if let habit { habit.name = trimmed; habit.symbol = symbol; habit.colorHex = color; habit.streakGoal = savedGoal }
        else { context.insert(Habit(name: trimmed, symbol: symbol, colorHex: color, order: nextOrder, streakGoal: savedGoal)) }
        do { try context.save(); WidgetCenter.shared.reloadAllTimelines(); dismiss() }
        catch { context.rollback(); failure = error.localizedDescription }
    }
}
