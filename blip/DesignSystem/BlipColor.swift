import SwiftUI
import UIKit

/// Adaptive color tokens. Every value responds automatically to light / dark mode
/// (driven by `.preferredColorScheme` at the app root via `ThemeManager`).
///
/// Dark palette:  pure black surfaces, neutral cool grays, white primary type.
/// Light palette: warm cream surfaces, near-black type, amber semantic accent.
enum BlipColor {

    // MARK: - Surfaces

    /// App background — pure black in dark, warm cream in light.
    static let background = adaptive(
        dark:  0x000000,
        light: 0xF5F0EB
    )

    /// Card / list row surface.
    static let surface = adaptive(
        dark:  0x0A0A0A,
        light: 0xEDEAE4
    )

    /// Elevated surface (sheets, popovers).
    static let surfaceElevated = adaptive(
        dark:  0x171717,
        light: 0xE5E0D8
    )

    static let border = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.10)
            : UIColor.black.withAlphaComponent(0.08)
    })

    // MARK: - Type

    static let textPrimary = adaptive(
        dark:  0xFAFAFA,
        light: 0x1A1512
    )

    static let textSecondary = adaptive(
        dark:  0xA1A1AA,
        light: 0x4A453F
    )

    static let textTertiary = adaptive(
        dark:  0x52525B,
        light: 0x847E78
    )

    // MARK: - Accent

    /// Warm-amber semantic accent — reserved for live/recording states (progress
    /// fill, active dot). No longer the primary CTA color in dark mode.
    static let accent = Color(red: 0.91, green: 0.66, blue: 0.49)   // #E8A87C

    /// Neutral CTA fill — white in dark, near-black in light. Use for primary
    /// buttons; contrast (not hue) carries the "moment that matters."
    static let accentNeutral = adaptive(
        dark:  0xFFFFFF,
        light: 0x1A1512
    )

    /// Foreground that pairs with `accentNeutral` (inverse of it).
    static let accentNeutralOn = adaptive(
        dark:  0x000000,
        light: 0xF5F0EB
    )

    // MARK: - Semantic states

    /// Always-black fill for "no clip posted" cells in the member grid — matches
    /// the stitched export pipeline's black frame for missing footage.
    static let blackCell = Color.black

    /// Fixed white overlay for text rendered on top of video content.
    /// Not theme-adaptive — video is always dark underneath.
    static let onMedia = Color.white

    /// Pure-black backdrop for camera viewfinders and fullscreen media viewers.
    /// Also the base for partial-coverage scrims drawn over media — apply
    /// `.opacity(...)` for the scrim intensity needed.
    /// Not theme-adaptive: viewfinders and media chrome are always rendered dark.
    static let mediaBackdrop = Color.black

    /// Invisible tap-target catcher. Use to claim taps on an otherwise empty
    /// region without showing a visible surface.
    static let touchProxy = Color.black.opacity(0.001)

    /// Inline error text. Warm rose — readable on both dark and light surfaces.
    static let error = adaptive(
        dark:  0xE87070,
        light: 0xC93535
    )

    // MARK: - Progress ring

    static let progressTrack = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.08)
            : UIColor.black.withAlphaComponent(0.10)
    })

    static let progressFill = accent

    // MARK: - Helpers

    private static func adaptive(dark darkHex: UInt32, light lightHex: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: darkHex)
                : UIColor(hex: lightHex)
        })
    }
}

// MARK: - UIColor hex convenience

private extension UIColor {
    convenience init(hex: UInt32) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >>  8) & 0xFF) / 255
        let b = CGFloat( hex        & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
