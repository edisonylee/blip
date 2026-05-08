import SwiftUI

struct ProfileHeader: View {
    let username: String
    let onShare: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack {
            Text(username)
                .font(BlipTypography.title)
                .foregroundStyle(BlipColor.textPrimary)
            Spacer()
            HStack(spacing: BlipSpacing.sm) {
                BlipIconButton(systemName: "square.and.arrow.up", style: .dark, action: onShare)
                BlipIconButton(systemName: "gearshape",           style: .dark, action: onSettings)
            }
        }
        .padding(.horizontal, BlipSpacing.lg)
        .background(BlipColor.background)
    }
}

#Preview {
    ProfileHeader(username: "eric", onShare: {}, onSettings: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(BlipColor.background)
        .preferredColorScheme(.dark)
}
