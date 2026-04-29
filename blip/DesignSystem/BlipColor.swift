import SwiftUI

/// Per setlog-research/mood-principles.md:
///   - Dark, but warm. Near-black surfaces, not pure #000.
///   - One warm accent (cream/amber family) used **once per screen**.
///   - The video is the color; chrome is restraint.
enum BlipColor {
    // Surfaces — warm near-black, not pure #000.
    static let background = Color(red: 0.04, green: 0.035, blue: 0.030)        // ~#0A0908
    static let surface = Color(red: 0.085, green: 0.075, blue: 0.060)          // ~#16130F
    static let surfaceElevated = Color(red: 0.122, green: 0.102, blue: 0.078)  // ~#1F1A14
    static let border = Color.white.opacity(0.06)

    // Type — measured contrast, not stark white.
    static let textPrimary = Color(red: 0.97, green: 0.95, blue: 0.92)         // warm white
    static let textSecondary = Color(red: 0.72, green: 0.68, blue: 0.62)
    static let textTertiary = Color(red: 0.45, green: 0.42, blue: 0.38)

    /// Single warm-amber accent. Use **once per screen, max** — guides the eye to
    /// the one moment that matters (stitch / send / record). Per principle #6.
    static let accent = Color(red: 0.91, green: 0.66, blue: 0.49)              // ~#E8A87C

    // Progress ring colors share the accent — reuse, don't introduce a second hue.
    static let progressTrack = Color.white.opacity(0.08)
    static let progressFill = accent
}
