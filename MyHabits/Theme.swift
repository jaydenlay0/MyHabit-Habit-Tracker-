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
    static let defaultColor = "63D6A3"
    // Twenty-four hues in rainbow order; existing saved colours remain in the palette.
    static let colors = [
        "FF6B6B", "FF8B66", "FF9F43", "FFB86C", "FFC857", "F0D66E",
        "D4E76C", "A5DC74", "77D98B", "63D6A3", "2FBF9B", "50C9BC",
        "53C9DC", "66C4F5", "73B5FF", "5A82E8", "8295F2", "9C87F5",
        "B79CFF", "CA8DE8", "E68BCB", "E56AB5", "F787A5", "F57589"
    ]
    static let colorNames = [
        "Red", "Coral", "Orange", "Peach", "Amber", "Yellow",
        "Lime", "Spring green", "Green", "Mint", "Emerald", "Teal",
        "Turquoise", "Sky blue", "Blue", "Cobalt", "Indigo", "Violet",
        "Lavender", "Purple", "Orchid", "Magenta", "Pink", "Rose"
    ]
    static let symbols = [
        "checkmark", "figure.walk", "book.closed", "drop", "moon", "leaf",
        "heart", "dumbbell", "pencil", "sun.max", "cup.and.saucer", "music.note",
        "figure.mind.and.body", "figure.yoga", "basketball.fill", "figure.jumprope", "pills.fill", "airpodsmax"
    ]
    static func symbolName(_ symbol: String) -> String {
        let names = [
            "checkmark": "Checkmark", "figure.walk": "Walking", "book.closed": "Reading",
            "drop": "Water", "moon": "Sleep", "leaf": "Leaf", "heart": "Heart",
            "dumbbell": "Exercise", "pencil": "Writing", "sun.max": "Sunshine",
            "cup.and.saucer": "Tea or coffee", "music.note": "Music",
            "figure.mind.and.body": "Meditation", "figure.yoga": "Yoga",
            "basketball.fill": "Basketball", "figure.jumprope": "Skipping rope",
            "pills.fill": "Pills", "airpodsmax": "AirPods Max headphones"
        ]
        return names[symbol] ?? symbol
    }
    static func colorName(_ hex: String) -> String {
        guard let index = colors.firstIndex(of: hex) else { return "Custom colour" }
        return colorNames[index]
    }
}
extension Color {
    init(habitHex: String) {
        let n = UInt64(habitHex, radix: 16) ?? 0x63D6A3
        self.init(.sRGB, red: Double((n >> 16) & 255) / 255, green: Double((n >> 8) & 255) / 255, blue: Double(n & 255) / 255, opacity: 1)
    }
}
