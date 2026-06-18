import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var repo: BlipRepository
    @EnvironmentObject private var moderation: ModerationService
    @EnvironmentObject private var users: UserRepository
    @EnvironmentObject private var friendsRepo: FriendsRepository
    @EnvironmentObject private var deepLinks: DeepLinkRouter

    var body: some View {
        Group {
            #if DEBUG
            if ProcessInfo.processInfo.environment["BLIP_CAPTURE_ONLY"] == "1" {
                CaptureView(blip: Self.debugBlip, onPosted: {})
            } else {
                authedBody
            }
            #else
            authedBody
            #endif
        }
        // Default Geist for any Text without an explicit font (SwiftUI inherits
        // through the environment). Tokens like `BlipTypography.title` or
        // `Font.blip(...)` still override per call site.
        .environment(\.font, BlipTypography.body)
    }

    @ViewBuilder
    private var authedBody: some View {
        switch auth.state {
        case .loading:
            loadingShell
        case .signedOut:
            OnboardingView()
        case .signedIn(let uid):
            // The user-doc listener publishes `users.profile` asynchronously.
            // Until the first snapshot lands we render a spinner — that's also
            // why `ensureUserDoc` runs in `.task(id:)` rather than blocking
            // routing. Once the profile is available we gate on `handle`:
            // nil/empty → claim screen, populated → Home.
            authedRouting(uid: uid)
                .task(id: uid) {
                    // Consume any referrer uid stashed by an invite deep link
                    // before signup. `ensureUserDoc` only honours it on first
                    // create; subsequent sign-ins ignore (rules + trigger
                    // wouldn't let us re-credit anyway).
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
            .background(BlipColor.background)
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
