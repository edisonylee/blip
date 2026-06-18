import SwiftUI

/// Small circular avatar for a blip member.
/// `size` controls diameter; `hasPosted` tints amber when the member contributed this hour.
struct AvatarView: View {

    /// `.standard` — dark surface, tinted on `hasPosted`. Default for list/row use.
    /// `.light`    — white fill, black text. Use on colored card backgrounds.
    enum Style { case standard, light }

    let initials: String
    var hasPosted: Bool = false
    var size: CGFloat = 28
    var overlap: CGFloat = 0  // negative value to stack with overlap
    var strokeColor: Color = BlipColor.background
    var style: Style = .standard

    private static let fontRatio: CGFloat = 0.38

    private var fillColor: Color {
        switch style {
        case .standard: hasPosted ? BlipColor.accent.opacity(0.05) : BlipColor.surfaceElevated
        case .light:    .white
        }
    }

    private var textColor: Color {
        switch style {
        case .standard: hasPosted ? BlipColor.accent : BlipColor.textTertiary
        case .light:    .black
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(fillColor)
                .overlay(Circle().stroke(strokeColor, lineWidth: BlipSpacing.avatarStroke))
            Text(initials)
                .font(.blip(size: size * Self.fontRatio, weight: .semibold))
                .foregroundStyle(textColor)
        }
        .frame(width: size, height: size)
    }
}

/// Horizontally stacked row of avatars with configurable max visible count.
struct AvatarRow: View {
    let members: [AvatarRowMember]
    var maxVisible: Int = 7
    var size: CGFloat = 26
    var strokeColor: Color = BlipColor.background

    private static let overlapRatio:       CGFloat = 0.25
    private static let overflowLeadRatio:  CGFloat = 0.40
    private static let overflowFontRatio:  CGFloat = 0.38

    var body: some View {
        HStack(spacing: -(size * Self.overlapRatio)) {
            ForEach(members.prefix(maxVisible)) { m in
                AvatarView(initials: m.initials, hasPosted: m.hasPosted, size: size, strokeColor: strokeColor)
            }
            if members.count > maxVisible {
                Text("+\(members.count - maxVisible)")
                    .font(.blip(size: size * Self.overflowFontRatio, weight: .semibold))
                    .foregroundStyle(BlipColor.textTertiary)
                    .padding(.leading, size * Self.overflowLeadRatio)
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
