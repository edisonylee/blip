import SwiftUI

// MARK: - Button styles

/// Full-width neutral CTA — white-on-black in dark, inverse in light.
/// Contrast (not hue) carries the primary action.
struct BlipPrimaryButtonStyle: ButtonStyle {
    var isLoading = false

    private static let cornerRadius: CGFloat = 10
    private static let height: CGFloat = 52

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            configuration.label
                .font(.blip(size: 16, weight: .semibold))
                .tracking(-0.2)
                .foregroundStyle(BlipColor.accentNeutralOn)
                .opacity(isLoading ? 0 : 1)
            if isLoading {
                ProgressView().tint(BlipColor.accentNeutralOn)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
        .background(
            BlipColor.accentNeutral,
            in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
        )
        .scaleEffect(configuration.isPressed ? 0.97 : 1)
        .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

/// Full-width surface-tinted secondary action.
struct BlipSecondaryButtonStyle: ButtonStyle {

    private static let cornerRadius: CGFloat = 10
    private static let height: CGFloat = 52

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.blip(size: 16, weight: .medium))
            .tracking(-0.2)
            .foregroundStyle(BlipColor.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: Self.height)
            .background(
                BlipColor.surface,
                in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .stroke(BlipColor.border, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

/// Plain text link style — for low-priority actions (e.g. "Resend code").
struct BlipGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.blip(size: 14))
            .foregroundStyle(BlipColor.textTertiary)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - Convenience modifiers

extension Button {
    func blipPrimary(isLoading: Bool = false) -> some View {
        self.buttonStyle(BlipPrimaryButtonStyle(isLoading: isLoading))
    }

    func blipSecondary() -> some View {
        self.buttonStyle(BlipSecondaryButtonStyle())
    }

    func blipGhost() -> some View {
        self.buttonStyle(BlipGhostButtonStyle())
    }
}
