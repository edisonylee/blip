import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var repo: BlipRepository
    @EnvironmentObject private var deepLinks: DeepLinkRouter

    @State private var showPlusMenu = false
    @State private var creationDestination: CreationDestination?
    @State private var showProfile = false
    @State private var path = NavigationPath()
    @State private var pendingCaptureBlip: Blip?

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                BlipColor.background.ignoresSafeArea()

                VStack(spacing: 16) {
                    HomeHeader(
                        onProfile: { showProfile = true },
                        onPlus: { showPlusMenu = true }
                    )

                    #if DEBUG
                    HStack(spacing: 8) {
                        Text("debug:")
                        Text("uid=\(currentUid.prefix(6))")
                        Text("blips=\(repo.blips.count)")
                        if let err = repo.lastError {
                            Text("err=\(err)").foregroundStyle(.red).lineLimit(1)
                        }
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(BlipColor.textTertiary)
                    .padding(.horizontal, 20)
                    #endif

                    ScrollView {
                        VStack(spacing: 12) {
                            // Solo "vlog" (parity with screen-01) — placeholder until we model it as a real blip
                            BlipCard(
                                title: "vlog",
                                subtitle: "your space. each day runs 4am to 4am.",
                                progress: nil
                            )

                            ForEach(repo.blips) { blip in
                                NavigationLink(value: blip) {
                                    BlipCard(
                                        title: blip.name,
                                        subtitle: subtitleFor(blip),
                                        progress: mockProgress(for: blip)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 0)

                    BottomToggle()
                        .padding(.bottom, 12)
                }
                .padding(.top, 8)

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
        .onChange(of: deepLinks.pending) { _, action in
            handle(action)
        }
        .onAppear { handle(deepLinks.pending) }
    }

    /// Notification → navigation. Consumes the pending action so it fires once.
    private func handle(_ action: DeepLinkRouter.Action?) {
        guard let action else { return }
        switch action {
        case .openCapture:
            // Pick the first non-solo blip; if none, fall back to no-op (user has no blip yet).
            if let target = repo.blips.first {
                pendingCaptureBlip = target
            }
        case .openBlip(let id):
            if let blip = repo.blips.first(where: { $0.id == id }) {
                path = NavigationPath([blip])
            }
        }
        deepLinks.consume()
    }

    private var currentUid: String {
        if case .signedIn(let uid) = auth.state { return uid }
        return "—"
    }

    private func subtitleFor(_ blip: Blip) -> String {
        let count = blip.members.count
        return "\(count) of \(blip.size) member\(blip.size == 1 ? "" : "s")"
    }

    /// Mocked until clip data is wired in Phase B step 8.
    private func mockProgress(for blip: Blip) -> BlipCardProgress {
        BlipCardProgress(
            hourCompletion: 0,
            members: blip.members.map { uid in
                .init(id: uid, initials: String(uid.prefix(2)).uppercased(), hasPostedThisHour: false)
            },
            secondsToNextPrompt: secondsUntilNextHour()
        )
    }

    private func secondsUntilNextHour() -> Int {
        let now = Date()
        let calendar = Calendar.current
        guard let nextHour = calendar.nextDate(after: now, matching: DateComponents(minute: 0, second: 0), matchingPolicy: .nextTime) else {
            return 0
        }
        return Int(nextHour.timeIntervalSince(now))
    }
}

private enum CreationDestination: String, Identifiable {
    case create, join
    var id: String { rawValue }
}

private struct HomeHeader: View {
    let onProfile: () -> Void
    let onPlus: () -> Void
    var body: some View {
        HStack {
            Button(action: onProfile) {
                Image(systemName: "person.crop.circle")
                    .font(.title2)
                    .foregroundStyle(BlipColor.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(BlipColor.surface, in: Circle())
            }
            Spacer()
            Text("blip")
                .font(BlipTypography.wordmark)
                .foregroundStyle(BlipColor.accent)
            Spacer()
            Button(action: onPlus) {
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundStyle(BlipColor.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(BlipColor.surface, in: Circle())
            }
        }
        .padding(.horizontal, 20)
    }
}

private struct BottomToggle: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("camera")
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .foregroundStyle(BlipColor.textTertiary)
            Text("blips")
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .foregroundStyle(BlipColor.textPrimary)
                .background(BlipColor.surfaceElevated, in: Capsule())
        }
        .frame(width: 160, height: 36)
        .background(BlipColor.surface, in: Capsule())
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthService())
        .environmentObject(BlipRepository())
}
