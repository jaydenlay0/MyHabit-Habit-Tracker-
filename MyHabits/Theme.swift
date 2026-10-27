import SwiftUI
import UIKit

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
    // Rows run deep to light; columns are red, blue, green, yellow, pink, purple.
    static let colors = [
        "C93645", "3568C8", "268B52", "D9A923", "D94888", "7850C5",
        "E94B57", "4F8FE8", "45BA73", "F6CC4D", "EE6AA7", "9C75E8",
        "FF6B6B", "73B5FF", "63D6A3", "F0D66E", "F787A5", "B79CFF",
        "FF9B9B", "A8D3FF", "A8E6B5", "FFF2A6", "FFD1E3", "DDCBFF"
    ]
    static let colorNames = [
        "Deep red", "Royal blue", "Forest green", "Mustard yellow", "Deep pink", "Deep purple",
        "Scarlet red", "Cornflower blue", "Leaf green", "Golden yellow", "Rose pink", "Violet",
        "Red", "Blue", "Mint green", "Yellow", "Pink", "Lavender",
        "Light red", "Baby blue", "Light green", "Pale yellow", "Baby pink", "Lilac"
    ]
    static func selectionInk(_ hex: String) -> Color {
        // Choose black or white to keep the selection mark readable on every shade.
        let value = UInt64(hex, radix: 16) ?? 0x63D6A3
        func linear(_ channel: UInt64) -> Double {
            let value = Double(channel) / 255
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear((value >> 16) & 255)
            + 0.7152 * linear((value >> 8) & 255) + 0.0722 * linear(value & 255)
        return luminance > 0.179 ? .black : .white
    }
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

// Semantic colours resolve with the current appearance, including sheet overrides.
// Light variants keep the existing native iOS colours.
enum AppTheme {
    static let background = adaptive("0D1117", light: .systemGroupedBackground)
    static let surface = adaptive("161B22", light: .secondarySystemGroupedBackground)
    static let border = adaptive("30363D", light: .separator)
    static let primaryText = adaptive("E6EDF3", light: .label)
    static let secondaryText = adaptive("9198A1", light: .secondaryLabel)
    static let accent = adaptive("58A6FF", light: .systemBlue)
    static let emptyHeatmap = Color(habitHex: "21262D")

    private static func adaptive(_ hex: String, light: UIColor) -> Color {
        let n = UInt64(hex, radix: 16)!
        let dark = UIColor(red: CGFloat((n >> 16) & 255) / 255,
                           green: CGFloat((n >> 8) & 255) / 255,
                           blue: CGFloat(n & 255) / 255, alpha: 1)
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}
