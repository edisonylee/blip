import SwiftUI

/// Per setlog-research/mood-principles.md principle #4 — time is the typography.
/// Hours, timestamps, countdowns get weight. Everything else gets out of their way.
enum BlipTypography {
    /// Wordmark — used **only at the export's end card**, never in-app chrome
    /// (signature move per mood doc). Onboarding is the one exception, since it's
    /// a pre-app moment that introduces the brand.
    static let wordmark = Font.system(size: 38, weight: .black, design: .rounded)

    static let title = Font.system(size: 22, weight: .semibold, design: .default)
    static let body = Font.system(size: 16, weight: .regular, design: .default)
    static let caption = Font.system(size: 13, weight: .regular, design: .default)

    /// Hour timestamps that overlay clips and labels per-cell in the grid (screen-08).
    /// Editorial weight + tabular figures so 02:00, 13:00, 21:00 align in the grid.
    static let clipTimestamp = Font.system(size: 32, weight: .heavy, design: .default)
        .monospacedDigit()

    /// Smaller hour label used for archive rows + countdown.
    static let timeLabel = Font.system(size: 14, weight: .semibold, design: .default)
        .monospacedDigit()
}
