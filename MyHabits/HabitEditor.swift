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
    @State private var streakGoal: Int
    @State private var color: String
    @State private var failure: String?
    init(habit: Habit? = nil, nextOrder: Int = 0) {
        self.habit = habit; self.nextOrder = nextOrder
        _name = State(initialValue: habit?.name ?? "")
        _symbol = State(initialValue: habit?.symbol ?? "checkmark")
        _streakGoal = State(initialValue: habit?.streakGoal ?? 30)
        _color = State(initialValue: habit?.colorHex ?? Palette.colors[0])
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("A small promise to yourself") {
                    TextField("Habit name", text: $name).onChange(of: name) { _, value in name = String(value.prefix(80)) }
                }
                Section {
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
                } header: {
                    Text("Streak goal")
                } footer: {
                    Text("Aim for consecutive days. Your goal appears on the habit card. Missing a full day restarts your current streak, but keeps your longest streak.")
                }
                Section("Colour") {
                    HStack {
                        ForEach(Palette.colors, id: \.self) { hex in
                            Button { color = hex } label: {
                                Circle().fill(Color(habitHex: hex)).frame(width: 34, height: 34)
                                    .overlay { if color == hex { Image(systemName: "checkmark").foregroundStyle(.black) } }
                            }.buttonStyle(.plain).accessibilityLabel("Colour \(hex)").accessibilityAddTraits(color == hex ? .isSelected : [])
                        }
                    }
                }
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6)) {
                        ForEach(Palette.symbols, id: \.self) { item in
                            Button { symbol = item } label: {
                                Image(systemName: item).frame(minWidth: 32, minHeight: 44)
                                    .foregroundStyle(symbol == item ? Color(habitHex: color) : .secondary)
                                    .background(symbol == item ? Color(habitHex: color).opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(.plain).accessibilityLabel(item).accessibilityAddTraits(symbol == item ? .isSelected : [])
                        }
                    }
                }
            }
            .navigationTitle(habit == nil ? "New habit" : "Edit habit")
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
        if let habit { habit.name = trimmed; habit.symbol = symbol; habit.colorHex = color; habit.streakGoal = streakGoal }
        else { context.insert(Habit(name: trimmed, symbol: symbol, colorHex: color, order: nextOrder, streakGoal: streakGoal)) }
        do { try context.save(); WidgetCenter.shared.reloadAllTimelines(); dismiss() }
        catch { context.rollback(); failure = error.localizedDescription }
    }
}
