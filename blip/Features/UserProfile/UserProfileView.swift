import SwiftUI

// MARK: - View (public)

/// Public profile for any user. Constructor signature is fixed:
/// `UserProfileView(uid:)`. The view resolves `AuthService`,
/// `FriendsRepository`, and `FriendsService` from `@EnvironmentObject`,
/// then mounts an inner content view that owns the `UserProfileViewModel`
/// — that two-step lets the VM's init receive concrete env collaborators
/// while keeping the public init parameter list at just `uid`.
struct UserProfileView: View {

    let uid: String

    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var friendsRepo: FriendsRepository
    @EnvironmentObject private var friendsService: FriendsService
    @EnvironmentObject private var userDirectory: FirestoreUserDirectory

    init(uid: String) {
        self.uid = uid
    }

    var body: some View {
        UserProfileContent(
            targetUid: uid,
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

// MARK: - Content (owns VM)

private struct UserProfileContent: View {

    @StateObject private var vm: UserProfileViewModel
    @ObservedObject private var friendsRepo: FriendsRepository
    @State private var showUnfriendConfirm = false

    init(
        targetUid: String,
        currentUid: String?,
        friendsService: any FriendMutating,
        friendsRepo: FriendsRepository,
        userDirectory: any UserDocFetching
    ) {
        _vm = StateObject(
            wrappedValue: UserProfileViewModel(
                targetUid: targetUid,
                currentUid: currentUid,
                friendsService: friendsService,
                friends: friendsRepo,
                userDirectory: userDirectory
            )
        )
        self.friendsRepo = friendsRepo
    }

    var body: some View {
        ZStack {
            BlipColor.background.ignoresSafeArea()
            content
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            vm.incomingRequests = friendsRepo.incomingRequests
            vm.outgoingRequests = friendsRepo.outgoingRequests
            vm.friendUids = friendsRepo.friends
            vm.startListening()
        }
        .onChange(of: friendsRepo.incomingRequests) { _, new in vm.incomingRequests = new }
        .onChange(of: friendsRepo.outgoingRequests) { _, new in vm.outgoingRequests = new }
        .onChange(of: friendsRepo.friends) { _, new in vm.friendUids = new }
        .confirmationDialog(
            Copy.unfriendConfirmTitle,
            isPresented: $showUnfriendConfirm,
            titleVisibility: .visible
        ) {
            Button(Copy.ctaUnfriend, role: .destructive) {
                Task { await vm.unfriend() }
            }
            Button(Copy.ctaCancel, role: .cancel) {}
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.profile == nil {
            loadingState
        } else if vm.notFound {
            emptyState
        } else if let profile = vm.profile {
            ProfileBody(
                profile: profile,
                handleText: vm.handleDisplay,
                joinedText: vm.daysSinceJoinedText ?? "",
                state: vm.friendshipState,
                lastError: vm.lastError,
                onSendRequest: { Task { await vm.sendRequest() } },
                onAccept: { req in Task { await vm.acceptRequest(req) } },
                onIgnore: { req in Task { await vm.ignoreRequest(req) } },
                onCancel: { Task { await vm.cancelRequest() } },
                onUnfriend: { showUnfriendConfirm = true }
            )
        }
    }

    // MARK: Loading + empty states

    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(BlipColor.textPrimary)
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: ProfileLayout.emptyStateSpacing) {
            Spacer()
            Text(Copy.notFound)
                .font(BlipTypography.body)
                .foregroundStyle(BlipColor.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, ProfileLayout.horizontalPadding)
    }
}

// MARK: - Profile body

private struct ProfileBody: View {
    let profile: BlipUser
    let handleText: String
    let joinedText: String
    let state: FriendshipState
    let lastError: String?
    let onSendRequest: () -> Void
    let onAccept: (FriendRequest) -> Void
    let onIgnore: (FriendRequest) -> Void
    let onCancel: () -> Void
    let onUnfriend: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: ProfileLayout.sectionSpacing) {
                header
                statsRow
                cta
                ErrorText(message: lastError)
                Spacer(minLength: ProfileLayout.bottomSpacer)
            }
            .padding(.horizontal, ProfileLayout.horizontalPadding)
            .padding(.top, ProfileLayout.topPadding)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: ProfileLayout.headerInnerSpacing) {
            Text(handleText)
                .font(.blip(size: ProfileLayout.handleFontSize, weight: .bold))
                .tracking(BlipTypography.titleTracking)
                .foregroundStyle(BlipColor.textPrimary)
                .lineLimit(1)
            Text(joinedText)
                .font(BlipTypography.caption)
                .foregroundStyle(BlipColor.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Stats

    private var statsRow: some View {
        HStack(spacing: ProfileLayout.statTileSpacing) {
            BlipStatTile(value: "\(profile.totalClips)", label: Copy.statClips)
            BlipStatTile(value: "\(profile.streakCurrent)", label: Copy.statStreak)
            BlipStatTile(value: "\(profile.friendsCount)", label: Copy.statFriends)
        }
    }

    // MARK: CTA

    @ViewBuilder
    private var cta: some View {
        switch state {
        case .self_:
            EmptyView()
        case .none:
            Button(Copy.ctaAdd, action: onSendRequest)
                .blipPrimary()
        case .requestSent:
            VStack(spacing: ProfileLayout.ctaStackSpacing) {
                Button(Copy.ctaRequested) {}
                    .blipSecondary()
                    .disabled(true)
                Button(Copy.ctaCancel, action: onCancel)
                    .blipGhost()
                    .frame(minWidth: ProfileLayout.minTap, minHeight: ProfileLayout.minTap)
            }
        case .requestReceived(let req):
            VStack(spacing: ProfileLayout.ctaStackSpacing) {
                Button(Copy.ctaAccept) { onAccept(req) }
                    .blipPrimary()
                Button(Copy.ctaIgnore) { onIgnore(req) }
                    .blipSecondary()
            }
        case .friends:
            Button(Copy.ctaUnfriend, action: onUnfriend)
                .blipSecondary()
        }
    }
}

// MARK: - Layout constants

private enum ProfileLayout {
    static let horizontalPadding: CGFloat = 20
    static let topPadding: CGFloat = 16
    static let bottomSpacer: CGFloat = 24

    static let sectionSpacing: CGFloat = 24
    static let headerInnerSpacing: CGFloat = 6
    static let handleFontSize: CGFloat = 28
    static let emptyStateSpacing: CGFloat = 12

    static let statTileSpacing: CGFloat = 10
    static let statTileInnerSpacing: CGFloat = 4
    static let statTilePadding: CGFloat = 14
    static let statValueFontSize: CGFloat = 22
    static let tileCornerRadius: CGFloat = 12

    static let ctaStackSpacing: CGFloat = 8
    static let minTap: CGFloat = 44
}

// MARK: - Copy (Lane A)

private enum Copy {
    static let notFound = "Couldn't find that user."
    static let statClips = "clips"
    static let statStreak = "streak"
    static let statFriends = "friends"
    static let ctaAdd = "Add friend"
    static let ctaRequested = "Requested"
    static let ctaCancel = "Cancel"
    static let ctaAccept = "Accept"
    static let ctaIgnore = "Ignore"
    static let ctaUnfriend = "Unfriend"
    static let unfriendConfirmTitle = "Remove this friend?"
}
