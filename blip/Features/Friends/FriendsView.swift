import SwiftUI

// MARK: - View

/// Two-section friends screen: incoming requests on top (only when
/// non-empty), the friend list below. Top-right toolbar item links to
/// the handle search. Auth and friend-graph reactivity arrive via
/// `@EnvironmentObject`; the inner `Content` view owns the VM so the
/// VM's init can take env-resolved collaborators.
struct FriendsView: View {

    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var friendsRepo: FriendsRepository
    @EnvironmentObject private var friendsService: FriendsService
    @EnvironmentObject private var userDirectory: FirestoreUserDirectory

    var body: some View {
        FriendsContent(
            currentUid: currentUid,
            friendsService: friendsService,
            friendsRepo: friendsRepo,
            userDirectory: userDirectory
        )
    }

    private var currentUid: String? {
        if case .signedIn(let uid) = auth.state { return uid }
        return nil
    }
}

// MARK: - Content

private struct FriendsContent: View {

    @StateObject private var vm: FriendsViewModel
    @ObservedObject private var friendsRepo: FriendsRepository

    private let userDirectory: FirestoreUserDirectory

    init(
        currentUid: String?,
        friendsService: any FriendMutating,
        friendsRepo: FriendsRepository,
        userDirectory: FirestoreUserDirectory
    ) {
        _vm = StateObject(
            wrappedValue: FriendsViewModel(
                currentUid: currentUid,
                friendsService: friendsService,
                userDirectory: userDirectory
            )
        )
        self.friendsRepo = friendsRepo
        self.userDirectory = userDirectory
    }

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: FriendsLayout.sectionSpacing) {
                    if !friendsRepo.incomingRequests.isEmpty {
                        incomingSection
                    }
                    friendsSection
                    ErrorText(message: vm.lastError ?? friendsRepo.lastError)
                    Spacer(minLength: FriendsLayout.bottomSpacer)
                }
                .padding(.horizontal, FriendsLayout.horizontalPadding)
                .padding(.top, FriendsLayout.topPadding)
            }
        }
        .navigationTitle(Copy.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    FriendSearchView(currentUid: vm.currentUid, userDirectory: userDirectory)
                } label: {
                    Image(systemName: "plus")
                        .font(.blip(size: FriendsLayout.toolbarIconSize, weight: .semibold))
                        .foregroundStyle(BlipColor.textPrimary)
                        .frame(width: FriendsLayout.toolbarTap, height: FriendsLayout.toolbarTap)
                }
                .accessibilityLabel(Copy.searchA11y)
            }
        }
        .onChange(of: friendsRepo.incomingRequests) { _, requests in
            vm.ensureProfilesLoaded(uids: requests.map { $0.fromUid })
        }
        .onChange(of: friendsRepo.friends) { _, uids in
            vm.ensureProfilesLoaded(uids: uids)
        }
        .task {
            vm.ensureProfilesLoaded(uids: friendsRepo.incomingRequests.map { $0.fromUid })
            vm.ensureProfilesLoaded(uids: friendsRepo.friends)
        }
    }

    // MARK: - Incoming section

    private var incomingSection: some View {
        VStack(alignment: .leading, spacing: FriendsLayout.rowSpacing) {
            Text(Copy.requestsHeader)
                .font(.blip(size: FriendsLayout.sectionHeaderFontSize, weight: .semibold))
                .foregroundStyle(BlipColor.textTertiary)
                .textCase(.uppercase)
                .tracking(FriendsLayout.sectionHeaderTracking)

            VStack(spacing: FriendsLayout.rowSpacing) {
                ForEach(friendsRepo.incomingRequests) { request in
                    IncomingRequestRow(
                        request: request,
                        display: vm.display(for: request.fromUid),
                        onAccept: { Task { await vm.accept(request) } },
                        onIgnore: { Task { await vm.reject(request) } }
                    )
                }
            }
        }
    }

    // MARK: - Friends section

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: FriendsLayout.rowSpacing) {
            Text(Copy.friendsHeader)
                .font(.blip(size: FriendsLayout.sectionHeaderFontSize, weight: .semibold))
                .foregroundStyle(BlipColor.textTertiary)
                .textCase(.uppercase)
                .tracking(FriendsLayout.sectionHeaderTracking)

            if friendsRepo.friends.isEmpty {
                Text(Copy.emptyFriends)
                    .font(BlipTypography.caption)
                    .foregroundStyle(BlipColor.textTertiary)
                    .padding(.top, FriendsLayout.emptyTopPadding)
            } else {
                VStack(spacing: FriendsLayout.rowSpacing) {
                    ForEach(friendsRepo.friends, id: \.self) { uid in
                        FriendRow(display: vm.display(for: uid))
                    }
                }
            }
        }
    }
}

