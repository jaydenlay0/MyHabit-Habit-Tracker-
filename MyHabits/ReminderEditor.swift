import SwiftUI

struct ReminderEditor: View {
    @Environment(\.colorScheme) private var scheme
    @Binding var settings: HabitReminders
    private var weekdays: [Int] {
        let first: Int = Calendar.current.firstWeekday
        var ordered: [Int] = []
        for offset in 0..<7 {
            let day: Int = (first - 1 + offset) % 7 + 1
            ordered.append(day)
        }
        return ordered
    }
    private func timeBinding(_ get: @escaping () -> Int, set: @escaping (Int) -> Void) -> Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: get() / 60, minute: get() % 60, second: 0, of: .now) ?? .now
        } set: { date in
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            set((components.hour ?? 0) * 60 + (components.minute ?? 0))
        }
    }
    private func label(_ minute: Int) -> String {
        (Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: .now) ?? .now)
            .formatted(date: .omitted, time: .shortened)
    }
    var body: some View {
        Section {
            Toggle("Reminders", isOn: $settings.enabled)
            if settings.enabled {
                Toggle("Every day", isOn: Binding(get: { settings.weekdays.count == 7 }, set: { settings.weekdays = $0 ? Array(1...7) : [] }))
                HStack(spacing: 4) {
                    ForEach(weekdays, id: \.self) { day in
                        let selected = settings.weekdays.contains(day)
                        Button {
                            if selected { settings.weekdays.removeAll { $0 == day } }
                            else { settings.weekdays.append(day) }
                        } label: {
                            Text(Calendar.current.veryShortStandaloneWeekdaySymbols[day - 1])
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .foregroundStyle(selected ? (scheme == .dark ? Color.black : Color.white) : AppTheme.secondaryText)
                                .background(selected ? AppTheme.accent : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(.plain)
                            .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
                            .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                Toggle("Use a time window", isOn: $settings.usesWindow)
                if settings.usesWindow {
                    DatePicker("From", selection: timeBinding({ settings.windowStart }, set: { settings.windowStart = $0 }), displayedComponents: .hourAndMinute)
                    DatePicker("Until", selection: timeBinding({ settings.windowEnd }, set: { settings.windowEnd = $0 }), displayedComponents: .hourAndMinute)
                    Stepper("\(settings.windowCount) \(settings.windowCount == 1 ? "reminder" : "reminders") per day", value: $settings.windowCount, in: 1...3)
                    if settings.validationMessage == nil {
                        Text("Scheduled at: \(settings.scheduledMinutes.map(label).joined(separator: ", "))")
                            .font(.caption).foregroundStyle(AppTheme.secondaryText)
                    }
                } else {
                    ForEach(settings.times.indices, id: \.self) { index in
                        HStack {
                            DatePicker("Reminder \(index + 1)", selection: timeBinding({ settings.times.indices.contains(index) ? settings.times[index] : 600 }, set: { if settings.times.indices.contains(index) { settings.times[index] = $0 } }), displayedComponents: .hourAndMinute)
                            if settings.times.count > 1 {
                                Button(role: .destructive) {
                                    if settings.times.count > 1 && settings.times.indices.contains(index) { settings.times.remove(at: index) }
                                } label: {
                                    Image(systemName: "minus.circle")
                                }.buttonStyle(.borderless).accessibilityLabel("Remove reminder \(index + 1)")
                            }
                        }
                    }
                    if settings.times.count < 3 {
                        Button("Add reminder") {
                            let next = (0..<1440).first { minute in
                                minute >= ((settings.times.max() ?? 480) + 60) && !settings.times.contains(minute)
                            } ?? (0..<1440).first { !settings.times.contains($0) } ?? 0
                            settings.times.append(next)
                        }
                    }
                }
                if let message = settings.validationMessage {
                    Text(message).font(.caption).foregroundStyle(.red)
                }
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text("Up to three reminders on each selected day. A time window spaces them evenly; a single reminder arrives at its midpoint. Delivery follows your local time and iPhone notification settings.")
        }
        .appSectionStyle()
    }
}

struct ReminderSummary: View {
    let settings: HabitReminders
    private var dayNames: String {
        guard settings.weekdays.count != 7 else { return "Every day" }
        let calendar: Calendar = .current
        let first: Int = calendar.firstWeekday
        let symbols: [String] = calendar.shortWeekdaySymbols
        var names: [String] = []
        for offset in 0..<7 {
            let day: Int = (first - 1 + offset) % 7 + 1
            if settings.weekdays.contains(day) {
                names.append(symbols[day - 1])
            }
        }
        return names.joined(separator: ", ")
    }
    private var timeNames: String {
        let calendar: Calendar = .current
        var names: [String] = []
        for minute in settings.scheduledMinutes {
            let date: Date = calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: .now) ?? .now
            let name: String = date.formatted(date: .omitted, time: .shortened)
            names.append(name)
        }
        return names.joined(separator: ", ")
    }
    var body: some View {
        if settings.enabled {
            VStack(alignment: .leading, spacing: 4) {
                Text(dayNames)
                Text(timeNames).font(.subheadline).foregroundStyle(AppTheme.secondaryText)
            }
        } else {
            Text("Off").foregroundStyle(AppTheme.secondaryText)
        }
    }
}
