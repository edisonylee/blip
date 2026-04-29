import SwiftUI

enum BlipColor {
    static let background = Color.black
    static let surface = Color(white: 0.08)
    static let surfaceElevated = Color(white: 0.12)
    static let border = Color.white.opacity(0.08)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.5)

    /// Primary accent — placeholder pending Phase D brand pass.
    /// Setlog uses pink/teal; blip's US-native identity is TBD.
    static let accent = Color(red: 1.0, green: 0.94, blue: 0.6)

    static let progressTrack = Color.white.opacity(0.08)
    static let progressFill = accent
}
