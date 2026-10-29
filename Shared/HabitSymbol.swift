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
        } else if name == "music.note" {
            // Keep the stored identifier compatible with existing habits and backups.
            DeodorantSpray()
                .stroke(style: StrokeStyle(lineWidth: size * 0.075, lineCap: .round, lineJoin: .round))
                .frame(width: size, height: size)
                .scaleEffect(1.5)
        } else {
            Image(systemName: name)
        }
    }
}

private struct DeodorantSpray: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Rounded spray button and its nozzle.
        path.move(to: CGPoint(x: 13, y: 6))
        path.addCurve(to: CGPoint(x: 16, y: 1), control1: CGPoint(x: 13, y: 2), control2: CGPoint(x: 14, y: 1))
        path.addCurve(to: CGPoint(x: 19, y: 6), control1: CGPoint(x: 18, y: 1), control2: CGPoint(x: 19, y: 2))
        path.move(to: CGPoint(x: 16, y: 3.5))
        path.addLine(to: CGPoint(x: 16, y: 4))
        // Shoulder, narrow neck, gently shaped can and flat base.
        path.move(to: CGPoint(x: 12.5, y: 6))
        path.addLine(to: CGPoint(x: 19.5, y: 6))
        path.addQuadCurve(to: CGPoint(x: 21, y: 8), control: CGPoint(x: 21.5, y: 6))
        path.addCurve(to: CGPoint(x: 20, y: 14), control1: CGPoint(x: 20.5, y: 10), control2: CGPoint(x: 20, y: 12))
        path.addCurve(to: CGPoint(x: 21, y: 23), control1: CGPoint(x: 20, y: 17), control2: CGPoint(x: 21, y: 20))
        path.addLine(to: CGPoint(x: 21, y: 31))
        path.addLine(to: CGPoint(x: 11, y: 31))
        path.addLine(to: CGPoint(x: 11, y: 23))
        path.addCurve(to: CGPoint(x: 12, y: 14), control1: CGPoint(x: 11, y: 20), control2: CGPoint(x: 12, y: 17))
        path.addCurve(to: CGPoint(x: 11, y: 8), control1: CGPoint(x: 12, y: 12), control2: CGPoint(x: 11.5, y: 10))
        path.addQuadCurve(to: CGPoint(x: 12.5, y: 6), control: CGPoint(x: 10.5, y: 6))
        path.closeSubpath()
        path.move(to: CGPoint(x: 11.5, y: 10))
        path.addLine(to: CGPoint(x: 20.5, y: 10))
        path.move(to: CGPoint(x: 12, y: 13))
        path.addLine(to: CGPoint(x: 20, y: 13))
        // Sweeping label edges from the supplied reference.
        path.move(to: CGPoint(x: 11, y: 23))
        path.addQuadCurve(to: CGPoint(x: 20.8, y: 19.5), control: CGPoint(x: 16, y: 19.5))
        path.move(to: CGPoint(x: 11, y: 28))
        path.addQuadCurve(to: CGPoint(x: 21, y: 23), control: CGPoint(x: 18, y: 28))
        let scale = min(rect.width, rect.height) / 32
        return path.applying(CGAffineTransform(a: scale, b: 0, c: 0, d: scale,
                                               tx: rect.midX - 16 * scale, ty: rect.midY - 16 * scale))
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
