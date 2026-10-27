import Foundation
import SwiftData

// Enable this same App Group for BOTH targets in Signing & Capabilities.
enum SharedStore {
    static let group = "group.com.example.MyHabits"
    private static var revisionURL: URL? {
        #if PERSONAL_TEAM
        return nil
        #else
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?.appendingPathComponent("widget-revision.txt")
        #endif
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
        #if PERSONAL_TEAM
        // Personal Teams cannot provision App Groups. Keep this build's data
        // in its own app sandbox; backups move data between the two editions.
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = support.appendingPathComponent("MyHabitsPersonal", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #else
        guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSLocalizedDescriptionKey: "Enable the MyHabits App Group for both targets in Xcode Signing & Capabilities."])
        }
        #endif
        let config = ModelConfiguration("MyHabits", schema: Schema([Habit.self]), url: directory.appendingPathComponent("MyHabits.store"), cloudKitDatabase: .none)
        return try ModelContainer(for: Habit.self, configurations: config)
    }
}
