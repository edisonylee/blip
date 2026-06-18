import SwiftUI

// MARK: - Clip card

/// Full-width media card for a single clip in the roommates feed.
/// Placeholder `Color` fills where `AVPlayerLayer` will go.
/// `isOwner` swaps the top-right action: ellipsis for the owner, heart + chat for others.
struct ClipCard: View {
    let username: String
    let hour: Int
    let status: String
    var isOwner: Bool = false

    private static let cardHeight: CGFloat = 200

    var body: some View {
        ZStack {
            BlipColor.surface

            VStack(spacing: BlipSpacing.xxs) {
                ClipTimestampLabel(hour: hour)
                Text(status)
                    .font(BlipTypography.medium)
                    .foregroundStyle(BlipColor.onMedia)
            }

            VStack {
                HStack(alignment: .top) {
                    Text(username)
                        .font(BlipTypography.medium)
                        .foregroundStyle(BlipColor.onMedia)
                    Spacer()
                    if isOwner {
                        Image(systemName: "ellipsis")
                            .font(BlipTypography.medium)
                            .foregroundStyle(BlipColor.onMedia)
                    } else {
                        HStack(spacing: BlipSpacing.sm) {
                            Image(systemName: "heart")
                            Image(systemName: "bubble.right")
                        }
                        .font(BlipTypography.medium)
                        .foregroundStyle(BlipColor.onMedia)
                    }
                }
                .padding(.horizontal, BlipSpacing.lg)
                .padding(.top, BlipSpacing.lg)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: BlipRadius.md, style: .continuous))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: BlipSpacing.sm) {
        ClipCard(username: "eric", hour: 14, status: "working", isOwner: true)
        ClipCard(username: "judson", hour: 14, status: "at the library", isOwner: false)
        ClipCard(username: "maya", hour: 14, status: "morning run", isOwner: false)
    }
    .padding(BlipSpacing.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(BlipColor.background)
    .preferredColorScheme(.dark)
}
