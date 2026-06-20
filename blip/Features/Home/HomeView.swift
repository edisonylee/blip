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
                // Pastel gradient fills the entire root canvas.
                BlipColor.backgroundGradient.ignoresSafeArea()

                // ── Main layout ──────────────────────────────────────────
                VStack(spacing: 0) {
                    TabView(selection: $activeTab) {
                        blipsPage.tag(Tab.blips)
                        ProfileView().tag(Tab.profile)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    // Full-width smooth bar (no FAB inside)
                    smoothBar
                }

                // ── Plus FAB — floats ABOVE the bar, centered ────────────
                VStack(spacing: 0) {
                    Spacer()
                    if activeTab == .blips {
                        plusFAB
                            .padding(.bottom, 76) // sits ~12pt above the 64pt bar
                            .transition(.scale(scale: 0.75).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: activeTab)

                // ── Plus popover ─────────────────────────────────────────
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
                        PlusPopover(
                            onCreate: { showPlusMenu = false; creationDestination = .create },
                            onJoin:   { showPlusMenu = false; creationDestination = .join },
                            onDismiss: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                    showPlusMenu = false
                                }
                            },
                            canCreate: canCreateBlip,
                            referralsToNextSlot: users.profile?.referralsToNextSlot ?? 4,
                            onLockedTap: { showPlusMenu = false; showReferralShare = true }
                        )
                        .padding(.horizontal, 20)
                        // 158 pt keeps the popover clearly above the FAB (top at ≈128 pt)
                        .padding(.bottom, 158)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .bottom)))
                    .animation(.spring(response: 0.28, dampingFraction: 0.82), value: showPlusMenu)
                }

                #if DEBUG
                if activeTab != .profile { debugBadge }
                #endif
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Blip.self) { blip in
                BlipDetailView(blip: blip)
            }
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

    // MARK: - Plus FAB (outside the bar)

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
                    .shadow(color: .black.opacity(0.28), radius: 16, x: 0, y: 6)
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(BlipColor.accentNeutralOn)
            }
        }
        .buttonStyle(_ScalePress())
        .accessibilityLabel("create or join a blip")
    }

    // MARK: - Smooth bar container (separator + SmoothBottomBar)

    private var smoothBar: some View {
        VStack(spacing: 0) {
            // Feather the gradient into the dark nav tray
            Rectangle()
                .fill(BlipColor.navBackground.opacity(0.18))
                .frame(height: 0.5)
            SmoothBottomBar(active: $activeTab, onCamera: handleCameraTab)
        }
        .background {
            BlipColor.navBackground.ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Blips page

    @ViewBuilder
    private var blipsPage: some View {
        if repo.isLoading && repo.blips.isEmpty {
            VStack { Spacer(); ProgressView().tint(BlipColor.textPrimary); Spacer() }
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
                            BlipCard(
                                title: blip.name,
                                cardColor: vm.cardColor(for: blip),
                                members: vm.cardMembers(for: blip)
                            )
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
            if case .signedIn(let me) = auth.state, me != referrerUid {
                Task { try? await users.claimReferral(referrerUid) }
            }
        }
        deepLinks.consume()
    }

    private var currentUid: String { vm.currentUid(from: auth.state) }

    // MARK: - Referral gate

    private var canCreateBlip: Bool {
        guard case .signedIn(let me) = auth.state else { return false }
        let unlocked = users.profile?.unlockedBlipSlots ?? 1
        let createdCount = repo.blips.filter { $0.ownerUid == me }.count
        return createdCount < unlocked
    }

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

// MARK: - Smooth Bottom Bar ──────────────────────────────────────────────────
//
// Replicates the Android SmoothBottomBar sliding-indicator concept in SwiftUI:
// a spring-animated capsule glides along the bar to the active tab, while
// icon + label crossfade between filled/bold (active) and ghost/medium (inactive).
//
// Layout: three equal columns — [blips] [camera] [me].
// The sliding capsule only shows for blips/profile (camera is a white circle).

private struct SmoothBottomBar: View {
    @Binding var active: HomeView.Tab
    let onCamera: () -> Void

    var body: some View {
        GeometryReader { geo in
            let colW = geo.size.width / 3

            ZStack(alignment: .center) {
                // ── Sliding pill indicator ───────────────────────────────
                // Moves between column centers via .offset; spring gives the
                // "smooth glide" that defines this bar style.
                if active != .camera {
                    Capsule()
                        .fill(BlipColor.accent.opacity(0.22))
                        .frame(width: colW * 0.72, height: 42)
                        .offset(x: pillOffset(colW: colW))
                        .animation(
                            .spring(response: 0.38, dampingFraction: 0.72),
                            value: active
                        )
                }

                // ── Icon + label row ─────────────────────────────────────
                HStack(spacing: 0) {
                    navTab(
                        tab: .blips,
                        activeIcon: "play.square.stack.fill",
                        inactiveIcon: "play.square.stack",
                        label: "blips",
                        colW: colW
                    )
                    cameraTab(colW: colW)
                    navTab(
                        tab: .profile,
                        activeIcon: "person.fill",
                        inactiveIcon: "person",
                        label: "me",
                        colW: colW
                    )
                }
            }
        }
        .frame(height: 64)
    }

    // Column-center offset from the ZStack mid-point.
    // Column 0 → −colW, Column 1 → 0, Column 2 → +colW
    private func pillOffset(colW: CGFloat) -> CGFloat {
        switch active {
        case .blips:   return -colW
        case .camera:  return 0
        case .profile: return  colW
        }
    }

    // MARK: Nav tab item

    private func navTab(
        tab: HomeView.Tab,
        activeIcon: String,
        inactiveIcon: String,
        label: String,
        colW: CGFloat
    ) -> some View {
        let on = active == tab
        return Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) { active = tab }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: on ? activeIcon : inactiveIcon)
                    .font(.system(size: 21, weight: on ? .bold : .medium))
                    .foregroundStyle(on ? BlipColor.navForeground : BlipColor.navForegroundInactive)
                    .scaleEffect(on ? 1.06 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: on)

                Text(label)
                    .font(.blip(size: 10, weight: on ? .bold : .medium))
                    .foregroundStyle(on ? BlipColor.navForeground : BlipColor.navForegroundInactive)
            }
            .frame(width: colW)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Camera tab (accent circle — pops against the dark tray)

    private func cameraTab(colW: CGFloat) -> some View {
        Button(action: onCamera) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(BlipColor.accentNeutral)
                        .frame(width: 44, height: 44)
                        .shadow(color: BlipColor.accentNeutral.opacity(0.4), radius: 8, x: 0, y: 2)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(BlipColor.accentNeutralOn)
                }
                Text("camera")
                    .font(.blip(size: 10, weight: .medium))
                    .foregroundStyle(BlipColor.navForegroundInactive)
            }
            .frame(width: colW)
        }
        .buttonStyle(_ScalePress())
        .accessibilityLabel("open camera")
    }
}

// MARK: - Shared press style

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
