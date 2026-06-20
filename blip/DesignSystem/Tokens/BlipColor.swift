import SwiftUI
import UIKit

/// Design-system color tokens — light-only pastel + glassmorphism theme.
///
/// Philosophy:
///   • Gradient background (lavender → blush pink → soft mint) is the hero.
///   • Surfaces use semi-transparent white so the gradient bleeds through —
///     cards feel like frosted glass, not flat white blocks.
///   • Accent is rose/blush (#F43F5E) — pulled from the gradient's pink stop;
///     NOT purple, which clashes with the light pastel background.
///   • Nav tray is neutral dark slate (no purple tint) so it reads as a clean
///     ground beneath the colourful content above.
enum BlipColor {

    // MARK: - Gradient background

    /// Root-screen gradient: soft lavender → blush pink → pale mint.
    static let backgroundGradient = LinearGradient(
        stops: [
            .init(color: Color(hex: 0xEDE9FE), location: 0.00),  // lavender-100
            .init(color: Color(hex: 0xFCE7F3), location: 0.50),  // pink-100
            .init(color: Color(hex: 0xD1FAE5), location: 1.00),  // emerald-100
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Surfaces (glassmorphism — white at partial opacity)

    /// Flat fallback for sheets / secondary screens that can't show the gradient.
    static let background = Color(hex: 0xF6F0FF)

    /// Card / row surface — semi-transparent white gives a frosted-glass look
    /// when layered over the gradient background.
    static let surface = Color.white.opacity(0.82)

    /// Elevated surface (sheet headers, popover cards).
    static let surfaceElevated = Color.white.opacity(0.92)

    /// Hairline border — very light, glass-feel.
    static let border = Color.black.opacity(0.07)

    // MARK: - Bottom navigation (always dark, neutral slate — no purple tint)

    /// Dark slate tray behind the tab icons. Neutral, not purple.
    static let navBackground         = Color(hex: 0x111827)   // gray-900
    static let navForeground         = Color.white
    static let navForegroundInactive = Color.white.opacity(0.40)
    /// Active tab pill — soft white glow instead of coloured highlight.
    static let navPill               = Color.white.opacity(0.14)

    // MARK: - Type

    static let textPrimary   = Color(hex: 0x111827)   // gray-900 — warm, readable
    static let textSecondary = Color(hex: 0x6B7280)   // gray-500
    static let textTertiary  = Color(hex: 0xA1A6B0)   // gray-400

    // MARK: - Accent  (rose / blush — pulled from the gradient's pink stop)
    //
    // Why not purple?  The gradient already has a lavender/violet tone in its
    // lightest stop.  Putting a heavy violet CTA on top creates a muddy clash.
    // Rose is distinct, modern, and directly references the gradient's pink mid.

    /// Semantic accent — recording dot, progress fill, active indicators.
    static let accent          = Color(hex: 0xFB7185)   // rose-400
    /// Primary CTA fill — buttons, FAB, camera bubble.
    static let accentNeutral   = Color(hex: 0xF43F5E)   // rose-500
    /// Foreground on top of accentNeutral.
    static let accentNeutralOn = Color.white

    // MARK: - Semantic / fixed

    static let blackCell   = Color.black
    static let onMedia     = Color.white
    static let mediaBackdrop = Color.black
    static let touchProxy  = Color.black.opacity(0.001)

    /// Error — slightly cooled red so it doesn't clash with the rose accent.
    static let error = Color(hex: 0xEF4444)

    // MARK: - Progress ring

    static let progressTrack = Color.black.opacity(0.06)
    static let progressFill  = accent

    // MARK: - Card palette (vibrant but gradient-harmonious)
    //
    // Removed the two heavy violet/purple cards; replaced with rose + teal
    // which sit naturally in the lavender-pink-mint gradient family.

    static let cardPalette: [Color] = [
        Color(hex: 0xDB2777),   // pink-600
        Color(hex: 0xF43F5E),   // rose-500
        Color(hex: 0x2563EB),   // blue-600
        Color(hex: 0x059669),   // emerald-600
        Color(hex: 0x0891B2),   // cyan-600
        Color(hex: 0xD97706),   // amber-600
    ]

    // MARK: - Glassmorphism helper

    /// Semi-transparent white for overlays and frosted-glass effects.
    /// Use `glassWhite(opacity:)` rather than `.white.opacity(n)` directly
    /// so we can tune all glass surfaces from one place.
    static func glassWhite(_ opacity: Double = 0.72) -> Color {
        Color.white.opacity(opacity)
    }

    // MARK: - Hex convenience

    static func hex(_ value: UInt32) -> Color { Color(hex: value) }
}

// MARK: - Color + UIColor hex init

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >>  8) & 0xFF) / 255
        let b = Double( hex        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >>  8) & 0xFF) / 255
        let b = CGFloat( hex        & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
