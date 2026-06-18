import SwiftUI

// MARK: - Card view

/// Rounded-rect card for a single blipchat. Background color is caller-supplied
/// so each room can have a distinct identity. Solo blips show a white-on-black
/// avatar; group blips show up to 3 avatars plus an overflow count badge whose stroke matches the
/// card color so the circles read as part of the surface.
struct BlipCard: View {
    let title: String
    let cardColor: Color
    let members: [BlipCardMember]

    private static let cardHeight:       CGFloat = 78
    private static let soloAvatarSize:   CGFloat = 32
    private static let memberAvatarSize: CGFloat = 24

    var body: some View {
        HStack(alignment: .center, spacing: BlipSpacing.sm) {
            Text(title)
                .font(BlipTypography.cardTitle)
                .tracking(BlipTypography.titleTracking)
                .foregroundStyle(BlipColor.onMedia)
                .lineLimit(1)
            Spacer()
            memberCluster
        }
        .padding(.horizontal, BlipSpacing.xl)
        .frame(maxWidth: .infinity)
        .frame(height: Self.cardHeight)
        .background(cardColor, in: RoundedRectangle(cornerRadius: BlipRadius.md, style: .continuous))
    }

    @ViewBuilder
    private var memberCluster: some View {
        // Hide avatars when only admin or single-person (1 member) — caller passes members accordingly.
        if members.count <= 1 {
            EmptyView()
        } else {
            let maxVisible = 3
            let visible = Array(members.prefix(maxVisible))
            let remaining = members.count - visible.count
            HStack(spacing: -Self.memberAvatarSize * 0.25) {
                ForEach(visible) { m in
                    AvatarView(
                        initials: m.initials,
                        size: Self.memberAvatarSize,
                        strokeColor: cardColor,
                        style: .light
                    )
                }
                if remaining > 0 {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.85))
                            .overlay(Circle().stroke(cardColor, lineWidth: BlipSpacing.avatarStroke))
                        Text("+\(remaining)")
                            .font(.blip(size: Self.memberAvatarSize * 0.40, weight: .semibold))
                            .foregroundStyle(.black)
                    }
                    .frame(width: Self.memberAvatarSize, height: Self.memberAvatarSize)
                    .padding(.leading, Self.memberAvatarSize * 0.40)
                }
            }
        }
    }
}

// MARK: - Data

struct BlipCardMember: Identifiable {
    let id: String
    let initials: String
}

// MARK: - Preview

#Preview {
    VStack(spacing: BlipSpacing.sm) {
        BlipCard(
            title: "your vlog",
            cardColor: BlipColor.cardPalette[0],
            members: [.init(id: "1", initials: "EK")]
        )
        BlipCard(
            title: "roommates",
            cardColor: BlipColor.cardPalette[1],
            members: [
                .init(id: "1", initials: "AB"),
                .init(id: "2", initials: "CD"),
                .init(id: "3", initials: "EF"),
            ]
        )
        BlipCard(
            title: "cs study group",
            cardColor: BlipColor.cardPalette[2],
            members: [
                .init(id: "1", initials: "GH"),
                .init(id: "2", initials: "IJ"),
                .init(id: "3", initials: "KL"),
                .init(id: "4", initials: "MN"),
                .init(id: "5", initials: "OP"),
            ]
        )
        BlipCard(
            title: "lorem ipsum dolor sit amet",
            cardColor: BlipColor.cardPalette[3],
            members: [
                .init(id: "1", initials: "QR"),
                .init(id: "2", initials: "ST"),
                .init(id: "3", initials: "UV"),
                .init(id: "4", initials: "WX"),
                .init(id: "5", initials: "YZ"),
            ]
        )
    }
    .padding(BlipSpacing.lg)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(BlipColor.background)
    .preferredColorScheme(.dark)
}
