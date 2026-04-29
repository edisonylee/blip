import SwiftUI

/// Profile page — the rightmost of the home pager. Identity (handle, joined-N
/// days-ago) plus stats and links into the social surfaces (friends list,
/// leaderboard). Settings (theme / quiet hours / sign out / delete) live on
/// the gear icon in the home header now, not here.
struct ProfileView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var users: UserRepository

    @State private var showHandleSheet = false

    // MARK: - Layout constants

    private static let horizontalPadding: CGFloat = 20
    private static let sectionSpacing: CGFloat = 20

    // MARK: - Body

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Self.sectionSpacing) {
                    ProfileStatsHero(
                        profile: users.profile,
                        onTapHandle: { showHandleSheet = true }
                    )
                    .padding(.horizontal, Self.horizontalPadding)
                    .padding(.top, 8)

                    socialLinks
                        .padding(.horizontal, Self.horizontalPadding)
                }
                .padding(.bottom, Self.sectionSpacing)
            }
        }
        .sheet(isPresented: $showHandleSheet) {
            EditHandleSheet()
        }
    }

    // MARK: - Subviews

    private var socialLinks: some View {
        VStack(spacing: 0) {
            NavigationLink {
                FriendsView()
            } label: {
                BlipLinkRow(title: "Friends", value: friendsCountLabel)
            }
            .buttonStyle(.plain)

            Divider().background(BlipColor.surfaceElevated)

            NavigationLink {
                LeaderboardView()
            } label: {
                BlipLinkRow(title: "Leaderboard")
            }
            .buttonStyle(.plain)
        }
        .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private var friendsCountLabel: String? {
        guard let count = users.profile?.friendsCount, count > 0 else { return nil }
        return count == 1 ? "1" : "\(count)"
    }
}

// MARK: - Stats hero

/// Top-of-screen hero for the own-profile screen. Shows the user's @handle
/// (or a "claim a handle" affordance when unset), how long they've been on
/// blip, and three stat tiles: total clips, current streak, friends.
private struct ProfileStatsHero: View {
    let profile: BlipUser?
    let onTapHandle: () -> Void

    // MARK: - Layout constants

    private static let stackSpacing: CGFloat = 16
    private static let tileSpacing: CGFloat = 8
    private static let cornerRadius: CGFloat = 12
    private static let contentPadding: CGFloat = 16
    private static let handleRowMinHeight: CGFloat = 44
    private static let handleSize: CGFloat = 28
    private static let handleTracking: CGFloat = -0.3
    private static let handleRowHSpacing: CGFloat = 8

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: Self.stackSpacing) {
            handleRow
            memberSinceLabel
            statTilesRow
            if let profile, profile.referralsCount > 0 || profile.unlockedBlipSlots == 1 {
                Text(referralProgressLabel)
                    .font(BlipTypography.caption)
                    .foregroundStyle(BlipColor.textTertiary)
            }
        }
        .padding(Self.contentPadding)
        .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .stroke(BlipColor.border, lineWidth: 1)
        )
    }

    // MARK: - Subviews

    private var handleRow: some View {
        Button(action: onTapHandle) {
            HStack(spacing: Self.handleRowHSpacing) {
                Text(handleDisplay)
                    .font(.blip(size: Self.handleSize, weight: .semibold))
                    .tracking(Self.handleTracking)
                    .foregroundStyle(handleTint)
                Spacer()
                Text(profile?.handle == nil ? "Claim" : "Edit")
                    .font(BlipTypography.caption)
                    .foregroundStyle(BlipColor.textTertiary)
            }
            .frame(minHeight: Self.handleRowMinHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var memberSinceLabel: some View {
        Text(memberSinceText)
            .font(BlipTypography.caption)
            .foregroundStyle(BlipColor.textSecondary)
    }

    private var statTilesRow: some View {
        HStack(spacing: Self.tileSpacing) {
            BlipStatTile(value: "\(profile?.totalClips ?? 0)", label: clipsLabel)
            BlipStatTile(value: "\(profile?.streakCurrent ?? 0)", label: "day streak")
            BlipStatTile(value: "\(profile?.friendsCount ?? 0)", label: friendsLabel)
            BlipStatTile(value: "\(profile?.referralsCount ?? 0)", label: referralsLabel)
        }
    }

    private var referralProgressLabel: String {
        guard let profile else { return "" }
        let need = profile.referralsToNextSlot
        return need == 1
            ? "1 more referral unlocks another blip slot"
            : "\(need) more referrals unlock another blip slot"
    }

    // MARK: - Helpers

    private var handleDisplay: String {
        if let h = profile?.handle, !h.isEmpty { return "@\(h)" }
        return "Claim a handle"
    }

    private var handleTint: Color {
        profile?.handle == nil ? BlipColor.textSecondary : BlipColor.textPrimary
    }

    private var memberSinceText: String {
        guard let createdAt = profile?.createdAt else { return "joined recently" }
        let days = daysBetween(createdAt, and: Date())
        if days <= 0 { return "joined today" }
        if days == 1 { return "joined 1 day ago" }
        return "joined \(days) days ago"
    }

    private var clipsLabel: String {
        let n = profile?.totalClips ?? 0
        return n == 1 ? "clip" : "clips"
    }

    private var friendsLabel: String {
        let n = profile?.friendsCount ?? 0
        return n == 1 ? "friend" : "friends"
    }

    private var referralsLabel: String {
        let n = profile?.referralsCount ?? 0
        return n == 1 ? "invite" : "invites"
    }

    private func daysBetween(_ a: Date, and b: Date) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: a)
        let end = cal.startOfDay(for: b)
        return cal.dateComponents([.day], from: start, to: end).day ?? 0
    }
}

