import SwiftUI

/// Compact stat tile used on profile heros (own + other-user) and any future
/// dashboard surface. Big number on top, small lowercase label below, neutral
/// surface background. Equal-width by default — drop a row of these into an
/// HStack and they share width.
struct BlipStatTile: View {
    let value: String
    let label: String

    private static let cornerRadius: CGFloat = 10
    private static let verticalPadding: CGFloat = 14
    private static let valueSize: CGFloat = 22
    private static let labelSize: CGFloat = 11
    private static let valueTracking: CGFloat = -0.2

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.blip(size: Self.valueSize, weight: .semibold))
                .tracking(Self.valueTracking)
                .foregroundStyle(BlipColor.textPrimary)
            Text(label)
                .font(.blip(size: Self.labelSize, weight: .medium))
                .foregroundStyle(BlipColor.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Self.verticalPadding)
        .background(BlipColor.surfaceElevated, in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
    }
}
