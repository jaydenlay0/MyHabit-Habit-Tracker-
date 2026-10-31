import SwiftUI
import SwiftData
import WidgetKit

struct MeasureEditor: View {
    let habit: Habit
    let date: Date
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(CompletionFeedback.self) private var feedback
    @State private var value: Double
    @State private var failure: String?

    init(habit: Habit, date: Date) {
        self.habit = habit; self.date = date
        _value = State(initialValue: habit.measured(on: date))
    }
    private var valid: Bool { value.isFinite && value >= 0 && value <= habit.measureTarget }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(habit.name).font(.headline)
                    Text(date, format: .dateTime.weekday().month().day())
                        .foregroundStyle(AppTheme.secondaryText)
                    HStack {
                        TextField("Total amount", value: $value, format: .number)
                            .keyboardType(.decimalPad)
                        Text(habit.measureUnit).foregroundStyle(AppTheme.secondaryText)
                    }
                    HStack {
                        Button { value = max(0, value - 1) } label: { Image(systemName: "minus") }
                            .disabled(value <= 0).accessibilityLabel("Decrease amount")
                        Spacer()
                        Button { value = min(habit.measureTarget, value + 1) } label: { Image(systemName: "plus") }
                            .disabled(value >= habit.measureTarget).accessibilityLabel("Increase amount")
                    }.buttonStyle(.bordered)
                    ProgressView(value: value.isFinite ? min(habit.measureTarget, max(0, value)) : 0, total: habit.measureTarget)
                    Text("Goal: \(habit.measureTarget.formatted()) \(habit.measureUnit)")
                        .font(.caption).foregroundStyle(AppTheme.secondaryText)
                    Text(LocalizedStringKey(value >= habit.measureTarget ? "Completed" : "Incomplete"))
                    Button("Reach goal") { value = habit.measureTarget }
                    Button("Reset") { value = 0 }
                }.appSectionStyle()
            }
            .appScreenStyle()
            .navigationTitle("Measure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(!valid) }
            }
            .alert("Couldn’t save", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) { Button("OK") {} } message: { Text(failure ?? "") }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    private func save() {
        guard valid else { return }
        let wasComplete = habit.isComplete(date)
        habit.setMeasured(value, on: date)
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
