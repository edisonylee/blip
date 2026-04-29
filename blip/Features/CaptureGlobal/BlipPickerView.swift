import SwiftUI

/// Multi-select destination picker for the global capture flow.
/// All rows start unchecked per spec; the bottom CTA shows the running selection count
/// and is disabled until at least one blip is picked.
struct BlipPickerView: View {

    // MARK: - Inputs

    let blips: [Blip]
    @Binding var selected: Set<String>
    let isSending: Bool
    let errorMessage: String?
    let onCancel: () -> Void
    let onSend: () -> Void

    // MARK: - Layout constants

    private static let rowSpacing: CGFloat = 10
    private static let rowPadding: CGFloat = 14
    private static let rowCornerRadius: CGFloat = 12
    private static let avatarSize: CGFloat = 32
    private static let footerVPadding: CGFloat = 16
    private static let listHPadding: CGFloat = 16
    private static let topBarHeight: CGFloat = 44

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                if blips.isEmpty {
                    emptyState
                } else {
                    list
                }
                footer
            }
        }
    }

    // MARK: - Subviews

    private var topBar: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.blip(size: 16, weight: .semibold))
                    .foregroundStyle(BlipColor.textPrimary)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("cancel")
            .disabled(isSending)

            Spacer()

            Text("send to")
                .font(BlipTypography.body)
                .foregroundStyle(BlipColor.textPrimary)

            Spacer()

            // Symmetry placeholder so title stays centered.
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
        .frame(height: Self.topBarHeight)
    }

    private var list: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Self.rowSpacing) {
                ForEach(blips) { blip in
                    Button {
                        toggle(blip.id)
                    } label: {
                        BlipPickerRow(
                            blip: blip,
                            isSelected: selected.contains(blip.id),
                            avatarSize: Self.avatarSize
                        )
                        .padding(Self.rowPadding)
                        .frame(minHeight: 44)
                        .background(
                            BlipColor.surface,
                            in: RoundedRectangle(cornerRadius: Self.rowCornerRadius, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Self.rowCornerRadius, style: .continuous)
                                .stroke(
                                    selected.contains(blip.id) ? BlipColor.textPrimary : BlipColor.border,
                                    lineWidth: selected.contains(blip.id) ? 1.5 : 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSending)
                    .accessibilityLabel("\(blip.name), \(blip.members.count) members")
                    .accessibilityAddTraits(selected.contains(blip.id) ? .isSelected : [])
                }
            }
            .padding(.horizontal, Self.listHPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("no blips yet")
                .font(.blip(size: 18, weight: .semibold))
                .foregroundStyle(BlipColor.textPrimary)
            Text("start a blip to share this clip with friends.")
                .font(BlipTypography.caption)
                .foregroundStyle(BlipColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            ErrorText(message: errorMessage)

            Button(action: onSend) {
                Text(sendLabel)
            }
            .blipPrimary(isLoading: isSending)
            .disabled(selected.isEmpty || isSending)
            .padding(.horizontal, Self.listHPadding)
        }
        .padding(.vertical, Self.footerVPadding)
        .background(BlipColor.background)
    }

    // MARK: - Helpers

    private func toggle(_ blipId: String) {
        if selected.contains(blipId) { selected.remove(blipId) }
        else { selected.insert(blipId) }
    }

    private var sendLabel: String {
        let n = selected.count
        switch n {
        case 0: return "pick a blip"
        case 1: return "send to 1 blip"
        default: return "send to \(n) blips"
        }
    }
}

// MARK: - Row

private struct BlipPickerRow: View {
    let blip: Blip
    let isSelected: Bool
    let avatarSize: CGFloat

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(
                initials: Self.initials(for: blip.name),
                hasPosted: false,
                size: avatarSize
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(blip.name)
                    .font(.blip(size: 16, weight: .medium))
                    .foregroundStyle(BlipColor.textPrimary)
                Text(subtitle)
                    .font(.blip(size: 12))
                    .foregroundStyle(BlipColor.textTertiary)
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.blip(size: 22))
                .foregroundStyle(isSelected ? BlipColor.textPrimary : BlipColor.textTertiary)
        }
    }

    private var subtitle: String {
        let count = blip.members.count
        return count == 1 ? "1 member" : "\(count) members"
    }

    private static func initials(for name: String) -> String {
        let words = name.split(separator: " ")
        let letters = words.prefix(2).compactMap { $0.first }
        let result = String(letters).uppercased()
        return result.isEmpty ? "?" : result
    }
}
