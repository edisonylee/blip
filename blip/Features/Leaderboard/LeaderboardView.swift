import SwiftUI

// MARK: - Shell

struct LeaderboardView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var userDirectory: FirestoreUserDirectory
    @EnvironmentObject private var moderation: ModerationService

    var body: some View {
        LeaderboardContent(
            currentUid: currentUid,
            userDirectory: userDirectory,
            moderation: moderation
        )
    }

    private var currentUid: String? {
        if case .signedIn(let uid) = auth.state { return uid }
        return nil
    }
}

// MARK: - Content

private struct LeaderboardContent: View {

    @StateObject private var vm: LeaderboardViewModel
    private let currentUid: String?
    @ObservedObject private var moderation: ModerationService

    /// Drives the staggered row-entrance animation.
    @State private var appeared = false

    init(currentUid: String?, userDirectory: any UserRanking, moderation: ModerationService) {
        self.currentUid = currentUid
        self.moderation = moderation
        _vm = StateObject(wrappedValue: LeaderboardViewModel(userDirectory: userDirectory))
    }

    var body: some View {
        ZStack {
            BlipColor.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                if vm.isLoading && vm.entries.isEmpty {
                    loadingState
                } else if vm.entries.isEmpty {
                    emptyState
                } else {
                    leaderboardList
                }
            }
        }
        .navigationTitle("leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(BlipColor.background, for: .navigationBar)
        .task {
            vm.startListening()
            vm.setBlocklist(moderation.blockedUsers)
        }
        .onReceive(moderation.$blockedUsers) { vm.setBlocklist($0) }
        .onDisappear { vm.stopListening() }
        .onChange(of: vm.entries.isEmpty) { _, empty in
            if !empty {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appeared = true }
            }
        }
        .onAppear {
            if !vm.entries.isEmpty { appeared = true }
        }
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "trophy.fill")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color(hex: 0xF59E0B).opacity(0.4))
            ProgressView().tint(BlipColor.accent)
            Text("loading…")
                .font(.blip(size: 13))
                .foregroundStyle(BlipColor.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "trophy")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(BlipColor.textTertiary)
            Text("no rankings yet")
                .font(BlipTypography.body)
                .foregroundStyle(BlipColor.textPrimary)
            Text("clip totals update as members record their day.")
                .font(.blip(size: 13))
                .foregroundStyle(BlipColor.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - List

    private var leaderboardList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {

                // ── Top 3 podium ───────────────────────────────────────────
                if vm.entries.count >= 3 {
                    podiumSection
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                        .opacity(appeared ? 1 : 0)
                        .scaleEffect(appeared ? 1 : 0.92, anchor: .top)
                        .animation(.spring(response: 0.55, dampingFraction: 0.78), value: appeared)
                }

                // ── Column header ──────────────────────────────────────────
                HStack {
                    Text("rank")
                        .frame(width: 52, alignment: .leading)
                    Text("player")
                    Spacer()
                    Text("clips")
                }
                .font(.blip(size: 11, weight: .semibold))
                .foregroundStyle(BlipColor.textTertiary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 6)

                // ── Rows (rank 4 onward) ───────────────────────────────────
                let rest = vm.entries.count > 3 ? Array(vm.entries[3...]) : []
                ForEach(Array(rest.enumerated()), id: \.element.id) { index, entry in
                    LeaderboardRow(entry: entry, isMe: entry.id == currentUid)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(
                            .spring(response: 0.45, dampingFraction: 0.78)
                                .delay(Double(index) * 0.04),
                            value: appeared
                        )
                }

                // ── My rank banner (if outside top 50) ────────────────────
                myRankBanner
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5).delay(0.3), value: appeared)
            }
        }
    }

    // MARK: - Podium (top 3)

    private var podiumSection: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // 2nd place — left, slightly shorter
            podiumCard(entry: vm.entries[1], podiumHeight: 72)
            // 1st place — center, tallest
            podiumCard(entry: vm.entries[0], podiumHeight: 96)
            // 3rd place — right, shortest
            podiumCard(entry: vm.entries[2], podiumHeight: 58)
        }
    }

    private func podiumCard(entry: LeaderboardEntry, podiumHeight: CGFloat) -> some View {
        let isMe = entry.id == currentUid
        return VStack(spacing: 6) {
            // Medal emoji
            Text(medalEmoji(for: entry.rank))
                .font(.system(size: 28))

            // Handle
            Text(entry.handle.map { "@\($0)" } ?? "—")
                .font(.blip(size: 11, weight: .semibold))
                .foregroundStyle(isMe ? BlipColor.accentNeutral : BlipColor.textPrimary)
                .lineLimit(1)

            // Clips count
            Text("\(entry.totalClips)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(BlipColor.textSecondary)
                .monospacedDigit()

            // Podium block
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(podiumFill(for: entry.rank))
                    .frame(height: podiumHeight)

                Text("\(entry.rank)")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(podiumNumberColor(for: entry.rank))
                    .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(
            isMe
            ? RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(BlipColor.accentNeutral.opacity(0.5), lineWidth: 1.5)
                .padding(.top, 60) // only outline the podium block
            : nil
        )
    }

    private func podiumFill(for rank: Int) -> LinearGradient {
        switch rank {
        case 1:
            return LinearGradient(
                colors: [Color(hex: 0xFBBF24), Color(hex: 0xF59E0B)],
                startPoint: .top, endPoint: .bottom
            )
        case 2:
            return LinearGradient(
                colors: [Color(hex: 0xD1D5DB), Color(hex: 0x9CA3AF)],
                startPoint: .top, endPoint: .bottom
            )
        default:
            return LinearGradient(
                colors: [Color(hex: 0xFBD0A4), Color(hex: 0xD97706)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    private func podiumNumberColor(for rank: Int) -> Color {
        switch rank {
        case 1: return Color(hex: 0x78350F)
        case 2: return Color(hex: 0x374151)
        default: return Color(hex: 0x78350F)
        }
    }

    private func medalEmoji(for rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        default: return "🥉"
        }
    }

    // MARK: - My rank banner

    @ViewBuilder
    private var myRankBanner: some View {
        if let myEntry = vm.entries.first(where: { $0.id == currentUid }),
           myEntry.rank > 3 {
            HStack(spacing: 12) {
                Image(systemName: "person.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(BlipColor.accentNeutral)
                    .frame(width: 32, height: 32)
                    .background(BlipColor.accentNeutral.opacity(0.12),
                                in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("your rank")
                        .font(.blip(size: 11))
                        .foregroundStyle(BlipColor.textTertiary)
                    Text("#\(myEntry.rank)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(BlipColor.textPrimary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "film.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(BlipColor.textTertiary)
                    Text("\(myEntry.totalClips) clips")
                        .font(.blip(size: 13, weight: .semibold))
                        .foregroundStyle(BlipColor.textSecondary)
                }
            }
            .padding(14)
            .background(BlipColor.surface,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(BlipColor.accentNeutral.opacity(0.25), lineWidth: 1.5)
            )
        }
    }
}

// MARK: - Row (rank 4+)

private struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    let isMe: Bool

    var body: some View {
        NavigationLink {
            UserProfileView(uid: entry.id)
        } label: {
            HStack(spacing: 12) {
                // Rank number in a subtle chip
                Text("\(entry.rank)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(isMe ? BlipColor.accentNeutral : BlipColor.textTertiary)
                    .frame(width: 36, alignment: .center)
                    .monospacedDigit()

                // Handle
                Text(entry.handle.map { "@\($0)" } ?? "—")
                    .font(.blip(size: 15, weight: isMe ? .bold : .medium))
                    .foregroundStyle(isMe ? BlipColor.accentNeutral : BlipColor.textPrimary)
                    .lineLimit(1)

                Spacer()

                // Clips count
                HStack(spacing: 4) {
                    Text("\(entry.totalClips)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(BlipColor.textSecondary)
                        .monospacedDigit()
                    Image(systemName: "film.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(BlipColor.textTertiary)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .background(
                isMe
                    ? BlipColor.accentNeutral.opacity(0.07)
                    : BlipColor.surface,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isMe ? BlipColor.accentNeutral.opacity(0.3) : BlipColor.border,
                        lineWidth: isMe ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "rank \(entry.rank), \(entry.handle.map { "@\($0)" } ?? "no handle"), \(entry.totalClips) clips"
        )
    }
}
