import SwiftUI

struct HabitProgressRing: View {
    let habits: [Habit]
    let today: Date
    @AppStorage("summaryWeekly") private var weekly = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let summary = HabitCompletionSummary(habits: habits, today: today, weekly: weekly)
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(AppTheme.secondaryText.opacity(0.18), lineWidth: 5)
                Circle().trim(from: 0, to: summary.fraction)
                    .stroke(AppTheme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                if summary.allDone {
                    Image(systemName: "checkmark").font(.headline).foregroundStyle(AppTheme.accent)
                } else {
                    Text("\(Int(summary.fraction * 100))%")
                        .font(.system(size: 11, weight: .semibold)).monospacedDigit()
                }
            }.frame(width: 44, height: 44)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Menu {
                    Picker("Progress period", selection: $weekly) {
                        Text("Today").tag(false)
                        Text("This week").tag(true)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(LocalizedStringKey(weekly ? "This week" : "Today"))
                        Image(systemName: "chevron.down").font(.caption2)
                    }.font(.caption).foregroundStyle(AppTheme.secondaryText)
                }
                if weekly {
                    Text("\(summary.completed) of \(summary.total) completed this week")
                        .font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                } else {
                    Text("\(summary.completed) of \(summary.total) completed today")
                        .font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: summary.fraction)
        .fixedSize(horizontal: false, vertical: true)
    }
}
