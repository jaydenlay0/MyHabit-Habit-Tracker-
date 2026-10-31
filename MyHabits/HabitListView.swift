import SwiftUI
import SwiftData
import WidgetKit

struct HabitListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Habit.order) private var habits: [Habit]
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.navigationBarCollapsed) private var updateNavigationScroll
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var headerHidden = false
    @State private var editMode: EditMode = .inactive
    @AppStorage("habitHomeLayout") private var layout: HabitHomeLayout = .list
    @State private var headerHeight: CGFloat = 170
    @State private var feedback = CompletionFeedback()
    @State private var now = Date.now
    @State private var counterToEdit: Habit?
    @State private var pendingArchive: Habit?
    @State private var pendingDelete: Habit?
    @State private var errorMessage: String?
    private var visible: [Habit] { habits.filter { !$0.archived } }
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Group {
                if layout == .list || editMode.isEditing {
                List {
                    if visible.isEmpty {
                        ContentUnavailableView("Make room for a good habit", systemImage: "leaf", description: Text("Tap + to start your first daily practice."))
                            .listRowBackground(Color.clear)
                    }
                    ForEach(visible) { habit in
                        HStack(spacing: 14) {
                            Button { if habit.isCounter { adjustCounter(habit, by: 1) } else { toggleToday(habit) } } label: {
                                HabitCompletionIcon(habit: habit, today: now)
                            }.buttonStyle(.borderless)
                                .accessibilityLabel(habit.isCounter ? "Increase \(habit.name) count" : "\(habit.isComplete(now) ? "Undo" : "Complete") \(habit.name) for today")
                                .accessibilityValue(habit.isComplete(now) ? "Completed" : "Not completed")
                            NavigationLink {
                                HabitDetailView(habit: habit)
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(habit.name).font(.headline)
                                    if habit.isCounter {
                                        Text("\(habit.count(on: now)) / \(habit.dailyTarget) today")
                                            .font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                                    }
                                    StreakGoalView(current: HabitStats(habit: habit, today: now).current, goal: habit.streakGoal, colorHex: habit.colorHex)
                                    MiniHeatmap(habit: habit, today: now)
                                }.padding(.vertical, 8)
                            }
                            if habit.isCounter {
                                VStack(spacing: 12) {
                                    Button { adjustCounter(habit, by: 1) } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                                        .accessibilityLabel(habit.isComplete(now) ? "Edit \(habit.name) count" : "Increase \(habit.name) count")
                                    Button { adjustCounter(habit, by: -1) } label: { Image(systemName: "minus.circle").font(.title2) }
                                        .disabled(habit.count(on: now) == 0)
                                        .accessibilityLabel("Decrease \(habit.name) count")
                                }.buttonStyle(.borderless).tint(Color(habitHex: habit.colorHex))
                            }
                        }
                        .appHabitCardStyle()
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.5, maximumDistance: 10)
                                .onEnded { _ in
                                    guard !editMode.isEditing else { return }
                                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                                        editMode = .active
                                    }
                                }
                        )
                        .swipeActions(edge: .trailing) {
                            Button { pendingDelete = habit } label: {
                                Label("Delete habit", systemImage: "trash")
                            }.tint(.red)
                        }
                        .swipeActions(edge: .leading) {
                            Button { pendingArchive = habit } label: {
                                Label("Archive", systemImage: "archivebox")
                            }.tint(.orange)
                        }
                    }.onMove(perform: move)
                }
                } else {
                    ScrollView {
                        if visible.isEmpty {
                            ContentUnavailableView("Make room for a good habit", systemImage: "leaf", description: Text("Tap + to start your first daily practice."))
                        } else {
                            LazyVGrid(columns: layout == .grid ? Array(repeating: GridItem(.flexible(), spacing: 10), count: 3) : [GridItem(.flexible())], alignment: .leading, spacing: 14) {
                                ForEach(visible) { habit in
                                    HabitLayoutCard(habit: habit, today: now, compact: layout == .grid) {
                                        if habit.isCounter { adjustCounter(habit, by: 1) } else { toggleToday(habit) }
                                    }
                                    .contextMenu {
                                        Button("Archive", systemImage: "archivebox") { pendingArchive = habit }
                                        Button("Delete habit", systemImage: "trash", role: .destructive) { pendingDelete = habit }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 90)
                        }
                    }
                }
                }
                .listRowSpacing(scheme == .dark ? 10 : nil)
                .environment(\.editMode, $editMode)
                .tracksNavigationScroll()
                .environment(\.navigationBarCollapsed, { scrollingDown in
                    guard !editMode.isEditing else {
                        hideHeaderForReordering()
                        return
                    }
                    updateNavigationScroll(scrollingDown)
                    guard headerHidden != scrollingDown else { return }
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
                        headerHidden = scrollingDown
                    }
                })
                .contentMargins(.top, headerHeight + 32, for: .scrollContent)
                .scrollContentBackground(.hidden)
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
                    Text("\(visible.filter { $0.isComplete(now) }.count) of \(visible.count) completed today").font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 4)
                .padding(.bottom, 12)
                .background(AppTheme.background)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(key: HomeHeaderHeightKey.self, value: geometry.size.height)
                    }
                }
                .offset(y: headerHidden && !reduceMotion ? -headerHeight - 16 : 0)
                .opacity(headerHidden ? 0 : 1)
                .allowsHitTesting(!headerHidden)
                .accessibilityHidden(headerHidden)
            }
            .onPreferenceChange(HomeHeaderHeightKey.self) { height in
                if height > 0 && abs(headerHeight - height) > 1 { headerHeight = height }
            }
            .background(AppTheme.background)
            .appScreenStyle()
            .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { now = $0 }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, $editMode)
            .onChange(of: editMode) { _, mode in
                if mode.isEditing { hideHeaderForReordering() }
            }
            .toolbar {
                #if compiler(>=6.2)
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarLeading) { brandLogo }
                        .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarLeading) { brandLogo }
                }
                #else
                ToolbarItem(placement: .topBarLeading) { brandLogo }
                #endif
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Picker("Habit layout", selection: $layout) {
                            ForEach(HabitHomeLayout.allCases) { option in
                                Label(LocalizedStringKey(option.title), systemImage: option.symbol).tag(option)
                            }
                        }
                    } label: {
                        Image(systemName: layout.symbol)
                    }
                    .accessibilityLabel("Habit layout")
                    .disabled(editMode.isEditing)

                    Button(editMode.isEditing ? "Done" : "Edit") {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                            editMode = editMode.isEditing ? .inactive : .active
                        }
                    }
                }
            }
            .sheet(item: $counterToEdit) { habit in
                CounterEditor(habit: habit, date: now)
            }
            .confirmationDialog("Archive this habit? It will leave your daily list and widgets. You can restore it later from Settings → Archived habits.", isPresented: Binding(get: { pendingArchive != nil }, set: { if !$0 { pendingArchive = nil } }), titleVisibility: .visible) {
                Button("Archive habit") {
                    pendingArchive?.archived = true
                    if save() {
                        Task { _ = await ReminderScheduler.shared.reconcile(habits) }
                    }
                    pendingArchive = nil
                }
                Button("Cancel", role: .cancel) { pendingArchive = nil }
            }
            .confirmationDialog("Permanently delete this habit and all its check-ins? This cannot be undone.", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
                Button("Delete permanently", role: .destructive) {
                    guard let habit = pendingDelete else { return }
                    pendingDelete = nil
                    context.delete(habit)
                    if save() {
                        Task { _ = await ReminderScheduler.shared.reconcile(habits) }
                    }
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
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
    private var brandLogo: some View {
        Image("BrandMark")
            .resizable()
            .scaledToFit()
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .offset(x: -8)
            .accessibilityLabel("MyHabits logo")
            .allowsHitTesting(false)
    }

    private func adjustCounter(_ habit: Habit, by amount: Int) {
        now = .now
        if amount > 0 && habit.count(on: now) >= habit.dailyTarget {
            counterToEdit = habit
            return
        }
        let wasComplete = habit.isComplete(now)
        habit.adjustCount(by: amount, on: now)
        guard save() else { return }
        if !wasComplete && habit.isComplete(now) { feedback.complete(habit.id, at: now) }
        else if wasComplete && !habit.isComplete(now) { feedback.undo(habit.id) }
    }

    private func toggleToday(_ habit: Habit) {
        now = .now
        let wasComplete = habit.isComplete(now)
        habit.toggle(now)
        guard save() else { return }
        if wasComplete { feedback.undo(habit.id) }
        else { feedback.complete(habit.id, at: now) }
    }

    private func hideHeaderForReordering() {
        guard !headerHidden else { return }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) {
            headerHidden = true
        }
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

private struct HomeHeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 170
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
