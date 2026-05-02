import PhotosUI
import SwiftUI

/// Profile page — the rightmost of the home pager. Beli-inspired layout:
/// wordmark + share/menu, large editable avatar, handle + member-since +
/// school affordance, three-stat row, action buttons, and bottom rank +
/// streak cards. All dark-mode adaptive via `BlipColor` tokens.
struct ProfileView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var users: UserRepository
    @EnvironmentObject private var userDirectory: FirestoreUserDirectory

    var body: some View {
        Group {
            if let uid = currentUid {
                ProfileContent(
                    uid: uid,
                    userMutator: users,
                    photoUploader: ProfilePhotoUploader(),
                    userDirectory: userDirectory
                )
            } else {
                BlipColor.background.ignoresSafeArea()
            }
        }
    }

    private var currentUid: String? {
        if case .signedIn(let uid) = auth.state { return uid }
        return nil
    }
}

// MARK: - Content (owns ViewModels + sheet plumbing)

private struct ProfileContent: View {

    // MARK: - Environment

    @EnvironmentObject private var users: UserRepository

    // MARK: - VMs

    @StateObject private var vm: ProfileViewModel
    @StateObject private var rankVM: LeaderboardViewModel

    // MARK: - Local UI state

    @State private var showHandleSheet = false
    @State private var showSchoolSheet = false
    @State private var showSettings = false
    @State private var showShareSheet = false
    @State private var pickerItem: PhotosPickerItem?

    private let uid: String

    // MARK: - Layout constants

    private static let horizontalPadding: CGFloat = 20
    private static let stackSpacing: CGFloat = 24
    private static let topBarHPadding: CGFloat = 16
    private static let topBarIconSize: CGFloat = 18
    private static let topBarTapTarget: CGFloat = 44
    private static let wordmarkSize: CGFloat = 22
    private static let wordmarkTracking: CGFloat = -0.4
    private static let avatarSize: CGFloat = 120
    private static let handleSize: CGFloat = 22
    private static let handleTracking: CGFloat = -0.3
    private static let metaSize: CGFloat = 13
    private static let actionRowSpacing: CGFloat = 8
    private static let bottomCardSpacing: CGFloat = 10
    private static let overflowSize: CGFloat = 52
    private static let rankFriendsThreshold: Int = 3

    // MARK: - Init

