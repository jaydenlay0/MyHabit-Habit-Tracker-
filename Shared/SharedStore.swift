import Foundation
import SwiftData

// Enable this same App Group for BOTH targets in Signing & Capabilities.
enum SharedStore {
    static let group = "group.com.example.MyHabits"
    private static var revisionURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?.appendingPathComponent("widget-revision.txt")
    }
    static func widgetRevision() -> String {
        guard let url = revisionURL else { return "" }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }
    static func markWidgetWrite() {
        guard let url = revisionURL else { return }
        try? UUID().uuidString.write(to: url, atomically: true, encoding: .utf8)
    }
    static func make() throws -> ModelContainer {
        guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSLocalizedDescriptionKey: "Enable the MyHabits App Group for both targets in Xcode Signing & Capabilities."])
        }
        let config = ModelConfiguration("MyHabits", schema: Schema([Habit.self]), url: directory.appendingPathComponent("MyHabits.store"), cloudKitDatabase: .none)
        return try ModelContainer(for: Habit.self, configurations: config)
    }
}
