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
                    HabitListView().modelContainer(container).id(generation)
                        .onChange(of: scenePhase) { _, phase in
                            if phase == .active && widgetRevision != SharedStore.widgetRevision() {
                                do { self.container = try SharedStore.make(); widgetRevision = SharedStore.widgetRevision(); generation = UUID() }
                                catch { failure = error.localizedDescription }
                            }
                        }
                } else {
                    ContentUnavailableView("Storage unavailable", systemImage: "externaldrive.badge.exclamationmark", description: Text(failure ?? "Unable to open local storage. Your data has not been reset."))
                }
            }
            .preferredColorScheme(appearance.colorScheme)
        }
    }
}
