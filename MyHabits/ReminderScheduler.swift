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
        var result: [ReminderDefinition] = []
        for habit in habits where !habit.archived {
            let settings = habit.reminders
            if settings.enabled { result.append(ReminderDefinition(id: habit.id, name: habit.name, settings: settings)) }
        }
        return result
    }
    static func validateCapacity(_ definitions: [ReminderDefinition]) throws {
        for definition in definitions {
            if let message = definition.settings.validationMessage { throw ReminderScheduleError.invalid(message) }
        }
        let slots = definitions.reduce(0) { $0 + $1.settings.notificationSlots }
        guard slots <= 64 else { throw ReminderScheduleError.exceeded(slots) }
    }
    static func requests(for definitions: [ReminderDefinition]) throws -> [UNNotificationRequest] {
        try validateCapacity(definitions)
        var requests: [UNNotificationRequest] = []
        for definition in definitions where definition.settings.enabled {
            guard definition.settings.validationMessage == nil else { continue }
            let weekdays: [Int?] = definition.settings.weekdays.count == 7 ? [nil] : definition.settings.weekdays.sorted().map { Optional($0) }
            for weekday in weekdays {
                for minute in definition.settings.scheduledMinutes {
                    let content = UNMutableNotificationContent()
                    content.title = definition.name
                    content.body = "A small moment for your habit. Ready to check in?"
                    content.sound = .default
                    var components = DateComponents()
                    components.hour = minute / 60; components.minute = minute % 60
                    components.weekday = weekday
                    // No fixed time zone: reminders follow the device's local clock.
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                    let id = Self.prefix + definition.id.uuidString + ".\(weekday ?? 0).\(minute)"
                    requests.append(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
                }
            }
        }
        return requests
    }
    static func requestsNeedingUpdate(_ requested: [UNNotificationRequest], existing: [UNNotificationRequest]) -> [UNNotificationRequest] {
        let previous = Dictionary(uniqueKeysWithValues: existing.map { ($0.identifier, $0) })
        return requested.filter { request in
            guard let old = previous[request.identifier],
                  let oldTrigger = old.trigger as? UNCalendarNotificationTrigger,
                  let newTrigger = request.trigger as? UNCalendarNotificationTrigger else { return true }
            let sameContent = old.content.title == request.content.title
                && old.content.body == request.content.body && old.content.sound == request.content.sound
            let sameTiming = oldTrigger.repeats == newTrigger.repeats && oldTrigger.dateComponents == newTrigger.dateComponents
            return !sameContent || !sameTiming
        }
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
        let requests: [UNNotificationRequest]
        do { requests = try Self.requests(for: definitions) }
        catch { return error.localizedDescription }
        let wanted = Set(requests.map(\.identifier))
        center.removePendingNotificationRequests(withIdentifiers: existing.map(\.identifier).filter { !wanted.contains($0) })
        do {
            let updates = Self.requestsNeedingUpdate(requests, existing: existing)
            for request in updates { try await center.add(request) }
            return nil
        } catch {
            return "Habit saved, but some reminders could not be scheduled. Reopen MyHabits to retry. \(error.localizedDescription)"
        }
    }
}
