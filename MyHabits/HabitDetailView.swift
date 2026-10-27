import SwiftUI
import SwiftData
import WidgetKit

struct HabitDetailView: View {
    @Bindable var habit: Habit
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var now = Date.now
    @State private var editing = false
    @State private var deleting = false
    @State private var archiving = false
    @State private var weekly = false
    @State private var failure: String?
    var body: some View {
        let stats = HabitStats(habit: habit, today: now)
        List {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: habit.symbol).font(.largeTitle).foregroundStyle(Color(habitHex: habit.colorHex))
                    VStack(alignment: .leading) { Text(habit.name).font(.title2.bold()); Text("Every day · Since \(habit.createdAt.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(.secondary) }
                }.padding(.vertical, 12)
                if !habit.archived {
                    Button { habit.toggle(now); save() } label: { Label(habit.isComplete(now) ? "Completed today · Undo" : "Check in today", systemImage: habit.isComplete(now) ? "checkmark.circle.fill" : "circle") }.tint(Color(habitHex: habit.colorHex))
                }
            }
            Section(habit.hasStreakGoal ? "Streak goal" : "Current streak") {
                StreakGoalView(current: stats.current, goal: habit.streakGoal, colorHex: habit.colorHex)
                    .padding(.vertical, 6)
                Button(habit.hasStreakGoal ? "Change or remove goal" : "Add a goal (optional)") { editing = true }
            }
            Section("Your rhythm") {
                Picker("View", selection: $weekly) { Text("Daily").tag(false); Text("Weekly").tag(true) }.pickerStyle(.segmented)
                HeatmapView(habit: habit, today: now, weekly: weekly) { date in habit.toggle(date); save() }.padding(.vertical, 8)
            }
            Section("All-time statistics") {
                LabeledContent("Current streak", value: "\(stats.current) days")
                LabeledContent("Longest streak", value: "\(stats.longest) days")
                LabeledContent("Completion", value: "\(stats.percentage)%")
                Text("Completion includes every day since creation, including today. Your current streak stays alive until the end of today.").font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Button("Archive habit") { archiving = true }
                    .confirmationDialog("Archive this habit? It will leave your daily list and widgets. Archived habits cannot be browsed or restored in the app.", isPresented: $archiving, titleVisibility: .visible) {
                        Button("Archive habit") {
                            habit.archived = true
                            if save() { dismiss() }
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                Button("Delete habit", role: .destructive) { deleting = true }
            }
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { now = $0 }
        .navigationTitle("Habit").navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Edit") { editing = true } }
        .sheet(isPresented: $editing) { HabitEditor(habit: habit) }
        .confirmationDialog("Delete this habit and all its check-ins?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete permanently", role: .destructive) {
                context.delete(habit)
                if save() { dismiss() }
            }
        }
        .alert("Couldn’t save", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) { Button("OK") {} } message: { Text(failure ?? "") }
    }
    @discardableResult private func save() -> Bool {
        do { try context.save(); WidgetCenter.shared.reloadAllTimelines(); return true }
        catch { context.rollback(); failure = error.localizedDescription; return false }
    }
}
