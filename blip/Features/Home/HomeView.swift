import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var repo: BlipRepository
    @EnvironmentObject private var users: UserRepository
    @EnvironmentObject private var deepLinks: DeepLinkRouter

    @StateObject private var vm = HomeViewModel()
    @StateObject private var clipUploader = ClipUploader()
    @State private var showPlusMenu = false
    @State private var creationDestination: CreationDestination?
    @State private var path = NavigationPath()
    @State private var pendingCaptureBlip: Blip?
    @State private var showGlobalCapture = false
    @State private var showReferralShare = false
    @State private var activeTab: BlipTabBar.Tab = .home

    /// Intercepts camera taps so they launch the capture sheet instead of
    /// switching pages — camera has never been a swipe page.
    private var tabBarSelection: Binding<BlipTabBar.Tab> {
        Binding(
            get: { activeTab },
            set: { tab in
                if tab == .camera {
                    showGlobalCapture = true
                } else {
                    withAnimation(.easeOut(duration: 0.2)) { activeTab = tab }
                }
            }
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                BlipColor.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    if activeTab != .profile {
                        BlipHomeHeader(
                            onPlus: { showPlusMenu = true },
                            onBell: {}
                        )
                        .padding(.top, BlipSpacing.sm)
                        .padding(.bottom, BlipSpacing.lg)
                    }

                    TabView(selection: $activeTab) {
                        blipsPage.tag(BlipTabBar.Tab.home)
                        ProfileView().tag(BlipTabBar.Tab.profile)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }

                if showPlusMenu {
                    PlusPopover(
                        onCreate: {
                            showPlusMenu = false
                            creationDestination = .create
                        },
                        onJoin: {
                            showPlusMenu = false
                            creationDestination = .join
                        },
                        onDismiss: { showPlusMenu = false },
                        canCreate: canCreateBlip,
                        referralsToNextSlot: users.profile?.referralsToNextSlot ?? 4,
                        onLockedTap: {
                            showPlusMenu = false
                            showReferralShare = true
                        }
                    )
                }

                #if DEBUG
                if activeTab != .profile { debugBadge }
                #endif
            }
            .navigationDestination(for: Blip.self) { blip in
                BlipDetailView(blip: blip)
            }
            .sheet(item: $creationDestination) { dest in
                switch dest {
                case .create: CreateBlipView()
                case .join: JoinBlipView()
                }
            }
            .sheet(isPresented: $showReferralShare) {
                ShareSheet(activityItems: [referralShareText])
            }
            .fullScreenCover(item: $pendingCaptureBlip) { blip in
                NavigationStack {
                    CaptureView(blip: blip, onPosted: { pendingCaptureBlip = nil })
                }
            }
            .fullScreenCover(isPresented: $showGlobalCapture) {
                if case .signedIn(let uid) = auth.state {
                    CaptureGlobalView(
                        uid: uid,
                        uploader: clipUploader,
                        onSent: { showGlobalCapture = false }
                    )
                    .environmentObject(repo)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BlipTabBar(selection: tabBarSelection)
        }
        .onChange(of: deepLinks.pending) { _, action in handle(action) }
        .onAppear { handle(deepLinks.pending) }
    }

    // MARK: - Blips page (default landing tab)

    @ViewBuilder
    private var blipsPage: some View {
        if repo.isLoading && repo.blips.isEmpty {
            VStack {
                Spacer()
                ProgressView().tint(BlipColor.textPrimary)
                Spacer()
            }
        } else if repo.blips.isEmpty {
            emptyState
        } else {
            blipList
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("who's in your day?")
                        .font(BlipTypography.title)
                        .foregroundStyle(BlipColor.textPrimary)
                    Text("start a blip with friends — every hour,\nyou each post 2 seconds of your day.")
                        .font(BlipTypography.body)
                        .foregroundStyle(BlipColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 32)

                VStack(spacing: 10) {
                    Button("start a blip") { creationDestination = .create }
                        .blipPrimary()

                    Button("join one") { creationDestination = .join }
                        .blipSecondary()
                }
                .padding(.horizontal, 32)
            }
            Spacer()
        }
    }

    // MARK: - Blip list

    private var blipList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: BlipSpacing.sm) {
                ForEach(repo.blips) { blip in
                    NavigationLink(value: blip) {
                        BlipCard(
                            title: blip.name,
                            cardColor: vm.cardColor(for: blip),
                            members: vm.cardMembers(for: blip)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, BlipSpacing.lg)
            .padding(.top, BlipSpacing.xs)
            .padding(.bottom, BlipSpacing.sm)
        }
    }

    // MARK: - Debug badge (debug builds only)

    private var debugBadge: some View {
        VStack {
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("uid \(currentUid.prefix(6))")
                    Text("blips \(repo.blips.count)")
                    if let err = repo.lastError {
                        Text(err).foregroundStyle(BlipColor.error).lineLimit(2)
                    }
                }
                .font(.blip(size: 9, design: .monospaced))
                .foregroundStyle(BlipColor.textTertiary.opacity(0.6))
                .padding(6)
                .background(BlipColor.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
                .padding(.trailing, 8)
                .padding(.top, 4)
            }
            Spacer()
        }
    }

    // MARK: - Deep link

    private func handle(_ action: DeepLinkRouter.Action?) {
        guard let action else { return }
        switch action {
        case .openCapture:
            if let target = repo.blips.first { pendingCaptureBlip = target }
        case .openBlip(let id):
            if let blip = repo.blips.first(where: { $0.id == id }) {
                path = NavigationPath([blip])
            }
        case .invite(let referrerUid):
            // First-sign-in path is covered by RootView's `consumePendingReferrerUid`
            // → `ensureUserDoc` → `onUserCreated` trigger. This branch covers the
            // after-sign-in path: an already-signed-in user taps a referral link,
            // so we credit the referrer via the `claimReferral` callable. Server
            // rejects self-loop, missing referrer, and already-credited cases.
            if case .signedIn(let me) = auth.state, me != referrerUid {
                Task { try? await users.claimReferral(referrerUid) }
            }
        }
        deepLinks.consume()
    }

    private var currentUid: String { vm.currentUid(from: auth.state) }

    // MARK: - Referral gate

    /// `true` while the user still has at least one unused blipchat slot.
    /// Slots only constrain *creation* — joining via invite is unlimited.
    /// Defaults to "unlocked" when the profile hasn't streamed in yet so a
    /// fresh sign-in doesn't briefly show the locked state.
    private var canCreateBlip: Bool {
        guard case .signedIn(let me) = auth.state else { return false }
        let unlocked = users.profile?.unlockedBlipSlots ?? 1
        let createdCount = repo.blips.filter { $0.ownerUid == me }.count
        return createdCount < unlocked
    }

    /// Locked-state share text — only the personal referral URL is needed
    /// since there's no specific blip to invite into. If uid isn't yet known,
    /// fall back to a bare prompt so the share sheet still opens.
    private var referralShareText: String {
        let uid: String? = {
            if case .signedIn(let id) = auth.state { return id }
            return nil
        }()
        if let url = InviteShare.inviteURL(referrerUid: uid) {
            return "on blip with me — \(url.absoluteString)"
        }
        return "on blip with me"
    }
}

private enum CreationDestination: String, Identifiable {
    case create, join
    var id: String { rawValue }
}


#Preview {
    HomeView()
        .environmentObject(AuthService())
        .environmentObject(BlipRepository())
}
