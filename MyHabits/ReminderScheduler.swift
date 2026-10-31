import Foundation
import Observation
import UserNotifications

struct ReminderDefinition {
    let id: UUID
    let name: String
    let settings: HabitReminders
}

enum ReminderScheduleError: LocalizedError {
    case exceeded(Int)
    case invalid(String)
    var errorDescription: String? {
        switch self {
        case .exceeded(let count):
            return "These settings need \(count) scheduled notification slots. iOS permits 64 per app. Choose fewer reminder times or weekdays, or turn off reminders for some habits. Every-day reminders use fewer slots."
        case .invalid(let message): return message
        }
    }
}

private final class ReminderNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

@MainActor @Observable
final class ReminderScheduler {
    static let shared = ReminderScheduler()
    private(set) var notice: String?
    private(set) var authorization: UNAuthorizationStatus = .notDetermined
    private let notificationDelegate = ReminderNotificationDelegate()
    private let center = UNUserNotificationCenter.current()
    private var pending: Task<String?, Never>?
    private var generation = UUID()
    private static let prefix = "myhabits.reminder."

    private init() { center.delegate = notificationDelegate }

    static func definitions(_ habits: [Habit]) -> [ReminderDefinition] {
        habits.filter { !$0.archived && $0.reminders.enabled }.map {
            ReminderDefinition(id: $0.id, name: $0.name, settings: $0.reminders)
        }
    }
    static func validateCapacity(_ definitions: [ReminderDefinition]) throws {
        for definition in definitions {
            if let message = definition.settings.validationMessage { throw ReminderScheduleError.invalid(message) }
        }
        let slots = definitions.reduce(0) { $0 + $1.settings.notificationSlots }
        guard slots <= 64 else { throw ReminderScheduleError.exceeded(slots) }
    }
    static let messages = [
        "Another day, another opportunity. Let's keep it going!",
        "MyHabits misses you 👀",
        "Your habit called. It's asking for you ⚡",
        "There's still A LOT of time to reach your daily goal"
    ]
    private static let rotationKey = "reminderRotationIndex"
    private static let planKey = "reminderRotationPlan"