    init(
        uid: String,
        userMutator: any BlipUserMutating,
        photoUploader: any ProfilePhotoUploading,
        userDirectory: any UserRanking
    ) {
        self.uid = uid
        _vm = StateObject(wrappedValue: ProfileViewModel(
            uid: uid,
            userMutator: userMutator,
            photoUploader: photoUploader
        ))
        _rankVM = StateObject(wrappedValue: LeaderboardViewModel(userDirectory: userDirectory))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(spacing: Self.stackSpacing) {
                        identityBlock
                        statsRow
                        actionRow
                        bottomCardsRow

                        if let err = vm.pendingError {
                            Text(err)
                                .font(BlipTypography.caption)
                                .foregroundStyle(BlipColor.error)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, Self.horizontalPadding)
                        }
                    }
                    .padding(.horizontal, Self.horizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, Self.stackSpacing)
                }
            }
        }
        .task { rankVM.startListening() }
        .onDisappear { rankVM.stopListening() }
        .sheet(isPresented: $showHandleSheet) { EditHandleSheet() }
        .sheet(isPresented: $showSchoolSheet) { EditSchoolSheet() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: vm.shareItems(handle: profile?.handle))
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await vm.uploadPhoto(image)
                }
                pickerItem = nil
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Text(wordmarkText)
                .font(.blip(size: Self.wordmarkSize, weight: .bold))
                .tracking(Self.wordmarkTracking)
                .foregroundStyle(BlipColor.textPrimary)
                .lineLimit(1)
            Spacer()
            Button { showShareSheet = true } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.blip(size: Self.topBarIconSize, weight: .medium))
                    .foregroundStyle(BlipColor.textPrimary)
                    .frame(minWidth: Self.topBarTapTarget, minHeight: Self.topBarTapTarget)
            }
            .accessibilityLabel("share profile")

            Button { showSettings = true } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.blip(size: Self.topBarIconSize, weight: .medium))
                    .foregroundStyle(BlipColor.textPrimary)
                    .frame(minWidth: Self.topBarTapTarget, minHeight: Self.topBarTapTarget)
            }
            .accessibilityLabel("settings")
        }
        .padding(.horizontal, Self.topBarHPadding)
    }

    // MARK: - Identity block (avatar + handle + meta)

    private var identityBlock: some View {
        VStack(spacing: 12) {
            avatarPicker
            handleLabel
            memberSinceLabel
            schoolAffordance
        }
        .frame(maxWidth: .infinity)
    }

    private var avatarPicker: some View {
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            ZStack {
                ProfileAvatarView(
                    photoURL: profile?.photoURL,
                    initials: avatarInitials,
                    size: Self.avatarSize,
                    isEditable: true
                )
                if vm.isUploadingPhoto {
                    Circle()
                        .fill(BlipColor.background.opacity(0.55))
                        .frame(width: Self.avatarSize, height: Self.avatarSize)
                    ProgressView().tint(BlipColor.textPrimary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("change profile photo")
        .disabled(vm.isUploadingPhoto)
    }

    private var handleLabel: some View {
        Button { showHandleSheet = true } label: {
            Text(handleDisplay)
                .font(.blip(size: Self.handleSize, weight: .semibold))
                .tracking(Self.handleTracking)
                .foregroundStyle(profile?.handle == nil ? BlipColor.textSecondary : BlipColor.textPrimary)
                .frame(minHeight: Self.topBarTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(profile?.handle == nil ? "claim a handle" : "edit handle")
    }

    private var memberSinceLabel: some View {
        Text(memberSinceText)
            .font(.blip(size: Self.metaSize))
            .foregroundStyle(BlipColor.textSecondary)
    }

    private var schoolAffordance: some View {
        Button { showSchoolSheet = true } label: {
            HStack(spacing: 4) {
                if profile?.school == nil {
                    Image(systemName: "plus")
                        .font(.system(size: Self.metaSize - 1, weight: .semibold))
                }
                Text(schoolText)
            }
            .font(.blip(size: Self.metaSize, weight: profile?.school == nil ? .medium : .regular))
            .foregroundStyle(profile?.school == nil ? BlipColor.accent : BlipColor.textPrimary)
            .frame(minHeight: Self.topBarTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(profile?.school == nil ? "add your school" : "edit your school")
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 8) {
            BlipStatTile(value: "\(friendsCount)", label: "friends")
            BlipStatTile(value: "\(likesCount)", label: "likes")
        }
    }

    // MARK: - Action row

    private var actionRow: some View {
        HStack(spacing: Self.actionRowSpacing) {
            Button("edit profile") { showHandleSheet = true }
                .blipSecondary()

            Button("share profile") { showShareSheet = true }
                .blipSecondary()

            Button { showSettings = true } label: {
                Image(systemName: "chevron.down")
                    .font(.blip(size: 14, weight: .semibold))
                    .foregroundStyle(BlipColor.textPrimary)
                    .frame(width: Self.overflowSize, height: Self.overflowSize)
                    .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(BlipColor.border, lineWidth: 1)
                    )
            }
            .accessibilityLabel("more options")
        }
    }

    // MARK: - Bottom cards

    private var bottomCardsRow: some View {
        HStack(spacing: Self.bottomCardSpacing) {
            BlipBottomCard(
                icon: "trophy.fill",
                label: "rank",
                value: rankValue,
                isLocked: isRankLocked
            )
            BlipBottomCard(
                icon: "flame.fill",
                label: "streak",
                value: streakValue
            )
        }
    }

    // MARK: - Helpers

    private var profile: BlipUser? { users.profile }

    private var wordmarkText: String {
        if let h = profile?.handle, !h.isEmpty { return h }
        return "blip"
    }

    private var avatarInitials: String {
        if let h = profile?.handle, let first = h.first { return String(first).uppercased() }
        return "?"
    }

    private var handleDisplay: String {
        if let h = profile?.handle, !h.isEmpty { return "@\(h)" }
        return "claim a handle"
    }

    private var memberSinceText: String {
        guard let createdAt = profile?.createdAt else { return "joined recently" }
        return "on blip since \(monthYear(createdAt))"
    }

    private func monthYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private var schoolText: String {
        profile?.school ?? "add your school"
    }

    private var friendsCount: Int { profile?.friendsCount ?? 0 }

    private var likesCount: Int { profile?.likesCount ?? 0 }

    private var streakValue: String {
        let n = profile?.streakCurrent ?? 0
        return n == 1 ? "1 day" : "\(n) days"
    }

    private var isRankLocked: Bool {
        (profile?.friendsCount ?? 0) < Self.rankFriendsThreshold
    }

    /// Reads the signed-in user's rank out of the live top-50 leaderboard.
    /// Returns `"—"` when the user is outside the top 50 (the leaderboard
    /// listener is bounded for cost reasons).
    private var rankValue: String? {
        if let entry = rankVM.entries.first(where: { $0.id == uid }) {
            return "#\(entry.rank)"
        }
        return rankVM.entries.isEmpty ? nil : "—"
    }
}
