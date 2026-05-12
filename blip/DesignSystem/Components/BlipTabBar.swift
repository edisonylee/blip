import SwiftUI

struct BlipTabBar: View {
    enum Tab { case camera, home, profile }

    @Binding var selection: Tab

    private static let height:    CGFloat = 56
    private static let iconSize:  CGFloat = 22
    private static let borderWidth: CGFloat = 0.5

    var body: some View {
        VStack(spacing: 0) {
            Color(white: 0x44 / 255.0)
                .frame(height: Self.borderWidth)

            HStack {
                Spacer()
                tabButton(.camera, asset: "icon.camera")
                Spacer()
                tabButton(.home,   asset: "icon.home")
                Spacer()
                tabButton(.profile, asset: "icon.profile")
                Spacer()
            }
            .frame(height: Self.height)
            .background(BlipColor.background)
        }
    }

    @ViewBuilder
    private func tabButton(_ tab: Tab, asset: String) -> some View {
        let isActive = selection == tab
        Button { selection = tab } label: {
            Image(asset)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: Self.iconSize, height: Self.iconSize)
                .foregroundStyle(Color.white)
                .frame(width: BlipSpacing.tapTarget, height: BlipSpacing.tapTarget)
                .background(
                    isActive ? AnyShapeStyle(BlipColor.surface) : AnyShapeStyle(Color.clear),
                    in: RoundedRectangle(cornerRadius: BlipRadius.button, style: .continuous)
                )
        }
        .buttonStyle(_TabButtonStyle())
    }
}

private struct _TabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? BlipMotion.pressScaleControl : 1)
            .animation(BlipMotion.spring, value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        BlipHomeHeader(onPlus: {}, onBell: {})
            .padding(.top, BlipSpacing.sm)
            .padding(.bottom, BlipSpacing.lg)

        ScrollView {
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
            .padding(.horizontal, BlipSpacing.lg)
        }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
        BlipTabBar(selection: .constant(.home))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(BlipColor.background)
    .preferredColorScheme(.dark)
}
