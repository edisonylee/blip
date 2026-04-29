import SwiftUI
import UIKit

/// Adaptive color tokens. Every value responds automatically to light / dark mode
/// (driven by `.preferredColorScheme` at the app root via `ThemeManager`).
///
/// Dark palette:  warm near-black surfaces, cream type, single amber accent.
/// Light palette: warm cream surfaces, near-black type, same amber accent.
enum BlipColor {

    // MARK: - Surfaces

    /// App background — near-black in dark, warm cream in light.
    static let background = adaptive(
        dark:  0x0A0908,
        light: 0xF5F0EB
    )

    /// Card / list row surface.
    static let surface = adaptive(
        dark:  0x16130F,
        light: 0xEDEAE4
    )

    /// Elevated surface (sheets, popovers).
    static let surfaceElevated = adaptive(
        dark:  0x1F1A14,
        light: 0xE5E0D8
    )

    static let border = Color(uiColor: UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.06)
            : UIColor.black.withAlphaComponent(0.08)
    })

    // MARK: - Type

    static let textPrimary = adaptive(
        dark:  0xF7F2EB,
        light: 0x1A1512
    )

    static let textSecondary = adaptive(
        dark:  0xB8AD9E,
        light: 0x4A453F
    )

    static let textTertiary = adaptive(
        dark:  0x73695E,
        light: 0x847E78
    )

    // MARK: - Accent (same hue both modes — amber reads on both backgrounds)

    /// Single warm-amber accent. Use **once per screen** — guides the eye to the
    /// one moment that matters (record, send, stitch). Per mood-principles §6.
    static let accent = Color(red: 0.91, green: 0.66, blue: 0.49)   // #E8A87C

    // MARK: - Semantic states

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
