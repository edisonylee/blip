import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var repo: BlipRepository
    @EnvironmentObject private var moderation: ModerationService

    var body: some View {
        Group {
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
                    }
            }
        }
    }
}
