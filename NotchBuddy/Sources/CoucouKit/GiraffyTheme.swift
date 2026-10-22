import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// Purple Giraffe's colours for Giraffy's own accent: the one place to change them.
/// Every other shade comes from `pgPurpleHex`.
///
/// Not part of the theme: per-agent and per-service pill colours (PillCatalog), and the
/// semantic colours (success green, error red, warning orange and amber), which stay as
/// they are so states read the same for everyone.
enum GiraffyTheme {
    /// PG brand purple. Placeholder until PG confirms its hex.
    static let pgPurpleHex = "#6E3FC4"
    /// Hover, and the accent on Giraffy's dark surfaces (the island, the Flow window):
    /// readable as text on black (WCAG AA).
    static let pgPurpleLightHex = mix(pgPurpleHex, towards: 1, amount: 0.30)
    /// Pressed, and the darker end of Giraffy's body gradient.
    static let pgPurpleDarkHex = mix(pgPurpleHex, towards: 0, amount: 0.35)
    /// Giraffy's spots.
    static let giraffeSpotHex = "#E8A94B"

    /// The app's accent where it sits on a dark surface.
    static let accentHex = pgPurpleLightHex
    /// Text and icons drawn on an accent fill.
    static let onAccentHex = "#140A26"

    /// Moves a colour towards white (`towards: 1`) or black (`towards: 0`) by `amount` (0…1).
    static func mix(_ hex: String, towards target: Double, amount: Double) -> String {
        let rgb = components(hex)
        let out = rgb.map { $0 * (1 - amount) + target * amount }
        return "#" + out.map { String(format: "%02X", Int(($0 * 255).rounded())) }.joined()
    }

    /// Red, green and blue in 0…1.
    static func components(_ hex: String) -> [Double] {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let v = UInt64(h, radix: 16) ?? 0
        return [Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255]
    }

    /// WCAG contrast ratio between two colours (1…21).
    static func contrast(_ a: String, _ b: String) -> Double {
        func luminance(_ hex: String) -> Double {
            let c = components(hex).map { $0 <= 0.03928 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
            return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
        }
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
}

#if canImport(SwiftUI)
extension GiraffyTheme {
    static let pgPurple = Color(hex: pgPurpleHex)
    static let pgPurpleLight = Color(hex: pgPurpleLightHex)
    static let pgPurpleDark = Color(hex: pgPurpleDarkHex)
    static let giraffeSpot = Color(hex: giraffeSpotHex)
    static let accent = Color(hex: accentHex)
    static let onAccent = Color(hex: onAccentHex)
}
#endif
