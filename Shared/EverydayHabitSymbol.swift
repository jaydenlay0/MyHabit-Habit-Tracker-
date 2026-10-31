import SwiftUI

// Original outline drawings, using the same 32-point canvas and rounded strokes.
struct EverydayHabitSymbol: Shape {
    static let identifiers = ["habit.bath", "habit.coding", "habit.studying", "habit.bed", "habit.robotVacuum", "habit.vacuum", "habit.cleaning"]
    let name: String

    func path(in rect: CGRect) -> Path {
        var path = Path()
        func line(_ points: [CGPoint]) {
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
        }
        func rounded(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ radius: CGFloat) {
            path.addRoundedRect(in: CGRect(x: x, y: y, width: width, height: height), cornerSize: CGSize(width: radius, height: radius))
        }
        switch name {
        case "habit.bath":
            rounded(2, 16, 28, 3, 1.5)
            path.move(to: CGPoint(x: 4, y: 19))
            path.addQuadCurve(to: CGPoint(x: 10, y: 28), control: CGPoint(x: 4, y: 28))
            path.addLine(to: CGPoint(x: 23, y: 28))
            path.addQuadCurve(to: CGPoint(x: 28, y: 19), control: CGPoint(x: 28, y: 28))
            line([CGPoint(x: 7, y: 28), CGPoint(x: 6, y: 30)])
            line([CGPoint(x: 25, y: 28), CGPoint(x: 26, y: 30)])
            path.move(to: CGPoint(x: 5, y: 16))
            path.addLine(to: CGPoint(x: 5, y: 5))
            path.addCurve(to: CGPoint(x: 12, y: 4), control1: CGPoint(x: 5, y: 0), control2: CGPoint(x: 10, y: 0))
            path.move(to: CGPoint(x: 9, y: 7))
            path.addQuadCurve(to: CGPoint(x: 16, y: 7), control: CGPoint(x: 12.5, y: 0))
            path.closeSubpath()
            for x in [CGFloat(10), 13, 16] { line([CGPoint(x: x, y: 10), CGPoint(x: x - 0.5, y: 12)]) }
        case "habit.coding":
            rounded(5, 5, 22, 20, 1.5)
            rounded(2, 25, 28, 3, 1.5)
            line([CGPoint(x: 12, y: 12), CGPoint(x: 9, y: 15), CGPoint(x: 12, y: 18)])
            line([CGPoint(x: 20, y: 12), CGPoint(x: 23, y: 15), CGPoint(x: 20, y: 18)])
            line([CGPoint(x: 18, y: 10), CGPoint(x: 14, y: 20)])
        case "habit.studying":
            path.move(to: CGPoint(x: 16, y: 7))
            path.addQuadCurve(to: CGPoint(x: 4, y: 5), control: CGPoint(x: 10, y: 2))
            path.addLine(to: CGPoint(x: 4, y: 25))
            path.addQuadCurve(to: CGPoint(x: 16, y: 28), control: CGPoint(x: 11, y: 24))
            path.addQuadCurve(to: CGPoint(x: 27, y: 25), control: CGPoint(x: 21, y: 24))
            path.addLine(to: CGPoint(x: 27, y: 5))
            path.addQuadCurve(to: CGPoint(x: 16, y: 7), control: CGPoint(x: 21, y: 2))
            line([CGPoint(x: 16, y: 7), CGPoint(x: 16, y: 28)])
            for y in [CGFloat(11), 15, 19] {
                line([CGPoint(x: 7, y: y), CGPoint(x: 12, y: y + 0.5)])
                line([CGPoint(x: 20, y: y + 0.5), CGPoint(x: 24, y: y)])
            }
            line([CGPoint(x: 29, y: 9), CGPoint(x: 29, y: 24), CGPoint(x: 30, y: 27), CGPoint(x: 31, y: 24), CGPoint(x: 31, y: 9), CGPoint(x: 29, y: 9)])
        case "habit.bed":
            rounded(4, 5, 24, 16, 2)
            rounded(6, 10, 9, 6, 2)
            rounded(17, 10, 9, 6, 2)
            rounded(2, 16, 28, 11, 3)
            line([CGPoint(x: 2, y: 21), CGPoint(x: 30, y: 21)])
            line([CGPoint(x: 4, y: 27), CGPoint(x: 4, y: 30)])
            line([CGPoint(x: 28, y: 27), CGPoint(x: 28, y: 30)])
        case "habit.robotVacuum":
            path.addEllipse(in: CGRect(x: 3, y: 3, width: 26, height: 26))
            path.addEllipse(in: CGRect(x: 5.5, y: 5.5, width: 21, height: 21))
            path.addEllipse(in: CGRect(x: 12, y: 7, width: 8, height: 8))
            rounded(14, 22, 4, 1, 0.5)
            line([CGPoint(x: 5, y: 25), CGPoint(x: 1, y: 28)])
            line([CGPoint(x: 27, y: 25), CGPoint(x: 31, y: 28)])
        case "habit.vacuum":
            rounded(3, 26, 19, 4, 2)
            line([CGPoint(x: 7, y: 28), CGPoint(x: 16, y: 28)])
            line([CGPoint(x: 14, y: 26), CGPoint(x: 22, y: 5)])
            line([CGPoint(x: 17, y: 26), CGPoint(x: 25, y: 5)])
            line([CGPoint(x: 21, y: 8), CGPoint(x: 28, y: 10), CGPoint(x: 26, y: 17), CGPoint(x: 19, y: 15)])
            path.move(to: CGPoint(x: 22, y: 5))
            path.addQuadCurve(to: CGPoint(x: 27, y: 2), control: CGPoint(x: 23, y: 1))
            path.addQuadCurve(to: CGPoint(x: 25, y: 5), control: CGPoint(x: 29, y: 4))
        case "habit.cleaning":
            line([CGPoint(x: 4, y: 3), CGPoint(x: 13, y: 3), CGPoint(x: 16, y: 6), CGPoint(x: 12, y: 6), CGPoint(x: 12, y: 10), CGPoint(x: 8, y: 10), CGPoint(x: 8, y: 6), CGPoint(x: 4, y: 6), CGPoint(x: 4, y: 3)])
            path.move(to: CGPoint(x: 8, y: 10))
            path.addLine(to: CGPoint(x: 8, y: 14))
            path.addQuadCurve(to: CGPoint(x: 4, y: 20), control: CGPoint(x: 4, y: 17))
            path.addLine(to: CGPoint(x: 4, y: 28))
            path.addQuadCurve(to: CGPoint(x: 6, y: 30), control: CGPoint(x: 4, y: 30))
            path.addLine(to: CGPoint(x: 14, y: 30))
            path.addLine(to: CGPoint(x: 14, y: 20))
            path.addLine(to: CGPoint(x: 12, y: 14))
            path.addLine(to: CGPoint(x: 12, y: 10))
            line([CGPoint(x: 8, y: 6), CGPoint(x: 6, y: 11), CGPoint(x: 9, y: 8)])
            rounded(16, 24, 14, 6, 2)
            line([CGPoint(x: 18, y: 24), CGPoint(x: 21, y: 21), CGPoint(x: 30, y: 21), CGPoint(x: 27, y: 27), CGPoint(x: 18, y: 27)])
            line([CGPoint(x: 23, y: 12), CGPoint(x: 24.5, y: 16), CGPoint(x: 28, y: 17), CGPoint(x: 24.5, y: 18), CGPoint(x: 23, y: 21), CGPoint(x: 22, y: 18), CGPoint(x: 19, y: 17), CGPoint(x: 22, y: 16), CGPoint(x: 23, y: 12)])
        default: break
        }
        let scale = min(rect.width, rect.height) / 32
        return path.applying(CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: rect.midX - 16 * scale, ty: rect.midY - 16 * scale))
    }
}
