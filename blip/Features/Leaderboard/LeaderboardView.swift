import SwiftUI

// MARK: - View

/// Live top-N global leaderboard. Each row taps through to
/// `UserProfileView`. The signed-in user's row gets a subtle highlight.
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

// MARK: - Content (owns VM)

private struct LeaderboardContent: View {

    @StateObject private var vm: LeaderboardViewModel
    private let currentUid: String?
    @ObservedObject private var moderation: ModerationService

    init(currentUid: String?, userDirectory: any UserRanking, moderation: ModerationService) {
        self.currentUid = currentUid
        self.moderation = moderation
        _vm = StateObject(wrappedValue: LeaderboardViewModel(userDirectory: userDirectory))
    }

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: LeaderboardLayout.outerSpacing) {
                Text(Copy.title)
                    .font(BlipTypography.title)
                    .tracking(BlipTypography.titleTracking)
                    .foregroundStyle(BlipColor.textPrimary)
                    .padding(.horizontal, LeaderboardLayout.horizontalPadding)
                    .padding(.top, LeaderboardLayout.topPadding)

                content
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            vm.startListening()
            vm.setBlocklist(moderation.blockedUsers)
        }
        .onReceive(moderation.$blockedUsers) { vm.setBlocklist($0) }
        .onDisappear { vm.stopListening() }
    }

    // MARK: - Content router

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.entries.isEmpty {
            VStack {
                Spacer()
                ProgressView().tint(BlipColor.textPrimary)
                Spacer()
            }
        } else if vm.entries.isEmpty {
            emptyState
        } else {
            list
        }
    }

    private var emptyState: some View {
        VStack(spacing: LeaderboardLayout.emptySpacing) {
            Spacer()
            Text(Copy.empty)
                .font(BlipTypography.body)
                .foregroundStyle(BlipColor.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, LeaderboardLayout.horizontalPadding)
    }

    private var list: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: LeaderboardLayout.rowSpacing) {
                ForEach(vm.entries) { entry in
                    NavigationLink {
                        UserProfileView(uid: entry.id)
                    } label: {
                        LeaderboardRow(
                            entry: entry,
                            isMe: entry.id == currentUid
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(rowAccessibility(for: entry))
                }
            }
            .padding(.horizontal, LeaderboardLayout.horizontalPadding)
            .padding(.bottom, LeaderboardLayout.bottomPadding)
        }
    }

    // MARK: - Helpers

    private func rowAccessibility(for entry: LeaderboardEntry) -> String {
        let handlePart = entry.handle.map { "@\($0)" } ?? "no handle"
        return "rank \(entry.rank), \(handlePart), \(entry.totalClips) clips"
    }
}

// MARK: - Row

private struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    let isMe: Bool

    var body: some View {
        HStack(spacing: LeaderboardLayout.rowInnerSpacing) {
            Text("\(entry.rank)")
                .font(.blip(size: LeaderboardLayout.rankFontSize, weight: .semibold))
                .foregroundStyle(BlipColor.textTertiary)
                .frame(width: LeaderboardLayout.rankWidth, alignment: .leading)
                .monospacedDigit()

            Text(handleText)
                .font(.blip(size: LeaderboardLayout.handleFontSize, weight: .medium))
                .foregroundStyle(BlipColor.textPrimary)
                .lineLimit(1)

            Spacer()

            Text("\(entry.totalClips)")
                .font(.blip(size: LeaderboardLayout.clipsFontSize, weight: .semibold))
                .foregroundStyle(BlipColor.textPrimary)
                .monospacedDigit()
        }
        .padding(.horizontal, LeaderboardLayout.rowHPadding)
        .frame(minHeight: LeaderboardLayout.rowMinHeight)
        .background(
            isMe ? BlipColor.surfaceElevated : BlipColor.surface,
            in: RoundedRectangle(cornerRadius: LeaderboardLayout.rowCornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LeaderboardLayout.rowCornerRadius, style: .continuous)
                .stroke(isMe ? BlipColor.textPrimary.opacity(0.25) : BlipColor.border, lineWidth: 1)
        )
    }

    private var handleText: String {
        if let h = entry.handle, !h.isEmpty { return "@\(h)" }
        return Copy.noHandle
    }
}

// MARK: - Layout constants

private enum LeaderboardLayout {
    static let horizontalPadding: CGFloat = 20
    static let topPadding: CGFloat = 8
    static let bottomPadding: CGFloat = 24
    static let outerSpacing: CGFloat = 16
    static let emptySpacing: CGFloat = 12

    static let rowSpacing: CGFloat = 6
    static let rowInnerSpacing: CGFloat = 14
    static let rowHPadding: CGFloat = 16
    static let rowMinHeight: CGFloat = 52
    static let rowCornerRadius: CGFloat = 12

    static let rankWidth: CGFloat = 28
    static let rankFontSize: CGFloat = 14
    static let handleFontSize: CGFloat = 16
    static let clipsFontSize: CGFloat = 16
}

// MARK: - Copy (Lane A)

private enum Copy {
    static let title = "Leaderboard"
    static let empty = "Nothing here yet."
    static let noHandle = "—"
}
