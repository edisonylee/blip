import SwiftUI

/// Large circular profile avatar — used on `ProfileView` (own profile) and
/// extensible to other-user profile screens.
///
/// Renders `photoURL` via `AsyncImage` when present and falls back to a
/// monogrammed initial circle (matching `AvatarView`'s palette) while the
/// image loads or when no URL is set. An optional camera-badge overlay marks
/// the avatar as tap-to-edit on the signed-in user's own profile.
///
/// No fixed height — the caller frames it. `size` controls only the diameter
/// of the rendered avatar; outer padding is the call site's job.
struct ProfileAvatarView: View {

    let photoURL: URL?
    let initials: String
    var size: CGFloat = 120
    var isEditable: Bool = false
    /// SF Symbol name used for the badge overlay when `isEditable` is true.
    /// Defaults to "camera.fill"; pass "qrcode" on the profile page avatar.
    var badgeIcon: String = "camera.fill"

    // MARK: - Layout constants

    private static let strokeWidth: CGFloat = 2
    private static let badgeRatio: CGFloat = 0.28
    private static let badgeIconRatio: CGFloat = 0.45

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            avatar
            if isEditable {
                cameraBadge
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var avatar: some View {
        ZStack {
            Circle().fill(BlipColor.surfaceElevated)

            if let photoURL {
                CachedAsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty, .failure:
                        initialFallback
                    @unknown default:
                        initialFallback
                    }
                }
            } else {
                initialFallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(BlipColor.border, lineWidth: Self.strokeWidth))
    }

    private var initialFallback: some View {
        Text(initials)
            .font(.blip(size: size * 0.36, weight: .semibold))
            .foregroundStyle(BlipColor.textSecondary)
    }

    private var cameraBadge: some View {
        let badgeSize = size * Self.badgeRatio
        return ZStack {
            Circle()
                .fill(BlipColor.accentNeutral)
                .overlay(Circle().stroke(BlipColor.background, lineWidth: Self.strokeWidth))
            Image(systemName: badgeIcon)
                .font(.system(size: badgeSize * Self.badgeIconRatio, weight: .semibold))
                .foregroundStyle(BlipColor.accentNeutralOn)
        }
        .frame(width: badgeSize, height: badgeSize)
    }
}

#Preview {
    VStack(spacing: 24) {
        ProfileAvatarView(photoURL: nil, initials: "E", isEditable: true)
        ProfileAvatarView(photoURL: nil, initials: "BL", size: 64)
    }
    .padding()
    .background(BlipColor.background)
}
