import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var repo: BlipRepository
    @EnvironmentObject private var users: UserRepository
    @EnvironmentObject private var deepLinks: DeepLinkRouter

    @StateObject private var vm = HomeViewModel()
    @StateObject private var clipUploader = ClipUploader()
    @StateObject private var requestsVM = RequestsViewModel()

    @State private var showPlusMenu = false
    @State private var creationDestination: CreationDestination?
    @State private var path = NavigationPath()
    @State private var pendingCaptureBlip: Blip?
    @State private var showGlobalCapture = false
    @State private var showReferralShare = false
    @State private var activeTab: Tab = .blips
    @State private var didOpenCameraOnLaunch = false

    // 4 navigable tabs — camera is the central raised button, not a tab page
    enum Tab { case blips, requests, friends, profile }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                BlipColor.backgroundGradient.ignoresSafeArea()

                VStack(spacing: 0) {
                    TabView(selection: $activeTab) {
                        blipsPage        .tag(Tab.blips)
                        RequestsView(vm: requestsVM).tag(Tab.requests)
                        FriendsView()    .tag(Tab.friends)
                        ProfileView()    .tag(Tab.profile)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    // 4-tab bar (NO camera inside — camera floats above as overlay)
                    smoothBar
                }

                // Camera bubble — half above bar, half inside.
                // Bar height = 64 pt.  Camera radius = 28 pt.
                // We want the camera CENTRE at the bar top edge, so
                //   camera bottom = 64 − 28 = 36 pt above safe-area bottom.
                VStack(spacing: 0) {
                    Spacer()
                    Button(action: handleCameraTab) {
                        ZStack {
                            // Thin ring acts as a visual separator between the
                            // content area above and the dark bar below.
                            Circle()
                                .stroke(BlipColor.backgroundGradient, lineWidth: 3)
                                .frame(width: 62, height: 62)
                            Circle()
                                .fill(BlipColor.accentNeutral)
                                .frame(width: 56, height: 56)
                                .shadow(color: BlipColor.accentNeutral.opacity(0.45),
                                        radius: 14, x: 0, y: -5)
                            Image(systemName: "camera.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(BlipColor.accentNeutralOn)
                        }
                    }
                    .buttonStyle(_ScalePress())
                    .accessibilityLabel("open camera")
                    // 36 pt from safe-area bottom → camera centre at bar top edge
                    .padding(.bottom, 36)
                }

                // Plus FAB — bottom-right corner, above bar
                VStack(spacing: 0) {
                    Spacer()
                    HStack(spacing: 0) {
                        Spacer()
                        if activeTab == .blips || activeTab == .requests {
                            plusFAB
                                .padding(.trailing, 20)
                                .padding(.bottom, 76)
                                .transition(.scale(scale: 0.75).combined(with: .opacity))
                        }
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: activeTab)

                // Plus popover — right-aligned
                if showPlusMenu {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                showPlusMenu = false
                            }
                        }
                    VStack(spacing: 0) {
                        Spacer()
                        HStack(spacing: 0) {
                            Spacer()
                            PlusPopover(
                                onCreate: { showPlusMenu = false; creationDestination = .create },
                                onJoin:   { showPlusMenu = false; creationDestination = .join },
                                onDismiss: {
                                    withAnimation(.spring(response: 0.25)) { showPlusMenu = false }
                                },
                                canCreate: canCreateBlip,
                                referralsToNextSlot: users.profile?.referralsToNextSlot ?? 4,
                                onLockedTap: { showPlusMenu = false; showReferralShare = true }
                            )
                            .padding(.trailing, 20)
                            .padding(.bottom, 158)
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .bottomTrailing)))
                    .animation(.spring(response: 0.28, dampingFraction: 0.82), value: showPlusMenu)
                }

                #if DEBUG
                if activeTab != .profile { debugBadge }
                #endif
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Blip.self) { blip in BlipDetailView(blip: blip) }
            .sheet(item: $creationDestination) { dest in
                switch dest {
                case .create: CreateBlipView()
                case .join:   JoinBlipView()
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
                    CaptureGlobalView(uid: uid, uploader: clipUploader,
                                      onSent: { showGlobalCapture = false })
                        .environmentObject(repo)
                }
            }
        }
        .onChange(of: deepLinks.pending) { _, action in handle(action) }
        .onAppear {
            handle(deepLinks.pending)
            if let uid = currentUid { requestsVM.startListening(uid: uid) }
            // Open camera on first home-screen appear (camera is the default action)
            if !didOpenCameraOnLaunch {
                didOpenCameraOnLaunch = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showGlobalCapture = true
                }
            }
        }
        .onChange(of: currentUid) { _, uid in
            if let uid { requestsVM.startListening(uid: uid) }
        }
    }

    // MARK: - Plus FAB

    private var plusFAB: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                showPlusMenu = true
            }
        } label: {
            ZStack {
                Circle()
                    .fill(BlipColor.accentNeutral)
                    .frame(width: 52, height: 52)
                    .shadow(color: BlipColor.accentNeutral.opacity(0.45), radius: 16, x: 0, y: 6)
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(BlipColor.accentNeutralOn)
            }
        }
        .buttonStyle(_ScalePress())
        .accessibilityLabel("create or join a blip")
    }

    // MARK: - Smooth bar (raised camera bubble)

    private var smoothBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(BlipColor.navBackground.opacity(0.2))
                .frame(height: 0.5)
            SmoothBottomBar(
                active: $activeTab,
                requestBadge: requestsVM.pendingCount
            )
        }
        .background { BlipColor.navBackground.ignoresSafeArea(edges: .bottom) }
    }

    // MARK: - Blips page

    @ViewBuilder
    private var blipsPage: some View {
        if repo.isLoading && repo.blips.isEmpty {
            VStack { Spacer(); ProgressView().tint(BlipColor.accent); Spacer() }
        } else if repo.blips.isEmpty {
            emptyState
        } else {
            blipList
        }
    }

    private var homeHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("blip.")
                    .font(BlipTypography.title)
                    .foregroundStyle(BlipColor.textPrimary)
                Text("\(repo.blips.count) group\(repo.blips.count == 1 ? "" : "s")")
                    .font(.blip(size: 13))
                    .foregroundStyle(BlipColor.textTertiary)
            }
            Spacer()
            Button { } label: {
                Image(systemName: "bell")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(BlipColor.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(BlipColor.surface.opacity(0.8), in: Circle())
                    .shadow(color: BlipColor.accent.opacity(0.12), radius: 6, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var blipList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                homeHeader
                LazyVStack(spacing: 14) {
                    ForEach(repo.blips) { blip in
                        NavigationLink(value: blip) {
                            BlipCard(title: blip.name,
                                     cardColor: vm.cardColor(for: blip),
                                     members: vm.cardMembers(for: blip))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("who's in\nyour day?")
                        .font(BlipTypography.title)
                        .foregroundStyle(BlipColor.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("start a blip with friends — every hour,\nyou each post 2 seconds of your day.")
                        .font(BlipTypography.body)
                        .foregroundStyle(BlipColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 32)
                VStack(spacing: 10) {
                    Button("start a blip") { creationDestination = .create }.blipPrimary()
                    Button("join one")      { creationDestination = .join  }.blipSecondary()
                }
                .padding(.horizontal, 32)
            }
            Spacer()
        }
    }

    // MARK: - Camera

    private func handleCameraTab() { showGlobalCapture = true }

    // MARK: - Debug badge

    private var debugBadge: some View {
        VStack {
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("uid \(currentUid?.prefix(6) ?? "—")")
                    Text("blips \(repo.blips.count)")
                    if let err = repo.lastError {
                        Text(err).foregroundStyle(BlipColor.error).lineLimit(2)
                    }
                }
                .font(.blip(size: 9, design: .monospaced))
                .foregroundStyle(BlipColor.textTertiary.opacity(0.6))
                .padding(6)
                .background(BlipColor.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
                .padding(.trailing, 8).padding(.top, 4)
            }
            Spacer()
        }
    }

    // MARK: - Deep link + helpers

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
            if let me = currentUid, me != referrerUid {
                Task { try? await users.claimReferral(referrerUid) }
            }
        }
        deepLinks.consume()
    }

    private var currentUid: String? {
        if case .signedIn(let uid) = auth.state { return uid }
        return nil
    }

    private var canCreateBlip: Bool {
        guard let me = currentUid else { return false }
        let unlocked = users.profile?.unlockedBlipSlots ?? 1
        return repo.blips.filter { $0.ownerUid == me }.count < unlocked
    }

    private var referralShareText: String {
        if let url = InviteShare.inviteURL(referrerUid: currentUid) {
            return "on blip with me — \(url.absoluteString)"
        }
        return "on blip with me"
    }
}

