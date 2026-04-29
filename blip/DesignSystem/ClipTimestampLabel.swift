import SwiftUI

/// Centered hour-of-day label that overlays a clip ("5:00 PM"). Renders the
/// digits in Geist Light and the AM/PM suffix visibly smaller so the overlay
/// reads as time without dominating the frame.
struct ClipTimestampLabel: View {
    let hour: Int

    var body: some View {
        let parts = Self.parts(for: hour)
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(parts.digits)
                .font(BlipTypography.clipTimestamp)
            Text(parts.suffix)
                .font(BlipTypography.clipTimestampSuffix)
                .foregroundStyle(.white.opacity(0.85))
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.55), radius: 8, y: 2)
        .allowsHitTesting(false)
    }

    private static func parts(for hour: Int) -> (digits: String, suffix: String) {
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let date = Calendar.current.date(from: components) ?? Date()

        let digitFormatter = DateFormatter()
        digitFormatter.locale = Locale(identifier: "en_US_POSIX")
        digitFormatter.dateFormat = "h:mm"

        let suffixFormatter = DateFormatter()
        suffixFormatter.locale = Locale(identifier: "en_US_POSIX")
        suffixFormatter.dateFormat = "a"

        return (digitFormatter.string(from: date), suffixFormatter.string(from: date))
    }
}

extension ClipTimestampLabel {
    /// Convenience for the live "now" overlay on the review screen.
    static func now(date: Date = Date()) -> ClipTimestampLabel {
        let hour = Calendar.current.component(.hour, from: date)
        return ClipTimestampLabel(hour: hour)
    }
}
