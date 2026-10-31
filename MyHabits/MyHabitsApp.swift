import SwiftUI
import SwiftData

@main
struct MyHabitsApp: App {
    @AppStorage("appLanguage") private var appLanguage = "en"
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
            .environment(\.locale, Locale(identifier: appLanguage))
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
    @AppStorage("habitHomeLayout") private var layout: HabitHomeLayout = .list
    @State private var creating = false
    @State private var homeScrollRequest = 0
    @State private var settingsScrollRequest = 0
    @State private var showingUpdates = false
    @State private var updatesOrigin = CGRect.zero
    @State private var barHiddenByScroll = false
    @State private var barHidden = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TabView(selection: $selectedTab) {
            HabitListView(scrollToTopRequest: homeScrollRequest)
                .tag(Tab.home)
                .toolbar(.hidden, for: .tabBar)
            BackupView(showsDoneButton: false, scrollToTopRequest: settingsScrollRequest)
                .tag(Tab.settings)
                .toolbar(.hidden, for: .tabBar)
        }
        .environment(\.openAppUpdates, { origin in
            guard !showingUpdates else { return }
            updatesOrigin = origin
            showingUpdates = true
        })
        .environment(\.navigationBarCollapsed, { collapsed in
            guard barHiddenByScroll != collapsed else { return }
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
                barHiddenByScroll = collapsed
            }
        })
        .environment(\.setBottomNavigationHidden, { hidden in barHidden = hidden })
        .onChange(of: layout) { _, _ in selectedTab = .home; barHiddenByScroll = false }
        .onChange(of: selectedTab) { _, _ in barHiddenByScroll = false; barHidden = false }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !barHidden {
                HStack(spacing: 4) {
                    navigationButton("Home", symbol: "house.fill", selected: selectedTab == .home) {
                        selectedTab = .home
                        barHiddenByScroll = false
                        homeScrollRequest += 1
                    }
                    navigationButton("New Habit", symbol: "plus", selected: false) {
                        creating = true
                    }
                    Menu {
                        Picker("Habit layout", selection: $layout) {
                            ForEach([HabitHomeLayout.list, .cards, .grid]) { option in
                                Label(LocalizedStringKey(option.title), systemImage: option.symbol).tag(option)
                            }
                        }
                    } label: {
                        Image(systemName: layout.symbol)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Capsule())
                    }
                    .menuOrder(.fixed)
                    .accessibilityLabel("Habit layout")
                    navigationButton("Settings", symbol: "gearshape.fill", selected: selectedTab == .settings) {
                        selectedTab = .settings
                        barHiddenByScroll = false
                        settingsScrollRequest += 1
                    }
                }
                .padding(4)
                .background(.regularMaterial, in: Capsule())
                .overlay { Capsule().strokeBorder(AppTheme.border.opacity(0.5), lineWidth: 1) }
                .frame(maxWidth: 276)
                .frame(height: 62, alignment: .bottom)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)
                // Reserve the same inset while hidden so scrolling does not jump.
                .opacity(barHiddenByScroll ? 0 : 1)
                .offset(y: barHiddenByScroll && !reduceMotion ? 84 : 0)
                .allowsHitTesting(!barHiddenByScroll)
                .accessibilityHidden(barHiddenByScroll)
            }
        }
        .tint(AppTheme.accent)
        .accessibilityHidden(showingUpdates)
        .overlay {
            if showingUpdates {
                AppUpdatesReveal(origin: updatesOrigin) { showingUpdates = false }
            }
        }
        .sheet(isPresented: $creating) {
            HabitEditor(nextOrder: (habits.map(\.order).max() ?? -1) + 1)
        }
    }
    private func navigationButton(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(selected ? AppTheme.accent : AppTheme.primaryText)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(selected ? AppTheme.background : .clear, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

}
