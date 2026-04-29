import SwiftUI

/// Screen-02 parity — small popover anchored top-right with create/join options.
struct PlusPopover: View {
    let onCreate: () -> Void
    let onJoin: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(alignment: .leading, spacing: 0) {
                Button(action: onCreate) {
                    Text("create a blip")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }
                Divider().background(BlipColor.border)
                Button(action: onJoin) {
                    Text("join a blip")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                }
            }
            .font(BlipTypography.body)
            .foregroundStyle(BlipColor.textPrimary)
            .frame(width: 180)
            .background(BlipColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.top, 56)
            .padding(.trailing, 16)
            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
        }
    }
}

#Preview {
    ZStack {
        BlipColor.background.ignoresSafeArea()
        PlusPopover(onCreate: {}, onJoin: {}, onDismiss: {})
    }
}
