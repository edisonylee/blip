import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var repo: BlipRepository
    @EnvironmentObject private var moderation: ModerationService
    @EnvironmentObject private var users: UserRepository

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
    }

    @ViewBuilder
    private var authedBody: some View {
        switch auth.state {
        case .loading:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(BlipColor.background)
        case .signedOut:
            OnboardingView()
        case .signedIn(let uid):
            HomeView()
                .task(id: uid) {
                    repo.startListening(for: uid)
                    moderation.startListening(for: uid)
                    users.startListening(for: uid)
                }
        }
    }

    #if DEBUG
    private static let debugBlip = Blip(
        id: "debug-blip",
        name: "Debug",
        ownerUid: "debug-uid",
        members: ["debug-uid"],
        size: 1,
        joinCode: "debug",
        inviteUrl: nil,
        timezoneIdentifier: TimeZone.current.identifier,
        createdAt: Date()
    )
    #endif
}
