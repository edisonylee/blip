import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var repo: BlipRepository
    @EnvironmentObject private var moderation: ModerationService
    @EnvironmentObject private var users: UserRepository
    @EnvironmentObject private var friendsRepo: FriendsRepository
    @EnvironmentObject private var deepLinks: DeepLinkRouter

    // Splash + onboarding flow state
    @State private var showSplash       = true
    @State private var showOnboarding   = false

    var body: some View {
        Group {
            #if DEBUG
            if ProcessInfo.processInfo.environment["BLIP_CAPTURE_ONLY"] == "1" {
                CaptureView(blip: Self.debugBlip, onPosted: {})
            } else {
                flowBody
            }
            #else
            flowBody
            #endif
        }
        .environment(\.font, BlipTypography.body)
    }

    // MARK: - Flow: Splash → Onboarding → Auth routing

    @ViewBuilder
    private var flowBody: some View {
        if showSplash {
            SplashView {
                showSplash = false
                if !OnboardingSlides.hasBeenSeen {
                    showOnboarding = true
                }
            }
        } else if showOnboarding {
            OnboardingSlides { showOnboarding = false }
        } else {
            authedBody
        }
    }

    @ViewBuilder
    private var authedBody: some View {
        switch auth.state {
        case .loading:
            loadingShell
        case .signedOut:
            OnboardingView()
        case .signedIn(let uid):
            authedRouting(uid: uid)
                .task(id: uid) {
                    let ref = deepLinks.consumePendingReferrerUid()
                    try? await users.ensureUserDoc(uid: uid, referredByUid: ref)
                    repo.startListening(for: uid)
                    moderation.startListening(for: uid)
                    users.startListening(for: uid)
                    friendsRepo.startListening(for: uid)
                }
        }
    }

    @ViewBuilder
    private func authedRouting(uid: String) -> some View {
        if let profile = users.profile {
            if let handle = profile.handle, !handle.isEmpty {
                HomeView()
            } else {
                ClaimHandleView()
            }
        } else {
            loadingShell
        }
    }

    private var loadingShell: some View {
        ProgressView()
            .controlSize(.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BlipColor.backgroundGradient.ignoresSafeArea())
    }

    #if DEBUG
    private static let debugBlip = Blip(
        id: "debug-blip",
        name: "Debug",
        ownerUid: "debug-uid",
        adminUids: ["debug-uid"],
        members: ["debug-uid"],
        size: 1,
        joinCode: "debug",
        inviteUrl: nil,
        timezoneIdentifier: TimeZone.current.identifier,
        activeStartHour: 4,
        activeEndHour: 4,
        createdAt: Date()
    )
    #endif
}
