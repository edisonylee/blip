import SwiftUI

/// Per setlog-research/mood-principles.md principle #4 — time is the typography.
/// Hours, timestamps, countdowns get weight. Everything else gets out of their way.
///
/// All in-app chrome resolves to Geist (bundled via `project.yml` UIAppFonts).
/// Use these tokens — never `Font.system(...)` inline — so a face swap stays
/// one-file-change.
enum BlipTypography {
    /// PostScript names for the bundled Geist faces. Keep in lockstep with
    /// `project.yml` UIAppFonts entries — if a name here doesn't match the
    /// PostScript name in the .otf, SwiftUI silently falls back to SF.
    private enum Face {
        static let light    = "Geist-Light"
        static let regular  = "Geist-Regular"
        static let medium   = "Geist-Medium"
        static let semibold = "Geist-SemiBold"
        static let bold     = "Geist-Bold"
        static let black    = "Geist-Black"
    }

    /// Wordmark — used **only at the export's end card**, never in-app chrome
    /// (signature move per mood doc). Onboarding is the one exception, since it's
    /// a pre-app moment that introduces the brand.
    static let wordmark = Font.custom(Face.black, size: 38)

    static let title   = Font.custom(Face.semibold, size: 22)
    static let body    = Font.custom(Face.regular, size: 16)
    static let caption = Font.custom(Face.regular, size: 13)

    /// Geist-style tracking applied at call sites for titles / 18pt card headings.
    /// Use as: `Text(...).font(BlipTypography.title).tracking(BlipTypography.titleTracking)`
    static let titleTracking: CGFloat = -0.2

    /// Hour timestamps that overlay clips center-of-frame.
    /// Skinny Geist Light + tabular figures so "5:00 PM" / "12:00 AM" align cleanly.
    static let clipTimestamp = Font.custom(Face.light, size: 32).monospacedDigit()

    /// Companion font for the AM/PM suffix on clip overlays — visibly smaller
    /// and lighter than the digits so the overlay reads as time without
    /// dominating the frame.
    static let clipTimestampSuffix = Font.custom(Face.light, size: 13)

    /// Smaller hour label used for archive rows + countdown.
    static let timeLabel = Font.custom(Face.semibold, size: 14).monospacedDigit()

    /// Map a SwiftUI `Font.Weight` onto the bundled Geist PostScript faces.
    /// Used internally by the `Font.blip(...)` helper so call sites can keep
    /// the same shape as the old `Font.system(size:weight:)` calls.
    fileprivate static func geistFace(for weight: Font.Weight) -> String {
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
/// the bundled Geist family. Behaves identically at call sites — pass `.bold`,
/// `.semibold`, etc. — but a single rebuild ships a coherent typographic system.
///
/// `.monospaced` and `.rounded` designs have no Geist equivalent (only the
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
            return .custom(BlipTypography.geistFace(for: weight), size: size)
        }
    }
}
