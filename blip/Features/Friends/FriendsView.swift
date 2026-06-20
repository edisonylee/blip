import SwiftUI

// MARK: - Shell

struct FriendsView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var friendsRepo: FriendsRepository
    @EnvironmentObject private var friendsService: FriendsService

    var body: some View {
        FriendsContent(
            currentUid: currentUid,
            friendsService: friendsService,
            friendsRepo: friendsRepo
        )
    }

    private var currentUid: String? {
        if case .signedIn(let uid) = auth.state { return uid }
        return nil
    }
}

// MARK: - Content

private struct FriendsContent: View {

    let currentUid: String?

    @StateObject private var vm: UserBrowserViewModel
    @ObservedObject private var friendsRepo: FriendsRepository
    @State private var searchText = ""

    init(currentUid: String?, friendsService: any FriendMutating, friendsRepo: FriendsRepository) {
        self.currentUid = currentUid
        _vm = StateObject(wrappedValue: UserBrowserViewModel(friendsService: friendsService))
        self.friendsRepo = friendsRepo
    }

    var body: some View {
        ZStack {
            BlipColor.backgroundGradient.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0, pinnedViews: []) {

                    // ── Page header ──────────────────────────────────────
                    pageHeader

                    // ── Search bar (sticky-feel, non-scrolling position) ─
                    searchBar
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                    // ── Friend requests (compact inline section) ─────────
                    if !friendsRepo.incomingRequests.isEmpty {
                        requestsSection
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                    }

                    // ── Section label ─────────────────────────────────────
                    HStack {
                        Text(searchText.isEmpty ? "people" : "results")
                            .font(.blip(size: 11, weight: .semibold))
                            .foregroundStyle(BlipColor.textTertiary)
                            .textCase(.uppercase)
                            .tracking(0.8)
                        Spacer()
                        if !vm.users.isEmpty {
                            Text("\(vm.users.count)")
                                .font(.blip(size: 11))
                                .foregroundStyle(BlipColor.textTertiary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)

                    // ── Paginated user list ──────────────────────────────
                    if vm.isLoading && vm.users.isEmpty {
                        ProgressView()
                            .tint(BlipColor.accent)
                            .padding(.top, 48)
                    } else if vm.users.isEmpty {
                        emptyState
                    } else {
                        userList
                    }

                    // ── Error ────────────────────────────────────────────
                    if let err = vm.errorMessage {
                        Text(err)
                            .font(.blip(size: 12))
                            .foregroundStyle(BlipColor.error)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .task {
            await vm.loadFirstPage(excludeUid: currentUid ?? "")
        }
        .onChange(of: searchText) { _, text in
            vm.search(prefix: text, excludeUid: currentUid ?? "")
        }
    }

    // MARK: - Page header

    private var pageHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("people")
                    .font(BlipTypography.title)
                    .foregroundStyle(BlipColor.textPrimary)
                Text("find friends · send requests")
                    .font(.blip(size: 13))
                    .foregroundStyle(BlipColor.textTertiary)
            }
            Spacer()
            // Incoming request badge
            if !friendsRepo.incomingRequests.isEmpty {
                ZStack {
                    Circle()
                        .fill(BlipColor.error)
                        .frame(width: 26, height: 26)
                    Text(friendsRepo.incomingRequests.count < 10
                         ? "\(friendsRepo.incomingRequests.count)"
                         : "9+")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(BlipColor.textTertiary)

            TextField("username or @handle", text: $searchText)
                .font(.blip(size: 15))
                .foregroundStyle(BlipColor.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.search)

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(BlipColor.textTertiary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(BlipColor.surface,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: BlipColor.accent.opacity(0.07), radius: 6, x: 0, y: 2)
        .animation(.spring(response: 0.28), value: searchText.isEmpty)
    }

    // MARK: - Incoming friend requests (compact)

    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("friend requests")
                .font(.blip(size: 11, weight: .semibold))
                .foregroundStyle(BlipColor.textTertiary)
                .textCase(.uppercase)
                .tracking(0.8)

            ForEach(friendsRepo.incomingRequests) { req in
                FriendRequestRow(
                    fromUid: req.fromUid,
                    onAccept: {
                        Task { try? await friendsService.acceptRequest(req) }
                    },
                    onIgnore: {
                        Task { try? await friendsService.rejectRequest(req) }
                    }
                )
            }
        }
    }

    // MARK: - User list + bottom pagination loader

    private var userList: some View {
        LazyVStack(spacing: 10) {
            ForEach(vm.users) { user in
                UserBrowseCard(
                    user: user,
                    state: cardState(for: user),
                    onAdd: { Task { await vm.sendRequest(toUid: user.id) } }
                )
                .padding(.horizontal, 20)
                .onAppear {
                    // Load next page when the last visible item appears
                    if user.id == vm.users.last?.id {
                        Task { await vm.loadNextPage(excludeUid: currentUid ?? "") }
                    }
                }
            }

            // Circular bottom loader
            if vm.isLoadingMore {
                VStack(spacing: 8) {
                    ProgressView()
                        .tint(BlipColor.accent)
                        .scaleEffect(1.1)
                    Text("loading more…")
                        .font(.blip(size: 11))
                        .foregroundStyle(BlipColor.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else if !vm.hasMore && !vm.users.isEmpty && searchText.isEmpty {
                Text("you've seen everyone 👋")
                    .font(.blip(size: 12))
                    .foregroundStyle(BlipColor.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: searchText.isEmpty ? "person.2" : "magnifyingglass")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(BlipColor.textTertiary)
                .padding(.top, 48)
            Text(searchText.isEmpty ? "no users yet" : "no results for "\(searchText)"")
                .font(BlipTypography.body)
                .foregroundStyle(BlipColor.textPrimary)
            if !searchText.isEmpty {
                Text("try a different handle")
                    .font(.blip(size: 13))
                    .foregroundStyle(BlipColor.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 40)
    }

    // MARK: - Card state

    private enum CardState { case addable, pending, friends }

    private func cardState(for user: BlipUser) -> CardState {
        if friendsRepo.friends.contains(user.id) { return .friends }
        if friendsRepo.outgoingRequests.contains(where: { $0.toUid == user.id }) { return .pending }
        if vm.justSentUids.contains(user.id) { return .pending }
        return .addable
    }
}

// MARK: - User browse card

private struct UserBrowseCard: View {
    let user: BlipUser
    let state: _State
    let onAdd: () -> Void

    enum _State { case addable, pending, friends }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            AvatarView(
                initials: initials,
                hasPosted: false,
                size: 44
            )

            // Handle + uid snippet
            VStack(alignment: .leading, spacing: 2) {
                Text(user.handle.map { "@\($0)" } ?? "unnamed")
                    .font(.blip(size: 15, weight: .semibold))
                    .foregroundStyle(BlipColor.textPrimary)
                    .lineLimit(1)
                Text(String(user.id.prefix(8)))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(BlipColor.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            // Action
            actionButton
        }
        .padding(14)
        .background(BlipColor.surface,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: BlipColor.accent.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    @ViewBuilder
    private var actionButton: some View {
        switch state {
        case .addable:
            Button(action: onAdd) {
                Text("add")
                    .font(.blip(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(BlipColor.accentNeutral,
                                in: Capsule())
            }
            .buttonStyle(_ScalePress())

        case .pending:
            Text("pending")
                .font(.blip(size: 12, weight: .medium))
                .foregroundStyle(BlipColor.textTertiary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(BlipColor.surface,
                            in: Capsule())
                .overlay(Capsule().stroke(BlipColor.border, lineWidth: 1))

        case .friends:
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                Text("friends")
                    .font(.blip(size: 12, weight: .semibold))
            }
            .foregroundStyle(Color(red: 0.2, green: 0.78, blue: 0.45))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(red: 0.2, green: 0.78, blue: 0.45).opacity(0.12),
                        in: Capsule())
        }
    }

    private var initials: String {
        guard let h = user.handle, !h.isEmpty else { return "?" }
        return String(h.prefix(2)).uppercased()
    }
}

// MARK: - Compact friend request row

private struct FriendRequestRow: View {
    let fromUid: String
    let onAccept: () -> Void
    let onIgnore: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(initials: String(fromUid.prefix(2)).uppercased(),
                       hasPosted: false, size: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text("friend request")
                    .font(.blip(size: 14, weight: .semibold))
                    .foregroundStyle(BlipColor.textPrimary)
                Text(String(fromUid.prefix(8)))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(BlipColor.textTertiary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: onIgnore) {
                    Text("ignore")
                        .font(.blip(size: 12, weight: .semibold))
                        .foregroundStyle(BlipColor.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(BlipColor.surface, in: Capsule())
                        .overlay(Capsule().stroke(BlipColor.border, lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button(action: onAccept) {
                    Text("accept")
                        .font(.blip(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(BlipColor.accentNeutral, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(BlipColor.surface,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: BlipColor.accent.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Press style (local)

private struct _ScalePress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6),
                       value: configuration.isPressed)
    }
}
