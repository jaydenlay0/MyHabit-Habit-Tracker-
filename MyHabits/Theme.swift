import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    static let storageKey = "appearance"
    case system, light, dark

    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum Palette {
    static let colors = ["63D6A3", "73B5FF", "B79CFF", "FFB86C", "F787A5", "F0D66E"]
    static let symbols = ["checkmark", "figure.walk", "book.closed", "drop", "moon", "leaf", "heart", "dumbbell", "pencil", "sun.max", "cup.and.saucer", "music.note"]
}
extension Color {
    init(habitHex: String) {
        let n = UInt64(habitHex, radix: 16) ?? 0x63D6A3
        self.init(.sRGB, red: Double((n >> 16) & 255) / 255, green: Double((n >> 8) & 255) / 255, blue: Double(n & 255) / 255, opacity: 1)
    }
}
