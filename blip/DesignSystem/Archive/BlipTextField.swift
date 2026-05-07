import SwiftUI

/// Labelled text-entry field with accent-bar left decoration and focus-animated border.
/// Replaces identical inline field chrome in CreateBlipView and JoinBlipView.
struct BlipTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    var font: Font = .blip(size: 20, weight: .semibold)
    var submitLabel: SubmitLabel = .done
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.blip(size: 11, weight: .semibold))
                .foregroundStyle(BlipColor.textTertiary)
                .textCase(.uppercase)
                .tracking(0.8)

            TextField(placeholder, text: $text)
                .focused(isFocused)
                .submitLabel(submitLabel)
                .foregroundStyle(BlipColor.textPrimary)
                .font(font)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { onSubmit?() }
                .padding(16)
                .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            isFocused.wrappedValue ? BlipColor.textPrimary.opacity(0.35) : BlipColor.border,
                            lineWidth: 1
                        )
                )
            .animation(.easeOut(duration: 0.2), value: isFocused.wrappedValue)
        }
    }
}
