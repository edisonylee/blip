import SwiftUI

struct BlipTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var font: Font = BlipTypography.body
    var submitLabel: SubmitLabel = .done
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: BlipSpacing.xxs) {
            Text(label)
                .font(BlipTypography.caption)
                .foregroundStyle(BlipColor.textPrimary)

            HStack(spacing: BlipSpacing.md) {
                TextField(placeholder, text: $text)
                    .focused(isFocused)
                    .submitLabel(submitLabel)
                    .foregroundStyle(BlipColor.textPrimary)
                    .font(font)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .tint(BlipColor.textPrimary)
                    .onSubmit { onSubmit?() }
            }
            .frame(height: BlipSpacing.tapTarget)
        }
        .padding(BlipSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BlipColor.background, in: RoundedRectangle(cornerRadius: BlipRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BlipRadius.md, style: .continuous)
                .stroke(
                    isFocused.wrappedValue ? BlipColor.textPrimary : BlipColor.textPrimary.opacity(0.35),
                    lineWidth: 1.5
                )
        )
        .animation(BlipMotion.easeOut, value: isFocused.wrappedValue)
    }
}

// MARK: - Preview

private struct _PreviewWrapper: View {
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: BlipSpacing.xl) {
            BlipTextField(
                label: "Blip name",
                placeholder: "Name your Blip",
                text: .constant(""),
                isFocused: $focused
            )
        }
        .padding(BlipSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BlipColor.background)
        .preferredColorScheme(.dark)
        .onTapGesture { focused = false }
    }
}

#Preview { _PreviewWrapper() }
