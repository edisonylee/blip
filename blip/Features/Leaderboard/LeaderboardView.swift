import SwiftUI

// MARK: - Shell

struct LeaderboardView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var userDirectory: FirestoreUserDirectory
    @EnvironmentObject private var moderation: ModerationService
    @EnvironmentObject private var users: UserRepository   // for current user's photo

    var body: some View {
        LeaderboardContent(
            currentUid: currentUid,
            myPhotoURL: users.profile?.photoURL,
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

// Number of ranks shown in the main list (others see their rank pinned below)
private let displayLimit = 10

private struct LeaderboardContent: View {

    @StateObject private var vm: LeaderboardViewModel
    private let currentUid: String?
    private let myPhotoURL: URL?
    @ObservedObject private var moderation: ModerationService

    /// Drives the staggered row-entrance animation.
    @State private var appeared = false

    init(
        currentUid: String?,
        myPhotoURL: URL?,
        userDirectory: any UserRanking,
        moderation: ModerationService
    ) {
        self.currentUid  = currentUid
        self.myPhotoURL  = myPhotoURL
        self.moderation  = moderation
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
        ZStack(alignment: .bottom) {
            // Scrollable top-10 list
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {

                    // ── Top 3 podium ───────────────────────────────────────
                    if vm.entries.count >= 3 {
                        podiumSection
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 8)
                            .opacity(appeared ? 1 : 0)
                            .scaleEffect(appeared ? 1 : 0.92, anchor: .top)
                            .animation(.spring(response: 0.55, dampingFraction: 0.78),
                                       value: appeared)
                    }

                    // ── Column header ──────────────────────────────────────
                    HStack {
                        Text("rank").frame(width: 52, alignment: .leading)
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

                    // ── Rows 4–10 ──────────────────────────────────────────
                    let topTen = Array(vm.entries.prefix(displayLimit))
                    let restRows = topTen.count > 3 ? Array(topTen[3...]) : []
                    ForEach(Array(restRows.enumerated()), id: \.element.id) { idx, entry in
                        LeaderboardRow(entry: entry, isMe: entry.id == currentUid)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(
                                .spring(response: 0.45, dampingFraction: 0.78)
                                    .delay(Double(idx) * 0.04),
                                value: appeared
                            )
                    }

                    // Bottom padding so the pinned card doesn't cover last row
                    if myEntryOutsideTopTen != nil {
                        Spacer().frame(height: 90)
                    } else {
                        Spacer().frame(height: 24)
                    }
                }
            }

            // ── Pinned "my rank" card (outside top 10) ────────────────────
            if let myEntry = myEntryOutsideTopTen {
                myPinnedCard(entry: myEntry)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .background(
                        // Fade from clear → gradient's bottom colour (emerald-100)
                        // so the list softly blurs into the pinned card.
                        LinearGradient(
                            colors: [Color.clear, Color(hex: 0xD1FAE5)],
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 80)
                        .allowsHitTesting(false),
                        alignment: .top
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4), value: myEntryOutsideTopTen?.id)
    }

    /// The current user's entry only when they are ranked below position `displayLimit`.
    private var myEntryOutsideTopTen: LeaderboardEntry? {
        guard let uid = currentUid,
              let entry = vm.entries.first(where: { $0.id == uid }),
              entry.rank > displayLimit
        else { return nil }
        return entry
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

    // MARK: - Pinned card (shown when current user is outside top 10)

    private func myPinnedCard(entry: LeaderboardEntry) -> some View {
        HStack(spacing: 12) {
            // Rank chip
            Text("#\(entry.rank)")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(BlipColor.accentNeutral)
                .frame(width: 48, alignment: .center)
                .monospacedDigit()

            // Profile photo avatar
            ZStack {
                Circle().fill(BlipColor.accentNeutral.opacity(0.15))
                if let url = myPhotoURL {
                    CachedAsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        default: Circle().fill(BlipColor.accentNeutral.opacity(0.15))
                        }
                    }
                    .clipShape(Circle())
                } else {
                    Text(entry.handle.map { QRCodeCard.initials(from: $0) } ?? "?")
                        .font(.blip(size: 13, weight: .bold))
                        .foregroundStyle(BlipColor.accentNeutral)
                }
            }
            .frame(width: 38, height: 38)
            .clipShape(Circle())
            .overlay(Circle().stroke(BlipColor.accentNeutral.opacity(0.3), lineWidth: 1.5))

            // Handle
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.handle.map { "@\($0)" } ?? "you")
                    .font(.blip(size: 15, weight: .bold))
                    .foregroundStyle(BlipColor.textPrimary)
                    .lineLimit(1)
                Text("your rank")
                    .font(.blip(size: 11))
                    .foregroundStyle(BlipColor.textTertiary)
            }

            Spacer()

            // Clips
            HStack(spacing: 4) {
                Text("\(entry.totalClips)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(BlipColor.textSecondary)
                    .monospacedDigit()
                Image(systemName: "film.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(BlipColor.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            BlipColor.surface
                .shadow(.drop(color: BlipColor.accentNeutral.opacity(0.14),
                              radius: 10, x: 0, y: -4)),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(BlipColor.accentNeutral.opacity(0.3), lineWidth: 1.5)
        )
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
