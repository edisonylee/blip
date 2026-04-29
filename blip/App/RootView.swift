import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthService

    var body: some View {
        switch auth.state {
        case .loading:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
        case .signedOut:
            OnboardingView()
        case .signedIn:
            HomeView()
        }
    }
}