    static func requests(for definitions: [ReminderDefinition], now: Date = .now, startingIndex: Int = 0) throws -> [UNNotificationRequest] {
        try validateCapacity(definitions)
        let calendar = Calendar.current
        var upcoming: [(date: Date, definition: ReminderDefinition, match: DateComponents)] = []
        for definition in definitions where definition.settings.enabled {
            let weekdays: [Int?] = definition.settings.weekdays.count == 7 ? [nil] : definition.settings.weekdays.sorted().map { Optional($0) }
            for weekday in weekdays {
                for minute in definition.settings.scheduledMinutes {
                    var match = DateComponents()
                    match.hour = minute / 60; match.minute = minute % 60; match.second = 0
                    match.weekday = weekday
                    if let date = calendar.nextDate(after: now, matching: match, matchingPolicy: .nextTime) {
                        upcoming.append((date, definition, match))
                    }
                }
            }
        }
        var requests: [UNNotificationRequest] = []
        while requests.count < 64 && !upcoming.isEmpty {
            upcoming.sort {
                if $0.date != $1.date { return $0.date < $1.date }
                return $0.definition.id.uuidString < $1.definition.id.uuidString
            }
            let next = upcoming.removeFirst()
            let index = (startingIndex + requests.count) % messages.count
            let content = UNMutableNotificationContent()
            content.title = next.definition.name
            content.body = messages[index]
            content.sound = .default
            content.userInfo = ["rotationIndex": index, "scheduledAt": next.date.timeIntervalSince1970]
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: next.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let id = Self.prefix + next.definition.id.uuidString + ".\(Int(next.date.timeIntervalSince1970))"
            requests.append(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            if let date = calendar.nextDate(after: next.date, matching: next.match, matchingPolicy: .nextTime) {
                upcoming.append((date, next.definition, next.match))
            }
        }
        return requests
    }
    static func rotationIndex(after plan: [[String: Double]], now: Date, fallback: Int) -> Int {
        let elapsed = plan.filter { ($0["scheduledAt"] ?? .greatestFiniteMagnitude) <= now.timeIntervalSince1970 }
        guard let latest = elapsed.max(by: { ($0["scheduledAt"] ?? 0) < ($1["scheduledAt"] ?? 0) }),
              let index = latest["rotationIndex"] else { return fallback }
        // The plan's ordinal resolves reminders scheduled at the same time.
        let latestTime = latest["scheduledAt"] ?? 0
        let simultaneous = elapsed.filter { $0["scheduledAt"] == latestTime }
        let last = simultaneous.max { ($0["ordinal"] ?? 0) < ($1["ordinal"] ?? 0) } ?? latest
        return (Int(last["rotationIndex"] ?? index) + 1) % messages.count
    }
    func refreshAuthorization() async {
        authorization = await center.notificationSettings().authorizationStatus
    }
    func reconcile(_ habits: [Habit], requestPermission: Bool = false) async -> String? {
        let definitions = Self.definitions(habits)
        // Serialise OS writes: a later edit or archive must always win over an earlier refresh.
        let previous = pending
        let token = UUID(); generation = token
        let task = Task { @MainActor in
            if let previous { _ = await previous.value }
            return await self.apply(definitions, requestPermission: requestPermission)
        }
        pending = task
        let result = await task.value
        if generation == token { notice = result; pending = nil }
        return result
    }
    private func apply(_ definitions: [ReminderDefinition], requestPermission: Bool) async -> String? {
        let existing = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix(Self.prefix) }
        if definitions.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: existing.map(\.identifier))
            await refreshAuthorization()
            return nil
        }
        do { try Self.validateCapacity(definitions) }
        catch {
            // Never leave stale notifications for renamed, archived or deleted habits.
            center.removePendingNotificationRequests(withIdentifiers: existing.map(\.identifier))
            return error.localizedDescription
        }
        await refreshAuthorization()
        if requestPermission && authorization == .notDetermined {
            do { _ = try await center.requestAuthorization(options: [.alert, .sound]) }
            catch { return "Habit saved, but notification permission could not be requested: \(error.localizedDescription)" }
            await refreshAuthorization()
        }
        guard authorization == .authorized || authorization == .provisional || authorization == .ephemeral else {
            center.removePendingNotificationRequests(withIdentifiers: existing.map(\.identifier))
            return "Reminders are saved but notifications are off. Allow MyHabits notifications in iPhone Settings to receive them."
        }
        let defaults = UserDefaults.standard
        let now = Date.now
        let plan = defaults.array(forKey: Self.planKey) as? [[String: Double]] ?? []
        let index = Self.rotationIndex(after: plan, now: now, fallback: defaults.integer(forKey: Self.rotationKey))
        let requests: [UNNotificationRequest]
        do { requests = try Self.requests(for: definitions, now: now, startingIndex: index) }
        catch { return error.localizedDescription }
        let wanted = Set(requests.map(\.identifier))
        center.removePendingNotificationRequests(withIdentifiers: existing.map(\.identifier).filter { !wanted.contains($0) })
        do {
            for request in requests { try await center.add(request) }
            let plan: [[String: Double]] = requests.enumerated().map { ordinal, request in
                ["scheduledAt": request.content.userInfo["scheduledAt"] as? Double ?? 0,
                 "rotationIndex": Double(request.content.userInfo["rotationIndex"] as? Int ?? 0),
                 "ordinal": Double(ordinal)]
            }
            defaults.set(index, forKey: Self.rotationKey)
            defaults.set(plan, forKey: Self.planKey)
            return nil
        } catch {
            return "Habit saved, but some reminders could not be scheduled. Reopen MyHabits to retry. \(error.localizedDescription)"
        }
    }
}
