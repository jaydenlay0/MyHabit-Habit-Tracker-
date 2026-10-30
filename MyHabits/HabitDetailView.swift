import SwiftUI
import SwiftData
import WidgetKit

struct HabitDetailView: View {
    @Bindable var habit: Habit
    @Environment(\.setBottomNavigationHidden) private var setBottomNavigationHidden
    @Environment(CompletionFeedback.self) private var feedback
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
                    HabitCompletionIcon(habit: habit, today: now, size: 56)
                    VStack(alignment: .leading) { Text(habit.name).font(.title2.bold()); Text("Every day · Since \(habit.createdAt.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(AppTheme.secondaryText) }
                }.padding(.vertical, 12)
                if let description = habit.habitDescription, !description.isEmpty {
                    Text(description).font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                }
                if !habit.archived {
                    Button { toggleCheckIn(.now) } label: {
                        Label {
                            Text(habit.isComplete(now) ? "Completed today · Undo" : "Check in today")
                        } icon: {
                            HabitSymbol(name: feedback.showsTick(habit.id, on: now) ? "checkmark" : habit.symbol)
                        }
                    }.tint(Color(habitHex: habit.colorHex))
                }
            }.appSectionStyle()
            if habit.isCounter {
                Section("Today's count") {
                    Stepper("\(habit.count(on: now)) / \(habit.dailyTarget)", onIncrement: { adjustCounter(1) }, onDecrement: { adjustCounter(-1) })
                }.appSectionStyle()
            }
            Section(habit.hasStreakGoal ? "Streak goal" : "Current streak") {
                StreakGoalView(current: stats.current, goal: habit.streakGoal, colorHex: habit.colorHex)
                    .padding(.vertical, 6)
                Button(habit.hasStreakGoal ? "Change or remove goal" : "Add a goal (optional)") { editing = true }
            }.appSectionStyle()
            Section("Reminders") {
                ReminderSummary(settings: habit.reminders)
                Button("Edit reminders") { editing = true }
            }.appSectionStyle()
            Section("Your rhythm") {
                Picker("View", selection: $weekly) { Text("Daily").tag(false); Text("Weekly").tag(true) }.pickerStyle(.segmented)
                HeatmapView(habit: habit, today: now, weekly: weekly) { date in toggleCheckIn(date) }.padding(.vertical, 8)
            }.appSectionStyle()
            Section("All-time statistics") {
                LabeledContent("Current streak", value: "\(stats.current) days")
                LabeledContent("Longest streak", value: "\(stats.longest) days")
                LabeledContent("Completion", value: "\(stats.percentage)%")
                Text("Completion includes every day since creation, including today. Your current streak stays alive until the end of today.").font(.caption).foregroundStyle(AppTheme.secondaryText)
            }.appSectionStyle()
            Section {
                Button("Archive habit") { archiving = true }
                    .confirmationDialog("Archive this habit? It will leave your daily list and widgets. Archived habits cannot be browsed or restored in the app.", isPresented: $archiving, titleVisibility: .visible) {
                        Button("Archive habit") {
                            habit.archived = true
                            if save() { refreshReminders(); dismiss() }
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                Button("Delete habit", role: .destructive) { deleting = true }
            }.appSectionStyle()
        }
        .appScreenStyle()
        .onAppear { setBottomNavigationHidden(true) }
        .onDisappear { setBottomNavigationHidden(false) }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { now = $0 }
        .navigationTitle("Habit").navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Edit") { editing = true } }
        .sheet(isPresented: $editing) { HabitEditor(habit: habit) }
        .confirmationDialog("Delete this habit and all its check-ins?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete permanently", role: .destructive) {
                context.delete(habit)
                if save() { refreshReminders(); dismiss() }
            }
        }
        .alert("Couldn’t save", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) { Button("OK") {} } message: { Text(failure ?? "") }
    }
    private func refreshReminders() {
        do {
            let all = try context.fetch(FetchDescriptor<Habit>())
            Task { _ = await ReminderScheduler.shared.reconcile(all) }
        } catch { failure = "Habit saved, but reminders could not be refreshed. Reopen MyHabits to retry." }
    }
    private func adjustCounter(_ amount: Int) {
        now = .now
        let wasComplete = habit.isComplete(now)
        habit.adjustCount(by: amount, on: now)
        guard save() else { return }
        if !wasComplete && habit.isComplete(now) { feedback.complete(habit.id, at: now) }
        else if wasComplete && !habit.isComplete(now) { feedback.undo(habit.id) }
    }
    private func toggleCheckIn(_ date: Date) {
        now = .now
        let isToday = Day.key(date) == Day.key(now)
        let wasComplete = habit.isComplete(date)
        habit.toggle(date)
        guard save(), isToday else { return }
        if wasComplete { feedback.undo(habit.id) }
        else { feedback.complete(habit.id, at: now) }
    }
    @discardableResult private func save() -> Bool {
        do { try context.save(); WidgetCenter.shared.reloadAllTimelines(); return true }
        catch { context.rollback(); failure = error.localizedDescription; return false }
    }
}