private enum CreationDestination: String, Identifiable {
    case create, join
    var id: String { rawValue }
}

// MARK: - Smooth Bottom Bar ─────────────────────────────────────────────────
//
// 4 equal tabs: [blips] [requests] [gap] [friends] [me]
// The transparent centre gap (68 pt) reserves visual space for the camera
// bubble that floats ABOVE the bar as a separate ZStack overlay in HomeView.
// Each tab shows its icon always; the active tab's label slides in to the
// right inside a RoundedRectangle pill (cornerRadius 14).

private struct SmoothBottomBar: View {
    @Binding var active: HomeView.Tab
    let requestBadge: Int

    // Camera bubble diameter used only to size the centre gap
    private let camD: CGFloat = 56

    var body: some View {
        HStack(spacing: 0) {
            navTab(.blips,    "play.square.stack", "blips")
            navTab(.requests, "bell",              "inbox",  badge: requestBadge)
            // Transparent gap where the camera button floats above
            Color.clear.frame(width: camD + 12)
            navTab(.friends,  "person.2",          "friends")
            navTab(.profile,  "person",             "me")
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
    }

    // MARK: Nav tab (icon always visible, label reveals on active)

    private func navTab(
        _ tab: HomeView.Tab, _ icon: String, _ label: String, badge: Int = 0
    ) -> some View {
        let on = active == tab
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) { active = tab }
        } label: {
            HStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: on ? "\(icon).fill" : icon)
                        .font(.system(size: 19, weight: on ? .bold : .medium))
                        .foregroundStyle(on ? BlipColor.navForeground
                                            : BlipColor.navForegroundInactive)
                    if badge > 0 {
                        ZStack {
                            Circle().fill(BlipColor.error).frame(width: 14, height: 14)
                            Text(badge < 10 ? "\(badge)" : "9+")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .offset(x: 9, y: -5)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 22, height: 22)

                if on {
                    Text(label)
                        .font(.blip(size: 11, weight: .bold))
                        .foregroundStyle(BlipColor.navForeground)
                        .fixedSize()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(x: -8)),
                            removal:   .opacity.combined(with: .offset(x: -8))
                        ))
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(on ? BlipColor.accent.opacity(0.22) : .clear)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: on)
    }
}

// MARK: - Press style

private struct _ScalePress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.91 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthService())
        .environmentObject(BlipRepository())
}
