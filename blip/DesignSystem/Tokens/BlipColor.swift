import SwiftUI
import UIKit

/// Design-system color tokens — light-only pastel theme.
/// Dark mode is not supported in this branch; all values are fixed
/// (the `adaptive()` helper is kept for the border/progress tokens that
/// do check OS style, but the theme is always forced to `.light` in `blipApp`).
enum BlipColor {

    // MARK: - Surfaces

    /// Main screen background — soft lavender used as the flat fallback
    /// in sheets and secondary screens. Primary screens use `backgroundGradient`.
    static let background = Color(hex: 0xF6F0FF)

    /// Card / list-row surface.
    static let surface = Color.white

    /// Elevated surface (sheets, popovers, picker cards).
    static let surfaceElevated = Color(hex: 0xFAF8FF)

    /// Hairline border / divider. Very light violet tint.
    static let border = Color(hex: 0xDDD6FE).opacity(0.7)

    // MARK: - Gradient background

    /// Multi-stop gradient applied to the root content area of main screens.
    /// Lavender → blush pink → soft mint — replicates the dreamy pastel look
    /// in the design reference.
    static let backgroundGradient = LinearGradient(
        stops: [
            .init(color: Color(hex: 0xEDE9FE), location: 0.00),   // violet-100
            .init(color: Color(hex: 0xFCE7F3), location: 0.50),   // pink-100
            .init(color: Color(hex: 0xD1FAE5), location: 1.00),   // emerald-100
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Navigation bar (always dark, even in light theme)

    /// Solid deep-purple-black used as the SmoothBottomBar tray background.
    /// Kept dark so the white icon/label contrast pops against the pastel screens.
    static let navBackground  = Color(hex: 0x160628)
    static let navForeground  = Color.white
    static let navForegroundInactive = Color.white.opacity(0.38)

    // MARK: - Type

    static let textPrimary   = Color(hex: 0x1E1B4B)   // deep indigo
    static let textSecondary = Color(hex: 0x7C6FA0)   // muted purple-gray
    static let textTertiary  = Color(hex: 0xB0A8C8)   // faded purple

    // MARK: - Accent

    /// Semantic accent — recording dot, progress fill, active-hour indicator.
    static let accent = Color(hex: 0x8B5CF6)           // violet-500

    /// Primary CTA fill — deep violet for buttons and the plus FAB.
    static let accentNeutral   = Color(hex: 0x7C3AED)  // violet-600
    /// Foreground that pairs with `accentNeutral`.
    static let accentNeutralOn = Color.white

    // MARK: - Semantic / fixed

    /// Always-black fill for "no clip posted" grid cells — matches the
    /// stitched export pipeline's black frame for missing footage.
    static let blackCell = Color.black

    /// Fixed white text rendered directly on video content.
    static let onMedia = Color.white

    /// Pure-black backdrop for camera viewfinders and fullscreen media.
    static let mediaBackdrop = Color.black

    /// Near-invisible tap-target catcher.
    static let touchProxy = Color.black.opacity(0.001)

    /// Inline error — warm red readable on both white cards and the gradient.
    static let error = Color(hex: 0xEF4444)

    // MARK: - Progress ring

    static let progressTrack = Color(hex: 0xEDE9FE)   // violet-100
    static let progressFill  = accent

    // MARK: - Card palette

    /// Vibrant, saturated card colors — each blip room gets one, hashed by ID.
    /// Designed to contrast white avatar initials and white title text (`onMedia`).
    static let cardPalette: [Color] = [
        Color(hex: 0x7C3AED),   // violet
        Color(hex: 0xDB2777),   // pink
        Color(hex: 0x2563EB),   // blue
        Color(hex: 0x059669),   // emerald
        Color(hex: 0xD97706),   // amber
        Color(hex: 0x9333EA),   // purple
    ]

    // MARK: - Hex convenience

    static func hex(_ value: UInt32) -> Color { Color(hex: value) }
}

// MARK: - UIColor + Color hex init

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >>  8) & 0xFF) / 255
        let b = Double( hex        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// Keep the private UIColor extension for any code that still constructs
// UIColor(hex:) directly (e.g. AvatarView stroke colors).
extension UIColor {
    convenience init(hex: UInt32) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >>  8) & 0xFF) / 255
        let b = CGFloat( hex        & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
