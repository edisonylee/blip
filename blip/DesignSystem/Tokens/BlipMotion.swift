import SwiftUI

/// Animation and interaction tokens.
/// All press feedback and transitions in the design system pull from here so
/// timing and scale feel consistent across every interactive surface.
enum BlipMotion {

    // MARK: - Press scale

    /// Scale applied to full-width buttons (primary, secondary) on press.
    static let pressScaleButton:  CGFloat = 0.97

    /// Scale applied to compact controls (icon buttons, text buttons) on press.
    static let pressScaleControl: CGFloat = 0.95

    // MARK: - Spring

    /// Standard spring for tap/press feedback — snappy but not jarring.
    static let spring = Animation.spring(duration: 0.2)

    /// Smooth ease-out for state transitions (e.g. focus changes).
    static let easeOut = Animation.easeOut(duration: 0.2)
}
