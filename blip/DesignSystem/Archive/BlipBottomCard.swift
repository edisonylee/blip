import SwiftUI

/// Slot card used at the foot of `ProfileView` for stats that need more
/// breathing room than `BlipStatTile` (rank, current streak). Icon-led,
/// label on top, value below — with an optional locked state that swaps the
/// value for a lock glyph and a "Locked" hint.
///
/// No fixed height — drop two of these in an HStack and they'll share width
/// and grow to fit their content.
struct BlipBottomCard: View {
    let icon: String
    let label: String
    let value: String?
    let isLocked: Bool

    init(icon: String, label: String, value: String?, isLocked: Bool = false) {
        self.icon = icon
        self.label = label
        self.value = value
        self.isLocked = isLocked
    }

    // MARK: - Layout constants

    private static let cornerRadius: CGFloat = 14
    private static let contentPadding: CGFloat = 14
    private static let iconSize: CGFloat = 18
    private static let labelSize: CGFloat = 13
    private static let valueSize: CGFloat = 17
    private static let valueTracking: CGFloat = -0.2

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: Self.iconSize, weight: .semibold))
                    .foregroundStyle(iconTint)
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: Self.iconSize * 0.75, weight: .semibold))
                        .foregroundStyle(BlipColor.textTertiary)
                }
                Spacer(minLength: 0)
            }

            Text(label)
                .font(.blip(size: Self.labelSize, weight: .medium))
                .foregroundStyle(BlipColor.textSecondary)
                .lineLimit(1)

            Text(displayValue)
                .font(.blip(size: Self.valueSize, weight: .semibold))
                .tracking(Self.valueTracking)
                .foregroundStyle(isLocked ? BlipColor.textTertiary : BlipColor.textPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Self.contentPadding)
        .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .stroke(BlipColor.border, lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private var iconTint: Color {
        isLocked ? BlipColor.textTertiary : BlipColor.accent
    }

    private var displayValue: String {
        if isLocked { return "Locked" }
        return value ?? "—"
    }
}

#Preview {
    HStack(spacing: 10) {
        BlipBottomCard(icon: "trophy.fill", label: "Rank on Blip", value: nil, isLocked: true)
        BlipBottomCard(icon: "flame.fill", label: "Current Streak", value: "9 days")
    }
    .padding()
    .background(BlipColor.background)
}
