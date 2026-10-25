import SwiftUI
import SwiftData
import WidgetKit

struct HabitListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Habit.order) private var habits: [Habit]
    @State private var now = Date.now
    @State private var creating = false
    @State private var settings = false
    @State private var showArchived = false
    @State private var errorMessage: String?
    private var visible: [Habit] { habits.filter { $0.archived == showArchived } }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(now, format: .dateTime.weekday(.wide).month(.wide).day()).font(.subheadline).foregroundStyle(.secondary)
                        Text(showArchived ? "Room for what’s next." : "Small steps. Lasting change.").font(.title2.bold())
                        if !showArchived {
                            Text("\(visible.filter { $0.isComplete(now) }.count) of \(visible.count) complete today").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 8)
                }.listRowBackground(Color.clear).listRowSeparator(.hidden)
                if visible.isEmpty {
                    ContentUnavailableView(showArchived ? "No archived habits" : "Make room for a good habit", systemImage: "leaf", description: Text(showArchived ? "Archived habits keep their history." : "Tap + to start your first daily practice."))
                        .listRowBackground(Color.clear)
                }
                ForEach(visible) { habit in
                    HStack(spacing: 14) {
                        if !showArchived {
                            Button { habit.toggle(now); save() } label: {
                                Image(systemName: habit.isComplete(now) ? "checkmark" : habit.symbol)
                                    .font(.headline).frame(width: 46, height: 46)
                                    .foregroundStyle(habit.isComplete(now) ? Color.black : Color(habitHex: habit.colorHex))
                                    .background(Color(habitHex: habit.colorHex).opacity(habit.isComplete(now) ? 1 : 0.14), in: RoundedRectangle(cornerRadius: 14))
                            }.buttonStyle(.borderless)
                                .accessibilityLabel("\(habit.isComplete(now) ? "Undo" : "Complete") \(habit.name) for today")
                        }
                        NavigationLink {
                            HabitDetailView(habit: habit)
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack { Text(habit.name).font(.headline); Spacer(); Text("\(HabitStats(habit: habit, today: now).current)d").font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
                                MiniHeatmap(habit: habit, today: now)
                            }.padding(.vertical, 8)
                        }
                    }
                    .swipeActions {
                        Button(showArchived ? "Restore" : "Archive") { habit.archived.toggle(); save() }.tint(.orange)
                    }
                }.onMove(perform: move)
            }
            .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { now = $0 }
            .navigationTitle(showArchived ? "Archive" : "MyHabits")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button { settings = true } label: { Image(systemName: "slider.horizontal.3") }.accessibilityLabel("Settings and backups") }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    EditButton()
                    Button { creating = true } label: { Image(systemName: "plus") }.accessibilityLabel("Create habit")
                }
                ToolbarItem(placement: .bottomBar) { Button(showArchived ? "Show active habits" : "View archive") { showArchived.toggle() } }
            }
            .sheet(isPresented: $creating) { HabitEditor(nextOrder: (habits.map(\.order).max() ?? -1) + 1) }
            .sheet(isPresented: $settings) { BackupView() }
            .alert("Couldn’t save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK") {} } message: { Text(errorMessage ?? "") }

        }
    }
    private func move(from source: IndexSet, to destination: Int) {
        var ordered = visible; ordered.move(fromOffsets: source, toOffset: destination)
        let hidden = habits.filter { $0.archived != showArchived }
        for (index, habit) in (ordered + hidden).enumerated() { habit.order = index }
        save()
    }
    private func save() {
        do { try context.save(); WidgetCenter.shared.reloadAllTimelines() }
        catch { context.rollback(); errorMessage = error.localizedDescription }
    }
}