// MARK: - Incoming request row

private struct IncomingRequestRow: View {
    let request: FriendRequest
    let display: FriendDisplay
    let onAccept: () -> Void
    let onIgnore: () -> Void

    var body: some View {
        HStack(spacing: FriendsLayout.rowInnerSpacing) {
            // The avatar + name span links to the sender's profile so the
            // recipient can vet the requester before accepting. Action
            // buttons live outside the link so a tap on accept/ignore
            // doesn't also trigger navigation.
            NavigationLink {
                UserProfileView(uid: display.id)
            } label: {
                HStack(spacing: FriendsLayout.rowInnerSpacing) {
                    AvatarView(
                        initials: initialsForDisplay(display),
                        hasPosted: false,
                        size: FriendsLayout.avatarSize
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(handleText(display))
                            .font(.blip(size: FriendsLayout.handleFontSize, weight: .medium))
                            .foregroundStyle(BlipColor.textPrimary)
                            .lineLimit(1)
                        Text(Copy.wantsToFriend)
                            .font(BlipTypography.caption)
                            .foregroundStyle(BlipColor.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open profile for \(handleText(display))")

            Spacer()

            HStack(spacing: FriendsLayout.actionSpacing) {
                Button(Copy.ignore, action: onIgnore)
                    .buttonStyle(BlipInlineGhostButtonStyle())
                    .accessibilityLabel("Ignore request from \(handleText(display))")
                Button(Copy.accept, action: onAccept)
                    .buttonStyle(BlipInlineFilledButtonStyle())
                    .accessibilityLabel("Accept request from \(handleText(display))")
            }
        }
        .padding(.horizontal, FriendsLayout.rowHPadding)
        .padding(.vertical, FriendsLayout.rowVPadding)
        .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: FriendsLayout.rowCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FriendsLayout.rowCornerRadius, style: .continuous)
                .stroke(BlipColor.border, lineWidth: 1)
        )
    }
}

// MARK: - Friend row

private struct FriendRow: View {
    let display: FriendDisplay

    var body: some View {
        NavigationLink {
            UserProfileView(uid: display.id)
        } label: {
            HStack(spacing: FriendsLayout.rowInnerSpacing) {
                AvatarView(
                    initials: initialsForDisplay(display),
                    hasPosted: false,
                    size: FriendsLayout.avatarSize
                )
                Text(handleText(display))
                    .font(.blip(size: FriendsLayout.handleFontSize, weight: .medium))
                    .foregroundStyle(BlipColor.textPrimary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(BlipColor.textTertiary)
            }
            .padding(.horizontal, FriendsLayout.rowHPadding)
            .frame(minHeight: FriendsLayout.rowMinHeight)
            .background(BlipColor.surface, in: RoundedRectangle(cornerRadius: FriendsLayout.rowCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FriendsLayout.rowCornerRadius, style: .continuous)
                    .stroke(BlipColor.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helpers

private func handleText(_ display: FriendDisplay) -> String {
    if let h = display.handle, !h.isEmpty { return "@\(h)" }
    return "@\(display.id.prefix(6))"
}

private func initialsForDisplay(_ display: FriendDisplay) -> String {
    if let h = display.handle, !h.isEmpty {
        let trimmed = h.replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "_", with: "")
        return String(trimmed.prefix(2)).uppercased()
    }
    return String(display.id.prefix(2)).uppercased()
}

// MARK: - Layout constants

private enum FriendsLayout {
    static let horizontalPadding: CGFloat = 20
    static let topPadding: CGFloat = 12
    static let bottomSpacer: CGFloat = 24
    static let sectionSpacing: CGFloat = 22
    static let emptyTopPadding: CGFloat = 4

    static let sectionHeaderFontSize: CGFloat = 11
    static let sectionHeaderTracking: CGFloat = 0.8

    static let rowSpacing: CGFloat = 8
    static let rowInnerSpacing: CGFloat = 12
    static let rowHPadding: CGFloat = 14
    static let rowVPadding: CGFloat = 10
    static let rowMinHeight: CGFloat = 56
    static let rowCornerRadius: CGFloat = 12

    static let avatarSize: CGFloat = 32
    static let handleFontSize: CGFloat = 16

    static let actionSpacing: CGFloat = 6

    static let toolbarIconSize: CGFloat = 17
    static let toolbarTap: CGFloat = 44
}

// MARK: - Copy (Lane A)

private enum Copy {
    static let title = "Friends"
    static let requestsHeader = "Requests"
    static let friendsHeader = "Friends"
    static let wantsToFriend = "Wants to be friends"
    static let accept = "Accept"
    static let ignore = "Ignore"
    static let emptyFriends = "No friends yet. Tap + to find people."
    static let searchA11y = "Search for friends"
}
