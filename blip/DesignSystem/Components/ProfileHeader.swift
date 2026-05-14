import SwiftUI

struct ProfileHeader: View {
    let username: String
    let onShareProfile: () -> Void
    let onEditProfile: () -> Void

    var body: some View {
        HStack {
            Text(username)
                .font(BlipTypography.title)
                .foregroundStyle(BlipColor.textPrimary)
            Spacer()
            HStack(spacing: BlipSpacing.sm) {
                BlipIconButton(systemName: "square.and.arrow.up", style: .light, action: onShareProfile)
                BlipIconButton(systemName: "gearshape",           style: .light, action: onEditProfile)
            }
        }
        .padding(.horizontal, BlipSpacing.lg)
        .background(BlipColor.background)
    }
}

#Preview {
    ProfileHeader(username: "eirocw", onShareProfile: {}, onEditProfile: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(BlipColor.background)
        .preferredColorScheme(.dark)
}
