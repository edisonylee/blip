import SwiftUI

enum BlipTypography {
    // typography
    private enum Face {
        static let light    = "Manrope-Light"
        static let regular  = "Manrope-Regular"
        static let medium   = "Manrope-Medium"
        static let semibold = "Manrope-SemiBold"
        static let bold     = "Manrope-Bold"
        static let black    = "Judson-Bold"
    }

    // font size
    private enum BlipFontSize {
        static let sm: CGFloat = 13    // captions
        static let md: CGFloat = 16
        static let lg: CGFloat = 20    // card headings
        static let xl: CGFloat = 36    // header, buttons

        static let timestamp: CGFloat = 36  // clip overlay
        static let wordmark:  CGFloat = 36  // export end card only
    }

    static let title     = Font.custom(Face.black,    size: BlipFontSize.xl)
    static let medium    = Font.custom(Face.semibold,   size: BlipFontSize.md)
    static let body      = Font.custom(Face.semibold,   size: BlipFontSize.lg)
    static let cardTitle = Font.custom(Face.bold, size: BlipFontSize.lg)
    static let caption   = Font.custom(Face.semibold,   size: BlipFontSize.sm)
    static let wordmark  = Font.custom(Face.black,    size: BlipFontSize.xl)
    static let iconButton = Font.custom(Face.medium, size: 24)

    /// Tracking applied at call sites for titles / card headings.
    /// Use as: `Text(...).font(BlipTypography.title).tracking(BlipTypography.titleTracking)`
    static let titleTracking: CGFloat = -0.2

    /// Hour timestamps that overlay clips center-of-frame.
    /// Judson Bold + tabular figures so "5:00 PM" / "12:00 AM" align cleanly.
    static let clipTimestamp = Font.custom(Face.black, size: BlipFontSize.xl).monospacedDigit()

    /// Companion font for the AM/PM suffix on clip overlays.
    static let clipTimestampSuffix = Font.custom(Face.black, size: BlipFontSize.xl)

    /// Smaller hour label used for archive rows + countdown.
    static let timeLabel = Font.custom(Face.semibold, size: BlipFontSize.lg).monospacedDigit()

    /// Map a SwiftUI `Font.Weight` onto the bundled Manrope/Judson PostScript faces.
    /// Used internally by the `Font.blip(...)` helper so call sites can keep
    /// the same shape as the old `Font.system(size:weight:)` calls.

    fileprivate static func customFace(for weight: Font.Weight) -> String {
        switch weight {
        case .ultraLight, .thin, .light:    return Face.light
        case .regular:                      return Face.regular
        case .medium:                       return Face.medium
        case .semibold:                     return Face.semibold
        case .bold:                         return Face.bold
        case .heavy, .black:                return Face.black
        default:                            return Face.regular
        }
    }
}

/// Drop-in replacement for `Font.system(size:weight:design:)` that resolves to
/// the bundled custom font family. Behaves identically at call sites — pass `.bold`,
/// `.semibold`, etc. — but a single rebuild ships a coherent typographic system.
///
/// `.monospaced` and `.rounded` designs have no custom font equivalent (only the
/// basic family is bundled), so they fall back to the SF system variant.

extension Font {
    static func blip(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> Font {
        switch design {
        case .monospaced, .rounded:
            return .system(size: size, weight: weight, design: design)
        default:
            return .custom(BlipTypography.customFace(for: weight), size: size)
        }
    }
}
