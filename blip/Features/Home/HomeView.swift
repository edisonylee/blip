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
    @State private var activeTab: Tab = .blips

    enum Tab { case camera, blips, profile }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                BlipColor.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Home header (wordmark + plus) is blips-only chrome —
                    // the profile tab owns its own top bar (wordmark + share +
                    // overflow), so hide this when profile is active.
                    if activeTab != .profile {
                        HomeHeader(
                            onPlus: { showPlusMenu = true }
                        )
                        .padding(.top, 8)
                    }

                    // Two swipe pages — blips (default) and profile. Camera is
                    // a tap-to-launch button on the bottom toggle, not a page,
                    // so the existing fullScreenCover capture flow stays intact.
                    TabView(selection: $activeTab) {
                        blipsPage.tag(Tab.blips)
                        ProfileView().tag(Tab.profile)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    BottomToggle(active: $activeTab, onCamera: handleCameraTab)
                        .padding(.bottom, 20)
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
                if activeTab != .profile {
                    debugBadge
                }
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
                        .font(.blip(size: 26, weight: .bold, design: .rounded))
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
            LazyVStack(spacing: 0) {
                ForEach(Array(repo.blips.enumerated()), id: \.element.id) { index, blip in
                    NavigationLink(value: blip) {
                        BlipCard(
                            title: blip.name,
                            subtitle: vm.subtitle(for: blip),
                            memberCount: blip.members.count,
                            progress: vm.progress(for: blip)
                        )
                    }
                    .buttonStyle(.plain)

                    if index < repo.blips.count - 1 {
                        Divider()
                            .background(BlipColor.border)
                            .padding(.leading, 64) // align under name, iMessage-style
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Camera tab

    private func handleCameraTab() {
        // Snapchat-style global capture: always opens the camera surface.
        // Empty-blip users still record — the picker shows an empty state
        // prompting them to start a blip first.
        showGlobalCapture = true
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
    /// Defaults to "unlocked" when the profile hasn't streamed in yet so a
    /// fresh sign-in doesn't briefly show the locked state.
    private var canCreateBlip: Bool {
        let unlocked = users.profile?.unlockedBlipSlots ?? 1
        return repo.blips.count < unlocked
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

// MARK: - Header

private struct HomeHeader: View {
    let onPlus: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button(action: onPlus) {
                Image(systemName: "plus")
                    .font(.blip(size: 18, weight: .semibold))
                    .foregroundStyle(BlipColor.textPrimary)
                    .frame(minWidth: 44, minHeight: 44)
                    .background(BlipColor.surface, in: Circle())
            }
            .accessibilityLabel("create or join a blip")
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Bottom tab toggle

private struct BottomToggle: View {
    @Binding var active: HomeView.Tab
    let onCamera: () -> Void

    private static let buttonWidth: CGFloat = 90
    private static let height: CGFloat = 40

    var body: some View {
        HStack(spacing: 0) {
            // Camera doesn't paginate — it launches the global capture sheet.
            // Tap selects it visually for the moment of action and then the
            // sheet takes over; the page selection itself stays on whatever
            // page the user was on so swiping back lands where they left off.
            tabButton(label: "camera", tab: .camera) {
                onCamera()
            }
            tabButton(label: "blips", tab: .blips) {
                withAnimation(.easeOut(duration: 0.2)) { active = .blips }
            }
            tabButton(label: "profile", tab: .profile) {
                withAnimation(.easeOut(duration: 0.2)) { active = .profile }
            }
        }
        .frame(width: Self.buttonWidth * 3, height: Self.height)
        .background(BlipColor.surface, in: Capsule())
    }

    private func tabButton(label: String, tab: HomeView.Tab, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.blip(size: 14, weight: active == tab ? .semibold : .regular))
                .foregroundStyle(active == tab ? BlipColor.textPrimary : BlipColor.textTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: Self.height)
                .background(
                    active == tab
                        ? BlipColor.surfaceElevated.clipShape(Capsule())
                        : nil
                )
                .animation(.spring(duration: 0.25), value: active)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthService())
        .environmentObject(BlipRepository())
}
