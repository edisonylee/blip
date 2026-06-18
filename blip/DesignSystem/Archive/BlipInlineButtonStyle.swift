import SwiftUI

/// Compact inline action button — sits next to a row's content, not a full
/// width CTA. Use on rows that present a binary choice (accept/ignore,
/// approve/dismiss, etc.) where the full-width `BlipPrimary` is overkill.
///
/// `BlipInlineFilledButtonStyle` is the primary action; `BlipInlineGhostButtonStyle`
/// is the secondary. Both clear the 44pt min-tap requirement.
struct BlipInlineFilledButtonStyle: ButtonStyle {
    private static let fontSize: CGFloat = 13
    private static let horizontalPadding: CGFloat = 14
    private static let minTap: CGFloat = 44
    private static let cornerRadius: CGFloat = 8

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.blip(size: Self.fontSize, weight: .semibold))
            .foregroundStyle(BlipColor.accentNeutralOn)
            .padding(.horizontal, Self.horizontalPadding)
            .frame(minWidth: Self.minTap, minHeight: Self.minTap)
            .background(
                BlipColor.accentNeutral,
                in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct BlipInlineGhostButtonStyle: ButtonStyle {
    private static let fontSize: CGFloat = 13
    private static let horizontalPadding: CGFloat = 14
    private static let minTap: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.blip(size: Self.fontSize, weight: .medium))
            .foregroundStyle(BlipColor.textSecondary)
            .padding(.horizontal, Self.horizontalPadding)
            .frame(minWidth: Self.minTap, minHeight: Self.minTap)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
