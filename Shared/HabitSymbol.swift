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
                .scaleEffect(1.32)
        } else {
            Image(systemName: name)
        }
    }
}

private struct ToothbrushWithPaste: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // End the brush at the first bristle on the left; the handle extends right.
        path.move(to: CGPoint(x: 8, y: 27))
        path.addLine(to: CGPoint(x: 29, y: 27))
        let bristles: [CGFloat] = [8, 12, 16, 20, 24]
        for x in bristles {
            path.move(to: CGPoint(x: x, y: 18))
            path.addLine(to: CGPoint(x: x, y: 27))
        }
        // Shift the ribbon slightly right to align it with the brush head.
        var toothpaste = Path()
        toothpaste.move(to: CGPoint(x: 18.5, y: 6.5))
        toothpaste.addCurve(to: CGPoint(x: 23, y: 10), control1: CGPoint(x: 22, y: 6.5), control2: CGPoint(x: 24, y: 8))
        toothpaste.addCurve(to: CGPoint(x: 20, y: 15), control1: CGPoint(x: 24, y: 13.5), control2: CGPoint(x: 23, y: 15))
        toothpaste.addLine(to: CGPoint(x: 6, y: 15))
        toothpaste.addCurve(to: CGPoint(x: 6, y: 11), control1: CGPoint(x: 2, y: 15), control2: CGPoint(x: 2, y: 11))
        toothpaste.addLine(to: CGPoint(x: 16, y: 11))
        toothpaste.addCurve(to: CGPoint(x: 18.5, y: 6.5), control1: CGPoint(x: 18.5, y: 11), control2: CGPoint(x: 18.5, y: 9))
        toothpaste.closeSubpath()
        path.addPath(toothpaste, transform: CGAffineTransform(translationX: 3, y: 0))
        // Fill the symbol frame to match the visual weight of the SF Symbols.
        let scale = min(rect.width, rect.height) / 25
        let offsetX = rect.midX - 18 * scale
        let offsetY = rect.midY - 16.75 * scale
        return path.applying(CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: offsetX, ty: offsetY))
    }
}
