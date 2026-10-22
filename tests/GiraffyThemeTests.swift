import Foundation

@main
enum GiraffyThemeTests {
    static var failures = 0
    static func check(_ name: String, _ ok: Bool) {
        print("\(ok ? "✓" : "✗") \(name)")
        if !ok { failures += 1 }
    }

    static func main() {
        // Shades derive from the one PG purple.
        check("mix towards white", GiraffyTheme.mix("#000000", towards: 1, amount: 0.5) == "#808080")
        check("mix towards black", GiraffyTheme.mix("#FFFFFF", towards: 0, amount: 0.25) == "#BFBFBF")
        check("light is lighter", GiraffyTheme.components(GiraffyTheme.pgPurpleLightHex).reduce(0, +)
              > GiraffyTheme.components(GiraffyTheme.pgPurpleHex).reduce(0, +))
        check("dark is darker", GiraffyTheme.components(GiraffyTheme.pgPurpleDarkHex).reduce(0, +)
              < GiraffyTheme.components(GiraffyTheme.pgPurpleHex).reduce(0, +))
        check("contrast black/white is 21", abs(GiraffyTheme.contrast("#000000", "#FFFFFF") - 21) < 0.01)

        // The accent stays readable on Giraffy's dark surfaces (WCAG AA, 4.5:1), whatever purple PG picks.
        for surface in ["#000000", "#0E0F11", "#18191C", "#1F2024"] {
            check("accent on \(surface) ≥ 4.5", GiraffyTheme.contrast(GiraffyTheme.accentHex, surface) >= 4.5)
        }
        check("text on an accent fill ≥ 4.5", GiraffyTheme.contrast(GiraffyTheme.onAccentHex, GiraffyTheme.accentHex) >= 4.5)
        check("white on PG purple ≥ 4.5", GiraffyTheme.contrast("#FFFFFF", GiraffyTheme.pgPurpleHex) >= 4.5)

        if failures > 0 { print("\n\(failures) failure(s)"); exit(1) }
        print("\nAll Giraffy theme tests passed")
    }
}
