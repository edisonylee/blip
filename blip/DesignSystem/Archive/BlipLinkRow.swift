import SwiftUI

/// List row that reads as "tap to navigate." Title on the left, optional
/// value on the right, chevron after. Use as a `NavigationLink` label or
/// inside a `Button`. Min-height enforces 44pt tap target.
struct BlipLinkRow: View {
    let title: String
    var value: String? = nil

    private static let horizontalPadding: CGFloat = 16
    private static let verticalPadding: CGFloat = 14
    private static let minHeight: CGFloat = 44

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(BlipColor.textPrimary)
            Spacer()
            if let value {
                Text(value)
                    .foregroundStyle(BlipColor.textSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(BlipColor.textTertiary)
        }
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.vertical, Self.verticalPadding)
        .frame(minHeight: Self.minHeight)
        .contentShape(Rectangle())
    }
}
