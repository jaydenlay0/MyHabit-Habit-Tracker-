import SwiftUI

enum HabitHomeLayout: String, CaseIterable, Identifiable {
    case list, cards, grid
    var id: String { rawValue }
    var title: String {
        switch self { case .list: return "List"; case .cards: return "Cards"; case .grid: return "Grid" }
    }
    var symbol: String {
        switch self { case .list: return "list.bullet"; case .cards: return "rectangle.grid.1x2"; case .grid: return "square.grid.3x3" }
    }
}

struct HabitLayoutCard: View {
    let habit: Habit
    let today: Date
    let compact: Bool
    let checkIn: () -> Void

    private var yearRange: YearToDateHeatmapRange { YearToDateHeatmapRange(today: today) }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 8) {
            HStack(spacing: compact ? 7 : 12) {
                Button(action: checkIn) {
                    HabitCompletionIcon(habit: habit, today: today, size: compact ? 32 : 46, symbolSize: compact ? 16 : nil)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(habit.isMeasure ? "Enter total" : (habit.isCounter ? "Increase count" : "Check in today"))
                NavigationLink { HabitDetailView(habit: habit) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(habit.name)
                            .font(compact ? .caption.weight(.semibold) : .headline)
                            .lineLimit(1)
                            .foregroundStyle(AppTheme.primaryText)
                        if !compact, let description = habit.habitDescription, !description.isEmpty {
                            Text(description).font(.subheadline).lineLimit(1).foregroundStyle(AppTheme.secondaryText)
                        }
                        if compact {
                            // Reserve the counter line in every tile to keep rows equal.
                            Text(habit.isQuantified ? habit.progressLabel(on: today) : " ")
                                .font(.caption2)
                                .foregroundStyle(Color(habitHex: habit.colorHex))
                                .lineLimit(1)
                                .accessibilityHidden(!habit.isQuantified)
                        } else if habit.isQuantified {
                            Text(habit.progressLabel(on: today))
                                .font(.caption2).foregroundStyle(Color(habitHex: habit.colorHex))
                        } else if !compact {
                            Text("Week \(yearRange.columns) · \(yearRange.year)")
                                .font(.caption).foregroundStyle(AppTheme.secondaryText)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain)
            }
            NavigationLink { HabitDetailView(habit: habit) } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedStringKey(habit.isComplete(today) ? "Completed" : "Incomplete"))
                        .font(.caption2).foregroundStyle(AppTheme.secondaryText)
                    if compact {
                        Text(today, format: .dateTime.month(.abbreviated).year())
                            .font(.caption2).foregroundStyle(AppTheme.secondaryText)
                    }
                    if compact {
                        HabitCardHeatmap(habit: habit, today: today, monthly: true)
                            .aspectRatio(7.0 / 6.0, contentMode: .fit)
                    } else {
                        HabitCardHeatmap(habit: habit, today: today, monthly: false)
                            .frame(height: 70)
                    }
                }
            }.buttonStyle(.plain)
        }
        .padding(compact ? 10 : 12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: compact ? 18 : 22))
        .overlay {
            RoundedRectangle(cornerRadius: compact ? 18 : 22)
                .strokeBorder(Color.white, lineWidth: 1)
        }
    }
}

private struct HabitCardHeatmap: View {
    let habit: Habit
    let today: Date
    let monthly: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let calendar = Day.calendar
        let monthStart = calendar.dateInterval(of: .month, for: today)?.start ?? today
        let leading = (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7) % 7
        let yearRange = YearToDateHeatmapRange(today: today)
        let start = monthly ? Day.adding(-leading, to: monthStart) : yearRange.start
        let completed = Set(habit.days)
        let todayKey = Day.key(today)
        let columns = monthly ? 7 : yearRange.columns
        let rows = monthly ? 6 : 7
        Canvas { context, size in
            let gap: CGFloat = monthly ? 3 : 2
            let availableWidth = (size.width - CGFloat(columns - 1) * gap) / CGFloat(columns)
            let availableHeight = (size.height - CGFloat(rows - 1) * gap) / CGFloat(rows)
            let cellWidth = monthly ? availableWidth : min(availableWidth, availableHeight)
            let cellHeight = monthly ? availableHeight : cellWidth
            guard cellWidth > 0, cellHeight > 0 else { return }
            for index in 0..<(columns * rows) {
                let date = Day.adding(index, to: start)
                if monthly && !calendar.isDate(date, equalTo: today, toGranularity: .month) { continue }
                if !monthly && (date < yearRange.firstDay || date > calendar.startOfDay(for: today)) { continue }
                let column = monthly ? index % columns : index / rows
                let row = monthly ? index / columns : index % rows
                let rect = CGRect(x: CGFloat(column) * (cellWidth + gap), y: CGFloat(row) * (cellHeight + gap), width: cellWidth, height: cellHeight)
                let path = Path(roundedRect: rect, cornerRadius: min(3, cellWidth / 3))
                let key = Day.key(date)
                let done = completed.contains(key)
                let eligible = date <= today && date >= calendar.startOfDay(for: habit.createdAt)
                let color = done ? Color(habitHex: habit.colorHex) : (scheme == .dark ? AppTheme.emptyHeatmap : Color(habitHex: habit.colorHex).opacity(0.12))
                context.fill(path, with: .color(color.opacity(eligible ? 1 : 0.35)))
                if key == todayKey { context.stroke(path, with: .color(AppTheme.secondaryText), lineWidth: 1.2) }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(monthly ? "Monthly consistency heatmap" : "Year-to-date consistency heatmap")
    }
}

struct YearToDateHeatmapRange {
    let firstDay: Date
    let start: Date
    let columns: Int
    let year: String

    init(today: Date, calendar: Calendar = .current) {
        firstDay = calendar.dateInterval(of: .year, for: today)?.start ?? calendar.startOfDay(for: today)
        let leading = (calendar.component(.weekday, from: firstDay) - calendar.firstWeekday + 7) % 7
        start = calendar.date(byAdding: .day, value: -leading, to: firstDay) ?? firstDay
        let elapsed = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: today)).day ?? 0
        columns = max(1, elapsed / 7 + 1)
        year = String(calendar.component(.year, from: today))
    }
}
