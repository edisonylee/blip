import SwiftUI

/// Menu card that appears above the centered plus FAB.
/// HomeView owns the full-screen backdrop and positioning; this view is purely
/// the rounded-rect menu content (create / join rows).
struct PlusPopover: View {
    let onCreate: () -> Void
    let onJoin: () -> Void
    let onDismiss: () -> Void
    var canCreate: Bool = true
    var referralsToNextSlot: Int = 4
    var onLockedTap: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if canCreate {
                Button(action: onCreate) {
                    rowLabel(title: "create a blip", subtitle: nil, locked: false)
                }
            } else {
                Button(action: onLockedTap) {
                    rowLabel(
                        title: "create a blip",
                        subtitle: lockedSubtitle,
                        locked: true
                    )
                }
            }
            Divider().background(BlipColor.border)
            Button(action: onJoin) {
                rowLabel(title: "join a blip", subtitle: nil, locked: false)
            }
        }
        .font(BlipTypography.body)
        .foregroundStyle(BlipColor.textPrimary)
        .background(
            BlipColor.surfaceElevated,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .shadow(color: .black.opacity(0.5), radius: 28, x: 0, y: -6)
    }

    // MARK: - Row

    private func rowLabel(title: String, subtitle: String?, locked: Bool) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.blip(size: 12, weight: .semibold))
                            .foregroundStyle(BlipColor.textTertiary)
                    }
                    Text(title)
                        .foregroundStyle(locked ? BlipColor.textSecondary : BlipColor.textPrimary)
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.blip(size: 12))
                        .foregroundStyle(BlipColor.textTertiary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lockedSubtitle: String {
        let n = referralsToNextSlot
        return "\(n) more friend\(n == 1 ? "" : "s") unlocks another"
    }
}

#Preview("Unlocked") {
    ZStack {
        BlipColor.background.ignoresSafeArea()
        VStack {
            Spacer()
            PlusPopover(onCreate: {}, onJoin: {}, onDismiss: {})
                .padding(.horizontal, 20)
                .padding(.bottom, 80)
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Locked") {
    ZStack {
        BlipColor.background.ignoresSafeArea()
        VStack {
            Spacer()
            PlusPopover(
                onCreate: {},
                onJoin: {},
                onDismiss: {},
                canCreate: false,
                referralsToNextSlot: 2,
                onLockedTap: {}
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 80)
        }
    }
    .preferredColorScheme(.dark)
}
