import SwiftUI

struct HabitSymbol: View {
    let name: String
    var size: CGFloat = 18

    var body: some View {
        if name == "leaf" {
            // Retain the stored identifier so existing habits and backups keep
            // working while the retired leaf option becomes Brushing teeth.
            ToothbrushWithPaste()
                .stroke(style: StrokeStyle(lineWidth: size * 0.075, lineCap: .round, lineJoin: .round))
                .frame(width: size, height: size)
        } else {
            Image(systemName: name)
        }
    }
}

private struct ToothbrushWithPaste: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Curved handle leading into the brush head.
        path.move(to: CGPoint(x: 3, y: 24))
        path.addLine(to: CGPoint(x: 14, y: 24))
        path.addCurve(to: CGPoint(x: 21, y: 19), control1: CGPoint(x: 18, y: 24), control2: CGPoint(x: 18, y: 19))
        path.addLine(to: CGPoint(x: 28, y: 19))
        path.addQuadCurve(to: CGPoint(x: 29, y: 17), control: CGPoint(x: 30, y: 19))
        path.addLine(to: CGPoint(x: 29, y: 16))
        path.addLine(to: CGPoint(x: 22, y: 16))
        // Three upright tufts of bristles.
        for x in [22, 25, 28] {
            path.move(to: CGPoint(x: CGFloat(x), y: 16))
            path.addLine(to: CGPoint(x: CGFloat(x), y: 12))
        }
        // A small toothpaste swirl resting on the bristles.
        path.move(to: CGPoint(x: 20, y: 10))
        path.addCurve(to: CGPoint(x: 24, y: 8), control1: CGPoint(x: 20, y: 7), control2: CGPoint(x: 23, y: 10))
        path.addQuadCurve(to: CGPoint(x: 26, y: 5), control: CGPoint(x: 26, y: 7))
        path.addCurve(to: CGPoint(x: 29, y: 10), control1: CGPoint(x: 29, y: 6), control2: CGPoint(x: 30, y: 8))
        path.addLine(to: CGPoint(x: 20, y: 10))
        let scale = min(rect.width, rect.height) / 32
        let offsetX = rect.midX - 16 * scale
        let offsetY = rect.midY - 16 * scale
        return path.applying(CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: offsetX, ty: offsetY))
    }
}
