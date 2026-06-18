import SwiftUI

/// Screen-02 parity — small popover anchored top-right with create/join options.
///
/// Create is gated by `unlockedBlipSlots`: every user gets 1 free slot, and
/// each additional slot requires 4 successful referrals (per `BlipUser`).
/// When the user is at the cap, the create row swaps to a locked variant
/// whose tap opens the share sheet — that's the conversion lever.
struct PlusPopover: View {
    let onCreate: () -> Void
    let onJoin: () -> Void
    let onDismiss: () -> Void
    /// `true` when the user can still create (`blips.count < unlockedSlots`).
    /// Default is `true` so existing call sites (and previews) work.
    var canCreate: Bool = true
    /// Friends still needed to unlock the next slot. Only consulted when
    /// `canCreate == false`. Always 1...4.
    var referralsToNextSlot: Int = 4
    /// Fired when the locked create row is tapped — caller opens a share sheet
    /// pre-populated with the user's invite URL.
    var onLockedTap: () -> Void = {}

    var body: some View {
        ZStack(alignment: .topTrailing) {
            BlipColor.touchProxy
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

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
            .frame(width: 220)
            .background(BlipColor.surfaceElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.top, 56)
            .padding(.trailing, 16)
            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
        }
    }

    // MARK: - Subviews

    private func rowLabel(title: String, subtitle: String?, locked: Bool) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
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
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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
        PlusPopover(onCreate: {}, onJoin: {}, onDismiss: {})
    }
}

#Preview("Locked — 2 to go") {
    ZStack {
        BlipColor.background.ignoresSafeArea()
        PlusPopover(
            onCreate: {},
            onJoin: {},
            onDismiss: {},
            canCreate: false,
            referralsToNextSlot: 2,
            onLockedTap: {}
        )
    }
}
