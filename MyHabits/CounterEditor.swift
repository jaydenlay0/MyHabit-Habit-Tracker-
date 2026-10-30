import SwiftUI
import SwiftData
import WidgetKit

struct CounterEditor: View {
    let habit: Habit
    let date: Date
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(CompletionFeedback.self) private var feedback
    @State private var value: Int
    @State private var failure: String?
    private var target: Int { max(1, habit.dailyTarget) }

    init(habit: Habit, date: Date) {
        self.habit = habit
        self.date = date
        _value = State(initialValue: min(max(1, habit.dailyTarget), habit.count(on: date)))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
            VStack(spacing: 22) {
                HStack(spacing: 14) {
                    HabitSymbol(name: habit.symbol, size: 24)
                        .foregroundStyle(Color(habitHex: habit.colorHex))
                        .frame(width: 48, height: 48)
                        .background(Color(habitHex: habit.colorHex).opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(habit.name).font(.title2.bold())
                        Text(date, format: .dateTime.weekday().month().day())
                            .font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer()
                }
                HStack(spacing: 16) {
                    Button { value = max(0, value - 1) } label: {
                        Image(systemName: "minus").frame(width: 48, height: 64)
                    }.disabled(value == 0).accessibilityLabel("Decrease count")
                    Text("\(value)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .monospacedDigit().frame(maxWidth: .infinity, minHeight: 80)
                        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 18))
                    Button { value = min(target, value + 1) } label: {
                        Image(systemName: "plus").frame(width: 48, height: 64)
                    }.disabled(value >= target).accessibilityLabel("Increase count")
                }.buttonStyle(.bordered)
                VStack(spacing: 10) {
                    ProgressView(value: Double(value), total: Double(target))
                    HStack {
                        Text("Daily target: \(target)")
                        Spacer()
                        Text("\(Int(Double(value) / Double(target) * 100))%")
                    }.font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                }
                HStack {
                    Button("Reset") { value = 0 }
                    Spacer()
                    Button("Reach goal") { value = target }
                }.buttonStyle(.bordered)
                Button("Save count") { save() }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .background(AppTheme.background)
            .tint(Color(habitHex: habit.colorHex))
            .navigationTitle("Today's count")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .alert("Couldn’t save", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("OK") {}
            } message: { Text(failure ?? "") }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func save() {
        let wasComplete = habit.isComplete(date)
        habit.adjustCount(by: value - habit.count(on: date), on: date)
        do {
            try context.save()
            WidgetCenter.shared.reloadAllTimelines()
            if Day.key(date) == Day.key(.now) {
                if !wasComplete && habit.isComplete(date) { feedback.complete(habit.id, at: .now) }
                else if wasComplete && !habit.isComplete(date) { feedback.undo(habit.id) }
            }
            dismiss()
        } catch { context.rollback(); failure = error.localizedDescription }
    }
}
