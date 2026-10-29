import SwiftUI
import SwiftData

@main
struct MyHabitsApp: App {
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system
    @State private var container: ModelContainer?
    @State private var failure: String?
    @Environment(\.scenePhase) private var scenePhase
    @State private var generation = UUID()
    @State private var widgetRevision = SharedStore.widgetRevision()
    init() {
        do {
            _container = State(initialValue: try SharedStore.make())
            _failure = State(initialValue: nil)
        } catch {
            _container = State(initialValue: nil)
            _failure = State(initialValue: error.localizedDescription)
        }
    }
    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    MainTabView().modelContainer(container).id(generation)
                        .task { await refreshReminders(container) }
                        .onChange(of: scenePhase) { _, phase in
                            if phase == .active {
                                if widgetRevision != SharedStore.widgetRevision() {
                                    do { self.container = try SharedStore.make(); widgetRevision = SharedStore.widgetRevision(); generation = UUID() }
                                    catch { failure = error.localizedDescription }
                                }
                                Task { await refreshReminders(self.container ?? container) }
                            }
                        }
                } else {
                    ContentUnavailableView("Storage unavailable", systemImage: "externaldrive.badge.exclamationmark", description: Text(failure ?? "Unable to open local storage. Your data has not been reset."))
                }
            }
            .preferredColorScheme(appearance.colorScheme)
        }
    }
    @MainActor private func refreshReminders(_ container: ModelContainer) async {
        do {
            let habits = try container.mainContext.fetch(FetchDescriptor<Habit>())
            _ = await ReminderScheduler.shared.reconcile(habits)
        } catch { /* Keep existing scheduled reminders if storage cannot be read. */ }
    }

}

private struct MainTabView: View {
    private enum Tab: Hashable { case home, settings }
    @Query(sort: \Habit.order) private var habits: [Habit]
    @State private var selectedTab: Tab = .home
    @State private var creating = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HabitListView()
                .tag(Tab.home)
                .toolbar(.hidden, for: .tabBar)
            BackupView(showsDoneButton: false)
                .tag(Tab.settings)
                .toolbar(.hidden, for: .tabBar)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 4) {
                navigationButton("Home", symbol: "house.fill", selected: selectedTab == .home) {
                    selectedTab = .home
                }
                navigationButton("Settings", symbol: "gearshape.fill", selected: selectedTab == .settings) {
                    selectedTab = .settings
                }
                navigationButton("New Habit", symbol: "plus", selected: false) {
                    creating = true
                }
            }
            .padding(6)
            .background(.regularMaterial, in: Capsule())
            .overlay { Capsule().strokeBorder(AppTheme.border.opacity(0.5), lineWidth: 1) }
            .frame(maxWidth: 360)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
        .tint(AppTheme.accent)
        .sheet(isPresented: $creating) {
            HabitEditor(nextOrder: (habits.map(\.order).max() ?? -1) + 1)
        }
    }
    private func navigationButton(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 22, weight: .semibold))
                Text(title).font(.caption2.weight(.semibold))
            }
            .foregroundStyle(selected ? AppTheme.accent : AppTheme.primaryText)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(selected ? AppTheme.background : .clear, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

}
