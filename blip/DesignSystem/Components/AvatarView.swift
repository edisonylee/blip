import SwiftUI

/// Small circular avatar for a blip member.
/// `size` controls diameter; `hasPosted` tints amber when the member contributed this hour.
struct AvatarView: View {
    let initials: String
    var hasPosted: Bool = false
    var size: CGFloat = 28
    var overlap: CGFloat = 0  // negative value to stack with overlap

    var body: some View {
        ZStack {
            Circle()
                .fill(hasPosted ? BlipColor.accent.opacity(0.2) : BlipColor.surfaceElevated)
                .overlay(Circle().stroke(BlipColor.background, lineWidth: 1.5))
            Text(initials)
                .font(.blip(size: size * 0.38, weight: .semibold))
                .foregroundStyle(hasPosted ? BlipColor.accent : BlipColor.textTertiary)
        }
        .frame(width: size, height: size)
    }
}

/// Horizontally stacked row of avatars with configurable max visible count.
struct AvatarRow: View {
    let members: [AvatarRowMember]
    var maxVisible: Int = 7
    var size: CGFloat = 26

    var body: some View {
        HStack(spacing: -(size * 0.25)) {
            ForEach(members.prefix(maxVisible)) { m in
                AvatarView(initials: m.initials, hasPosted: m.hasPosted, size: size)
            }
            if members.count > maxVisible {
                Text("+\(members.count - maxVisible)")
                    .font(.blip(size: 10, weight: .semibold))
                    .foregroundStyle(BlipColor.textTertiary)
                    .padding(.leading, size * 0.4)
            }
        }
    }
}

struct AvatarRowMember: Identifiable {
    let id: String
    let initials: String
    let hasPosted: Bool
}

#Preview {
    VStack(spacing: 20) {
        AvatarRow(members: [
            .init(id: "1", initials: "ED", hasPosted: true),
            .init(id: "2", initials: "LJ", hasPosted: true),
            .init(id: "3", initials: "AM", hasPosted: false),
            .init(id: "4", initials: "KR", hasPosted: false),
        ])

        AvatarRow(members: (1...10).map {
            .init(id: "\($0)", initials: "A\($0)", hasPosted: $0 % 2 == 0)
        }, maxVisible: 5)
    }
    .padding()
    .background(BlipColor.mediaBackdrop)
}
