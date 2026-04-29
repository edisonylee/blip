import SwiftUI

enum BlipTypography {
    /// Wordmark — brand title. Phase D will swap to a custom face.
    static let wordmark = Font.system(size: 34, weight: .heavy, design: .rounded)

    static let title = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let body = Font.system(size: 16, weight: .regular, design: .default)
    static let caption = Font.system(size: 13, weight: .regular, design: .default)

    /// Used for hour timestamps overlaid on clips (matches screen-08 "21:00")
    static let clipTimestamp = Font.system(size: 28, weight: .heavy, design: .rounded)
}
