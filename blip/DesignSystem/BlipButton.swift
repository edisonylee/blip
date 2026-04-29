import SwiftUI

// MARK: - Button styles

/// Full-width amber CTA. Use once per screen.
struct BlipPrimaryButtonStyle: ButtonStyle {
    var isLoading = false

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            configuration.label
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.black)
                .opacity(isLoading ? 0 : 1)
            if isLoading {
                ProgressView().tint(.black)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(BlipColor.accent)
        .clipShape(Capsule())
        .scaleEffect(configuration.isPressed ? 0.97 : 1)
        .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

/// Full-width surface-tinted secondary action.
struct BlipSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(BlipColor.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(BlipColor.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(BlipColor.border, lineWidth: 0.5))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

/// Plain text link style — for low-priority actions (e.g. "Resend code").
struct BlipGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14))
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
