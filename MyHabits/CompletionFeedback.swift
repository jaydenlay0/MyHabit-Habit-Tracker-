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
    private(set) var burst: CompletionBurst?
    private(set) var hapticTrigger = 0

    func complete(_ habitID: UUID, at date: Date = .now) {
        moments = moments.filter { $0.value.expiresAt > date }
        moments[habitID] = CompletionMoment(day: Day.key(date), expiresAt: date.addingTimeInterval(2))
        burst = CompletionBurst(habitID: habitID, startedAt: date)
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
        if burst?.id == token { burst = nil }
    }
    func undo(_ habitID: UUID) {
        moments.removeValue(forKey: habitID)
        if burst?.habitID == habitID { burst = nil }
    }
    func stop() { moments.removeAll(); burst = nil }
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
        Image(systemName: tick ? "checkmark" : habit.symbol)
            .font(size > 46 ? .title2 : .headline)
            .frame(width: size, height: size)
            .foregroundStyle(complete ? Palette.selectionInk(habit.colorHex) : Color(habitHex: habit.colorHex))
            .background(Color(habitHex: habit.colorHex).opacity(complete ? 1 : 0.14), in: RoundedRectangle(cornerRadius: 14))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: complete)
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

struct CompletionCelebration: View {
    @Environment(CompletionFeedback.self) private var feedback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let burst = feedback.burst {
                if reduceMotion {
                    // A quiet acknowledgement instead of moving particles.
                    VStack {
                        Label("Well done!", systemImage: "sparkles")
                            .font(.headline).padding(14)
                            .background(.regularMaterial, in: Capsule())
                        Spacer()
                    }.padding(.top, 12)
                } else {
                    ConfettiBurst(startedAt: burst.startedAt).id(burst.id)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: feedback.burst?.id) {
            guard let burst = feedback.burst else { return }
            do { try await Task.sleep(for: .seconds(2.2)) }
            catch { return }
            feedback.finishBurst(token: burst.id)
        }
    }
}

private struct ConfettiBurst: View {
    let startedAt: Date
    private let colors = ["FF6B6B", "73B5FF", "63D6A3", "F0D66E", "F787A5", "B79CFF"]
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = max(0, timeline.date.timeIntervalSince(startedAt))
                guard elapsed < 2.2 else { return }
                for index in 0..<48 {
                    let angle = Double(index) * 2.39996
                    let horizontalSpeed = cos(angle) * (80 + Double(index % 5) * 35)
                    let verticalSpeed = 140 + Double(index % 7) * 32
                    let x = size.width / 2 + CGFloat(horizontalSpeed * elapsed)
                    let y = size.height * 0.38 + CGFloat(-verticalSpeed * elapsed + 250 * elapsed * elapsed)
                    var particle = context
                    particle.opacity = min(1, max(0, (2.2 - elapsed) / 0.6))
                    particle.translateBy(x: x, y: y)
                    particle.rotate(by: .degrees(Double(index) * 23 + elapsed * 190))
                    let rect = CGRect(x: -3, y: -5, width: 6, height: 10)
                    particle.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(Color(habitHex: colors[index % colors.count])))
                }
            }
        }
    }
}
