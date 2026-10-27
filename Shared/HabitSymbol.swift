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
        // Horizontal brush base with five rounded upright bristles.
        path.move(to: CGPoint(x: 4, y: 27))
        path.addLine(to: CGPoint(x: 29, y: 27))
        let bristles: [CGFloat] = [8, 12, 16, 20, 24]
        for x in bristles {
            path.move(to: CGPoint(x: x, y: 18))
            path.addLine(to: CGPoint(x: x, y: 27))
        }
        // Outlined toothpaste ribbon with a lifted, curved tip.
        path.move(to: CGPoint(x: 18.5, y: 6.5))
        path.addCurve(to: CGPoint(x: 23, y: 10), control1: CGPoint(x: 22, y: 6.5), control2: CGPoint(x: 24, y: 8))
        path.addCurve(to: CGPoint(x: 20, y: 15), control1: CGPoint(x: 24, y: 13.5), control2: CGPoint(x: 23, y: 15))
        path.addLine(to: CGPoint(x: 6, y: 15))
        path.addCurve(to: CGPoint(x: 6, y: 11), control1: CGPoint(x: 2, y: 15), control2: CGPoint(x: 2, y: 11))
        path.addLine(to: CGPoint(x: 16, y: 11))
        path.addCurve(to: CGPoint(x: 18.5, y: 6.5), control1: CGPoint(x: 18.5, y: 11), control2: CGPoint(x: 18.5, y: 9))
        path.closeSubpath()
        let scale = min(rect.width, rect.height) / 32
        let offsetX = rect.midX - 16 * scale
        let offsetY = rect.midY - 16 * scale
        return path.applying(CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: offsetX, ty: offsetY))
    }
}
