import SwiftUI
import SwiftData
import WidgetKit

struct HabitListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Habit.order) private var habits: [Habit]
    @State private var now = Date.now
    @State private var creating = false
    @State private var settings = false
    @State private var pendingArchive: Habit?
    @State private var errorMessage: String?
    private var visible: [Habit] { habits.filter { !$0.archived } }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(now, format: .dateTime.weekday(.wide).month(.wide).day()).font(.subheadline).foregroundStyle(.secondary)
                        Text("Another Day, Another Opportunity.").font(.title2.bold())
                        Text("\(visible.filter { $0.isComplete(now) }.count) of \(visible.count) complete today").font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.vertical, 8)
                }.listRowBackground(Color.clear).listRowSeparator(.hidden)
                if visible.isEmpty {
                    ContentUnavailableView("Make room for a good habit", systemImage: "leaf", description: Text("Tap + to start your first daily practice."))
                        .listRowBackground(Color.clear)
                }
                ForEach(visible) { habit in
                    HStack(spacing: 14) {
                        Button { habit.toggle(now); save() } label: {
                            Image(systemName: habit.isComplete(now) ? "checkmark" : habit.symbol)
                                .font(.headline).frame(width: 46, height: 46)
                                .foregroundStyle(habit.isComplete(now) ? Color.black : Color(habitHex: habit.colorHex))
                                .background(Color(habitHex: habit.colorHex).opacity(habit.isComplete(now) ? 1 : 0.14), in: RoundedRectangle(cornerRadius: 14))
                        }.buttonStyle(.borderless)
                            .accessibilityLabel("\(habit.isComplete(now) ? "Undo" : "Complete") \(habit.name) for today")
                        NavigationLink {
                            HabitDetailView(habit: habit)
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(habit.name).font(.headline)
                                StreakGoalView(current: HabitStats(habit: habit, today: now).current, goal: habit.streakGoal, colorHex: habit.colorHex)
                                MiniHeatmap(habit: habit, today: now)
                            }.padding(.vertical, 8)
                        }
                    }
                    .swipeActions {
                        Button("Archive") { pendingArchive = habit }.tint(.orange)
                    }
                }.onMove(perform: move)
            }
            .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { now = $0 }
            .navigationTitle("MyHabits")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button { settings = true } label: { Image(systemName: "slider.horizontal.3") }.accessibilityLabel("Settings and backups") }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    EditButton()
                    Button { creating = true } label: { Image(systemName: "plus") }.accessibilityLabel("Create habit")
                }
            }
            .sheet(isPresented: $creating) { HabitEditor(nextOrder: (habits.map(\.order).max() ?? -1) + 1) }
            .sheet(isPresented: $settings) { BackupView() }
            .confirmationDialog("Archive this habit? It will leave your daily list and widgets. Archived habits cannot be browsed or restored in the app.", isPresented: Binding(get: { pendingArchive != nil }, set: { if !$0 { pendingArchive = nil } }), titleVisibility: .visible) {
                Button("Archive habit") {
                    pendingArchive?.archived = true
                    save()
                    pendingArchive = nil
                }
                Button("Cancel", role: .cancel) { pendingArchive = nil }
            }
            .alert("Couldn’t save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK") {} } message: { Text(errorMessage ?? "") }
        }
    }
    private func move(from source: IndexSet, to destination: Int) {
        var ordered = visible; ordered.move(fromOffsets: source, toOffset: destination)
        let hidden = habits.filter { $0.archived }
        for (index, habit) in (ordered + hidden).enumerated() { habit.order = index }
        save()
    }
    private func save() {
        do { try context.save(); WidgetCenter.shared.reloadAllTimelines() }
        catch { context.rollback(); errorMessage = error.localizedDescription }
    }
}
