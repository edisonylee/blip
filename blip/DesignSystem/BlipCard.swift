import SwiftUI

/// iMessage-style row for a single blipchat. Used in the home list.
///
/// Layout: avatar cluster (left) — name + subtitle (center) — relative-time
/// + unread dot (right). Visually flat (no card border) so the home list reads
/// as a continuous list rather than a stack of cards.
struct BlipCard: View {
    let title: String
    let subtitle: String
    let memberCount: Int
    let progress: BlipCardProgress?

    // MARK: - Layout constants
    private static let avatarClusterSize: CGFloat = 48
    private static let avatarSize: CGFloat = 32
    private static let rowVPadding: CGFloat = 10
    private static let rowHPadding: CGFloat = 4
    private static let unreadDotSize: CGFloat = 9

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            avatarCluster
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.blip(size: 17, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(BlipColor.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.blip(size: 14))
                    .foregroundStyle(BlipColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            trailingMeta
        }
        .padding(.vertical, Self.rowVPadding)
        .padding(.horizontal, Self.rowHPadding)
        .contentShape(Rectangle())
    }

    // MARK: - Subviews

    private var avatarCluster: some View {
        ZStack {
            // Two members overlapping in iMessage-group style. If only one
            // member, render a single centered avatar; if many, the visible
            // two read as a "group" affordance and the count pill takes care
            // of cardinality.
            let visible = (progress?.members ?? []).prefix(2)
            if visible.count >= 2 {
                AvatarView(initials: visible[1].initials, hasPosted: false, size: Self.avatarSize)
                    .offset(x: 8, y: 8)
                AvatarView(initials: visible[0].initials, hasPosted: false, size: Self.avatarSize)
                    .offset(x: -8, y: -8)
            } else if let single = visible.first {
                AvatarView(initials: single.initials, hasPosted: false, size: Self.avatarSize + 4)
            } else {
                AvatarView(initials: "··", hasPosted: false, size: Self.avatarSize + 4)
            }
        }
        .frame(width: Self.avatarClusterSize, height: Self.avatarClusterSize)
    }

    @ViewBuilder
    private var trailingMeta: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if let stamp = progress?.lastClipAt.flatMap(Self.relativeTimeString) {
                Text(stamp)
                    .font(.blip(size: 12))
                    .foregroundStyle(BlipColor.textTertiary)
            }
            if (progress?.unreadCount ?? 0) > 0 {
                Circle()
                    .fill(BlipColor.accent)
                    .frame(width: Self.unreadDotSize, height: Self.unreadDotSize)
            } else {
                Image(systemName: "chevron.right")
                    .font(.blip(size: 12, weight: .semibold))
                    .foregroundStyle(BlipColor.textTertiary)
            }
        }
    }

    // MARK: - Helpers

    /// "5m", "1h", "Yesterday", or formatted date for older entries —
    /// mirrors iMessage's right-aligned timestamp behaviour.
    private static func relativeTimeString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "now" }
        if interval < 60 * 60 {
            return "\(Int(interval / 60))m"
        }
        if interval < 60 * 60 * 24 {
            return "\(Int(interval / 3600))h"
        }
        if interval < 60 * 60 * 48 {
            return "Yesterday"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

// MARK: - Data

struct BlipCardProgress {
    /// nil = completion unknown (no clip data loaded). Retained for API
    /// continuity even though the row no longer renders a ring.
    var hourCompletion: Double?
    var members: [Member]
    var secondsToNextPrompt: Int
    /// Most recent activity in this blipchat — drives the right-side timestamp.
    /// `nil` hides the timestamp.
    var lastClipAt: Date? = nil
    /// Coarse "any new clip not authored by me" signal. >0 shows an accent dot
    /// on the right; 0 shows a chevron. Real per-user read receipts is a
    /// follow-up — see plan's Known limitations.
    var unreadCount: Int = 0

    struct Member: Identifiable {
        let id: String
        let initials: String
        let hasPostedThisHour: Bool
    }
}

// MARK: - Previews

#Preview("List rows") {
    VStack(spacing: 0) {
        BlipCard(
            title: "spring break crew",
            subtitle: "4 members",
            memberCount: 4,
            progress: BlipCardProgress(
                hourCompletion: nil,
                members: [
                    .init(id: "1", initials: "ED", hasPostedThisHour: false),
                    .init(id: "2", initials: "LJ", hasPostedThisHour: false),
                ],
                secondsToNextPrompt: 0,
                lastClipAt: Date().addingTimeInterval(-5 * 60),
                unreadCount: 1
            )
        )
        Divider().background(BlipColor.border)
        BlipCard(
            title: "fam",
            subtitle: "5 members",
            memberCount: 5,
            progress: BlipCardProgress(
                hourCompletion: nil,
                members: [
                    .init(id: "1", initials: "AM", hasPostedThisHour: false),
                    .init(id: "2", initials: "KR", hasPostedThisHour: false),
                ],
                secondsToNextPrompt: 0,
                lastClipAt: Date().addingTimeInterval(-3 * 3600),
                unreadCount: 0
            )
        )
        Divider().background(BlipColor.border)
        BlipCard(
            title: "solo",
            subtitle: "just you",
            memberCount: 1,
            progress: BlipCardProgress(
                hourCompletion: nil,
                members: [
                    .init(id: "1", initials: "ED", hasPostedThisHour: false),
                ],
                secondsToNextPrompt: 0
            )
        )
    }
    .padding()
    .background(BlipColor.background)
}
