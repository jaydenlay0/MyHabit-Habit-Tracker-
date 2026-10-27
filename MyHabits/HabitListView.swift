import SwiftUI
import SwiftData
import WidgetKit

struct HabitListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Habit.order) private var habits: [Habit]
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var feedback = CompletionFeedback()
    @State private var now = Date.now
    @State private var creating = false
    @State private var settings = false
    @State private var pendingArchive: Habit?
    @State private var errorMessage: String?
    private var visible: [Habit] { habits.filter { !$0.archived } }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .center, spacing: 8) {
                    Text("MyHabits")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                        .padding(.bottom, 20)
                    Text(now, format: .dateTime.weekday(.wide).month(.wide).day()).font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                    Text("Another Day, Another Opportunity.")
                        .font(.title2.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .allowsTightening(true)
                    Text("\(visible.filter { $0.isComplete(now) }.count) of \(visible.count) complete today").font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 4)
                .padding(.bottom, 12)
                List {
                    if visible.isEmpty {
                        ContentUnavailableView("Make room for a good habit", systemImage: "leaf", description: Text("Tap + to start your first daily practice."))
                            .listRowBackground(Color.clear)
                    }
                    ForEach(visible) { habit in
                        HStack(spacing: 14) {
                            Button { toggleToday(habit) } label: {
                                HabitCompletionIcon(habit: habit, today: now)
                            }.buttonStyle(.borderless)
                                .accessibilityLabel("\(habit.isComplete(now) ? "Undo" : "Complete") \(habit.name) for today")
                                .accessibilityValue(habit.isComplete(now) ? "Completed" : "Not completed")
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
                        .appHabitCardStyle()
                        .swipeActions {
                            Button("Archive") { pendingArchive = habit }.tint(.orange)
                        }
                    }.onMove(perform: move)
                }
                .listRowSpacing(scheme == .dark ? 10 : nil)
                .contentMargins(.top, 32, for: .scrollContent)
                .scrollContentBackground(.hidden)
            }
            .background(AppTheme.background)
            .appScreenStyle()
            .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { now = $0 }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
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
                    if save() {
                        Task { _ = await ReminderScheduler.shared.reconcile(habits) }
                    }
                    pendingArchive = nil
                }
                Button("Cancel", role: .cancel) { pendingArchive = nil }
            }
            .alert("Couldn’t save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK") {} } message: { Text(errorMessage ?? "") }
        }
        .overlay { CompletionCelebration() }
        .environment(feedback)
        .sensoryFeedback(.success, trigger: feedback.hapticTrigger)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { feedback.stop() }
            else { now = .now }
        }
    }
    private func toggleToday(_ habit: Habit) {
        now = .now
        let wasComplete = habit.isComplete(now)
        habit.toggle(now)
        guard save() else { return }
        if wasComplete { feedback.undo(habit.id) }
        else { feedback.complete(habit.id, at: now) }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = visible; ordered.move(fromOffsets: source, toOffset: destination)
        let hidden = habits.filter { $0.archived }
        for (index, habit) in (ordered + hidden).enumerated() { habit.order = index }
        save()
    }
    @discardableResult private func save() -> Bool {
        do { try context.save(); WidgetCenter.shared.reloadAllTimelines(); return true }
        catch { context.rollback(); errorMessage = error.localizedDescription; return false }
    }
}
