import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var repo: BlipRepository
    @EnvironmentObject private var deepLinks: DeepLinkRouter

    @StateObject private var vm = HomeViewModel()
    @State private var showPlusMenu = false
    @State private var creationDestination: CreationDestination?
    @State private var showProfile = false
    @State private var path = NavigationPath()
    @State private var pendingCaptureBlip: Blip?
    @State private var activeTab: Tab = .blips

    enum Tab { case camera, blips }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                BlipColor.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    HomeHeader(
                        onProfile: { showProfile = true },
                        onPlus: { showPlusMenu = true }
                    )
                    .padding(.top, 8)

                    if repo.isLoading && repo.blips.isEmpty {
                        Spacer()
                        ProgressView().tint(BlipColor.accent)
                        Spacer()
                    } else if repo.blips.isEmpty {
                        emptyState
                    } else {
                        blipList
                    }

                    Spacer(minLength: 0)

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
                        onDismiss: { showPlusMenu = false }
                    )
                }

                #if DEBUG
                debugBadge
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
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .fullScreenCover(item: $pendingCaptureBlip) { blip in
                NavigationStack {
                    CaptureView(blip: blip, onPosted: { pendingCaptureBlip = nil })
                }
            }
        }
        .onChange(of: deepLinks.pending) { _, action in handle(action) }
        .onAppear { handle(deepLinks.pending) }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("who's in your day?")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
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
            VStack(spacing: 12) {
                ForEach(repo.blips) { blip in
                    NavigationLink(value: blip) {
                        BlipCard(
                            title: blip.name,
                            subtitle: vm.subtitle(for: blip),
                            memberCount: blip.members.count,
                            progress: vm.progress(for: blip)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Camera tab

    private func handleCameraTab() {
        if let first = repo.blips.first {
            pendingCaptureBlip = first
        } else {
            creationDestination = .create
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
                        Text(err).foregroundStyle(.red).lineLimit(2)
                    }
                }
                .font(.system(size: 9, design: .monospaced))
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
        }
        deepLinks.consume()
    }

    private var currentUid: String { vm.currentUid(from: auth.state) }
}

private enum CreationDestination: String, Identifiable {
    case create, join
    var id: String { rawValue }
}

// MARK: - Header

private struct HomeHeader: View {
    let onProfile: () -> Void
    let onPlus: () -> Void

    var body: some View {
        HStack {
            Button(action: onProfile) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(BlipColor.textSecondary)
                    .frame(width: 40, height: 40)
            }
            Spacer()
            Button(action: onPlus) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(BlipColor.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(BlipColor.surface, in: Circle())
            }
            .accessibilityLabel("Create or join a blip")
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Bottom tab toggle

private struct BottomToggle: View {
    @Binding var active: HomeView.Tab
    let onCamera: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            tabButton(label: "camera", tab: .camera) {
                active = .camera
                onCamera()
            }
            tabButton(label: "blips", tab: .blips) {
                active = .blips
            }
        }
        .frame(width: 180, height: 40)
        .background(BlipColor.surface, in: Capsule())
    }

    private func tabButton(label: String, tab: HomeView.Tab, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: active == tab ? .semibold : .regular))
                .foregroundStyle(active == tab ? BlipColor.textPrimary : BlipColor.textTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
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
