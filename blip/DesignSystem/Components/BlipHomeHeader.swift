import SwiftUI

struct BlipHomeHeader: View {
    let onPlus: () -> Void
    let onBell: () -> Void

    var body: some View {
        HStack {
            Text("your blips")
                .font(BlipTypography.title)
                .foregroundStyle(BlipColor.textPrimary)
            Spacer()
            HStack(spacing: BlipSpacing.sm) {
                BlipIconButton(systemName: "plus", style: .light, action: onPlus)
                BlipIconButton(systemName: "bell", style: .light,  action: onBell)
            }
        }
        .padding(.horizontal, BlipSpacing.lg)
        .background(BlipColor.background)
    }
}

#Preview {
    BlipHomeHeader(onPlus: {}, onBell: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(BlipColor.background)
        .preferredColorScheme(.dark)
}
