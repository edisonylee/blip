import SwiftUI

// MARK: - Card view

/// Rounded-rect card for a single blip group.
///
/// Layout (68 pt tall):
///   Row 1 — live dot · group name (bold) · member count
///   Row 2 — up to 4 overlapping avatar circles + "+N" overflow chip
///
/// Each avatar shows the member's profile photo when a URL is supplied;
/// falls back to their two-letter initials on a tinted background.
struct BlipCard: View {
    let title:     String
    let cardColor: Color
    let members:   [BlipCardMember]
    /// Pass true when the blip's active recording window is currently open.
    var isActive: Bool = false

    private static let cardHeight:  CGFloat = 68
    private static let avatarSize:  CGFloat = 26   // circle diameter
    private static let maxVisible:  Int     = 4    // 4 photos + 1 overflow = 5 total

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            // ── Row 1: live dot + name + member count ─────────────────
            HStack(spacing: 0) {
                // Active "LIVE" dot
                if isActive {
                    Circle()
                        .fill(Color(red: 0.2, green: 0.85, blue: 0.45))
                        .frame(width: 7, height: 7)
                        .padding(.trailing, 6)
                        .shadow(color: Color(red: 0.2, green: 0.85, blue: 0.45).opacity(0.6),
                                radius: 4, x: 0, y: 0)
                }

                Text(title)
                    .font(BlipTypography.cardTitle)
                    .tracking(BlipTypography.titleTracking)
                    .foregroundStyle(BlipColor.onMedia)
                    .lineLimit(1)

                Spacer(minLength: 6)

                // Member count chip
                Text("\(members.count) \(members.count == 1 ? "member" : "members")")
                    .font(.blip(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .lineLimit(1)
            }

            // ── Row 2: overlapping member avatar circles ───────────────
            memberRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Self.cardHeight)
        // ZStack can't be used as a ShapeStyle — apply base colour, then
        // overlay the gradient separately both clipped to the same shape.
        .background(cardColor,
                    in: RoundedRectangle(cornerRadius: BlipRadius.md, style: .continuous))
        .overlay(
            LinearGradient(
                colors: [Color.white.opacity(0.12), Color.clear],
                startPoint: .topLeading,
                endPoint: .center
            )
            .clipShape(RoundedRectangle(cornerRadius: BlipRadius.md, style: .continuous))
        )
        .shadow(color: cardColor.opacity(0.35), radius: 8, x: 0, y: 3)
    }

    // MARK: - Member avatar row

    @ViewBuilder
    private var memberRow: some View {
        if members.isEmpty {
            EmptyView()
        } else {
            let visible  = Array(members.prefix(Self.maxVisible))
            let overflow = members.count - visible.count

            HStack(spacing: -(Self.avatarSize * 0.32)) {
                ForEach(visible) { member in
                    MemberAvatarCircle(
                        member: member,
                        size: Self.avatarSize,
                        strokeColor: cardColor
                    )
                }

                if overflow > 0 {
                    // "+N" overflow chip
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.25))
                            .overlay(Circle().stroke(cardColor, lineWidth: 1.5))
                        Text("+\(overflow)")
                            .font(.system(size: Self.avatarSize * 0.38, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: Self.avatarSize, height: Self.avatarSize)
                }
            }
        }
    }
}

// MARK: - Member avatar circle

/// Single avatar: shows profile photo when available, initials otherwise.
private struct MemberAvatarCircle: View {
    let member: BlipCardMember
    let size: CGFloat
    let strokeColor: Color

    var body: some View {
        ZStack {
            // Background fill — a subtle white tint so initials are readable
            Circle().fill(Color.white.opacity(0.18))

            if let url = member.photoURL {
                CachedAsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        initialsView
                    }
                }
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(strokeColor, lineWidth: 1.5))
    }

    private var initialsView: some View {
        Text(member.initials)
            .font(.system(size: size * 0.38, weight: .bold))
            .foregroundStyle(Color.white)
    }
}

// MARK: - Data model

struct BlipCardMember: Identifiable {
    let id:       String      // uid
    let initials: String      // 1–2 uppercase letters
    var photoURL: URL? = nil  // nil → show initials
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        BlipCard(
            title: "bestfriends",
            cardColor: BlipColor.cardPalette[0],
            members: [
                .init(id: "1", initials: "AB"),
                .init(id: "2", initials: "CD"),
                .init(id: "3", initials: "EF"),
                .init(id: "4", initials: "GH"),
                .init(id: "5", initials: "IJ"),
                .init(id: "6", initials: "KL"),
            ],
            isActive: true
        )
        BlipCard(
            title: "roommates",
            cardColor: BlipColor.cardPalette[1],
            members: [
                .init(id: "1", initials: "QR"),
                .init(id: "2", initials: "ST"),
            ],
            isActive: false
        )
        BlipCard(
            title: "cs study group — a very long name that truncates",
            cardColor: BlipColor.cardPalette[2],
            members: [.init(id: "1", initials: "XY")],
            isActive: true
        )
    }
    .padding(20)
    .background(BlipColor.backgroundGradient)
}
