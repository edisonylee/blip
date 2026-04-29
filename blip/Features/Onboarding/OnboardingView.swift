import AuthenticationServices
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var auth: AuthService

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Text("blip")
                    .font(BlipTypography.wordmark)
                    .foregroundStyle(BlipColor.accent)

                Text("a day with your people,\nstitched together.")
                    .font(BlipTypography.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                SignInWithAppleButton(
                    onRequest: { _ in },
                    onCompletion: { _ in }
                )
                .signInWithAppleButtonStyle(.white)
                .frame(height: 52)
                .cornerRadius(12)
                .padding(.horizontal, 24)
                .allowsHitTesting(false)
                .overlay(
                    Button {
                        Task { await auth.signInWithApple() }
                    } label: {
                        Color.clear
                    }
                )

                if let error = auth.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 24)
                }

                #if DEBUG
                Button("continue as guest (debug)") {
                    Task { await auth.signInAnonymously() }
                }
                .font(.caption)
                .foregroundStyle(BlipColor.textTertiary)
                #endif

                Spacer().frame(height: 24)
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AuthService())
}
