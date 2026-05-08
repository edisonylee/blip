import SwiftUI

struct CreateHeader: View {
    let onDismiss: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        HStack {
            Text("new blip")
                .font(BlipTypography.title)
                .foregroundStyle(BlipColor.textPrimary)
            Spacer()
            HStack(spacing: BlipSpacing.sm) {
                BlipIconButton(systemName: "xmark",     style: .ghost, action: onDismiss)
                BlipIconButton(systemName: "checkmark", style: .light, action: onConfirm)
            }
        }
        .padding(.horizontal, BlipSpacing.lg)
        .background(BlipColor.background)
    }
}

#Preview {
    CreateHeader(onDismiss: {}, onConfirm: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(BlipColor.background)
        .preferredColorScheme(.dark)
}
