import SwiftUI

/// The green contribution-graph ramp, with a light and a dark variant.
enum HeatmapPalette {
    static let empty = Color.adaptive(light: 0xEBEDF0, dark: 0x22262E)

    static let levels: [Color] = [
        Color.adaptive(light: 0x9BE9A8, dark: 0x0E4429),
        Color.adaptive(light: 0x40C463, dark: 0x006D32),
        Color.adaptive(light: 0x30A14E, dark: 0x26A641),
        Color.adaptive(light: 0x216E39, dark: 0x39D353),
    ]

    /// Quartile bucketing, the same scheme every contribution graph uses.
    static func color(count: Int, maxCount: Int, isFuture: Bool) -> Color {
        // Days after today are left blank so the grid visibly ends at today.
        guard !isFuture, count > 0 else { return isFuture ? .clear : empty }

        let ceiling = Swift.max(maxCount, 1)
        let ratio = Double(count) / Double(ceiling)

        let index: Int
        switch ratio {
        case ..<0.25: index = 0
        case ..<0.5: index = 1
        case ..<0.75: index = 2
        default: index = 3
        }

        // A quiet week should not paint a single submission at full brightness.
        let adjusted = ceiling <= 2 ? Swift.min(index, 1) : index
        return levels[adjusted]
    }
}
