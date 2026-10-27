import SwiftUI
import Observation

struct CompletionMoment {
    let id = UUID()
    let day: String
    let expiresAt: Date
}
struct CompletionBurst: Identifiable {
    let id = UUID()
    let habitID: UUID
    let startedAt: Date
}

@MainActor @Observable
final class CompletionFeedback {
    private(set) var moments: [UUID: CompletionMoment] = [:]
    private(set) var bursts: [CompletionBurst] = []
    private(set) var hapticTrigger = 0

    func complete(_ habitID: UUID, at date: Date = .now) {
        moments = moments.filter { $0.value.expiresAt > date }
        moments[habitID] = CompletionMoment(day: Day.key(date), expiresAt: date.addingTimeInterval(2))
        bursts.removeAll { date.timeIntervalSince($0.startedAt) >= CelebrationTiming.duration }
        bursts.append(CompletionBurst(habitID: habitID, startedAt: date))
        hapticTrigger += 1
    }
    func showsTick(_ habitID: UUID, on date: Date, now: Date = .now) -> Bool {
        guard let moment = moments[habitID] else { return false }
        return moment.day == Day.key(date) && moment.expiresAt > now
    }
    func finishTick(_ habitID: UUID, token: UUID) {
        // A cancelled or older task must not clear a newer check-in's tick.
        if moments[habitID]?.id == token { moments.removeValue(forKey: habitID) }
    }
    func finishBurst(token: UUID) {
        bursts.removeAll { $0.id == token }
    }
    func undo(_ habitID: UUID) {
        moments.removeValue(forKey: habitID)
        bursts.removeAll { $0.habitID == habitID }
    }
    func stop() { moments.removeAll(); bursts.removeAll() }
}

struct HabitCompletionIcon: View {
    let habit: Habit
    let today: Date
    var size: CGFloat = 46
    @Environment(CompletionFeedback.self) private var feedback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let complete = habit.isComplete(today)
        let tick = complete && feedback.showsTick(habit.id, on: today)
        let moment = feedback.moments[habit.id]
        ZStack {
            Image(systemName: habit.symbol).opacity(tick ? 0 : 1)
            Image(systemName: "checkmark").opacity(tick ? 1 : 0)
        }
            .font(size > 46 ? .title2 : .headline)
            .frame(width: size, height: size)
            .foregroundStyle(complete ? Palette.selectionInk(habit.colorHex) : Color(habitHex: habit.colorHex))
            .background(Color(habitHex: habit.colorHex).opacity(complete ? 1 : 0.14), in: RoundedRectangle(cornerRadius: 14))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: tick)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: complete)
            .accessibilityHidden(true)
            .task(id: moment?.id) {
                guard let moment else { return }
                let remaining = max(0, moment.expiresAt.timeIntervalSinceNow)
                do { try await Task.sleep(for: .seconds(remaining)) }
                catch { return }
                feedback.finishTick(habit.id, token: moment.id)
            }
    }
}

private enum CelebrationTiming {
    static let duration: TimeInterval = 3.8
}

struct CompletionCelebration: View {
    @Environment(CompletionFeedback.self) private var feedback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(feedback.bursts) { burst in
                ConfettiLayer(burst: burst)
            }
            if reduceMotion && !feedback.bursts.isEmpty {
                // Show just one quiet acknowledgement when showers overlap.
                VStack {
                    Label("Well done!", systemImage: "sparkles")
                        .font(.headline).padding(14)
                        .background(.regularMaterial, in: Capsule())
                    Spacer()
                }.padding(.top, 12)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ConfettiLayer: View {
    let burst: CompletionBurst
    @Environment(CompletionFeedback.self) private var feedback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion { Color.clear }
            else { ConfettiRain(startedAt: burst.startedAt).ignoresSafeArea() }
        }
        // Each stable layer keeps its own clock and cleanup task. Adding another
        // completion never resets the start time or cancels an older shower.
        .task(id: burst.id) {
            let remaining = max(0, burst.startedAt.addingTimeInterval(CelebrationTiming.duration).timeIntervalSinceNow)
            do { try await Task.sleep(for: .seconds(remaining)) }
            catch { return }
            feedback.finishBurst(token: burst.id)
        }
    }
}

private struct ConfettiRain: View {
    let startedAt: Date
    private let colors = ["FF6B6B", "73B5FF", "63D6A3", "F0D66E", "F787A5", "B79CFF"]
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = max(0, timeline.date.timeIntervalSince(startedAt))
                guard elapsed < CelebrationTiming.duration else { return }
                for index in 0..<192 {
                    // More stagger and varied speeds make a taller, airier shower,
                    // rather than packing extra pieces into a thin falling band.
                    let delay = Double(index % 8) * 0.08
                    let fallDuration = 2.2 + Double(index % 5) * 0.2
                    let progress = (elapsed - delay) / fallDuration
                    guard progress >= 0 && progress <= 1 else { continue }
                    // Distribute flakes across the top and let each cross the full screen.
                    let startX = CGFloat((index * 73) % 193) / 192 * size.width
                    let drift = CGFloat(sin(elapsed * 3 + Double(index)) * 16)
                    let x = startX + drift
                    let y = -24 + (size.height + 48) * CGFloat(progress)
                    var particle = context
                    particle.opacity = min(1, max(0, (1 - progress) * 8))
                    particle.translateBy(x: x, y: y)
                    particle.rotate(by: .degrees(Double(index) * 23 + elapsed * 190))
                    let rect = CGRect(x: -3, y: -5, width: 6, height: 10)
                    particle.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(Color(habitHex: colors[index % colors.count])))
                }
            }
        }
    }
}
