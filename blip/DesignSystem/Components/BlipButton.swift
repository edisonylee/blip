import SwiftUI

// MARK: - Button styles

/// Full-width primary CTA. Uses `accentNeutral` fill so contrast — not hue —
/// signals importance. Supports an in-place loading spinner that swaps out the
/// label without reflowing the layout.
struct BlipPrimaryButtonStyle: ButtonStyle {
    var isLoading = false

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            configuration.label
                .font(BlipTypography.body)
                .tracking(BlipTypography.titleTracking)
                .foregroundStyle(BlipColor.accentNeutralOn)
                .opacity(isLoading ? 0 : 1)
            if isLoading {
                ProgressView().tint(BlipColor.accentNeutralOn)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: BlipSpacing.buttonHeight)
        .background(
            BlipColor.accentNeutral,
            in: RoundedRectangle(cornerRadius: BlipRadius.button, style: .continuous)
        )
        .scaleEffect(configuration.isPressed ? BlipMotion.pressScaleButton : 1)
        .animation(BlipMotion.spring, value: configuration.isPressed)
    }
}

/// Full-width secondary action. Surface fill with a hairline border keeps it
/// visually distinct from the background without competing with the primary CTA.
struct BlipSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BlipTypography.body)
            .tracking(BlipTypography.titleTracking)
            .foregroundStyle(BlipColor.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: BlipSpacing.buttonHeight)
            .background(
                BlipColor.surface,
                in: RoundedRectangle(cornerRadius: BlipRadius.button, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BlipRadius.button, style: .continuous)
                    .stroke(BlipColor.border, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? BlipMotion.pressScaleButton : 1)
            .animation(BlipMotion.spring, value: configuration.isPressed)
    }
}

/// Minimal text-link style for low-priority actions such as "Forgot password?"
/// or "Resend code". No background — presence comes from position alone.
struct BlipGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(BlipTypography.body)
            .foregroundStyle(BlipColor.textTertiary)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(BlipMotion.spring, value: configuration.isPressed)
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

// MARK: - Icon button

/// Square 44 × 44 icon button for SF Symbol actions.
///
/// `.dark`  — `surface` background, white icon. Use on `background`-colored screens.
/// `.light` — white background, `background`-colored icon. Use on surface/card areas.
struct BlipIconButton: View {
    enum Style { case dark, light, ghost }

    let systemName: String
    let style: Style
    let action: () -> Void

    private var background: Color {
        switch style {
        case .dark:  BlipColor.surface
        case .light: Color.white
        case .ghost: Color.clear
        }
    }

    private var iconColor: Color {
        switch style {
        case .dark:  Color.white
        case .light: BlipColor.background
        case .ghost: BlipColor.textTertiary
        }
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(BlipTypography.body)
                .foregroundStyle(iconColor)
                .frame(width: BlipSpacing.tapTarget, height: BlipSpacing.tapTarget)
                .background(background, in: RoundedRectangle(cornerRadius: BlipRadius.button, style: .continuous))
        }
        .buttonStyle(_IconButtonStyle())
    }
}

// MARK: - Text button

/// Pill-shaped button sized to its text label. Mirrors the primary button's
/// white-on-black contrast — use for inline or floating actions (e.g. "Export",
/// "Share") where a full-width CTA would be too heavy.
struct BlipTextButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(BlipTypography.body)
                .tracking(BlipTypography.titleTracking)
                .foregroundStyle(BlipColor.accentNeutralOn)
                .padding(.horizontal, BlipSpacing.xl)
                .frame(height: BlipSpacing.textButtonHeight)
                .background(
                    BlipColor.accentNeutral,
                    in: RoundedRectangle(cornerRadius: BlipRadius.button, style: .continuous)
                )
        }
        .buttonStyle(_IconButtonStyle())
    }
}

/// Shared spring-scale press feedback. Private so it can't leak into
/// unrelated button hierarchies.
private struct _IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? BlipMotion.pressScaleControl : 1)
            .animation(BlipMotion.spring, value: configuration.isPressed)
            .contentShape(Rectangle())  // ensures the full frame is hittable
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: BlipSpacing.sm) {
        Button("Create Blip") {}.blipPrimary()
        HStack(spacing: BlipSpacing.sm) {
            BlipTextButton(title: "Export") {}
            BlipIconButton(systemName: "plus",  style: .light) {}
            BlipIconButton(systemName: "bell",  style: .dark)  {}
            BlipIconButton(systemName: "xmark", style: .dark)  {}
            BlipIconButton(systemName: "ellipsis", style: .ghost) {}
        }

        
    }
    .padding(BlipSpacing.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(BlipColor.background)
    .preferredColorScheme(.dark)
}
